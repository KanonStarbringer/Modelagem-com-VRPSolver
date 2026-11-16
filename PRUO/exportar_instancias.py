"""Exporta as instâncias do protótipo para o modelo no VRPSolver (pasta vrpsolver/instancias).

Cada arquivo traz os dados da instância e, até n = 20, o valor do compacto (C) no CBC
(60 s), com a indicação de ótimo provado ou não. Também escreve os arquivos de lote.

Uso: python exportar_instancias.py
"""
import os
import sys

import pulp

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import prototipo_pruo as p  # noqa: E402

PASTA = os.path.join(AQUI, 'vrpsolver')
# (n, sementes, K; None = K igual a n, como no teste de escala do Python; calcular referência?)
GRUPOS = [(7, range(1, 21), 3, True), (10, (1, 2, 3), None, True), (15, (1, 2, 3), None, True),
          (20, (1, 2, 3), None, True), (30, (1, 2, 3), None, False), (40, (1, 2, 3), None, False),
          (50, (1, 2, 3), None, False)]


def escreve(I, nome, ref, provado):
    n = I['n']
    with open(os.path.join(PASTA, 'instancias', nome + '.txt'), 'w', encoding='utf-8') as f:
        f.write(f'# PRUO: instância {nome}, exportada de prototipo_pruo.py\n')
        for k in ('n', 'K', 'F', 'H', 'D', 'P', 'E', 'cE', 'v'):
            f.write(f'{k} {I[k]!r}\n')
        f.write('C ' + ' '.join(repr(float(c)) for c in I['C']) + '\n')
        f.write('gam ' + ' '.join(map(str, I['gam'])) + '\n')
        f.write(f'ref {"NaN" if ref is None else repr(ref)} {int(provado)}\n')
        f.write('# id x y a b w tauL epsL tauS epsS  (tauS = epsS = -1: fora do alcance do servidor)\nnos\n')
        f.write(f'0 0.0 0.0 0.0 {float(I["H"])!r} 0.0 0.0 0.0 -1.0 -1.0\n')
        for i in range(1, n + 1):
            x, y = I['pts'][i]
            tS, eS = (I['tau'][i, 'S'], I['eps'][i, 'S']) if (i, 'S') in I['tau'] else (-1.0, -1.0)
            f.write(f'{i} {x!r} {y!r} {I["a"][i]!r} {I["b"][i]!r} {float(I["w"][i])!r} '
                    f'{I["tau"][i, "L"]!r} {I["eps"][i, "L"]!r} {tS!r} {eS!r}\n')


def main():
    os.makedirs(os.path.join(PASTA, 'instancias'), exist_ok=True)
    p.SOLVER = pulp.PULP_CBC_CMD(msg=0, timeLimit=60)
    lotes = {'validacao': [], 'escala': []}
    for n, sementes, K, com_ref in GRUPOS:
        for seed in sementes:
            I = p.instancia(seed, n)
            I['K'] = K or n
            nome = f'pruo_n{n}_s{seed:02d}'
            ref, provado = None, False
            if com_ref:
                C = p.compacto(I)
                if C:
                    ref, provado = C['obj'], C['provado']
            escreve(I, nome, ref, provado)
            lotes['validacao' if com_ref else 'escala'].append(f'instancias/{nome}.txt')
            print(nome, 'ref =', ref, '(provado)' if provado else '')
    for k, linhas in lotes.items():
        with open(os.path.join(PASTA, k + '.batch'), 'w', encoding='utf-8') as f:
            f.write('\n'.join(linhas) + '\n')


if __name__ == '__main__':
    main()
