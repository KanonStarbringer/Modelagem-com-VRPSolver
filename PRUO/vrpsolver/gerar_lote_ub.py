"""Gera bench_ub.batch: todas as instâncias do benchmark com --ub = valor do Hexaly em 1 h + 0,01.

Lê as linhas HEXALY; de saida_hexaly25/50/100.txt. Instâncias sem resultado do Hexaly ficam de
fora (o script avisa). Busca por melhor limitante (teste_busca, 11/11/2026); n = 100 também
limita a enumeração em 1e5, como no lote sem UB.
Uso: python gerar_lote_ub.py
"""
import os

AQUI = os.path.dirname(os.path.abspath(__file__))
FOLGA = 0.01  # set_cutoff! poda nós com LB >= cutoff: a folga mantém alcançável a solução do Hexaly

hex_ = {}
for n in (25, 50, 100):
    arq = os.path.join(AQUI, f'saida_hexaly{n}.txt')
    if os.path.exists(arq):
        for l in open(arq, encoding='utf-8'):
            c = l.strip().split(';')
            if c[0] == 'HEXALY':
                hex_[c[1]] = float(c[3])

linhas, faltam = [], []
for n in (25, 50, 100):
    for l in open(os.path.join(AQUI, f'bench_n{n}.batch'), encoding='utf-8'):
        if not l.strip():
            continue
        inst = l.split()[0]
        nome = os.path.splitext(os.path.basename(inst))[0]
        if nome not in hex_:
            faltam.append(nome)
            continue
        cfg = ' -c config/PRUO_melhor_limitante_enum100k.cfg' if n == 100 else ' -c config/PRUO_melhor_limitante.cfg'
        linhas.append(f'{inst} -u {hex_[nome] + FOLGA:.4f}{cfg}')

with open(os.path.join(AQUI, 'bench_ub.batch'), 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(linhas) + '\n')
print(f'bench_ub.batch: {len(linhas)} instâncias')
if faltam:
    print(f'Sem resultado do Hexaly ({len(faltam)}):', ', '.join(faltam))
