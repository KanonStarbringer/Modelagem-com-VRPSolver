"""Protótipo do PRUO: roteamento de USVs com offloading de computação.

Valida a formulação da nota "Formalização - Roteamento de USVs com offloading":
  1. modelo compacto (fluxo em arcos) == partição de conjuntos sobre todas as colunas;
  2. relaxação linear: a da partição é mais forte que a do compacto;
  3. valor do acoplamento: integrado x sequencial (rota primeiro, computação depois).

Uso: python -I prototipo_pruo.py [n_sementes] [n_tarefas]
"""
import math
import random
import sys

import pulp

SOLVER = pulp.PULP_CBC_CMD(msg=0, timeLimit=600)


def instancia(seed, n=7):
    """Instância aleatória pequena. Tempo em min, distância em km, energia em kWh."""
    rnd = random.Random(seed)
    H, D, P = 240, 30, 8                   # horizonte, duração e nº de períodos
    pts = [(0.0, 0.0)] + [(rnd.uniform(-6, 6), rnd.uniform(-6, 6)) for _ in range(n)]
    dist = [[math.dist(p, q) for q in pts] for p in pts]
    a = [0.0] + [rnd.uniform(0, 160) for _ in range(n)]
    b = [H] + [a[i] + rnd.uniform(30, 60) for i in range(1, n + 1)]
    s = {i: 10.0 for i in range(1, n + 1)}  # sensoriamento no ponto
    R = 6.0                                 # alcance do enlace com o servidor (no depósito)
    tau, eps = {}, {}                       # duração e energia do serviço, por modo
    for i in range(1, n + 1):
        pL = rnd.uniform(20, 35)            # processamento a bordo, lento
        tau[i, 'L'], eps[i, 'L'] = s[i] + pL, 0.03 * pL / 60
        if dist[0][i] <= R:                 # fora do alcance, só computação local
            th = 2 + 0.5 * dist[0][i]       # transmissão piora com a distância
            tau[i, 'S'], eps[i, 'S'] = s[i] + th, 0.01 * th / 60
    down = rnd.randrange(P)                 # um período sem enlace (DDIL)
    return dict(n=n, v=1 / 3, H=H, D=D, P=P, pts=pts, dist=dist, a=a, b=b, s=s, tau=tau, eps=eps,
                w={i: 1 for i in range(1, n + 1)}, C=[1] * P,
                gam=[0 if t == down else 1 for t in range(P)],
                E=2.5, cE=0.05, F=100, K=3)


def modos(I, i):
    return [m for m in ('L', 'S') if (i, m) in I['tau']]


