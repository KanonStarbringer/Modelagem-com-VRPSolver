"""Geração de colunas do PRUO no nó raiz, com pricing exato por rotulagem.

1. Confere o limitante da GC contra o LP(SP) com todas as colunas enumeradas (prototipo_pruo).
2. Resolve o mestre inteiro só com as colunas geradas (price-and-branch: limitante superior).
3. Em instâncias maiores, onde a enumeração não cabe, compara com o modelo compacto (C) no CBC.

Uso: python geracao_colunas.py
"""
import heapq
import os
import sys
import time

import numpy as np
import pulp
from scipy.optimize import Bounds, LinearConstraint, linprog, milp

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import prototipo_pruo as p  # noqa: E402

BIG = 1e4   # custo das variáveis artificiais do mestre restrito


class Rot:
    """Rótulo: rota parcial que deixa o nó físico `no` no instante `sai`."""
    __slots__ = ('no', 'sai', 'en', 'cr', 'vis', 'q', 'pai', 'passo', 'vivo')

    def __init__(self, no, sai, en, cr, vis, q, pai, passo):
        self.no, self.sai, self.en, self.cr, self.vis, self.q = no, sai, en, cr, vis, q
        self.pai, self.passo, self.vivo = pai, passo, True

    def domina(self, o):
        # vale por H6 (espera grátis) e porque o custo não depende do horário (§4 da nota)
        return (self.sai <= o.sai + 1e-9 and self.en <= o.en + 1e-12 and self.cr <= o.cr + 1e-9
                and not self.vis & ~o.vis and all(x <= y for x, y in zip(self.q, o.q)))


def opcoes(I):
    """Cópias de cada tarefa no grafo expandido: (modo, período, início mín., início máx., duração, energia)."""
    D, a, b = I['D'], I['a'], I['b']
    ops = {}
    for j in range(1, I['n'] + 1):
        ops[j] = [('L', None, a[j], b[j], I['tau'][j, 'L'], I['eps'][j, 'L'])]
        if (j, 'S') in I['tau']:
            ops[j] += [('S', t, max(a[j], t * D), min(b[j], (t + 1) * D), I['tau'][j, 'S'], I['eps'][j, 'S'])
                       for t in range(I['P']) if I['gam'][t] and max(a[j], t * D) <= min(b[j], (t + 1) * D)]
    return ops


def coluna(I, seq):
    """(custo, tarefas como bitmask, carga por período, sequência) de uma rota."""
    d, nos, q = I['dist'], [0] + [j for j, _, _ in seq] + [0], [0] * I['P']
    for j, _, t in seq:
        if t is not None:
            q[t] += I['w'][j]
    return (I['F'] + sum(d[x][y] for x, y in zip(nos, nos[1:])), sum(1 << j for j, _, _ in seq), tuple(q), seq)


def pricing(I, ops, pi, sigma, rho, max_cols=50):
    """ESPPRC exato no grafo expandido. Devolve até max_cols colunas de custo reduzido
    negativo, o menor custo reduzido e o nº de rótulos criados."""
    n, d, v, E, cE = I['n'], I['dist'], I['v'], I['E'], I['cE']
    cesto = {j: [] for j in range(1, n + 1)}       # rótulos não dominados, por nó físico
    heap = [(0.0, 0, Rot(0, 0.0, 0.0, I['F'] - sigma, 0, (0,) * I['P'], None, None))]
    k, achadas, rc_min = 1, {}, 0.0
    while heap:
        _, _, L = heapq.heappop(heap)
        if not L.vivo:
            continue
        i = L.no
        if i:                                       # fechar a rota no depósito
            rc = L.cr + d[i][0]
            rc_min = min(rc_min, rc)
            if rc < -1e-6 and ((L.vis, L.q) not in achadas or rc < achadas[L.vis, L.q][0]):
                achadas[L.vis, L.q] = (rc, L)
        for j in range(1, n + 1):
            if L.vis >> j & 1:
                continue
            chegada = L.sai + d[i][j] / v
            for m, t, lo, hi, dur, ener in ops[j]:
                ini = max(chegada, lo)
                if ini > hi:
                    continue
                sai, en = ini + dur, L.en + cE * d[i][j] + ener
                if sai + d[j][0] / v > I['H'] or en + cE * d[j][0] > E:
                    continue                        # tempo e energia só crescem: poda
                q, cr = L.q, L.cr + d[i][j] - pi[j - 1]
                if t is not None:
                    q = q[:t] + (q[t] + I['w'][j],) + q[t + 1:]
                    if q[t] > I['C'][t]:
                        continue
                    cr -= rho[t] * I['w'][j]        # rho <= 0: período congestionado encarece
                N = Rot(j, sai, en, cr, L.vis | 1 << j, q, L, (j, m, t))
                if any(o.domina(N) for o in cesto[j]):
                    continue
                for o in cesto[j]:
                    if N.domina(o):
                        o.vivo = False
                cesto[j] = [o for o in cesto[j] if o.vivo] + [N]
                heapq.heappush(heap, (sai, k, N))
                k += 1
    cols = []
    for _, L in sorted(achadas.values(), key=lambda x: x[0])[:max_cols]:
        seq = []
        while L.passo:
            seq.append(L.passo)
            L = L.pai
        cols.append(coluna(I, seq[::-1]))
    return cols, rc_min, k


