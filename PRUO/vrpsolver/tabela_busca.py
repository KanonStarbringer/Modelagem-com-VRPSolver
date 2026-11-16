"""Linhas da tab:search: instâncias em aberto na busca padrão (profundidade) rodadas de novo com
treeSearchStrategy = 0 (melhor limitante), sem UB inicial. Uso: python -X utf8 tabela_busca.py
"""
import csv, re

pad = {r['instancia']: r for r in csv.DictReader(open('tabela_pruo.csv', encoding='utf-8'))}
PAT = r'statistics: (\S+) & (\d) & \S+ & \S+ & \S+ & (\S+) & (\S+) & (\S+) & (\S+)'
bb = {}
for f in ('saida_teste_busca.txt', 'saida_abertas_melhor.txt'):
    for m in re.findall(PAT, open(f, encoding='utf-8', errors='ignore').read()):
        bb[m[0]] = m[1:]

num = lambda x: None if x in ('', '--', 'nan') else float(x)
fmt = lambda x: '--' if x is None else f'{x:.2f}'
gap = lambda u, l: None if u is None else 100 * (u - l) / u
ordem = sorted(bb, key=lambda k: (int(re.search(r'_n(\d+)_', k)[1]), k))
for k in ordem:
    o, nos, lb, ub, t = bb[k]
    d = pad[k]
    du, dl = num(d['ub']), float(d['lb'])
    u, l = num(ub), float(lb)
    t = 'opt' if o == '1' else ''
    print(f"{k[6:].replace('_', chr(92) + '_')} & {fmt(du)} & {dl:.2f} & {fmt(gap(du, dl))} & "
          f"{fmt(u)} & {l:.2f} & {fmt(gap(u, l))} & {float(bb[k][4]):.0f} \\\\")
