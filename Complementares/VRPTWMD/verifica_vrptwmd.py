"""Verificador independente das soluções do VRPTWMD-2R impressas nos logs do batch.

Não usa padrões nem o parser Julia: lê a instância, lê as rotas do log e simula do zero.
Veículo sai do depósito em 0, chega no parking (espera a abertura), libera os entregadores na chegada;
cada entregador anda a 1/3 da velocidade (tempo = 3·dist), espera a janela do cliente, atende e volta;
o veículo parte quando o último entregador volta. Checa janelas, capacidade, cobertura, nº de veículos.
Custo = 1000·veículos + 100·entregadores + 10·dist. veículo + 1·dist. a pé.
Distância: euclidiana truncada + Floyd–Warshall por nível (convenção do modelo); também informa
quantos arcos usados encurtam com o FW (se 0, a convenção não afeta o custo daquela solução).

Uso: python -I verifica_vrptwmd.py <pasta VRPTWMD>   (lê resultados.csv, Instancias/, logs/)
"""
import csv, math, re, sys
from pathlib import Path


def trunc(p, r):
    return math.floor(math.sqrt((p[0] - r[0]) ** 2 + (p[1] - r[1]) ** 2))


def floyd(pts):
    m = len(pts)
    d = [[trunc(p, r) for r in pts] for p in pts]
    raw = [row[:] for row in d]
    for k in range(m):
        for i in range(m):
            for j in range(m):
                if d[i][k] + d[k][j] < d[i][j]:
                    d[i][j] = d[i][k] + d[k][j]
    return d, raw


def ler_instancia(path):
    L = [l.split() for l in open(path) if l.strip()]
    iv = next(i for i, l in enumerate(L) if l[0] == "VEHICLE")
    ik = next(i for i, l in enumerate(L) if l[0] == "CLU")
    ic = next(i for i, l in enumerate(L) if l[0] == "CUST")
    K, Q = map(int, L[iv + 2])
    clu = [list(map(int, l)) for l in L[ik + 1:ic]]
    cus = {int(l[0]): list(map(int, l)) for l in L[ic + 1:]}
    return K, Q, clu, cus


def ler_solucao(log):
    veics, cur = [], None
    for l in open(log, encoding="utf-8", errors="replace"):
        m = re.match(r"veículo com (\d+) entregador", l)
        if m:
            cur = {"l": int(m.group(1)), "paradas": []}
            veics.append(cur)
            continue
        m = re.match(r"\s+parking (\d+): .*a pé: (.*)$", l)
        if m and cur is not None:
            rotas = [[int(x) for x in r.split(" - ")[1:-1]] for r in m.group(2).split(" | ")]
            cur["paradas"].append((int(m.group(1)), rotas))
        m = re.match(r"Custo ótimo: ([\d.]+)", l)
        if m:
            custo_log = float(m.group(1))
    return veics, custo_log


def verifica(inst_path, log_path):
    K, Q, clu, cus = ler_instancia(inst_path)
    n = len(clu) - 1
    d1, raw1 = floyd([c[1:3] for c in clu])
    loc = {}                                    # por cluster: (d2, raw2, índice local de cada cliente)
    for i in range(1, n + 1):
        cs = [c for c in cus.values() if c[7] == i]
        d2, raw2 = floyd([clu[i][1:3]] + [c[1:3] for c in cs])
        loc[i] = (d2, raw2, {c[0]: h + 1 for h, c in enumerate(cs)})
    veics, custo_log = ler_solucao(log_path)
    erros, fw_usado = [], 0
    vistos_clu, vistos_cus = [], []
    dv_tot = dp_tot = ent_tot = 0
    for v in veics:
        t, prev, carga, dv = 0, 0, 0, 0
        for p, rotas in v["paradas"]:
            vistos_clu.append(p)
            if len(rotas) > v["l"]:
                erros.append(f"parking {p}: {len(rotas)} rotas e só {v['l']} entregadores")
            dv += d1[prev][p]; fw_usado += d1[prev][p] < raw1[prev][p]
            t = max(t + d1[prev][p], clu[p][4])
            if t > clu[p][5]:
                erros.append(f"parking {p}: chega {t} > {clu[p][5]}")
            d2, raw2, idx = loc[p]
            volta = t
            for r in rotas:
                s, h0 = t, 0
                for c in r:
                    if c not in idx:
                        erros.append(f"cliente {c} não pertence ao cluster {p}")
                        continue
                    h = idx[c]
                    vistos_cus.append(c); carga += cus[c][3]
                    dp_tot += d2[h0][h]; fw_usado += d2[h0][h] < raw2[h0][h]
                    s = max(s + 3 * d2[h0][h], cus[c][4])
                    if s > cus[c][5]:
                        erros.append(f"cliente {c}: início {s} > {cus[c][5]}")
                    s += cus[c][6]; h0 = h
                dp_tot += d2[h0][0]; fw_usado += d2[h0][0] < raw2[h0][0]
                volta = max(volta, s + 3 * d2[h0][0])
            t, prev = volta, p
        dv += d1[prev][0]; fw_usado += d1[prev][0] < raw1[prev][0]
        t += d1[prev][0]
        if t > clu[0][5]:
            erros.append(f"volta ao depósito em {t} > {clu[0][5]}")
        if carga > Q:
            erros.append(f"carga {carga} > {Q}")
        dv_tot += dv; ent_tot += v["l"]
    if sorted(vistos_clu) != list(range(1, n + 1)):
        erros.append("clusters não cobertos exatamente uma vez")
    if sorted(vistos_cus) != sorted(cus):
        erros.append("clientes não cobertos exatamente uma vez")
    if len(veics) > K:
        erros.append(f"{len(veics)} veículos > {K}")
    custo = 1000 * len(veics) + 100 * ent_tot + 10 * dv_tot + dp_tot
    if abs(custo - custo_log) > 1e-6:
        erros.append(f"custo recalculado {custo} ≠ log {custo_log}")
    return custo, len(veics), ent_tot, dv_tot, dp_tot, fw_usado, erros


if __name__ == "__main__":
    base = Path(sys.argv[1])
    ruins, sem_log = 0, []
    with open(base / "resultados.csv", encoding="utf-8") as f:
        linhas = list(csv.DictReader(f))
    for r in linhas:
        nome, tam = r["instancia"], r["tamanho"]
        if not (base / "logs" / f"{nome}.log").exists():
            sem_log.append(nome)
            continue
        custo, nv, ne, dv, dp, fw, erros = verifica(base / "Instancias" / f"Solomon_{tam}" / f"{nome}.txt",
                                                    base / "logs" / f"{nome}.log")
        ruins += bool(erros)
        if erros or r["comparacao"] != "igual (ótimo)":
            print(f"{nome:14} {r['comparacao']:16} UB pub {r['ref_UB']:>6}  recalc {custo:>6}  "
                  f"veíc {nv} entreg {ne} dist {dv}/{dp}  arcos FW {fw}  {'OK' if not erros else erros}")
    print(f"{len(linhas) - len(sem_log)} soluções verificadas, {ruins} com erro; sem log: {len(sem_log)}")
