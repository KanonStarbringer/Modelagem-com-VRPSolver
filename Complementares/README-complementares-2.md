# Complementares 2 no VRPSolver — VRPTW, MDVRP e HFVRP

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos à pasta `Complementares/`.

Data: 2026-10-17
Contexto: Exercícios complementares 2 da Lista 1: **VRPTW**, **MDVRP** e **HFVRP**. Cada exercício tem sua pasta em `Complementares/` e segue o roteiro de [Complementares no VRPSolver - CVRP, OVRP e custo fixo](README.md). Os exemplos de aula correspondentes são `model_vrptw.jl`, `model_mdvrp.jl` e `model_hfvrp.jl`.

## VRPTW

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `VRPTW/Instancias/*.txt` | 56 instâncias de Solomon (1987) com 100 clientes (C1, C2, R1, R2, RC1, RC2) |
| `VRPTW/Instancias/*.sol` | Solução ótima de cada uma, da CVRPLIB (via PyVRP/VRPLIB) |
| `VRPTW/vrptw_parser.jl` | `read_vrptw(path; n)` e auto-teste |
| `VRPTW/toy_vrptw.txt` | Toy no formato de Solomon |

A pasta `VRPTW/` tem também o modelo (`vrptw_model.jl`) e o `CVRP.cfg`.

### Parser

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

### Instância toy — `toy_vrptw.txt`

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

### Atenção para a modelagem

- **Formulação por arestas (a do professor, `model_vrptw.jl`)** funciona: `x[e]` com os dois arcos mapeados para a mesma aresta, e grau `== 2`. A correção da Lista usa arcos, com `x_ij` e grau de entrada `== 1`. As duas são válidas.
- **O tempo é assimétrico.** Ao criar os dois arcos de uma aresta $(i,j)$, o arco $i \to j$ consome `T[i+1, j+1]` e o arco $j \to i$ consome `T[j+1, i+1]`.
- **Recurso de tempo:** `set_resource_bounds!(G, i, time, l_i, u_i)` em cada vértice, inclusive no depósito, com $[l_0, u_0]$. A espera é automática: o VRPSolver faz $T_j = \max\{l_j, T_i + t_{ij}\}$.
- **Capacidade:** igual ao CVRP, com consumo `(d(i) + d(j)) / 2` no estilo do professor.
- **Frota:** $L = \lceil \sum d / Q \rceil$ e $U = $ `inst.K`. Os ótimos dos `.sol` usam no máximo K veículos.
- **`.cfg`:** o `model_vrptw.jl` usa `VRPTW.cfg`, que não está na pasta. Use o `CVRP.cfg`.
- **Opcional, para as instâncias grandes:** não criar arcos inviáveis, isto é, os com $l_i + t_{ij} > u_j$.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **151.1** — 0-1-0, 0-2-3-4-0, 0-5-6-0; raiz, 1 nó | 151.1 | 0.64 s |
| R101, $n = 25$ | **617.1** — 8 rotas; raiz, 1 nó | 617.1 | 0.63 s |
| R101, $n = 50$ | **1044.0** — 12 rotas; raiz, 1 nó (conferido em Python: 50 clientes, janelas e capacidade ok) | 1044.0 | 0.68 s |
| R101, $n = 100$ | **1637.7** — 20 rotas; raiz, 1 nó (conferido em Python: 100 clientes, janelas e capacidade ok) | 1637.7 | 1.04 s |

R101 com 25 clientes, conferido em Python (sentido que respeita as janelas): 0-23-22-4-25-0 (104.7), 0-2-21-3-24-0 (99.4), 0-18-0 (31.6), 0-7-8-17-0 (77.7), 0-14-15-13-0 (78.9), 0-12-9-20-1-0 (83.1), 0-11-19-10-0 (80.9), 0-5-16-6-0 (60.8).

### Referências para o benchmark

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

## MDVRP

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `MDVRP/Instancias/p01..p23` | 23 instâncias de Cordeau, Gendreau & Laporte (1997), via fboliveira/MDVRP-Instances |
| `MDVRP/mdvrp_parser.jl` | `read_mdvrp(path)` e auto-teste |
| `MDVRP/toy_mdvrp` | Toy no formato de Cordeau |

