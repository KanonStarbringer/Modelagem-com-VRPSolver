# VRPTW — Vehicle Routing Problem with Time Windows

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-2.md`](../README-complementares-2.md).

CVRP em que cada cliente tem uma janela de tempo $[l_i, u_i]$ para o início do serviço (chegar cedo e esperar é permitido) e um tempo de serviço $s_i$. Minimiza a distância total com frota homogênea de capacidade $Q$.

## Como rodar

```bash
julia vrptw_parser.jl      # auto-teste do parser
julia vrptw_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/*.txt` | 56 instâncias de Solomon (1987) com 100 clientes (C1, C2, R1, R2, RC1, RC2) |
| `Instancias/*.sol` | Solução ótima de cada uma, da CVRPLIB (via PyVRP/VRPLIB) |
| `vrptw_parser.jl` | `read_vrptw(path; n)` e auto-teste |
| `toy_vrptw.txt` | Toy no formato de Solomon |

Esta pasta tem também o modelo (`vrptw_model.jl`) e o `CVRP.cfg`.

## Parser

```julia
include("vrptw_parser.jl")
inst = read_vrptw(joinpath(@__DIR__, "toy_vrptw.txt"))
inst = read_vrptw(joinpath(@__DIR__, "Instancias", "R101.txt"); n = 25)   # 25 primeiros clientes
inst.n, inst.K, inst.Q          # clientes, frota de Solomon, capacidade
inst.d[i+1], inst.l[i+1], inst.u[i+1], inst.s[i+1]   # demanda, janela [l, u], serviço
inst.C[i+1, j+1]                # custo
inst.T[i+1, j+1]                # tempo do arco i→j = s_i + c_ij (assimétrico!)
inst.opt                        # custo do .sol (só para n = 100)
```

**Convenção — atenção:** a literatura exata (e os `.sol`) usa a distância euclidiana **truncada em uma casa decimal**, $c_{ij} = \lfloor 10\,\text{dist} \rfloor / 10$, e o tempo $t_{ij} = s_i + c_{ij}$. O parser já faz isso. Conferi em Python as 56 soluções: o custo de todas bate com o `.sol`, e todas respeitam janelas, capacidade e frota.

Auto-teste: `julia vrptw_parser.jl` → `OK: toy + 56 instâncias de Solomon lidas`.

## Instância toy — `toy_vrptw.txt`

Depósito em (0, 0) com janela [0, 200]; $Q = 11$; serviço $s = 5$ em todo cliente. São as posições e demandas da toy dos complementares 1, agora com janelas.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (10, 0) | (20, 0) | (30, 0) | (0, 12) | (−3, 22) | (−14, 6) |
| $d_i$ | 3 | 3 | 3 | 4 | 4 | 4 |
| $[l_i, u_i]$ | [0, 15] | [0, 40] | [0, 35] | [60, 90] | [10, 40] | [80, 120] |

$L = \lceil 21/11 \rceil = 2$ e $U = 6$ (o `K` do arquivo).

**Ótimo (força bruta): 151.1**, com cutoff `151.11`:

| Rota | Custo | Horários de início do serviço |
|---|---|---|
| 0-1-0 | 20 | 1: 10 |
| 0-2-3-4-0 | 20 + 10 + 32.3 + 12 = 74.3 | 2: 20 · 3: 35 · 4: 72.3 |
| 0-5-6-0 | 22.2 + 19.4 + 15.2 = 56.8 | 5: 22.2 · 6: 80 (espera desde 46.6) |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Janela global $[0, T]$ em todos os vértices (o erro 1 da correção) | **135**, que é o ótimo do CVRP |
| Sem o tempo de serviço ($t_{ij} = c_{ij}$) | **135**: sem os 5 de serviço, 0-1-2-3 chega em 3 no instante 30 ≤ 35 |
| Tempo do arco simétrico (`T[i,j]` com $i < j$ nos dois sentidos) | **151.1**: a toy **não detecta**, porque o serviço é igual em todos os clientes e só a volta ao depósito (com folga) perde o $s_j$. Mesmo assim está errado |

## Atenção para a modelagem

- **Formulação por arestas (a do professor, `model_vrptw.jl`)** funciona: `x[e]` com os dois arcos mapeados para a mesma aresta, e grau `== 2`. A correção da Lista usa arcos, com `x_ij` e grau de entrada `== 1`. As duas são válidas.
- **O tempo é assimétrico.** Ao criar os dois arcos de uma aresta $(i,j)$, o arco $i \to j$ consome `T[i+1, j+1]` e o arco $j \to i$ consome `T[j+1, i+1]`.
- **Recurso de tempo:** `set_resource_bounds!(G, i, time, l_i, u_i)` em cada vértice, inclusive no depósito, com $[l_0, u_0]$. A espera é automática: o VRPSolver faz $T_j = \max\{l_j, T_i + t_{ij}\}$.
- **Capacidade:** igual ao CVRP, com consumo `(d(i) + d(j)) / 2` no estilo do professor.
- **Frota:** $L = \lceil \sum d / Q \rceil$ e $U = $ `inst.K`. Os ótimos dos `.sol` usam no máximo K veículos.
- **`.cfg`:** o `model_vrptw.jl` usa `VRPTW.cfg`, que não está na pasta. Use o `CVRP.cfg`.
- **Opcional, para as instâncias grandes:** não criar arcos inviáveis, isto é, os com $l_i + t_{ij} > u_j$.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **151.1** — 0-1-0, 0-2-3-4-0, 0-5-6-0; raiz, 1 nó | 151.1 | 0.64 s |
| R101, $n = 25$ | **617.1** — 8 rotas; raiz, 1 nó | 617.1 | 0.63 s |
| R101, $n = 50$ | **1044.0** — 12 rotas; raiz, 1 nó (conferido em Python: 50 clientes, janelas e capacidade ok) | 1044.0 | 0.68 s |
| R101, $n = 100$ | **1637.7** — 20 rotas; raiz, 1 nó (conferido em Python: 100 clientes, janelas e capacidade ok) | 1637.7 | 1.04 s |

R101 com 25 clientes, conferido em Python (sentido que respeita as janelas): 0-23-22-4-25-0 (104.7), 0-2-21-3-24-0 (99.4), 0-18-0 (31.6), 0-7-8-17-0 (77.7), 0-14-15-13-0 (78.9), 0-12-9-20-1-0 (83.1), 0-11-19-10-0 (80.9), 0-5-16-6-0 (60.8).

## Referências para o benchmark

| Instância | $n$ | Ótimo | Rotas | Fonte |
|---|---|---|---|---|
| R101 | 25 | **617.1** | 8 | CBC, ótimo provado |
| C101 | 25 | **191.3** | 3 | CBC, ótimo provado |
| RC101 | 25 | **461.1** | 4 | CBC, ótimo provado |
| R101 | 50 | **1044.0** | 12 | CBC, ótimo provado |
| C101 | 100 | **827.3** | 10 | `.sol` da CVRPLIB |
| R101 | 100 | **1637.7** | 20 | `.sol` |
| R102 | 100 | **1466.6** | 18 | `.sol` |
| RC101 | 100 | **1619.8** | 15 | `.sol` |
| C201 | 100 | **589.1** | 3 | `.sol` |
| R201 | 100 | **1143.2** | 8 | `.sol` |
| RC201 | 100 | **1261.8** | 9 | `.sol` |

Os valores de 25 e 50 clientes batem com os ótimos publicados (Kohl et al., 1999). As instâncias da classe 2 (C2, R2, RC2) têm janelas largas e rotas longas, e são bem mais difíceis para o pricing.

## Fontes

- Solomon, M. M. (1987). Algorithms for the vehicle routing and scheduling problems with time window constraints. *Operations Research* 35(2), 254–265.
- Instâncias e soluções: CVRPLIB, via <https://github.com/PyVRP/VRPLIB> (`tests/data/cvrplib/Vrp-Set-Solomon`).
- Documentação do VRPSolver — CVRPTW: <https://vrpsolvereasy.readthedocs.io/en/latest/Demos/CVRPTW.html>
