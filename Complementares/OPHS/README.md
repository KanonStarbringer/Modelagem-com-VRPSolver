# OPHS — Orienteering Problem with Hotel Selection

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-4.md`](../README-complementares-4.md).

## Definição

O tour começa no hotel 1 e termina no hotel $m$ ($\neq 1$), com **exatamente $D$ trips**, cada uma de duração $\le T$, e duração total $\le U$. Cada cliente $j$ tem lucro $w_j$, e a visita é **opcional**. Objetivo: maximizar o lucro.

O slide 109 é o **caso particular** de Roboredo et al. (2024), com o mesmo $T$ em todas as trips: um grafo só e $\sum \lambda = D$. No caso geral, com $T_d$ diferente por trip, o artigo usa um grafo por trip e encadeia os hotéis no mestre. As instâncias SET1 a SET3 e SET5 de Divsalar et al. (2013) têm $T_d$ diferentes e **não servem** para o modelo da aula. O parser avisa (`inst.uniforme`).


## Como rodar

```bash
julia ophs_parser.jl     # auto-teste do parser
julia ophs_model.jl      # usa ../TSPHS/mincut.jl
```

No topo do `ophs_model.jl`, escolha a instância e o cutoff `ub = -(lucro conhecido) + 0.01` (negativo: o modelo minimiza −lucro).

## Modelo no VRPSolver (slide 110)

Mesmos $G'$, recurso de tempo (sem serviço: as instâncias não têm), mapeamento $M$, $x_e$ e $y_h$ do TSPHS, com $L = U = D$. Variável nova $g_j \in \{0, 1\}$, **não mapeada**: o cliente $j$ é visitado.

$$\max \sum_{j \in C} w_j\, g_j \qquad (\text{no VRPSolver: } \min -\textstyle\sum_j w_j g_j) \tag{3a}$$

$$\sum_{e \in \delta(j)} x_e = 2\,g_j \quad \forall j \in C \tag{3b}$$

$$\sum_{e \in \delta(h)} x_e = 2\,y_h \quad \forall h \in H \setminus \{1, m\} \tag{3c}$$

$$\sum_{e \in \delta(h)} x_e = 2\,y_h - 1 \quad \forall h \in \{1, m\} \tag{3d}$$

$$y_m \ge 1, \qquad \sum_{e \in E} t_e\, x_e \le U, \qquad \textstyle\sum_p \lambda_p = D \tag{3e–3g}$$

(3d): os hotéis 1 e $m$ têm grau **ímpar**, porque o tour é um caminho $1 \to m$, não um ciclo.

**Cortes (3h), (3i).** O tour é um caminho de 1 a $m$. Um corte que separa 1 de $m$ é cruzado só uma vez, então o lado $S$ precisa conter **os dois**:

$$\sum_{e \in \delta(S)} x_e \ge 2\,g_j \quad \forall j \in C,\ \forall S : \{1, m\} \subseteq S,\ j \notin S \tag{3h}$$

$$\sum_{e \in \delta(S)} x_e \ge \frac{2}{D-1}\, y_h \quad \forall h \in H \setminus \{1, m\},\ \forall S : \{1, m\} \subseteq S,\ h \notin S \tag{3i}$$

Na separação, basta "colar" 1 e $m$ no corte mínimo (`cap[1, m] = cap[m, 1] = Inf`) e rodar `mincut(cap, 1, j)`. O código do professor chega ao mesmo resultado com uma trip fictícia $m \to 1$, que fecha o ciclo.

**Packing sets:** os clientes. **Branching:** $x$, $y$ e $g$.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/SET_{2-3,4-4,8-4,9-7}_TSP/*.ophs` | 64 instâncias de Sohrabi et al. (2021), derivadas do TSPHS, todas com $T$ uniforme |
| `Instancias/SET_4-4_VRP/*.ophs` | 16 instâncias de Sohrabi et al. (2021), derivadas de Solomon/Cordeau, com $T$ uniforme |
| `Instancias/SET_4/*.ophs` | 10 instâncias do SET4 de Divsalar et al. (2013), o único conjunto deles com $T$ uniforme |
| `referencias_bks.csv` | melhor lucro conhecido das 36 instâncias TSP que o professor rodou no caso uniforme (o `-u` do `symmetric.sh`) |
| `ophs_parser.jl` | `read_ophs(path)` e auto-teste |
| `toy_ophs.ophs` | toy |

O modelo usa o corte mínimo do TSPHS: `include(joinpath(@__DIR__, "..", "TSPHS", "mincut.jl"))`. A pasta tem o `OPHS.cfg`, igual ao `TSPHS.cfg`.

## Parser