def compacto(I, relax=False, x_fix=None, ignora_comp=False, so_local=False):
    """Formulação (C) da nota. ignora_comp: serviço = só sensoriamento, sem capacidade."""
    n, d, a, b, H, D, v = I['n'], I['dist'], I['a'], I['b'], I['H'], I['D'], I['v']
    N, fim = range(1, n + 1), n + 1
    loc = lambda i: 0 if i == fim else i
    tt = lambda i, j: d[loc(i)][loc(j)] / v
    M = {i: ['0'] if ignora_comp else ['L'] if so_local else modos(I, i) for i in N}
    tau = lambda i, m: I['s'][i] if m == '0' else I['tau'][i, m]
    eps = lambda i, m: 0.0 if m == '0' else I['eps'][i, m]
    tmin = {i: min(tau(i, m) for m in M[i]) for i in N}
    tmax = {i: max(tau(i, m) for m in M[i]) for i in N}
    A = ([(0, j) for j in N] + [(i, fim) for i in N] +
         [(i, j) for i in N for j in N if i != j and a[i] + tmin[i] + tt(i, j) <= b[j]])
    cat = 'Continuous' if relax else 'Binary'
    pb = pulp.LpProblem('C', pulp.LpMinimize)
    x = {k: pulp.LpVariable(f'x_{k[0]}_{k[1]}', 0, 1, cat) for k in A}
    z = {(i, m): pulp.LpVariable(f'z_{i}_{m}', 0, 1, cat) for i in N for m in M[i]}
    T = {i: pulp.LpVariable(f'T_{i}', a[i], b[i]) for i in N}
    Y = {i: pulp.LpVariable(f'Y_{i}', 0, I['E']) for i in N}
    pb += I['F'] * pulp.lpSum(x[0, j] for j in N) + pulp.lpSum(d[loc(i)][loc(j)] * x[i, j] for i, j in A)
    for i in N:
        pb += pulp.lpSum(x[k] for k in A if k[0] == i) == 1
        pb += pulp.lpSum(x[k] for k in A if k[1] == i) == 1
        pb += pulp.lpSum(z[i, m] for m in M[i]) == 1
    pb += pulp.lpSum(x[0, j] for j in N) <= I['K']
    tau_i = {i: pulp.lpSum(tau(i, m) * z[i, m] for m in M[i]) for i in N}
    eps_i = {i: pulp.lpSum(eps(i, m) * z[i, m] for m in M[i]) for i in N}
    ME = I['E'] + 1 + I['cE'] * max(map(max, d))
    for i, j in A:                          # tempo e energia ao longo dos arcos (elimina subciclos)
        if i == 0:
            pb += T[j] >= tt(0, j) * x[0, j]
            pb += Y[j] >= I['cE'] * d[0][j] * x[0, j]
        elif j == fim:
            pb += T[i] + tau_i[i] + tt(i, 0) <= H + max(0, b[i] + tmax[i] + tt(i, 0) - H) * (1 - x[i, j])
            pb += Y[i] + eps_i[i] + I['cE'] * d[i][0] <= I['E'] + ME * (1 - x[i, j])
        else:
            pb += T[j] >= T[i] + tau_i[i] + tt(i, j) - (b[i] + tmax[i] + tt(i, j) - a[j]) * (1 - x[i, j])
            pb += Y[j] >= Y[i] + eps_i[i] + I['cE'] * d[i][j] - ME * (1 - x[i, j])
    u = {}
    if not ignora_comp:                     # offloading: período, enlace e capacidade do servidor
        for i in N:
            if (i, 'S') not in z:
                continue
            for t in range(I['P']):
                if I['gam'][t] and t * D <= b[i] and (t + 1) * D >= a[i]:
                    u[i, t] = pulp.LpVariable(f'u_{i}_{t}', 0, 1, cat)
                    pb += T[i] >= t * D - t * D * (1 - u[i, t])
                    pb += T[i] <= (t + 1) * D + b[i] * (1 - u[i, t])
            pb += pulp.lpSum(u[i, t] for t in range(I['P']) if (i, t) in u) == z[i, 'S']
        for t in range(I['P']):
            pb += pulp.lpSum(I['w'][i] * u[k] for k in u if k[1] == t for i in [k[0]]) <= I['C'][t]
    if x_fix is not None:
        for k in A:
            pb += x[k] == (1 if k in x_fix else 0)
    pb.solve(SOLVER)
    if pulp.LpStatus[pb.status] != 'Optimal':
        return None
    used = {k for k in A if x[k].value() > 0.5}
    sol = dict(obj=pulp.value(pb.objective), arcs=used, provado=pb.sol_status == pulp.LpSolutionOptimal)
    if not relax:
        rotas = []
        for j0 in [j for (i, j) in used if i == 0]:
            r, i = [], j0
            while i != fim:
                m = max(M[i], key=lambda mm: z[i, mm].value())
                t = next((t for (k, t) in u if k == i and u[k, t].value() > 0.5), None)
                r.append((i, m, t, round(T[i].value(), 1)))
                i = next(j for (k, j) in used if k == i)
            rotas.append(r)
        sol['rotas'] = rotas
    return sol


def colunas(I):
    """Enumera todas as rotas viáveis (sequência + modo + período). Fica, para cada
    vetor de coeficientes (tarefas visitadas, carga por período), só a de menor custo."""
    n, d, a, b, H, D, P, v = I['n'], I['dist'], I['a'], I['b'], I['H'], I['D'], I['P'], I['v']
    E, cE = I['E'], I['cE']
    best = {}

    def dfs(i, tdep, en, km, vis, q, seq):
        if seq and tdep + d[i][0] / v <= H and en + cE * d[i][0] <= E:
            key, c = (vis, q), I['F'] + km + d[i][0]
            if key not in best or c < best[key][0]:
                best[key] = (c, seq)
        for j in range(1, n + 1):
            if j in vis:
                continue
            arr = tdep + d[i][j] / v
            if arr > b[j]:
                continue
            for m in modos(I, j):
                if m == 'L':
                    opts = [(max(arr, a[j]), None)]
                else:                       # começar mais tarde = escolher outro período
                    opts = [(max(arr, a[j], t * D), t) for t in range(P)
                            if I['gam'][t] and max(arr, a[j], t * D) <= min(b[j], (t + 1) * D)]
                for st, t in opts:
                    if st > b[j]:
                        continue
                    dep, e2 = st + I['tau'][j, m], en + I['eps'][j, m] + cE * d[i][j]
                    if dep + d[j][0] / v > H or e2 + cE * d[j][0] > E:
                        continue            # tempo e energia só crescem: poda
                    q2 = q
                    if t is not None:
                        q2 = q[:t] + (q[t] + I['w'][j],) + q[t + 1:]
                        if q2[t] > I['C'][t]:
                            continue
                    dfs(j, dep, e2, km + d[i][j], vis | {j}, q2, seq + ((j, m, t),))

    dfs(0, 0.0, 0.0, 0.0, frozenset(), (0,) * P, ())
    return best


