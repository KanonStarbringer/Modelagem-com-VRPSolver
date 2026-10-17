# SDVRP — Site-Dependent Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-3.md`](../README-complementares-3.md).

Frota heterogênea em que cada cliente $i$ só pode ser atendido por tipos de veículo de um conjunto $\mathcal{K}_i$ (compatibilidade). O tipo $k$ tem capacidade $Q^k$ e disponibilidade $u^k$.

## Como rodar

```bash
julia sdvrp_parser.jl      # auto-teste do parser
julia sdvrp_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/p01..p23` | 23 instâncias SDVRP de Chao, Golden & Wasil (1999), no formato de Cordeau (type 3), via espelho em pauljmello/HGSADC-vs-ACS-on-SDVRP. Todas **sem limite de duração** |
| `sdvrp_parser.jl` | `read_sdvrp(path)` e auto-teste |
| `toy_sdvrp` | Toy no mesmo formato |

O conjunto "new" de Cordeau & Laporte (pr01–pr12) tem duração máxima D = 500, por isso ficou de fora: o exercício não tem esse limite. Esta pasta tem também o modelo e o `CVRP.cfg`.

## Parser

```julia
include("sdvrp_parser.jl")
inst = read_sdvrp(joinpath(@__DIR__, "toy_sdvrp"))
inst = read_sdvrp(joinpath(@__DIR__, "Instancias", "p07"))
inst.n, inst.K, inst.m     # clientes, nº de tipos, veículos POR tipo (u^k = m para todo k)
inst.Q[k]                  # capacidade do tipo k
inst.comp[i]               # Set dos tipos que podem visitar o cliente i (𝒦_i)
inst.d[i+1], inst.ℓ[i+1, j+1]   # demanda e distância (depósito = 0)
```

**Convenções:**
- **Custo:** é a distância real, **igual para todos os tipos** ($c^k = \ell$). O formato não tem $\alpha_k$.
- **Compatibilidade:** vem como uma bit string lida da esquerda para a direita. Com $t = 3$, o código 4 = 100 significa o tipo 1; o código 2 = 010, o tipo 2; o código 1 = 001, o tipo 3.
- **Frota:** o mesmo $m$ vale para todos os tipos. A p01 tem 5 clientes nas coordenadas do depósito, com demanda 160 e só o tipo 3 permitido, uma herança da construção de Chao et al. Outras instâncias também têm clientes nas coordenadas do depósito; não conferi as demandas deles. O parser lê todos como clientes comuns.

Auto-teste: `julia sdvrp_parser.jl` → `OK: toy + 23 instâncias SDVRP lidas`.

## Instância toy — `toy_sdvrp`

As posições e demandas são as da toy dos complementares. Há dois tipos, com **$m = 1$ veículo de cada**: o tipo 1 tem $Q = 10$ e o tipo 2 tem $Q = 12$. O custo é a distância.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| $\mathcal{K}_i$ | **{2}** | {1, 2} | {1, 2} | **{1}** | {1, 2} | {1, 2} |

**Ótimo (força bruta): 144.5129**, com cutoff `144.52`:

| Tipo | Rota | Custo | Carga |
|---|---|---|---|
| 2 | 0-1-5-6-0 | 70.2019 | 11 / 12 |
| 1 | 0-2-3-4-0 | 74.3110 | 10 / 10 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem compatibilidade (todos os clientes em todos os grafos) | **117.0883**: tipo 1 0-1-2-3-0 e tipo 2 0-4-5-6-0, que é exatamente o que a compatibilidade proíbe |
| Sem o limite de veículos por tipo ($U^k = n$ no lugar de $m$) | **135.107**: três rotas, duas do tipo 1 |

## Atenção para a modelagem

É o **HFVRP com compatibilidade**: um grafo por tipo, `x[k, e]`, grau somando sobre os tipos, limites $(0, m)$ e capacidade `Q[k]`.
- **Compatibilidade:** o grafo do tipo $k$ só contém os clientes $i$ com $k \in \mathcal{K}_i$. Os outros clientes **não entram** no grafo, e as arestas que tocam neles também não.
- **Arestas e variáveis:** a forma mais simples é criar `x[k, e]` só para as arestas compatíveis, com `E_k = [(i, j) for (i, j) in E if (i == 0 || k in comp[i]) && j in ...]`. A outra opção é criar todas e fixar em zero as incompatíveis.
- **Grau:** `sum(x[k, e] for k in K for e in δ[i] if e in E_k) == 2`.
- **Packing sets:** cada cliente reúne só as cópias dos grafos compatíveis, `[(G[k], i) for k in comp[i]]`.
- **Custo:** `ℓ(i, j)` em todos os tipos. Se quiser treinar o $c^k$ do enunciado, multiplique por um $\alpha_k$ seu.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **144.5129** — tipo 1: 0-2-3-4-0; tipo 2: 0-1-5-6-0; raiz, 1 nó | 144.5129 | 0.74 s |
| p07 | **391.3022** — uma rota por tipo; raiz, 1 nó | 391.3022 (CBC) | 0.90 s |

p07 conferido em Julia. Cada tipo faz uma rota de custo 130.434 com 9 clientes, todos compatíveis:

| Tipo | Clientes | Carga |
|---|---|---|
| 1 | 1–8 e 25 | 130 / 150 |
| 2 | 9–16 e 26 | 170 / 200 |
| 3 | 17–24 e 27 | 210 / 250 |

A instância é simétrica, em "estrela": três pétalas geometricamente iguais, e a compatibilidade define qual tipo atende cada pétala.

| p08 | **664.4632** — 6 rotas, 2 por tipo; raiz, 1 nó | ≤ 1056.29 (CBC, não provado) | 1.08 s |
|---|---|---|---|

p08 conferido em Julia: 6 pétalas de custo 110.744 cada, 2 por tipo ($m = 2$), 54 clientes, todos compatíveis. As cargas são 130 / 150 (tipo 1), 170 / 200 (tipo 2) e 210 / 250 (tipo 3). O **VRPSolver provou o ótimo 664.4632**. A solução do CBC (1056.29) estava 59% acima, o que mostra quão fraca é a formulação MTZ para esse problema.

## Referências para o benchmark

| Instância | $n$ | Tipos (Q) | $m$ | Referência | Fonte |
|---|---|---|---|---|---|
| p07 | 27 | 150 / 200 / 250 | 1 | **391.3022** | CBC, **ótimo provado**; uma rota de cada tipo |
| p08 | 54 | 150 / 200 / 250 | 2 | **664.4632** | **VRPSolver, ótimo provado** na raiz. O CBC tinha parado em 1056.29 com `sol_status = 2` |

Não encontrei online os valores publicados para o conjunto de Chao et al. Comece pela **p07**.

## Fontes

- Chao, I-M., Golden, B., Wasil, E. (1999). A computational study of a new heuristic for the site-dependent vehicle routing problem. *INFOR* 37(3), 319–336.
- Cordeau, J.-F., Laporte, G. (2001). A tabu search algorithm for the site dependent vehicle routing problem with time windows. *INFOR* 39(3), 292–298.
- Instâncias SDVRP: espelho dos dados de Cordeau em <https://github.com/pauljmello/HGSADC-vs-ACS-on-SDVRP> (`data/_mirror/sdvrp/old`).