def matrizes(I, cols):
    n, P, nc = I['n'], I['P'], len(cols)
    Aeq = np.array([[c[1] >> i & 1 for c in cols] for i in range(1, n + 1)], float).reshape(n, nc)
    Aub = np.array([[1.0] * nc] + [[c[2][t] for c in cols] for t in range(P)], float).reshape(P + 1, nc)
    return Aeq, Aub, np.array([I['K']] + list(I['C']), float)


def rmp(I, cols, frota=None):
    """Mestre restrito (LP) com artificiais nas linhas de partição e frota em [lo, hi].
    Devolve valor, duais (pi, sigma efetivo da frota, rho), soma das artificiais e nº de USVs."""
    n, nc = I['n'], len(cols)
    lo, hi = frota or (0, I['K'])
    Aeq, Aub, bub = matrizes(I, cols)
    Aub = np.vstack([Aub[:1], -Aub[:1], Aub[1:]])      # frota <= hi; -frota <= -lo; capacidade
    bub = np.concatenate([[hi, -lo], bub[1:]])
    s = np.zeros((Aub.shape[0], 1))
    s[1] = -1                                           # artificial da frota mínima
    r = linprog(np.array([c[0] for c in cols] + [BIG] * (n + 1)),
                A_ub=np.hstack([Aub, np.zeros((Aub.shape[0], n)), s]), b_ub=bub,
                A_eq=np.hstack([Aeq, np.eye(n), np.zeros((n, 1))]), b_eq=np.ones(n), bounds=(0, None), method='highs')
    assert r.status == 0, r.message
    y = r.ineqlin.marginals
    return r.fun, r.eqlin.marginals, y[0] - y[1], y[2:], r.x[nc:].sum(), r.x[:nc].sum()


def gc(I, frota=None, cols0=(), max_it=2000):
    ops, cols, t0, rot = opcoes(I), list(cols0), time.perf_counter(), 0
    for it in range(1, max_it + 1):
        z, pi, sigma, rho, art, usv = rmp(I, cols, frota)
        novas, _, k = pricing(I, ops, pi, sigma, rho)
        rot += k
        if not novas:
            break
        cols += novas
    return dict(lb=z, art=art, usv=usv, cols=cols, it=it, tempo=time.perf_counter() - t0, rotulos=rot)


def lb_frota(I, R):
    """Limitante com a frota inteira. O valor do LP é convexo no tamanho da frota,
    então basta resolver com a frota do raiz arredondada para baixo e para cima."""
    f = R['usv']
    if abs(f - round(f)) < 1e-6:
        return R['lb']
    filhos = [gc(I, (k, k), R['cols']) for k in (int(f), int(f) + 1) if 1 <= k <= I['K']]
    return min(F['lb'] for F in filhos if F['art'] < 1e-6)


