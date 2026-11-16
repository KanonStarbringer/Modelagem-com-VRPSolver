"""Linhas da tab:compact: (C) no CPLEX por grupo (n, janela, C_t): ótimas, gap final médio,
desvio médio do UB em relação à melhor solução conhecida, e instâncias paradas por memória."""
import csv
from collections import defaultdict

bks = {r['instancia']: float(r['bks']) for r in csv.DictReader(open('melhor_conhecido.csv', encoding='utf-8'))}
G = defaultdict(list)
for n in (25, 50, 100):
    for l in open(f'saida_compacto{n}.txt', encoding='utf-8'):
        c = l.strip().split(';')
        if c[0] != 'COMPACTO':
            continue
        nome, ub, lb, st, t, lp = c[1], float(c[3]), float(c[4]), c[5], float(c[6]), float(c[7])
        fam, _, cap, _ = nome.split('_')[1:]
        if ub < bks[nome] - 0.005:
            print(f'% ATENÇÃO: {nome} UB {ub:.2f} abaixo da BKS {bks[nome]:.2f}')
        G[n, fam[-1], cap[1]].append((st, 100 * (ub - lb) / ub, 100 * (ub - bks[nome]) / bks[nome], t, 100 * (bks[nome] - lp) / bks[nome]))
tot = defaultdict(int)
for k in sorted(G):
    L = G[k]
    opt = sum(x[0] == 'Optimal' for x in L)
    tot['opt'] += opt; tot['n'] += len(L); tot['mem'] += sum(x[0] == 'Memoria' for x in L)
    print(f'{k[0]} & {k[1]} & {k[2]} & {opt}/{len(L)} & {sum(x[3] for x in L) / len(L):.1f} & '
          f'{sum(x[1] for x in L) / len(L):.2f} & {sum(x[2] for x in L) / len(L):.2f} & '
          f'{sum(x[0] == "Memoria" for x in L)} & {sum(x[4] for x in L) / len(L):.1f} \\')
for n in (25, 50, 100):
    L = [x for k, v in G.items() if k[0] == n for x in v]
    print(f'% n={n}: {sum(x[0] == "Optimal" for x in L)}/{len(L)} ótimas; gap {sum(x[1] for x in L) / len(L):.2f}; '
          f'desvio UB {sum(x[2] for x in L) / len(L):.2f}; memória {sum(x[0] == "Memoria" for x in L)}')
print(f'% total: {tot["opt"]}/{tot["n"]} ótimas, {tot["mem"]} por memória')
