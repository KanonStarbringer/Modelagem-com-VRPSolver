# CSP — Cutting Stock Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-5.md`](../README-complementares-5.md).

## Definição

Há $m$ **tipos** de item: o tipo $t$ tem largura $w_t$ e demanda $d_t$. Rolos idênticos de largura $Q$ são cortados em **padrões**. Objetivo: atender todas as demandas com o menor número de rolos. É o BPP com os itens de mesmo peso agrupados (Gilmore & Gomory, 1961).


## Como rodar

```bash
julia csp_parser.jl      # auto-teste do parser
julia csp_model.jl
```

No topo do `csp_model.jl`, escolha a instância e o cutoff `ub` (nº de rolos ótimo + 0.01).

## Por que não reaproveitar o grafo do BPP

O grafo do BPP tem um par de arcos "dentro/fora" por **item**, e cada arco "dentro" é um packing set. No CSP, o tipo $t$ aparece $d_t$ vezes no total, então um packing set por tipo **viola** a propriedade de packing set (cada um deveria ser coberto no máximo uma vez pela solução). Sem packing sets não há Ryan-Foster, e o branching em $x_t$ não basta, como já não bastava no BPP. Expandir as demandas em itens unitários volta ao BPP, mas a u1000 vira um grafo com 1000 itens.

## Modelo no VRPSolver: arc-flow (Valério de Carvalho, 1999)

**Grafo** $G = (V, A)$: um vértice por **carga acumulada**, $V = \{0, 1, \dots, Q\}$, source $0$, sink $Q$, $L = 0$, $U = n = \sum_t d_t$. Um caminho de 0 a $Q$ é um padrão.

| Arco | Existe para | Significado | Consumo (recurso "carga", $[0, Q]$) | Mapeamento |
|---|---|---|---|---|
| $(l,\ l + w_t)$ | $t \in T$, $0 \le l \le Q - w_t$ | corta uma peça do tipo $t$ | $w_t$ | $y_{l,t}$ |
| $(l,\ Q)$ | $0 < l < Q$ | fecha o rolo; o resto é perda | $0$ | nenhum |

Não há arco $(0, Q)$: seria o rolo vazio.

**Mestre** ($y_{l,t} \in \mathbb{Z}_+$ = nº de padrões que cortam uma peça do tipo $t$ começando na posição $l$):

$$\min \sum_{t \in T} y_{0,t} \tag{1a}$$

$$\sum_{l = 0}^{Q - w_t} y_{l,t} \ \ge\ d_t \quad \forall t \in T \tag{1b}$$

- (1a): todo padrão sai do vértice 0 por exatamente um arco de item, então $\sum_t y_{0,t} = \sum_p \lambda_p$ = nº de rolos. Não é preciso um $x_0$ separado.
- (1b) com $\ge$: sobra de produção é permitida, como no modelo de Gilmore-Gomory.

**Branching em $y$ é completo.** Um $y$ inteiro é um fluxo inteiro de 0 a $Q$ num grafo acíclico. Pela decomposição de fluxos, ele se decompõe em caminhos inteiros, e todo caminho de 0 a $Q$ é um padrão viável, porque o vértice já guarda a carga. É isso que faltava no grafo do BPP, em que o vértice guarda o item e não a carga.

**Packing sets:** nenhum. Sem eles, o VRPSolver não usa ng-routes, cortes rank-1 nem enumeração de rotas: o pricing é um caminho mínimo num DAG.

