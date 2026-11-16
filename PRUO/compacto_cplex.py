"""Formulação compacta (C) do artigo no CPLEX 22.1.1 (cplex.exe), nas instâncias do benchmark.

Reusa prototipo_pruo.compacto (a mesma (C) validada contra o VRPSolver) e lê as instâncias no
formato do VRPSolver (vrpsolver/instancias). Um thread, limite de tempo por instância.
Para cada instância escreve COMPACTO;nome;n;UB;LB;status;tempo;LP, com LP = relaxação linear de (C).
Pula as instâncias que já estão na saída. Uma instância interrompida não deixa linha parcial.

Uso: python -X utf8 compacto_cplex.py <instância.txt | lote.batch> <segundos> <saída.txt>
"""
import math
import os
import re
import sys
import tempfile
import time

import pulp

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import prototipo_pruo as p  # noqa: E402

# Dropbox/antivírus às vezes seguram o cplex.log por um instante e o PuLP derruba o lote ao apagá-lo:
# um log que não pôde ser apagado não afeta o resultado.
_rm = pulp.apis.core.LpSolver_CMD.silent_remove
def _rm_tolerante(self, file):
    try:
        _rm(self, file)
    except PermissionError:
        pass
pulp.apis.core.LpSolver_CMD.silent_remove = _rm_tolerante

CPLEX = r'C:\Program Files\IBM\ILOG\CPLEX_Studio2211\cplex\bin\x64_win64\cplex.exe'
# ponytail: árvore limitada a 8 GB (excesso em arquivo de nós comprimido no disco), para não
# competir por memória com o WSL; se estourar, o CPLEX para e a linha sai com status Memoria.
# Os arquivos de nós vão para a pasta temporária, fora do Dropbox.
OPCOES = ['set mip limits treememory 8000', 'set mip strategy file 3', 'set workmem 2048',
          f'set workdir {tempfile.gettempdir()}']


def ler(path):
    """Instância no formato de exportar_instancias.escreve -> dicionário do protótipo."""
    kv, nos = {}, []
    with open(path, encoding='utf-8') as f:
        em_nos = False
        for linha in f:
            c = linha.split('#')[0].split()
            if not c:
                continue
            if c[0] == 'nos':
                em_nos = True
            elif em_nos:
                nos.append([float(x) for x in c[1:]])
            else:
                kv[c[0]] = c[1:]
    n = int(kv['n'][0])
    pts = [(r[0], r[1]) for r in nos]
    tau, eps = {}, {}
    for i in range(1, n + 1):
        _, _, _, _, _, tL, eL, tS, eS = nos[i]
        tau[i, 'L'], eps[i, 'L'] = tL, eL
        if tS >= 0:
            tau[i, 'S'], eps[i, 'S'] = tS, eS
    fl = lambda k: float(kv[k][0])
    return dict(n=n, K=int(kv['K'][0]), F=fl('F'), H=fl('H'), D=fl('D'), P=int(kv['P'][0]), E=fl('E'),
                cE=fl('cE'), v=fl('v'), C=[float(x) for x in kv['C']], gam=[int(x) for x in kv['gam']],
                pts=pts, dist=[[math.dist(a, b) for b in pts] for a in pts],
                a=[r[2] for r in nos], b=[r[3] for r in nos], w={i: nos[i][4] for i in range(n + 1)},
                s={i: 10.0 for i in range(1, n + 1)},  # sensoriamento (gerar_benchmark: 10 min)
                tau=tau, eps=eps)


def resolve(I, seg, relax=False):
    """Roda compacto(I) no cplex.exe; devolve (UB ou None, LB, status, tempo) lidos do log."""
    log = os.path.join(tempfile.gettempdir(), f'compacto_{os.getpid()}.log')
    if os.path.exists(log):
        os.remove(log)
    p.SOLVER = pulp.CPLEX_CMD(path=CPLEX, msg=False, timeLimit=seg, threads=1, logPath=log, options=OPCOES)
    t0 = time.time()
    sol = p.compacto(I, relax=relax)
    tempo = time.time() - t0
    txt = open(log, encoding='utf-8', errors='ignore').read()
    m = re.search(r'Solution time =\s*([\d.]+) sec', txt)  # a 1ª é a do MIP
    tempo = float(m[1]) if m else tempo
    ub = sol['obj'] if sol else None
    if relax:
        return ub, ub, 'LP', tempo
    if 'Integer optimal' in txt:
        return ub, ub, 'Optimal', tempo
    lb = re.findall(r'Current MIP best bound =\s*([-\d.e+]+)', txt)
    st = 'Memoria' if 'memory limit' in txt.lower() else 'TimeLimit' if 'Time limit exceeded' in txt else 'Outro'
    return ub, float(lb[-1]) if lb else float('nan'), st, tempo


def main(alvo, seg, saida):
    seg = float(seg)
    alvo, saida = os.path.abspath(alvo), os.path.abspath(saida)
    # o cplex.exe grava cplex.log no diretório corrente: uma pasta por processo, para rodar lotes em paralelo
    os.chdir(tempfile.mkdtemp(prefix='compacto_'))
    if alvo.endswith('.batch'):
        base = os.path.dirname(os.path.abspath(alvo))
        insts = [os.path.join(base, l.split()[0]) for l in open(alvo, encoding='utf-8') if l.strip()]
    else:
        insts = [alvo]
    feitas = set()
    if os.path.exists(saida):
        feitas = {l.split(';')[1] for l in open(saida, encoding='utf-8') if l.startswith('COMPACTO;')}
    for path in insts:
        nome = os.path.splitext(os.path.basename(path))[0]
        if nome in feitas:
            continue
        I = ler(path)
        lp = resolve(I, 600, relax=True)[0]
        ub, lb, st, t = resolve(I, seg)
        f = lambda x: 'NaN' if x is None or x != x else repr(x)
        linha = f'COMPACTO;{nome};{I["n"]};{f(ub)};{f(lb)};{st};{t:.1f};{f(lp)}'
        print(linha, flush=True)
        with open(saida, 'a', encoding='utf-8') as g:
            g.write(linha + '\n')


if __name__ == '__main__':
    main(*sys.argv[1:4])
