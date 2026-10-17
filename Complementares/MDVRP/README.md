# MDVRP — Multi-Depot Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-2.md`](../README-complementares-2.md).

CVRP com vários depósitos: cada rota começa e termina no mesmo depósito $k$, e cada depósito tem no máximo $m_k$ veículos.

## Como rodar

```bash
julia mdvrp_parser.jl      # auto-teste do parser
julia mdvrp_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/p01..p23` | 23 instâncias de Cordeau, Gendreau & Laporte (1997), via fboliveira/MDVRP-Instances |
| `mdvrp_parser.jl` | `read_mdvrp(path)` e auto-teste |
| `toy_mdvrp` | Toy no formato de Cordeau |

Esta pasta tem também o modelo (`mdvrp_model.jl`) e o `CVRP.cfg`.

## Parser

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

## Instância toy — `toy_mdvrp`

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

## Atenção para a modelagem

- **Um grafo por depósito:** $V^k = \{k\} \cup V_+$, com source = sink = $k$ e limites $(0, m)$. É exatamente o `model_mdvrp.jl` do professor, que usa $(0, 1)$ porque o exemplo tem 1 veículo por depósito.
- **Arestas cliente-cliente** são mapeadas em **todos** os grafos. As arestas depósito-cliente $(k, i)$ são mapeadas **só** no grafo de $k$.
- **Packing sets:** cada cliente forma um único packing set que reúne suas cópias em todos os grafos, `[(graphs[g], i) for g in 1:t]`.
- **Distância entre packing sets:** chamar `define_elementarity_sets_distance_matrix!` em cada grafo, como o professor faz.
- **Frota mínima:** opcional. A frota total $\lceil \sum d / Q \rceil$ não pode ser imposta por grafo. O professor não usa nenhuma, e o modelo funciona sem ela.
- **`.cfg`:** o `model_mdvrp.jl` usa `MDVRP.cfg`, que não está na pasta. Use o `CVRP.cfg`.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **116.2778** — 7-2-1-4-7, 8-3-5-6-8; raiz, 1 nó | 116.2778 | 0.66 s |
| p01 | **576.8657** — 11 rotas (depósitos 51: 3, 52: 4, 53: 2, 54: 2); raiz, 1 nó | 576.87 | 1.22 s |

| p02 | **473.5333** — 5 rotas (51: 1, 52: 1, 53: 2, 54: 1); raiz, 1 nó | 473.53 | 2.19 s |

p01 e p02 conferidos em Python: toda rota volta ao depósito de onde saiu, carga ≤ Q (no p02, as cargas vão de 153 a 158, de 160), no máximo $m$ rotas por depósito, 50 clientes. As referências **576.87 e 473.53 ficam confirmadas**.

## Referências para o benchmark

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

## Fontes

- Cordeau, J.-F., Gendreau, M., Laporte, G. (1997). A tabu search heuristic for periodic and multi-depot vehicle routing problems. *Networks* 30(2), 105–119.
- Instâncias MDVRP: <https://github.com/fboliveira/MDVRP-Instances> (formato descrito em `DESCRIPTION.md`, a partir do NEO/Málaga).
