"""PRUO no Hexaly (modelo de listas), para comparar com o BPC do VRPSolver.

Cada USV é uma lista de tarefas (partição); cada tarefa tem um modo m_i em {0..P}:
0 = a bordo, t+1 = offloading no período t. Mesmas regras do grafo de cópias (data.jl):
offloading em t exige início do serviço em [max(a, tD), min(b, (t+1)D)], enlace em t e
alcance do servidor; capacidade sum w_i [m_i = t+1] <= C_t; espera permitida.

Uso: python hexaly_pruo.py <instancia.txt | lote.batch> [segundos=3600] [saida.txt]
Imprime, por instância, HEXALY_T;nome;t;obj nos marcos de 60/600/3600 s e
HEXALY;nome;n;obj;usvs;status;tempo;limitante no fim (n25 rodou sem o limitante). Pula instâncias que já estão na saída.
"""
import math
import os
import sys
import time

import hexaly.optimizer as hx

AQUI = os.path.dirname(os.path.abspath(__file__))
MARCOS = (60, 600, 3600)


def le(path):
    kv, nos, em_nos = {}, [], False
    for linha in open(path, encoding='utf-8'):
        s = linha.split('#')[0].strip()
        if not s:
            continue
        c = s.split()
        if c[0] == 'nos':
            em_nos = True
        elif em_nos:
            nos.append([float(x) for x in c[1:]])
        else:
            kv[c[0]] = c[1:]
    I = {k: float(kv[k][0]) for k in ('F', 'H', 'D', 'E', 'cE', 'v')}
    I.update(n=int(kv['n'][0]), K=int(kv['K'][0]), P=int(kv['P'][0]),
             C=[float(x) for x in kv['C']], gam=[int(x) for x in kv['gam']], no=nos,
             nome=os.path.splitext(os.path.basename(path))[0])
    return I


def tabelas(I):
    """LO/HI/DUR/EN[i][m] para tarefa i (0..n-1) e modo m; OK[i][m] = modo permitido."""
    n, P, D = I['n'], I['P'], I['D']
    pts = [(r[0], r[1]) for r in I['no']]
    dist = [[math.dist(p, q) for q in pts[1:]] for p in pts[1:]]
    d0 = [math.dist(pts[0], p) for p in pts[1:]]
    LO, HI, DUR, EN, OK = [], [], [], [], []
    for i in range(n):
        _, _, a, b, _, tL, eL, tS, eS = I['no'][i + 1]
        lo, hi, du, en, ok = [a], [b], [tL], [eL], [1]
        for t in range(P):
            l, h = max(a, t * D), min(b, (t + 1) * D)
            okt = tS >= 0 and I['gam'][t] == 1 and max(l, d0[i] / I['v']) <= h
            lo.append(l if okt else 0.0); hi.append(h if okt else -1.0)
            du.append(tS if okt else 0.0); en.append(eS if okt else 0.0); ok.append(int(okt))
        LO.append(lo); HI.append(hi); DUR.append(du); EN.append(en); OK.append(ok)
    return dist, d0, LO, HI, DUR, EN, OK


def avalia(I, rotas, modo):
    """Checagem independente da solução do Hexaly: devolve o custo ou levanta AssertionError."""
    dist, d0, LO, HI, DUR, EN, OK = tabelas(I)
    v, H = I['v'], I['H']
    assert sorted(i for r in rotas for i in r) == list(range(I['n']))
    custo, carga = 0.0, [0.0] * I['P']
    for r in (r for r in rotas if r):
        t, e, km, ant = 0.0, 0.0, 0.0, None
        for i in r:
            m = modo[i]
            assert OK[i][m], (i, m)
            leg = d0[i] if ant is None else dist[ant][i]
            t = max((0 if ant is None else t + DUR[ant][modo[ant]]) + leg / v, LO[i][m])
            assert t <= HI[i][m] + 1e-6, (i, m, t, HI[i][m])
            e += EN[i][m] + I['cE'] * leg
            km += leg
            if m:
                carga[m - 1] += I['no'][i + 1][4]
            ant = i
        km += d0[ant]
        assert t + DUR[ant][modo[ant]] + d0[ant] / v <= H + 1e-6
        assert e + I['cE'] * d0[ant] <= I['E'] + 1e-6
        custo += I['F'] + km
    assert all(c <= cap + 1e-6 for c, cap in zip(carga, I['C']))
    return custo


