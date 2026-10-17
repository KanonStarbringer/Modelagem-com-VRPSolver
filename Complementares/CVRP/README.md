# CVRP simétrico — Capacitated Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF).

Frota homogênea de capacidade $Q$, rotas que começam e terminam no depósito $0$, cada cliente visitado uma vez e custo total mínimo. É o modelo do professor (`Modelos/model.jl`), na formulação por **arestas**: `x[e]` com os dois sentidos de cada aresta mapeados para a mesma variável e grau `== 2`.

## Como rodar

```bash
julia ../cvrp_parser.jl   # auto-teste do parser compartilhado (toy + 85 instâncias da CVRPLIB)
julia scvrp_model.jl
```

O modelo inclui o parser da pasta de cima, `include(joinpath(@__DIR__, "..", "cvrp_parser.jl"))`, e usa as instâncias de `../Instancias/`. Esse parser, por sua vez, inclui `../DCVRP/dcvrp_parser.jl`, então mantenha as pastas lado a lado.

## Parser

```julia
inst = read_cvrp(joinpath(@__DIR__, "toy_comp.vrp"))                          # custo arredondado (padrão)
inst = read_cvrp(joinpath(@__DIR__, "..", "Instancias", "A-n32-k5.vrp"))        # A-n32-k5 = 784
inst.n, inst.Q, inst.K, inst.d[i+1], inst.C[i+1, j+1]
```

Os ótimos da CVRPLIB usam custo EUC_2D **arredondado** (`arred = true`, o padrão).

## Instância toy — `toy_comp.vrp`

Depósito em (0, 0); $Q = 11$; frota livre ($L = 2$, $U = n$).

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (10, 0) | (20, 0) | (30, 0) | (0, 12) | (−3, 22) | (−14, 6) |
| $d_i$ | 3 | 3 | 3 | 4 | 4 | 4 |

**Ótimo (força bruta): 134**, com rotas 0-1-2-3-0 (60), 0-4-5-0 (44) e 0-6-0 (30). A rota 0-6-0 aparece como `x[(0,6)] = 2`.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **134** | 134 | 0.70 s |
| A-n32-k5 (arredondado) | **784**, raiz, 1 nó | 784 | 0.88 s |

Mais ótimos de referência estão em [`../otimos.csv`](../otimos.csv), na coluna `cvrp_arred`.

## Fontes

- CVRPLIB: <https://galgos.inf.puc-rio.br/cvrplib/>
