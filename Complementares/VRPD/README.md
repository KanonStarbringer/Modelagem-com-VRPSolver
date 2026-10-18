# VRP-D — VRP com drone (slides 113 a 117)

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-4.md`](../README-complementares-4.md).

## Definição

Um caminhão e um drone saem do depósito. O caminhão percorre uma rota; entre duas paradas consecutivas $i$ e $j$, ele vai **direto**, ou lança o drone em $i$ para atender **um** cliente $c$ e o recolhe em $j$ (uma *sortie*). O drone tem alcance $R$ e não recarrega: $d_{ic} + d_{cj} \le R$. O caminhão não para em outros clientes durante a sortie. Cada cliente é atendido uma vez, pelo caminhão ou pelo drone. Objetivo: custo mínimo.

Parâmetros desta implementação:
- custo do caminhão: $c_{ij}$;
- custo do drone na sortie: $d^c_{ij} = \alpha\,(c_{ic} + c_{cj})$;
- alcance: $c_{ic} + c_{cj} \le R$;
- matriz $c$: distância euclidiana arredondada (nint, TSPLIB);
- sorties podem começar ou terminar no depósito ($i = 0$ ou $j = 0$);
- frota de **um** caminhão ($L = U = 1$), como no slide.


## Como rodar

```bash
julia vrpd_parser.jl     # auto-teste do parser
julia vrpd_model.jl
```

No topo do `vrpd_model.jl`, escolha a instância, `R`, `α` e o cutoff `ub` (ótimo + 0.01).

## Modelo no VRPSolver

**Grafo:** o grafo do CVRP assimétrico, com source = sink = 0 e $L = U = 1$. Entre cada par $(i, j)$ há **arcos paralelos**: um direto e um arco-sortie $(i, j)^c$ para cada $c$ com $c_{ic} + c_{cj} \le R$.

| Arco | Mapeamento | Consumo do recurso "clientes atendidos" ($[0, n]$, principal) |
|---|---|---|
| direto $(i, j)$ | $x_{ij}$ | $1$ se $j \neq 0$ |
| sortie $(i, j)^c$ | $x_{ij}$ **e** $y^c_{ij}$ | $1 + [j \neq 0]$ |

O recurso não restringe nada (são no máximo $n$ clientes), mas o VRPSolver precisa de um recurso principal que cresça ao longo do caminho, para o conjunto de caminhos ser finito.

**Mestre:**

$$\min \sum_{(i,j)} c_{ij}\, x_{ij} + \sum_{(i,j),\,c} d^c_{ij}\, y^c_{ij}$$

$$\sum_j x_{vj} = \sum_i x_{iv} \quad \forall v \qquad (\text{fluxo do caminhão; redundante, pois cada caminho já é um fluxo})$$

$$\underbrace{\sum_i x_{iv}}_{\text{caminhão para em } v} + \underbrace{\sum_{i,j} y^v_{ij}}_{\text{drone atende } v} = 1 \quad \forall v \in C$$

O fluxo usa só $x$, porque a perna do caminhão é a mesma com ou sem drone (por isso não há $z$). O $y$ aparece só na cobertura.

**Packing sets em arcos.** No slide, o packing set de $v$ tem os arcos que chegam em $v$ **e** os arcos-sortie que atendem $v$. Assim, o arco $(i, j)^c$ fica nos packing sets de $c$ e de $j$, e eles se interceptam. **A versão instalada não aceita isso.** A versão disjunta, válida, é:

$$P_v = \{\text{arcos diretos } (i, v)\} \cup \{\text{arcos-sortie } (i, j)^v\} \quad \forall v \in C$$

Cada arco-sortie fica só no packing set do cliente que o **drone** atende. Cada $P_v$ contém só arcos que atendem $v$, então $\sum_p \sum_{a \in P_v} h^p_a \lambda_p \le 1$ continua valendo. A diferença em relação à versão com interseção é que o pricing não impede, sozinho, que o caminhão chegue em $v$ por um arco-sortie de outro cliente depois de o drone ter atendido $v$. O mestre corta essas rotas (cobertura $= 1$), mas o limite fica um pouco mais fraco.

**Branching:** em $x$ e em $y$.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/*.tsp` | eil51, berlin52, st70, eil76 e kroA100 da TSPLIB |
| `referencias_cplex.csv` | ótimos calculados com um MIP no CPLEX, para os pares $(R, \alpha)$ da tabela abaixo |
| `vrpd_parser.jl` | `read_vrpd(path; R, α)` e auto-teste |
| `toy_vrpd.vrp` | toy, com `DRONE_RANGE` e `DRONE_ALPHA` no cabeçalho |

## Parser

```julia
include("vrpd_parser.jl")
inst = read_vrpd(joinpath(@__DIR__, "toy_vrpd.vrp"))                          # R = 20, α = 0.2 do arquivo
inst = read_vrpd(joinpath(@__DIR__, "Instancias", "eil51.tsp"); R = 20, α = 0.2)
inst.n, inst.C, inst.R, inst.α, inst.c[i+1, j+1]                               # depósito 0, clientes 1..n
```

Auto-teste: `julia vrpd_parser.jl` → `OK: toy + 5 instâncias da TSPLIB lidas`.

## Instância toy — `toy_vrpd.vrp`