A pasta `MDVRP/` tem também o modelo (`mdvrp_model.jl`) e o `CVRP.cfg`.

### Parser

```julia
include("mdvrp_parser.jl")
inst = read_mdvrp(joinpath(@__DIR__, "toy_mdvrp"))
inst = read_mdvrp(joinpath(@__DIR__, "Instancias", "p01"))
inst.n, inst.m, inst.Q        # clientes, veículos POR depósito, capacidade
inst.depots                   # [n+1, ..., n+t]
inst.d[i], inst.C[i, j]       # SEM o +1: os vértices vão de 1 a n+t (não há vértice 0)
inst.D                        # duração máxima da rota (Inf se não houver)
```

**Numeração:** igual à do `model_mdvrp.jl` do professor. Os clientes são `1..n` e os depósitos `n+1..n+t`, então `c(i, j) = inst.C[i, j]` e `d(i) = inst.d[i]`, **sem o `+ 1`** dos outros parsers.

**Custo:** distância euclidiana real, sem arredondamento.

Auto-teste: `julia mdvrp_parser.jl` → `OK: toy + 23 instâncias de Cordeau lidas`.

### Instância toy — `toy_mdvrp`

Dois depósitos, 7 em (0, 0) e 8 em (40, 0); $Q = 11$; $m = 1$ veículo por depósito.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (15, 15) | (4, −3) | (36, −14) | (−1, 11) | (29, −12) | (18, 3) |
| $d_i$ | 3 | 3 | 3 | 4 | 4 | 4 |

**Ótimo (força bruta): 116.2778**, com cutoff `116.28`:

| Depósito | Rota | Custo |
|---|---|---|
| 7 | 7-2-1-4-7 | 53.63 |
| 8 | 8-3-5-6-8 | 62.65 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem o limite de veículos por depósito ($U^k = n$ no lugar de $m$) | **106.2745**: 7-4-1-6-7, 7-2-7 e 8-5-3-8 (dois veículos no depósito 7) |
| Rota voltando a outro depósito (source ≠ sink, ou as arestas de um depósito mapeadas no grafo do outro) | **111.5664**: 7-4-1-6-7 e 8-3-5-2-**7** |

### Atenção para a modelagem

- **Um grafo por depósito:** $V^k = \{k\} \cup V_+$, com source = sink = $k$ e limites $(0, m)$. É exatamente o `model_mdvrp.jl` do professor, que usa $(0, 1)$ porque o exemplo tem 1 veículo por depósito.
- **Arestas cliente-cliente** são mapeadas em **todos** os grafos. As arestas depósito-cliente $(k, i)$ são mapeadas **só** no grafo de $k$.
- **Packing sets:** cada cliente forma um único packing set que reúne suas cópias em todos os grafos, `[(graphs[g], i) for g in 1:t]`.
- **Distância entre packing sets:** chamar `define_elementarity_sets_distance_matrix!` em cada grafo, como o professor faz.
- **Frota mínima:** opcional. A frota total $\lceil \sum d / Q \rceil$ não pode ser imposta por grafo. O professor não usa nenhuma, e o modelo funciona sem ela.
- **`.cfg`:** o `model_mdvrp.jl` usa `MDVRP.cfg`, que não está na pasta. Use o `CVRP.cfg`.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **116.2778** — 7-2-1-4-7, 8-3-5-6-8; raiz, 1 nó | 116.2778 | 0.66 s |
| p01 | **576.8657** — 11 rotas (depósitos 51: 3, 52: 4, 53: 2, 54: 2); raiz, 1 nó | 576.87 | 1.22 s |

| p02 | **473.5333** — 5 rotas (51: 1, 52: 1, 53: 2, 54: 1); raiz, 1 nó | 473.53 | 2.19 s |

p01 e p02 conferidos em Python: toda rota volta ao depósito de onde saiu, carga ≤ Q (no p02, as cargas vão de 153 a 158, de 160), no máximo $m$ rotas por depósito, 50 clientes. As referências **576.87 e 473.53 ficam confirmadas**.