```julia
include("ophs_parser.jl")
inst = read_ophs(joinpath(@__DIR__, "toy_ophs.ophs"))
inst = read_ophs(joinpath(@__DIR__, "Instancias", "SET_2-3_TSP", "eil51-H4-T3-S3.ophs"))
inst.H, inst.C           # hotéis 1..H+2 (inst.ini = 1, inst.fim = 2 = "m"), clientes depois
inst.D, inst.T, inst.U, inst.uniforme, inst.w[i], inst.t[i, j]
```

Distância euclidiana **real**, sem tempo de serviço. O SET_4 termina com uma linha de traços, que o parser ignora.

Auto-teste: `julia ophs_parser.jl` → `OK: toy + 90 instâncias com T uniforme lidas`.

## Instância toy — `toy_ophs.ophs`

$D = 3$ trips, $T = 25$, $U = 60$, distância real.

| Vértice | 1 (início) | 2 (fim, $m$) | 3 (H) | 4 (H) | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| (x, y) | (0, 0) | (30, 0) | (15, 8) | (15, 30) | (6, 5) | (10, −4) | (19, 12) | (24, −5) | (28, 7) | (12, 33) | (18, 33) |
| $w_j$ | | | | | 10 | 15 | 20 | 10 | 15 | 30 | 30 |

**Ótimo (enumeração exata): lucro 55**, com cutoff `ub = -54.99` (objetivo $-\sum w g$). Tempo total: 56.15.

| Trip | Sequência | Duração |
|---|---|---|
| 1 | 1-5-3 | 17.30 |
| 2 | 3-7-9-2 | 23.23 |
| 3 | 2-8-2 | 15.62 |

Os clientes 10 e 11 (lucro 60) estão perto do hotel 4, mas nenhum tour conexo de 3 trips chega até lá e ainda termina no hotel 2.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| **Sem os cortes** | **105**: soma o laço 4-10-11-4, desconexo do caminho 1 → 2 |
| Sem a restrição $\sum t_e x_e \le U$ | **60** (tempo 62.07): 1-6-1, 1-5-3, 3-7-9-2 |
| Grau $2y_h$ também em 1 e $m$ (sem o $-1$) | **inviável**: o modelo passa a exigir um ciclo que sai de 1 e volta a 1 passando por $m$, e não há um com 3 trips |
| Corte com $1 \in S$ mas $m \notin S$ | corte **inválido**: corta o caminho ótimo, que cruza esse $\delta(S)$ uma vez só |

## Atenção para a modelagem

- **Objetivo**: VRPSolver minimiza; use `Min, -sum(w[j] * g[j])`. O cutoff fica negativo: `ub = -(lucro conhecido) + 0.01`.
- $g$ e $y$ são `Int`/`Bin` e não mapeadas. Com lucros inteiros, o objetivo é inteiro e o VRPSolver arredonda o limite.
- **Caso uniforme apenas**: confira `inst.uniforme` e use `T = inst.T`.
- A partida do tour sai de $v_1$ e a chegada final entra em $\bar v_m$. Não é preciso restringir os arcos do source e do sink: (3d) e (3e) garantem isso.

## Referências para o benchmark (`referencias_bks.csv`)

| Instância | Hotéis extras | $D$ | $T$ | Melhor lucro conhecido | cutoff |
|---|---|---|---|---|---|
| eil51-H4-T3-S3 | 2 | 3 | 114 | 2470 | `-2469.99` |
| berlin52-H4-T3-S3 | 2 | 3 | 2041 | 2690 | `-2689.99` |
| st70-H4-T3-S3 | 2 | 3 | 181 | 3300 | `-3299.99` |
| eil51-H6-T4-S3 | 4 | 4 | 79 | 2360 | `-2359.99` |
| eil51-H10-T4-S4 | 8 | 4 | 85.2 | 2600 | `-2599.99` |
| eil51-H11-T7-S3 | 8 | 7 | 46 | 2240 | `-2239.99` |

O "melhor lucro conhecido" é o `-u` passado ao VRPSolver no `symmetric.sh` do repositório do professor (o `run.jl` usa `set_cutoff!(ub + 1.00001)`). É um lucro já atingido; o ótimo é **pelo menos** esse valor. Roboredo et al. (2024) dizem ter resolvido as 44 instâncias uniformes, mas os ótimos estão no artigo. O SET_4 de Divsalar não tem referência aqui.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | 55 (raiz −65, 5 nós; $g = \{5, 7, 8, 9\}$) | 55 | 1.74 s |
| eil51-H4-T3-S3 | **2470, ótimo provado** (raiz −2479, 3 nós; trips 1→3→4→2 com 113.57, 113.93, 113.10 ≤ 114; total 340.6 ≤ 342) | ≥ 2470 | 6.91 s |

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