$R = 20$, $\alpha = 0.2$, custo nint.

| Vértice | 0 (depósito) | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| (x, y) | (0, 0) | (10, 0) | (20, 0) | (30, 0) | (5, 8) | (15, −8) | (25, 9) | (18, −15) |

**Ótimo (DP exata, conferido no CPLEX): 81.6**, com cutoff `81.61`.
- Caminhão: 0-1-2-3-7-5-0, custo 74.
- Sorties: na perna 0 → 1, o drone atende 4 ($9 + 9 = 18 \le 20$, custo $0.2 \cdot 18 = 3.6$); na perna 2 → 3, o drone atende 6 ($10 + 10 = 20$, custo 4). A solução espelhada (sentido inverso) tem o mesmo custo.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem arcos-sortie (só o caminhão; equivale a $R = 0$) | **91**, o TSP |
| Sem o limite de alcance $R$ | **66.6** |
| Custo do drone ignorado ($\alpha = 0$) | **72** |
| $x$ mapeada só nos arcos diretos | a perna do caminhão na sortie sai de graça, e $j$ deixa de ser coberto quando o caminhão chega por um arco-sortie |
| Packing sets com interseção (como no slide) | erro `an arc cannot belong to more than 1 packing set` na versão instalada |

## Atenção para a modelagem

- `add_arc_var_mapping!(G, a, [x[(i, j)], y[(i, j, c)]])` no arco-sortie: um arco, duas variáveis, como o $z$ do custo fixo.
- Gere só os arcos-sortie que respeitam $R$. Para os pares $(R, \alpha)$ do benchmark, isso dá: eil51 com 2550 arcos diretos e 940 sorties, berlin52 com 2652 e 1208 ($R = 200$), st70 com 4830 e 1612, eil76 com 5700 e 3910. Com $R = 400$, o berlin52 tem 7082 sorties, e o MIP de verificação no CPLEX não fechou em 1 h.
- `set_arc_packing_sets!` recebe uma lista de listas de `(G, arc_id)`. Guarde os ids devolvidos por `add_arc!` ao montar os arcos.
- `define_elementarity_sets_distance_matrix!` com a matriz $c$ entre clientes, que também indexa os packing sets em arcos.

## Referências para o benchmark (`referencias_cplex.csv`)

Com $R = 0$ não há sortie, e o resultado é o ótimo do TSP: eil51 = 426, berlin52 = 7542, st70 = 675, eil76 = 538, kroA100 = 21282. É uma boa verificação estrutural.

| Instância | $R$ | $\alpha$ | Ótimo (CPLEX) | Sorties | cutoff |
|---|---|---|---|---|---|
| eil51 | 20 | 0.2 | 367.0 | 17 | `367.01` |

As outras instâncias não têm referência do CPLEX: as rodadas foram interrompidas, e o VRPSolver passa a ser a referência.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | 81.6 (raiz, 1 nó; caminhão 0-1-2-3-7-5-0, sorties 0→4→1 e 2→6→3) | 81.6 | 0.65 s |
| eil51 ($R = 20$, $\alpha = 0.2$) | interrompida, sem resultado: pesada demais com 2550 arcos diretos + 940 sorties | 367.0 (CPLEX, 61.5 s) | — |

## Fontes (da leva)

- Roboredo, M., Lima, D., Silva, J. M. P., Uchoa, E. (2024). Branch-cut-and-price algorithms for two routing problems with hotel selection. *Computers & Industrial Engineering* 196, 110467. <https://doi.org/10.1016/j.cie.2024.110467> · código e instâncias: <https://github.com/mcroboredo/TSPHS_OPHS>
- Barbosa, L. H. S. (2018). *A branch-cut-and-price algorithm for the traveling salesperson problem with hotel selection*. Tese (Doutorado em Engenharia de Produção), UFF. <https://app.uff.br/riuff/handle/1/7606> · Barbosa, L. H., Uchoa, E. (2020). *Computers & Operations Research*, <https://doi.org/10.1016/j.cor.2020.104986>
- Vansteenwegen, P., Souffriau, W., Sörensen, K. (2012). The travelling salesperson problem with hotel selection. *JORS* 63(2), 207–217.
- Divsalar, A., Vansteenwegen, P., Cattrysse, D. (2013). A variable neighborhood search method for the orienteering problem with hotel selection. *International Journal of Production Economics* 145(1), 150–160. Instâncias: <https://www.mech.kuleuven.be/en/mim/op/OPHSinstances>
- Sohrabi, S., Ziarati, K., Keshtkaran, M. (2021). New instances for the Orienteering Problem with Hotel Selection. Mendeley Data, <https://doi.org/10.17632/bct4g4w9y2.1>
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
- Delorme, M., Iori, M., Martello, S. (2018). BPPLIB: a library for bin packing and cutting stock problems. *Optimization Letters* 12(2), 235–250. <https://github.com/mdelorme2/BPPLIB>
- Falkenauer, E. (1996). A hybrid grouping genetic algorithm for bin packing. *Journal of Heuristics* 2(1), 5–30 (OR-Library, `binpack1`, `binpack2`, `binpack5`).
- Reinelt, G. (1991). TSPLIB — A traveling salesman problem library. *ORSA Journal on Computing* 3(4), 376–384.