### Referências para o benchmark

Só as instâncias **sem limite de duração** ($D = 0$) correspondem ao exercício: p01–p07, p12, p15, p18 e p21. As outras (p08–p11, p13, p14, p16, …) têm $D > 0$ e exigiriam um recurso de duração.

| Instância | $n$ | Depósitos | $m$ | $Q$ | Valor de referência |
|---|---|---|---|---|---|
| p01 | 50 | 4 | 4 | 80 | **576.87** |
| p02 | 50 | 4 | 2 | 160 | **473.53** |
| p03 | 75 | 5 | 3 | 140 | **641.19** |
| p04 | 100 | 2 | 8 | 100 | **1001.04** |
| p05 | 100 | 2 | 5 | 200 | **750.03** |
| p06 | 100 | 3 | 6 | 100 | **876.50** |

**Atenção:** esses valores são os clássicos da literatura (BKS de Cordeau et al., depois provados ótimos por métodos exatos), mas **não consegui confirmá-los numa fonte online nesta sessão**. O p01 e o p02 foram confirmados pelo VRPSolver (ótimo provado); os demais seguem a confirmar.

## HFVRP

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `HFVRP/Instancias/c*_*hd.txt` | As 8 instâncias 13–20 de Golden et al. (1984), na versão **HD** de Taillard (1999): frota limitada e só custo variável por tipo. Fonte: demos do VRPSolverEasy |
| `HFVRP/hfvrp_parser.jl` | `read_hfvrp(path)` e auto-teste |
| `HFVRP/toy_hfvrp.txt` | Toy no mesmo formato |

A pasta `HFVRP/` tem também o modelo (`hfvrp_model.jl`) e o `CVRP.cfg`.

### Parser

```julia
include("hfvrp_parser.jl")
inst = read_hfvrp(joinpath(@__DIR__, "toy_hfvrp.txt"))
inst = read_hfvrp(joinpath(@__DIR__, "Instancias", "c50_14hd.txt"))
inst.n, inst.K                   # clientes, nº de tipos
inst.Q[k], inst.α[k], inst.u[k]  # capacidade, custo por unidade de distância, nº máx. de veículos do tipo k
inst.d[i+1], inst.ℓ[i+1, j+1]    # demanda e distância física (vértice 0 = depósito)
```

**Custo:** o custo do tipo $k$ é $c^k_{ij} = \alpha_k\,\ell_{ij}$, com $\ell$ a distância euclidiana real. É o caso do item 4 da correção: a matriz $\ell$ serve para a distância entre packing sets, e $\alpha_k \ell$ vai para o objetivo.

Auto-teste: `julia hfvrp_parser.jl` → `OK: toy + 8 instâncias de Golden/Taillard (hd) lidas`.

### Instância toy — `toy_hfvrp.txt`

As posições e demandas são as da toy dos complementares 1. Dois tipos de veículo:

| Tipo | $Q^k$ | $\alpha_k$ | $u^k$ |
|---|---|---|---|
| 1 | 7 | 1.0 | 2 |
| 2 | 11 | 1.5 | 2 |

**Ótimo (força bruta): 176.936**, com cutoff `176.94`:

| Tipo | Rota | Distância | Custo ($\alpha \cdot \ell$) | Carga |
|---|---|---|---|---|
| 1 | 0-1-6-0 | 49.9702 | 49.9702 | 7 |
| 1 | 0-2-3-0 | 60 | 60 | 6 |
| 2 | 0-4-5-0 | 44.6439 | 66.9659 | 8 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Custo igual para todos os tipos (sem $\alpha_k$) | **135.107**: vira o CVRP com o tipo 2 |
| Sem o limite de veículos por tipo ($U^k = n$) | **172.2206**: 4 veículos do tipo 1 |
| Só o tipo 2 (um grafo só, com $Q = 11$) | **202.6605** |

### Atenção para a modelagem

