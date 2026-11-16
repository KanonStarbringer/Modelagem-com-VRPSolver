"""Gerador de instâncias de benchmark do PRUO, no formato lido pelo modelo do VRPSolver.

Cenário: área de 30 x 30 km; base (depósito) no meio da borda sul, em (0, 0); um servidor
(navio-mãe fundeado) no centro, em (0, 15), com alcance de 12 km; missão de 8 h.
Famílias à la Solomon:
  distribuição  R (uniforme), C (clusters) ou RC (metade de cada);
  janela        E (estreita, 30-60 min) ou L (larga, 90-180 min);
  capacidade    C por período de 30 min do servidor (1 ou 2), com carga w_i em {1, 2};
  enlace        2 períodos sorteados sem enlace (DDIL).
Toda tarefa é viável sozinha, a bordo; logo, toda instância é viável com K = n.

Uso: python gerar_benchmark.py      (escreve vrpsolver/instancias/bench_*.txt e bench_n*.batch)
"""
import math
import os
import random
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
from exportar_instancias import PASTA, escreve  # noqa: E402

H, D, V = 480, 30, 1 / 3              # horizonte (min), período (min), velocidade (km/min = 20 km/h)
SERVIDOR, ALCANCE = (0.0, 15.0), 12.0
NS, DISTS, JANELAS, CAPS, SEMENTES = (25, 50, 100), ('R', 'C', 'RC'), ('E', 'L'), (1, 2), (1, 2)


def pontos(rnd, n, dist):
    def uniforme():
        return (rnd.uniform(-15, 15), rnd.uniform(1, 30))
    centros = [uniforme() for _ in range(rnd.randint(4, 6))]

    def cluster():
        while True:                     # sorteia até cair dentro da área
            cx, cy = rnd.choice(centros)
            p = (rnd.gauss(cx, 2.0), rnd.gauss(cy, 2.0))
            if -15 <= p[0] <= 15 and 1 <= p[1] <= 30:
                return p
    gera = {'R': [uniforme] * n, 'C': [cluster] * n, 'RC': [uniforme, cluster] * (n // 2 + 1)}[dist]
    return [(0.0, 0.0)] + [g() for g in gera[:n]]


def instancia(n, dist, jan, cap, seed, pts=None):
    """pts (opcional): lista [(x, y)] em km, com o depósito primeiro, para usar pontos reais."""
    rnd = random.Random(f'{n}{dist}{jan}{cap}{seed}')
    pts = pts or pontos(rnd, n, dist)
    P = H // D
    a, b, tau, eps, w = [0.0], [float(H)], {}, {}, {0: 0}
    for i in range(1, n + 1):
        d0 = math.dist(pts[0], pts[i])
        pL = rnd.uniform(20, 40)
        tau[i, 'L'], eps[i, 'L'] = 10 + pL, 0.03 * pL / 60
        ds = math.dist(SERVIDOR, pts[i])
        if ds <= ALCANCE:
            th = 2 + 0.25 * ds
            tau[i, 'S'], eps[i, 'S'] = 10 + th, 0.01 * th / 60
        larg = rnd.uniform(30, 60) if jan == 'E' else rnd.uniform(90, 180)
        ult = H - tau[i, 'L'] - d0 / V      # início mais tarde que ainda permite voltar
        ai = rnd.uniform(max(0.0, d0 / V - larg), max(0.0, ult - larg))
        a.append(ai)
        b.append(min(ai + larg, ult))
        w[i] = rnd.choice((1, 2))
    gam = [1] * P
    for t in rnd.sample(range(P), 2):
        gam[t] = 0
    return dict(n=n, K=n, F=100, H=H, D=D, P=P, E=6.0, cE=0.05, v=V, C=[cap] * P, gam=gam,
                pts=pts, a=a, b=b, tau=tau, eps=eps, w=w)


def main():
    lotes = {}
    for n in NS:
        for dist in DISTS:
            for jan in JANELAS:
                for cap in CAPS:
                    for seed in SEMENTES:
                        nome = f'bench_{dist}{jan}_n{n}_c{cap}_s{seed}'
                        escreve(instancia(n, dist, jan, cap, seed), nome, None, False)
                        lotes.setdefault(n, []).append(f'instancias/{nome}.txt')
    for n, linhas in lotes.items():
        with open(os.path.join(PASTA, f'bench_n{n}.batch'), 'w', encoding='utf-8') as f:
            f.write('\n'.join(linhas) + '\n')
        print(f'n = {n}: {len(linhas)} instâncias -> bench_n{n}.batch')


if __name__ == '__main__':
    main()
