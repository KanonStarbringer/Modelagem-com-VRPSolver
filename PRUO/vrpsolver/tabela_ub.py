"""Linhas da tab:bpc-ub (BPC com melhor limitante e --ub = Hexaly 1 h + 0,01), no formato da tab:bpc,
e o quadro final da melhor solução conhecida (melhor UB e melhor LB entre todas as rodadas).
Sem UB próprio (o BPC não achou nada abaixo do cutoff), o gap usa a solução do Hexaly.
Uso: python -X utf8 tabela_ub.py
"""
import glob, re
from collections import defaultdict

PAT = r'statistics: (\S+) & (\d) & \S+ & (\S+) & \S+ & (\S+) & (\S+) & (\S+) & (\S+)'
num = lambda x: None if x == '--' else float(x)

def stats(arq):
    return {m[0]: (m[1] == '1', float(m[2]), int(m[3]), float(m[4]), num(m[5]), float(m[6]))
            for m in re.findall(PAT, open(arq, encoding='utf-8', errors='ignore').read())}

hexa = {}
for n in (25, 50, 100):
    for l in open(f'saida_hexaly{n}.txt', encoding='utf-8'):
        c = l.split(';')
        if c[0] == 'HEXALY':
            hexa[c[1]] = float(c[3])

ub_run = stats('saida_bench_ub.txt')
grupo = lambda k: (lambda m: (int(m[2]), m[1][-1], int(m[3])))(re.match(r'bench_([A-Z]+)_n(\d+)_c(\d)', k))

G = defaultdict(list)
for k, (opt, rdb, nos, lb, ub, t) in ub_run.items():
    u = min(x for x in (ub, hexa[k]) if x is not None)
    G[grupo(k)].append((opt, t if opt else 3600.0, None if opt else 100 * (u - lb) / u,
                        100 * (u - rdb) / u, nos, t + 3600.0 if opt else 7200.0))
print('% tab:bpc-ub: n & janela & C_t & opt/inst & tempo BPC & gap abertas & gap raiz & nós & tempo total')
for g in sorted(G):
    L = G[g]
    ab = [x[2] for x in L if not x[0]]
    m = lambda i: sum(x[i] for x in L) / len(L)
    gab = f'{sum(ab) / len(ab):.2f}' if ab else '--'
    print(f'{g[0]} & {g[1]} & {g[2]} & {sum(x[0] for x in L)}/{len(L)} & {m(1):.1f} & {gab} & '
          f'{m(3):.2f} & {m(4):.0f} & {m(5):.0f} \\')
print('% total ótimas com UB:', sum(x[0] for L in G.values() for x in L), 'de', sum(map(len, G.values())))

# melhor conhecido entre as três configurações do artigo (e o Hexaly como UB). Só estas saídas:
# diagnóstico, escala e validação usam outros parâmetros ou outras instâncias.
RODADAS = ('saida_bench25.txt', 'saida_bench50.txt', 'saida_bench100.txt', 'saida_bench100_enum100k.txt',
           'saida_teste_busca.txt', 'saida_abertas_melhor.txt', 'saida_bench_ub.txt')
best = defaultdict(lambda: [None, 0.0, False, ''])  # UB, LB, ótimo provado, origem do UB fora do BPC (h, s)
for arq in RODADAS:
    for k, (opt, rdb, nos, lb, ub, t) in stats(arq).items():
        b = best[k]
        if ub is not None and (b[0] is None or ub < b[0]):
            b[0] = ub
        b[1] = max(b[1], lb if not opt else ub)
        b[2] |= opt
for k, h in hexa.items():
    if best[k][0] is None or h < best[k][0] - 0.005:  # statistics: duas casas decimais
        best[k][0], best[k][3] = h, 'h'
# a sequencial pessimista (tudo a bordo) é uma restrição do problema: suas soluções valem como UB
for l in open('saida_seq_pess.txt', encoding='utf-8', errors='ignore'):
    c = l.strip().split(';')
    if c[0] == 'RESULTADO' and c[3] not in ('-', 'NaN'):
        k = c[1].removeprefix('pess_')
        if k in best and float(c[3]) < best[k][0] - 0.005:
            best[k][0], best[k][3] = float(c[3]), 's'
fech = {k for k, b in best.items() if b[2] or b[0] - b[1] <= 1e-6 * b[0]}
print('% ótimas em alguma rodada:', len(fech), 'de', len(best))
for k in sorted(best, key=lambda k: (grupo(k), k)):
    if k not in fech:
        u, l, _, _ = best[k]
        print(f'%   aberta {k}: UB {u:.2f} LB {l:.2f} gap {100 * (u - l) / u:.2f}%')

# tab:best: uma linha por família, capacidade e semente; colunas por n (BKS e LB, "opt" se provado)
NL = chr(92) * 2
linhas = []
for fam in ('RE', 'RL', 'CE', 'CL', 'RCE', 'RCL'):
    for c in (1, 2):
        for s in (1, 2):
            cel = [f'{fam} & {c} & {s}']
            for n in (25, 50, 100):
                k = f'bench_{fam}_n{n}_c{c}_s{s}'
                u, l, _, so_hex = best[k]
                cel.append(f'{u:.2f}' + (f'$^{{{so_hex}}}$' if so_hex else '') + ' & ' + ('opt' if k in fech else f'{l:.2f}'))
            linhas.append(' & '.join(cel) + ' ' + NL)
    linhas.append(chr(92) + 'addlinespace')
open('tabela_instancias.tex', 'w', encoding='utf-8').write('\n'.join(linhas[:-1]) + '\n')
with open('melhor_conhecido.csv', 'w', encoding='utf-8') as f:  # lido por ../sequencial.py
    f.write('instancia,bks,lb,otimo\n')
    f.writelines(f'{k},{b[0]!r},{b[1]!r},{int(k in fech)}\n' for k, b in sorted(best.items()))
print('% tabela_instancias.tex escrita')
