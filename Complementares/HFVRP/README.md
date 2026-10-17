# HFVRP — Heterogeneous Fleet Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-2.md`](../README-complementares-2.md).

CVRP com frota heterogênea **limitada**: o tipo $k$ tem capacidade $Q^k$, custo por distância $\alpha_k$ e no máximo $u^k$ veículos. Variante HD de Taillard: só custo variável.

## Como rodar

```bash
julia hfvrp_parser.jl      # auto-teste do parser
julia hfvrp_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/c*_*hd.txt` | As 8 instâncias 13–20 de Golden et al. (1984), na versão **HD** de Taillard (1999): frota limitada e só custo variável por tipo. Fonte: demos do VRPSolverEasy |
| `hfvrp_parser.jl` | `read_hfvrp(path)` e auto-teste |
| `toy_hfvrp.txt` | Toy no mesmo formato |

Esta pasta tem também o modelo (`hfvrp_model.jl`) e o `CVRP.cfg`.

## Parser

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

## Instância toy — `toy_hfvrp.txt`

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

## Atenção para a modelagem

- **Modelo do professor (`model_hfvrp.jl`):** um grafo por tipo, `x[k, e]` por tipo e aresta, e grau somando sobre os tipos. Ele já está quase pronto. O que muda:
  - o custo no objetivo passa a ser **$\alpha_k \cdot \ell$**, ou seja, `inst.α[k] * ℓ(i, j)`, e não um `c(i, j)` único;
  - os limites passam a ser `(0, inst.u[k])` e a capacidade `inst.Q[k]`;
  - o `.cfg` passa a ser o `CVRP.cfg`, porque o `HFVRP.cfg` não está na pasta.
- **Demanda:** é a mesma em todos os grafos (item 2 da correção). O que muda por tipo é só $Q^k$.
- **Packing sets:** as cópias de cada cliente nos $K$ grafos, como no MDVRP.
- **Matriz de distâncias:** use a distância física $\ell$ em todos os grafos.
- **Branching:** `set_branching_priority!(model, "x", 1)` faz o branching em `x[k, e]`. Opcionalmente, pode-se fazer o branching também na soma sobre os tipos, mas não é necessário.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **176.936** — tipo 1: 0-1-6-0, 0-2-3-0; tipo 2: 0-4-5-0; raiz, 1 nó | 176.936 | 0.67 s |
| c50_14hd | **607.529** — tipo 1: 3 rotas (de 4); tipo 2: 2 (de 2); tipo 3: 1 (de 1); raiz, 1 nó | 607.53 | 2.03 s |

c50_14hd conferido em Python: custo $\sum_k \alpha_k \ell$ = 607.529, 50 clientes, cargas 120/119/119 (Q = 120), 156/159 (Q = 160) e 300 (Q = 300). A referência **607.53 fica confirmada**.

## Referências para o benchmark

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

- Golden, B., Assad, A., Levy, L., Gheysens, F. (1984). The fleet size and mix vehicle routing problem. *Computers & Operations Research* 11(1), 49–66.
- Taillard, É. D. (1999). A heuristic column generation method for the heterogeneous fleet VRP. *RAIRO* 33(1), 1–14.
- Baldacci, R., Mingozzi, A. (2009). A unified exact method for solving different classes of vehicle routing problems. *Mathematical Programming* 120(2), 347–380.
- Instâncias HFVRP: <https://github.com/inria-UFF/VRPSolverEasy> (`VRPSolverEasy/demos/data/HFVRP`).