**Limite da relaxação:** igual ao de Gilmore-Gomory, porque todo padrão é um caminho e vice-versa. Como o objetivo tem coeficientes inteiros, o VRPSolver arredonda o limite para cima.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/Falkenauer_U/*.txt` | 80 instâncias (u120, u250, u500, u1000), $Q = 150$ |
| `Instancias/Falkenauer_T/*.txt` | 80 *triplets* (t60, t120, t249, t501), $Q = 1000$ |
| `Instancias/Schwerin_1/`, `Schwerin_2/` | 100 + 100 instâncias, $n = 100$ e $120$, $Q = 1000$ |
| `Instancias/Hard28/*.txt` | 28 instâncias de Schoenfield, $Q = 1000$ |
| `otimos.csv` | ótimos da BPPLIB (`Solutions.xlsx`), $\lceil \sum w_t d_t / Q \rceil$ e o nº de arcos do grafo arc-flow |
| `csp_parser.jl` | `read_csp(path)` e auto-teste |
| `toy_csp.txt` | toy |

São as versões CSP da BPPLIB (Delorme, Iori & Martello, 2018): as mesmas instâncias do BPP, agregadas. Os ótimos são iguais aos do BPP. O conjunto de Wäscher ficou de fora: com $Q = 10000$, o grafo teria 10 001 vértices.

## Parser

```julia
include("csp_parser.jl")
inst = read_csp(joinpath(@__DIR__, "toy_csp.txt"))
inst = read_csp(joinpath(@__DIR__, "Instancias", "Falkenauer_U", "Falkenauer_u120_00.txt"))
inst.m, inst.n, inst.Q, inst.w[t], inst.d[t]      # t em 1..m; n = Σ d_t
```

O parser recusa larguras repetidas: o grafo tem um arco por (posição, largura), e dois tipos com a mesma largura gerariam arcos paralelos com a mesma função.

Auto-teste: `julia csp_parser.jl` → `OK: toy + 388 instâncias CSP da BPPLIB lidas (Falkenauer U/T, Schwerin 1/2 e Hard28)`.

## Instância toy — `toy_csp.txt`

$Q = 10$.

| Tipo | 1 | 2 | 3 | 4 |
|---|---|---|---|---|
| $w_t$ | 7 | 5 | 4 | 3 |
| $d_t$ | 2 | 3 | 2 | 3 |

**Ótimo (força bruta, conferido com um MIP de fluxo no CPLEX): 5 rolos**, com cutoff `5.01`. A relaxação (Gilmore-Gomory) vale **4.75**, e $\lceil 46/10 \rceil = 5$.

| Rolo | Padrão | Carga |
|---|---|---|
| 1 | 7 | 7 |
| 2 | 7 + 3 | 10 |
| 3 | 5 + 4 | 9 |
| 4 | 5 + 5 | 10 |
| 5 | 4 + 3 + 3 | 10 |

No grafo, o rolo 5 é o caminho 0 → 4 → 7 → 10: $y_{0,3} = y_{4,4} = y_{7,4} = 1$, nessa ordem ou em outra.

Armadilhas (conferidas no CPLEX com o mesmo grafo):

| Modelo errado | Resultado |
|---|---|
| Sem os arcos de fechamento $(l, Q)$ | **6**: só padrões perfeitos (carga exatamente $Q$) |
| Rolos contados nos arcos que **chegam** em $Q$ pelo fechamento | **0**: os padrões perfeitos não passam por esses arcos e saem de graça (com $\ge$, dá para cobrir tudo com padrões perfeitos) |
| Rolos contados em **todos** os arcos | **12**: o objetivo passa a contar peças + fechamentos |
| $y$ contínuas (sem `Int`) | **4.75** ou algo próximo: o VRPSolver aceita a relaxação, como no BPP |
| Packing set por tipo | **inválido**: o tipo 2 aparece 3 vezes na solução ótima |

## Atenção para a modelagem

- **Ids dos vértices:** são as cargas $0..Q$. `VrpGraph(model, collect(0:Q), 0, Q, (0, n))`.
- **Arcos de item:** guarde o id devolvido por `add_arc!` só se for usar depois; o mapeamento é feito na hora, `add_arc_var_mapping!(G, a, y[(l, t)])`.
- **$y$ é `Int` e não tem limite superior.** O VrpSolver recusa limite superior em variável mapeada.
- **Tamanho do grafo** (`arcos_arcflow` no CSV): u120_00 tem 5 487 arcos; u1000_00, 7 521; t60_00, 34 023; Hard28_BPP14, 86 599. O nº de arcos cresce com $Q \cdot m$, não com $n$.
- **Impressão — `get_value` ignora a multiplicidade do caminho.** `get_value(optimizer, y)` e `get_objective_value` somam cada caminho positivo **uma vez só**, sem multiplicar pelo seu $\lambda$ (`VrpSolver.jl`, `_get_value`). No BPP isso não aparece, porque os packing sets forçam $\lambda = 1$. No CSP, o mesmo padrão pode entrar com $\lambda = 2$. Na toy, o BaPCod achou 5 rolos, com o padrão 7+3 duas vezes, mas a leitura por `get_value` deu **4 rolos** e só uma peça do tipo 1. Para ler a solução, percorra `p in 1:get_number_of_positive_paths(optimizer)`, use `λ = get_value(optimizer, p)` e as peças `get_value(optimizer, y[e], p)`, e some com peso $\lambda$.
- Não é preciso `define_elementarity_sets_distance_matrix!`: sem packing sets, não há o que definir.

## Referências para o benchmark (`otimos.csv`)

| Instância | $m$ | $n$ | $Q$ | Arcos | Ótimo | $\lceil \sum w d / Q \rceil$ | cutoff |
|---|---|---|---|---|---|---|---|
| Falkenauer_u120_00 | 58 | 120 | 150 | 5 487 | 48 | 48 | `48.01` |
| Falkenauer_u1000_00 | 81 | 1000 | 150 | 7 521 | 399 | 399 | `399.01` |
| Falkenauer_t60_00 | 50 | 60 | 1000 | 34 023 | 20 | 20 | `20.01` |
| Schwerin1_BPP1 | 46 | 100 | 1000 | 39 022 | 18 | 18 | `18.01` |
| Hard28_BPP14 | 136 | 160 | 1000 | 86 599 | 62 | 61 | `62.01` |

A u120_00 é a mesma instância que o BPP resolveu em 119 s e 35 nós. Comparar os dois modelos nela, e na u1000_00 (1000 itens no BPP, 81 tipos no CSP), mostra o efeito da agregação.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **5** — raiz, 1 nó; padrões 7+3 (×2), 5+5, 5+4, 4+3+3; produzido [2, 3, 2, 4] ≥ demanda [2, 3, 2, 3] (uma peça de largura 3 sobra) | 5 | 0.70 s |
| Falkenauer_u120_00 | **48** — raiz 48.00, **1 nó**; 42 padrões distintos (6 com ×2); sobram uma peça do tipo 20 (73) e uma do tipo 49 (32) | 48 | **0.90 s** |
| Falkenauer_u1000_00 | **399** — raiz 399.00, **1 nó**; 86 padrões distintos (até ×17); sobram uma peça do tipo 53 (48) e uma do tipo 67 (34) | 399 | **1.17 s** |
| Hard28_BPP14 | **62** — raiz 62.00, **1 nó**; 62 padrões, todos ×1; sobram 6 peças (tipos 65, 102 ×2, 112, 128 e 136) | 62 | **8.74 s** |

**Hard28 fecha na raiz, mesmo com ótimo acima do limite trivial.** O limite da raiz não é $\lceil \sum w d / Q \rceil = 61$: é o LP de Gilmore-Gomory, arredondado para cima porque o objetivo tem coeficientes inteiros. As Hard28 têm a propriedade IRUP ($\lceil z_{LP} \rceil$ = ótimo), então o LP já prova o 62. A dificuldade dessas instâncias está em **achar** a solução de 62, e o cutoff `62.01` não ajuda nisso. Para ver branching no arc-flow, seria preciso uma instância sem IRUP (non-IRUP), em que $\lceil z_{LP} \rceil$ < ótimo.

**CSP × BPP na u120_00:** o mesmo ótimo, 48. O BPP (120 itens, Ryan-Foster) levou **119 s e 35 nós**. O CSP (58 tipos, grafo arc-flow de 5 487 arcos) fechou na **raiz em 0.90 s**, cerca de 130× mais rápido. A agregação elimina a simetria entre itens de mesmo peso, e o pricing vira um caminho mínimo num DAG, sem ng-routes nem enumeração.

## Fontes (da leva)

- Gilmore, P. C., Gomory, R. E. (1961). A linear programming approach to the cutting-stock problem. *Operations Research* 9(6), 849–859.
- Valério de Carvalho, J. M. (1999). Exact solution of bin-packing problems using column generation and branch-and-bound. *Annals of Operations Research* 86, 629–659.
- Delorme, M., Iori, M., Martello, S. (2016). Bin packing and cutting stock problems: Mathematical models and exact algorithms. *European Journal of Operational Research* 255(1), 1–20.
- Delorme, M., Iori, M., Martello, S. (2018). BPPLIB: a library for bin packing and cutting stock problems. *Optimization Letters* 12(2), 235–250. <https://github.com/mdelorme2/BPPLIB>
- Spieksma, F. C. R. (1994). A branch-and-bound algorithm for the two-dimensional vector packing problem. *Computers & Operations Research* 21(1), 19–25.
- Caprara, A., Toth, P. (2001). Lower bounds and algorithms for the 2-dimensional vector packing problem. *Discrete Applied Mathematics* 111(3), 231–262. Instâncias: <https://site.unibo.it/operations-research/en/research/library-of-codes-and-instances-1> ("Two-Constraint Bin Packing Problem").
- Brandão, F., Pedroso, J. P. (2016). Bin packing and related problems: General arc-flow formulation with graph compression. *Computers & Operations Research* 69, 56–67.
- Heßler, K., Gschwind, T., Irnich, S. (2018). Stabilized branch-and-price algorithms for vector packing problems. *European Journal of Operational Research* 271(2), 401–419.
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