def experimento_frota():
    """Quanto do gap do raiz some ao ramificar só no número de USVs."""
    print(f'{"n":>3} {"sem":>3} {"USVs LP":>7} {"LB raiz":>8} {"LB frota":>8} {"ótimo":>8} {"gap raiz":>8} {"gap frota":>9}')
    p.SOLVER = pulp.PULP_CBC_CMD(msg=0, timeLimit=60)
    g = {}
    for n, sementes, K in ((7, range(1, 21), 3), (10, (1, 2, 3), 10), (15, (1, 2, 3), 15)):
        for seed in sementes:
            I = dict(p.instancia(seed, n), K=K)
            R = gc(I)
            lbf, C = lb_frota(I, R), p.compacto(I)
            if not (C and C['provado']):
                continue
            gr, gf = (round(100 * (C['obj'] - x) / C['obj'], 1) + 0.0 for x in (R['lb'], lbf))
            g.setdefault(n, []).append((gr, gf))
            print(f'{n:>3} {seed:>3} {R["usv"]:7.2f} {R["lb"]:8.1f} {lbf:8.1f} {C["obj"]:8.1f} {gr:8.1f} {gf:9.1f}')
    for n, v in g.items():
        print(f'n = {n}: gap médio do raiz {sum(a for a, _ in v) / len(v):.1f}% -> com frota inteira '
              f'{sum(b for _, b in v) / len(v):.1f}% ({len(v)} instâncias com ótimo provado)')


def mestre_inteiro(I, cols):
    """Price-and-branch: mestre inteiro só com as colunas geradas (limitante superior)."""
    Aeq, Aub, bub = matrizes(I, cols)
    r = milp(np.array([c[0] for c in cols]), integrality=np.ones(len(cols)), bounds=Bounds(0, 1),
             constraints=[LinearConstraint(Aeq, 1, 1), LinearConstraint(Aub, -np.inf, bub)])
    return r.fun if r.status == 0 else None


def num(x):
    return '       -' if x is None else f'{x:8.1f}'


def main():
    print('1) n = 7 (20 instâncias): limitante da GC x LP(SP) enumerado; price-and-branch x ótimo')
    print(f'{"sem":>3} {"LB(GC)":>8} {"LP enum":>8} {"UB(P&B)":>8} {"ótimo":>8} {"cols":>5} {"it":>4} {"s":>6}')
    iguais = sem_ub = 0
    for seed in range(1, 21):
        I = p.instancia(seed, 7)
        R = gc(I)
        lp_enum = p.particao(I, p.colunas(I), relax=True)
        assert R['art'] < 1e-6 and abs(R['lb'] - lp_enum) <= 1e-5 * max(1, abs(lp_enum)), (seed, R['lb'], lp_enum)
        ub, opt = mestre_inteiro(I, R['cols']), p.compacto(I)['obj']
        iguais += ub is not None and abs(ub - opt) < 1e-6
        sem_ub += ub is None
        print(f'{seed:>3} {R["lb"]:8.1f} {lp_enum:8.1f} {num(ub)} {opt:8.1f} {len(R["cols"]):5d} {R["it"]:4d} {R["tempo"]:6.2f}')
    print(f'LB(GC) == LP(SP) enumerado em 20 de 20 (assert). Price-and-branch: ótimo em {iguais} de 20; '
          f'sem solução inteira só com as colunas do LP em {sem_ub}.\n')

    print('2) instâncias maiores (K = n): GC no nó raiz x compacto (C) no CBC com 60 s')
    print(f'{"n":>3} {"sem":>3} {"LB(GC)":>8} {"UB(P&B)":>8} {"gap%":>5} {"cols":>5} {"it":>4} {"s GC":>6}'
          f' {"LP(C)":>8} {"C: obj":>8} {"prova":>5} {"s C":>5}')
    p.SOLVER = pulp.PULP_CBC_CMD(msg=0, timeLimit=60)
    for n in (10, 15, 20):
        for seed in (1, 2, 3):
            I = dict(p.instancia(seed, n), K=n)
            R = gc(I)
            ub = mestre_inteiro(I, R['cols'])
            t0 = time.perf_counter()
            C = p.compacto(I)
            tc = time.perf_counter() - t0
            clp = p.compacto(I, relax=True)['obj']
            gap = '    -' if ub is None else f'{100 * (ub - R["lb"]) / ub:5.1f}'
            prova = ('sim' if C['provado'] else 'não') if C else '-'
            print(f'{n:>3} {seed:>3} {R["lb"]:8.1f} {num(ub)} {gap} {len(R["cols"]):5d} {R["it"]:4d}'
                  f' {R["tempo"]:6.1f} {clp:8.1f} {num(C["obj"] if C else None)} {prova:>5} {tc:5.0f}')


if __name__ == '__main__':
    experimento_frota() if sys.argv[1:] == ['frota'] else main()