- **Modelo do professor (`model_hfvrp.jl`):** um grafo por tipo, `x[k, e]` por tipo e aresta, e grau somando sobre os tipos. Ele já está quase pronto. O que muda:
  - o custo no objetivo passa a ser **$\alpha_k \cdot \ell$**, ou seja, `inst.α[k] * ℓ(i, j)`, e não um `c(i, j)` único;
  - os limites passam a ser `(0, inst.u[k])` e a capacidade `inst.Q[k]`;
  - o `.cfg` passa a ser o `CVRP.cfg`, porque o `HFVRP.cfg` não está na pasta.
- **Demanda:** é a mesma em todos os grafos (item 2 da correção). O que muda por tipo é só $Q^k$.
- **Packing sets:** as cópias de cada cliente nos $K$ grafos, como no MDVRP.
- **Matriz de distâncias:** use a distância física $\ell$ em todos os grafos.
- **Branching:** `set_branching_priority!(model, "x", 1)` faz o branching em `x[k, e]`. Opcionalmente, pode-se fazer o branching também na soma sobre os tipos, mas não é necessário.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **176.936** — tipo 1: 0-1-6-0, 0-2-3-0; tipo 2: 0-4-5-0; raiz, 1 nó | 176.936 | 0.67 s |
| c50_14hd | **607.529** — tipo 1: 3 rotas (de 4); tipo 2: 2 (de 2); tipo 3: 1 (de 1); raiz, 1 nó | 607.53 | 2.03 s |

c50_14hd conferido em Python: custo $\sum_k \alpha_k \ell$ = 607.529, 50 clientes, cargas 120/119/119 (Q = 120), 156/159 (Q = 160) e 300 (Q = 300). A referência **607.53 fica confirmada**.

### Referências para o benchmark

| Instância | $n$ | Tipos | Valor de referência (HD) |
|---|---|---|---|
| c50_13hd | 50 | 6 | **1517.84** |
| c50_14hd | 50 | 3 | **607.53** |
| c50_15hd | 50 | 3 | **1015.29** |
| c50_16hd | 50 | 3 | **1144.94** |
| c75_17hd | 75 | 4 | **1061.96** |
| c75_18hd | 75 | 6 | **1823.58** |
| c100_19hd | 100 | 3 | **1117.51** |
| c100_20hd | 100 | 3 | **1534.17** |

**Atenção:** como no MDVRP, esses são os valores clássicos da literatura (Taillard 1999; ótimos de Baldacci & Mingozzi 2009), mas **não os confirmei numa fonte online nesta sessão**. O c50_14hd foi confirmado pelo VRPSolver (ótimo provado); os demais seguem a confirmar.

## Fontes

- Solomon, M. M. (1987). Algorithms for the vehicle routing and scheduling problems with time window constraints. *Operations Research* 35(2), 254–265.
- Instâncias e soluções: CVRPLIB, via <https://github.com/PyVRP/VRPLIB> (`tests/data/cvrplib/Vrp-Set-Solomon`).
- Documentação do VRPSolver — CVRPTW: <https://vrpsolvereasy.readthedocs.io/en/latest/Demos/CVRPTW.html>
- Cordeau, J.-F., Gendreau, M., Laporte, G. (1997). A tabu search heuristic for periodic and multi-depot vehicle routing problems. *Networks* 30(2), 105–119.
- Instâncias MDVRP: <https://github.com/fboliveira/MDVRP-Instances> (formato descrito em `DESCRIPTION.md`, a partir do NEO/Málaga).
- Golden, B., Assad, A., Levy, L., Gheysens, F. (1984). The fleet size and mix vehicle routing problem. *Computers & Operations Research* 11(1), 49–66.
- Taillard, É. D. (1999). A heuristic column generation method for the heterogeneous fleet VRP. *RAIRO* 33(1), 1–14.
- Baldacci, R., Mingozzi, A. (2009). A unified exact method for solving different classes of vehicle routing problems. *Mathematical Programming* 120(2), 347–380.
- Instâncias HFVRP: <https://github.com/inria-UFF/VRPSolverEasy> (`VRPSolverEasy/demos/data/HFVRP`).

## Notas relacionadas

- Exercícios complementares 2 · [Complementares no VRPSolver - CVRP, OVRP e custo fixo](README.md) · VRP com Janelas de Tempo · Capacitated VRP
- VRPSolver · Resource-Constrained Shortest Path
