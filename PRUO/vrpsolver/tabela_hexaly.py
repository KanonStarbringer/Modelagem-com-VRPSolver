"""Linhas da tab:hexaly: desvio médio (%) do Hexaly em 60/600/3600 s em relação à melhor solução
conhecida (menor UB do BPC em qualquer saída, ou o próprio Hexaly) e nº de instâncias em que o
Hexaly em 1 h iguala essa melhor solução. Só entram instâncias com a linha HEXALY; final.
Uso: python -X utf8 tabela_hexaly.py
"""
import glob, re
from collections import defaultdict

TOL = 1e-4  # relativo; o Hexaly às vezes fica -0,00% abaixo do ótimo do BPC por arredondamento
melhor = {}
for f in glob.glob('saida_*.txt'):
    if 'hexaly' in f:
        continue
    for l in open(f, encoding='utf-8', errors='ignore'):
        c = l.strip().split(';')
        if c[0] == 'RESULTADO' and len(c) > 3:
            try:
                v = float(c[3])
            except ValueError:
                continue
            if v == v and not c[1].startswith('otim_'):  # otimista: inviável no problema integrado
                k = c[1].removeprefix('pess_')
                melhor[k] = min(v, melhor.get(k, v))

T, fim = defaultdict(dict), set()
for n in (25, 50, 100):
    try:
        for l in open(f'saida_hexaly{n}.txt', encoding='utf-8'):
            c = l.strip().split(';')
            if c[0] == 'HEXALY_T':
                T[c[1]][c[2]] = float(c[3])
            elif c[0] == 'HEXALY':
                fim.add(c[1])
    except FileNotFoundError:
        pass

G = defaultdict(list)
for nome in sorted(fim):
    m = re.match(r'bench_([A-Z]+)_n(\d+)_c(\d)_s\d', nome)
    ref = min(melhor.get(nome, float('inf')), T[nome]['3600'])
    dev = [max(0.0, 100 * (T[nome][t] / ref - 1)) for t in ('60', '600', '3600')]
    G[(int(m[2]), m[1][-1], int(m[3]))].append((dev, T[nome]['3600'] <= ref * (1 + TOL)))

for (n, w, c), L in sorted(G.items(), key=lambda kv: (kv[0][0], kv[0][1], kv[0][2])):
    med = [sum(d[i] for d, _ in L) / len(L) for i in range(3)]
    print(f'{n} & {w} & {c} & {med[0]:.2f} & {med[1]:.2f} & {med[2]:.2f} & {sum(b for _, b in L)}/{len(L)} \\')
for n in (25, 50, 100):
    L = [x for k, v in G.items() if k[0] == n for x in v]
    if L:
        print(f'% n={n}: {len(L)} inst.; médias', *[f'{sum(d[i] for d, _ in L) / len(L):.2f}' for i in range(3)],
              f'; iguais {sum(b for _, b in L)}')