def particao(I, cols, relax=False):
    """Formulação (SP) da nota, com todas as colunas."""
    pb = pulp.LpProblem('SP', pulp.LpMinimize)
    ks = list(cols)
    lam = {k: pulp.LpVariable(f'l{h}', 0, 1, 'Continuous' if relax else 'Binary') for h, k in enumerate(ks)}
    pb += pulp.lpSum(cols[k][0] * lam[k] for k in ks)
    for i in range(1, I['n'] + 1):
        pb += pulp.lpSum(lam[k] for k in ks if i in k[0]) == 1
    pb += pulp.lpSum(lam.values()) <= I['K']
    for t in range(I['P']):
        pb += pulp.lpSum(k[1][t] * lam[k] for k in ks if k[1][t]) <= I['C'][t]
    pb.solve(SOLVER)
    return pulp.value(pb.objective) if pulp.LpStatus[pb.status] == 'Optimal' else None


def main(n_sem=20, n=7):
    lin, sem_sol = [], 0
    print(f'{"sem":>3} {"ótimo":>8} {"SP":>8} {"LP(C)":>8} {"LP(SP)":>8} {"cols":>6} {"USVs":>4} '
          f'{"seq.otim.":>10} {"seq.pess.":>10}')
    for seed in range(1, n_sem + 1):
        I = instancia(seed, n)
        opt = compacto(I)
        if opt is None:
            sem_sol += 1
            print(f'{seed:>3} inviável')
            continue
        cols = colunas(I)
        sp, sp_lp, c_lp = particao(I, cols), particao(I, cols, relax=True), compacto(I, relax=True)['obj']
        assert sp is not None and abs(sp - opt['obj']) <= 1e-4 * max(1, abs(sp)), (seed, sp, opt['obj'])
        assert sp_lp >= c_lp - 1e-6, (seed, sp_lp, c_lp)
        r1 = compacto(I, ignora_comp=True)              # rota primeiro, ignorando a computação
        seq_ot = compacto(I, x_fix=r1['arcs'])           # ... e computação depois, com a rota fixa
        seq_pe = compacto(I, so_local=True)              # rota supondo tudo a bordo
        usv = len(opt['rotas'])
        lin.append((opt['obj'], c_lp, sp_lp, seq_ot, seq_pe))
        f = lambda r: 'inviável' if r is None else f'{r["obj"]:.1f}'
        print(f'{seed:>3} {opt["obj"]:8.1f} {sp:8.1f} {c_lp:8.1f} {sp_lp:8.1f} {len(cols):6d} {usv:4d} '
              f'{f(seq_ot):>10} {f(seq_pe):>10}')
        if seed == 1:
            exemplo = (I, opt)
    k = len(lin)
    gap = lambda lb, ub: 100 * (ub - lb) / ub
    print(f'\nResolvidas: {k} de {n_sem} (sem solução: {sem_sol}). Compacto == SP em todas (assert).')
    print(f'Gap médio da relaxação: compacto {sum(gap(l[1], l[0]) for l in lin) / k:.1f}% | '
          f'partição {sum(gap(l[2], l[0]) for l in lin) / k:.1f}%')
    print(f'Sequencial otimista (rota sem computação, depois offloading): inviável em '
          f'{sum(l[3] is None for l in lin)} de {k}')
    pe = [100 * (l[4]['obj'] - l[0]) / l[0] for l in lin if l[4]]
    print(f'Sequencial pessimista (tudo a bordo): {sum(l[4] is None for l in lin)} inviáveis; '
          f'custo médio {sum(pe) / len(pe):.1f}% acima do integrado nas {len(pe)} viáveis; '
          f'pior caso {max(pe):.1f}%')
    if 'exemplo' in locals():
        I, opt = exemplo
        print('\nExemplo (semente 1): (tarefa, modo, período do offloading, início do serviço)')
        for r in opt['rotas']:
            print('  0 ->', ' -> '.join(f'{i}[{m}{"" if t is None else f"@{t}"}, {T}]' for i, m, t, T in r), '-> 0')
        print(f'  Enlace fora no período {I["gam"].index(0)}; capacidade: {I["C"][0]} tarefa por período de {I["D"]} min.')


if __name__ == '__main__':
    main(*map(int, sys.argv[1:3]))
