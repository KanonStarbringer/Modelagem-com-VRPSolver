"""Valor da integração no benchmark: abordagens sequenciais (rota primeiro, computação depois).

Otimista: rotas com serviço = só sensoriamento (10 min), sem energia de processamento e sem
  servidor; depois, com as rotas fixas, escolhe modos e períodos no compacto (C) (CPLEX).
  Pode ser inviável. Se for viável e a rota otimista for ótima, o plano é ótimo para o integrado.
Pessimista: rotas com toda tarefa processada a bordo (só cópias L); sempre viável.
As rotas vêm do VRPSolver (WSL), nas instâncias escritas por "gerar".

Uso:
  python -X utf8 sequencial.py gerar     -> vrpsolver/instancias/{otim,pess}_bench_*.txt e seq_*.batch
  (WSL) bash rodar_lote.sh seq_pess.batch saida_seq_pess.txt; idem seq_otim -> saida_seq_otim.txt
  python -X utf8 sequencial.py avaliar   -> fase 2 do otimista e resumo (saida_sequencial.txt)
"""
import csv
import os
import re
import sys
from collections import defaultdict

import pulp

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import compacto_cplex as cc  # noqa: E402
import prototipo_pruo as p  # noqa: E402

VRP = os.path.join(AQUI, 'vrpsolver')
INST = os.path.join(VRP, 'instancias')
NOMES = [os.path.splitext(os.path.basename(l.split()[0]))[0]
         for n in (25, 50, 100) for l in open(os.path.join(VRP, f'bench_n{n}.batch'), encoding='utf-8') if l.strip()]


def gerar():
    lotes = defaultdict(list)
    for nome in NOMES:
        linhas = open(os.path.join(INST, nome + '.txt'), encoding='utf-8').read().split('\n')
        i0 = linhas.index('nos') + 2                      # depois do depósito
        for tipo in ('otim', 'pess'):
            out = linhas[:i0]
            for l in linhas[i0:]:
                if not l.strip():
                    out.append(l)
                    continue
                c = l.split()                             # id x y a b w tauL epsL tauS epsS
                if tipo == 'otim':
                    c[6], c[7] = '10.0', '0.0'            # só sensoriamento
                c[8], c[9] = '-1.0', '-1.0'               # sem servidor
                out.append(' '.join(c))
            open(os.path.join(INST, f'{tipo}_{nome}.txt'), 'w', encoding='utf-8', newline='\n').write('\n'.join(out))
            cfg = ' -c config/PRUO_enum100k.cfg' if '_n100_' in nome else ''
            lotes[tipo].append(f'instancias/{tipo}_{nome}.txt{cfg}')
    for tipo, L in lotes.items():
        open(os.path.join(VRP, f'seq_{tipo}.batch'), 'w', encoding='utf-8', newline='\n').write('\n'.join(L) + '\n')
        print(f'seq_{tipo}.batch: {len(L)} instâncias')


def resultados(arq):
    """{nome original: (custo ou None, status, [rotas como listas de tarefas])} da saída do VRPSolver."""
    res, rotas = {}, []
    for l in open(os.path.join(VRP, arq), encoding='utf-8', errors='ignore'):
        if l.startswith('Rota #'):
            rotas.append([int(x) for x in re.findall(r'(\d+)\[', l)])
        elif l.startswith('RESULTADO;'):
            c = l.strip().split(';')
            custo = None if c[3] in ('-', 'NaN') else float(c[3])
            res[c[1].split('_', 1)[1]] = (custo, c[6], rotas if custo is not None else [])
            rotas = []
    return res


def fase2(I, rotas):
    """Modos e períodos com as rotas fixas: custo (= o das rotas) ou None se inviável."""
    fim = I['n'] + 1
    arcos = {(a, b) for r in rotas for a, b in zip([0] + r, r + [fim])}
    p.SOLVER = pulp.CPLEX_CMD(path=cc.CPLEX, msg=False, timeLimit=600, threads=1)
    sol = p.compacto(I, x_fix=arcos)
    return sol['obj'] if sol else None


def avaliar():
    bks = {r['instancia']: r for r in csv.DictReader(open(os.path.join(VRP, 'melhor_conhecido.csv'), encoding='utf-8'))}
    ot, pe = resultados('saida_seq_otim.txt'), resultados('saida_seq_pess.txt')
    linhas = []
    for nome in NOMES:
        if nome not in ot or nome not in pe:
            print('falta', nome)
            continue
        I = cc.ler(os.path.join(INST, nome + '.txt'))
        c_ot, st_ot, R = ot[nome]
        viavel = fase2(I, R) is not None if R else None   # None: o VRPSolver não achou rota otimista
        c_pe, st_pe, Rp = pe[nome]
        b = float(bks[nome]['bks'])
        linhas.append((nome, I['n'], c_ot, st_ot, viavel, c_pe, st_pe, len(Rp), b, int(bks[nome]['otimo'])))
    with open(os.path.join(VRP, 'saida_sequencial.txt'), 'w', encoding='utf-8') as f:
        f.write('nome;n;otim_custo;otim_status;otim_viavel;pess_custo;pess_status;pess_usvs;bks;bks_otimo\n')
        f.writelines(';'.join(map(str, l)) + '\n' for l in linhas)
    for n in (25, 50, 100):
        L = [l for l in linhas if l[1] == n]
        if not L:
            continue
        inv = sum(l[4] is False for l in L)
        dif = [100 * (l[5] - l[8]) / l[8] for l in L if l[5] is not None]
        print(f'n={n}: {len(L)} inst.; otimista inviável em {inv}, viável em {sum(l[4] is True for l in L)}; '
              f'pessimista {sum(dif) / len(dif):.2f}% acima da BKS (máx. {max(dif):.2f}%), '
              f'{sum(l[6] == "Optimal" for l in L)} pessimistas ótimas')


if __name__ == '__main__':
    {'gerar': gerar, 'avaliar': avaliar}[sys.argv[1]]()
