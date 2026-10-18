# BPP — Bin Packing (slides 122 a 127)

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-4.md`](../README-complementares-4.md).

## Definição

Itens $T$ com pesos $w_t$ e bins idênticos de capacidade $Q$. O objetivo é empacotar todos os itens usando o menor número de bins.


## Como rodar

```bash
julia bpp_parser.jl      # auto-teste do parser
julia bpp_model.jl
```

No topo do `bpp_model.jl`, escolha a instância e o cutoff `ub` (nº de bins ótimo + 0.01).

## Modelo no VRPSolver

**Grafo** (um caminho = um bin): vértices $v_0, \dots, v_{|T|}$, source $v_0$, sink $v_{|T|}$, $L = 0$, $U = |T|$. Entre $v_{t-1}$ e $v_t$ há dois arcos paralelos:
- $a_t^+$: o item $t$ entra no bin; consome $w_t$;
- $a_t^-$: o item fica fora; consome 0.

O recurso de capacidade (principal) tem limites $[0, Q]$.

**Mestre** (variáveis **inteiras**, `Int`):

$$\min\ x_0 \qquad \text{s.a.} \qquad x_t = 1 \quad \forall t \in T$$

- $M(x_t) = \{a_t^+\}$: cada item é empacotado uma vez.
- $M(x_0) = \{a_1^+, a_1^-\}$: todo caminho passa por exatamente um dos dois arcos do item 1, então $x_0 = \sum_p \lambda_p$ = nº de bins.

**Packing sets em arcos:** $\{\{a_t^+\} : t \in T\}$; cada arco "item dentro" aparece no máximo uma vez.

**Branching:** em $x$ não há onde ramificar. $x_t = 1$ é fixo, e $x_0$ pode ser inteiro com $\lambda$ fracionário. Por isso o **Ryan-Foster** sobre os packing sets (itens $i$ e $j$ juntos ou separados) é necessário e suficiente para a corretude: `enable_packset_ryanfoster_branching!(model, 1)`.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/Falkenauer_U120/*.txt` | 20 instâncias, $n = 120$, $Q = 150$ |
| `Instancias/Falkenauer_U250/*.txt` | 20 instâncias, $n = 250$, $Q = 150$ |
| `Instancias/Falkenauer_T60/*.txt` | 20 *triplets*, $n = 60$; empacotamento perfeito, com cada bin cheio. Convertidas para inteiros: $\times 10$, $Q = 1000$ |
| `Instancias/Hard28/*.txt` | 28 instâncias difíceis de Schoenfield, $n$ de 160 a 200, $Q = 1000$ |
| `otimos.csv` | ótimos da BPPLIB (`Solutions.xlsx`) e $\lceil \sum w / Q \rceil$ |
| `bpp_parser.jl` | `read_bpp(path)` e auto-teste |
| `toy_bpp.txt` | toy do slide 123 |

## Parser

```julia
include("bpp_parser.jl")
inst = read_bpp(joinpath(@__DIR__, "toy_bpp.txt"))
inst = read_bpp(joinpath(@__DIR__, "Instancias", "Falkenauer_U120", "u120_00.txt"))
inst.n, inst.Q, inst.w[t]
```

O cabeçalho da OR-Library traz o melhor valor conhecido **de 1996**, que está desatualizado em u120_08 (51, mas o ótimo é 50), u120_19 (50 → 49), u250_07 (104 → 103) e u250_12 (106 → 105). O `otimos.csv` usa os ótimos da BPPLIB.

Auto-teste: `julia bpp_parser.jl` → `OK: toy + 88 instâncias da BPPLIB lidas (Falkenauer U120/U250/T60 e Hard28)`.

## Instância toy — `toy_bpp.txt`

$w = (6, 5, 4, 3, 2)$, $Q = 8$. **Ótimo: 3 bins**: {6, 2}, {5, 3}, {4}, com cutoff `3.01`. O peso total é 20, então $\lceil 20/8 \rceil = 3$.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| $x_0$ mapeada só em $a_1^+$ | **1**: só conta o bin que leva o item 1 |
| $x_0$ mapeada em todos os arcos | **15** $= 5 \cdot 3$: cada caminho passa por $n$ arcos |
| Packing sets nos vértices $v_t$ | **inválido**: todo caminho passa por todos os $v_t$, então a propriedade de packing set não vale |
| **$x$ contínuas** (sem `Int`) | **47 na u120_00** ($< \lceil \sum w/Q \rceil = 48$): o VrpSolver passa as colunas mapeadas como `'C'`, o BaPCod não vê nada inteiro a exigir e aceita a solução da relaxação como incumbente. Os "bins" impressos repetem itens (74, 84, 117…), porque os $\lambda$ são fracionários. Na toy não aparece, porque a relaxação já é inteira |
| Sem Ryan-Foster | o modelo fica sem regra de branching correta. Vale testar na toy e numa Falkenauer para ver o que o VRPSolver faz |

## Atenção para a modelagem

- O objetivo $\min x_0$ tem coeficiente inteiro e todas as variáveis são mapeadas, então o VRPSolver arredonda o limite para cima. Um LP de 47.3 já prova 48.
- $U = n$ no lugar do $\infty$ do slide.
- Não é preciso `define_elementarity_sets_distance_matrix!`: o grafo é acíclico, e o ng não tem o que relaxar.

## Referências para o benchmark (`otimos.csv`)

| Instância | $n$ | $Q$ | Ótimo | $\lceil \sum w/Q \rceil$ | cutoff |
|---|---|---|---|---|---|
| u120_00 | 120 | 150 | 48 | 48 | `48.01` |
| u120_08 | 120 | 150 | 50 | 50 | `50.01` |
| u250_00 | 250 | 150 | 99 | 99 | `99.01` |
| u250_13 | 250 | 150 | 103 | 102 | `103.01` |
| t60_00 | 60 | 1000 | 20 | 20 | `20.01` |
| Hard28 BPP14 | 160 | 1000 | 62 | 61 | `62.01` |
| Hard28 BPP832 | 160 | 1000 | 60 | 60 | `60.01` |

As T60 e a Hard28 são as difíceis. Nas T60 todo bin fica exatamente cheio no ótimo. A Hard28 é o conjunto clássico de instâncias difíceis para métodos baseados em LP. Em BPP14 e u250_13, $\lceil \sum w/Q \rceil$ é menor que o ótimo.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | 3 (raiz, 1 nó; {4, 3}, {5, 2}, {6}) | 3 | 0.70 s |
| u120_00 | 48 (raiz 48 arredondada, 35 nós; cada item em exatamente um bin) | 48 | 119.31 s |

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