def resolve(I, segundos, out):
    n, P, v = I['n'], I['P'], I['v']
    dist, d0, LO, HI, DUR, EN, OK = tabelas(I)
    w = [I['no'][i + 1][4] for i in range(n)]
    with hx.HexalyOptimizer() as opt:
        m = opt.model
        Dm, D0 = m.array(dist), m.array(d0)
        aLO, aHI, aDUR, aEN, aOK = map(m.array, (LO, HI, DUR, EN, OK))
        rotas = [m.list(n) for _ in range(I['K'])]
        m.constraint(m.partition(rotas))
        modo = [m.int(0, P) for _ in range(n)]
        aM = m.array(modo)
        for i in range(n):
            m.constraint(m.at(aOK, i, modo[i]) == 1)
        for t in range(P):
            m.constraint(m.sum(w[i] * (modo[i] == t + 1) for i in range(n)) <= I['C'][t])
        custo = []
        for r in rotas:
            c = m.count(r)
            md = lambda j: m.at(aM, r[j])  # noqa: E731
            ini = m.array(m.range(0, c), m.lambda_function(lambda j, prev: m.max(
                m.at(aLO, r[j], md(j)),
                m.iif(j == 0, m.at(D0, r[0]) / v,
                      prev + m.at(aDUR, r[j - 1], md(j - 1)) + m.at(Dm, r[j - 1], r[j]) / v))))
            m.constraint(m.and_(m.range(0, c), m.lambda_function(lambda j: m.at(ini, j) <= m.at(aHI, r[j], md(j)))))
            km = m.sum(m.range(1, c), m.lambda_function(lambda j: m.at(Dm, r[j - 1], r[j]))) + \
                m.iif(c > 0, m.at(D0, r[0]) + m.at(D0, r[c - 1]), 0)
            m.constraint(m.iif(c > 0, m.at(ini, c - 1) + m.at(aDUR, r[c - 1], md(c - 1)) +
                               m.at(D0, r[c - 1]) / v, 0) <= I['H'])
            m.constraint(m.sum(m.range(0, c), m.lambda_function(lambda j: m.at(aEN, r[j], md(j)))) +
                         I['cE'] * km <= I['E'])
            custo.append(I['F'] * (c > 0) + km)
        obj = m.sum(custo)
        m.minimize(obj)
        m.close()
        for i in range(n):                # solução inicial: uma USV por tarefa, tudo a bordo
            rotas[i].value.add(i)
            modo[i].value = 0
        opt.param.nb_threads = 1
        opt.param.time_limit = segundos
        opt.param.verbosity = 0
        t0, marcos = time.time(), [s for s in MARCOS if s <= segundos]

        def tique(o, tipo):
            el = time.time() - t0
            while marcos and el >= marcos[0]:
                out(f'HEXALY_T;{I["nome"]};{marcos.pop(0)};{obj.value}')
        opt.param.time_between_ticks = 5
        opt.add_callback(hx.HxCallbackType.TIME_TICKED, tique)
        opt.solve()
        el = time.time() - t0
        for s in marcos:                  # parou antes do marco (ex.: ótimo provado)
            out(f'HEXALY_T;{I["nome"]};{s};{obj.value}')
        rs = [list(r.value) for r in rotas]
        md_ = [int(x.value) for x in modo]
        val = avalia(I, rs, md_)
        assert abs(val - obj.value) <= 1e-4 * val, (val, obj.value)
        out(f'HEXALY;{I["nome"]};{n};{obj.value};{sum(1 for r in rs if r)};'
            f'{opt.solution.status.name};{el:.1f};{opt.solution.get_objective_bound(0)}')


def main():
    alvo = sys.argv[1]
    seg = int(sys.argv[2]) if len(sys.argv) > 2 else 3600
    saida = sys.argv[3] if len(sys.argv) > 3 else None
    feitos = open(saida, encoding='utf-8').read() if saida and os.path.exists(saida) else ''
    arqs = [l.split()[0] for l in open(alvo, encoding='utf-8') if l.strip()] if alvo.endswith('.batch') else [alvo]

    def out(s):
        print(s, flush=True)
        if saida:
            with open(saida, 'a', encoding='utf-8') as f:
                f.write(s + '\n')
    for a in arqs:
        I = le(a if os.path.isabs(a) else os.path.join(AQUI, a))
        if f'HEXALY;{I["nome"]};' in feitos:
            continue
        resolve(I, seg, out)


if __name__ == '__main__':
    main()
