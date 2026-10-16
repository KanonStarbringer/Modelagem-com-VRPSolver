# m-CTP no VRPSolver — instâncias, toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-16
Contexto: exercício 7 da Lista 1 - Resolução (Multi-vehicle Covering Tour Problem). Segue o roteiro de [GVRP no VRPSolver - Toy e parser](../GVRP/README.md).

## Definição

Os vértices se dividem em três grupos: $T$, obrigatórios, incluindo o depósito 0; $V \setminus T$, opcionais; e $W$, clientes que **devem ser cobertos, mas nunca visitados**. Um vértice visitado $v$ cobre $w \in W$ se $c_{vw} \le \bar c$. Cada rota visita **no máximo $p$ vértices** e tem **comprimento ≤ $q$**. O objetivo é encontrar rotas de custo mínimo que visitem todo $T$ e um subconjunto de $V \setminus T$ tal que todo $w \in W$ fique coberto.

Variantes da literatura: **m-CTP-p** tem só o limite $p$; **m-CTP** tem $p$ e $q$. A frota é livre ($U = |V| - 1$ no código dos autores).

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/*.ctp` | As 192 instâncias da literatura (96 bases × maxL ∈ {250, 500}) |
| `toy_mctp.ctp` | Instância toy |
| `mctp_parser.jl` | `read_mctp(path; maxL)` e auto-teste |
| `mctp_otimos.csv` | Ótimos de 16 instâncias, transcritos do suplementar |

A pasta `mCTP/` do WSL tem tudo isso, mais o `CVRP.cfg`.

Fontes dos arquivos: <https://github.com/brunomattos1/m-ctp_instances>. O código dos autores, também em VRPSolver e com a **formulação por arestas do professor**, está em <https://github.com/brunomattos1/mCTP-BCP>.

## Benchmark

São as instâncias de Hà et al. (2013), derivadas de kroA/B/C/D da TSPLIB. O nome `A1-1-25-75-4-250` codifica:
- `A1`: a base;
- `1`: $|T|$, contando o depósito;
- `25`: $|V|$, o número de vértices roteáveis;
- `75`: $|W|$;
- `4`: $p$;
- `250`: o **maxL**, que define $q$.

**Comprimento máximo (convenção do código dos autores):** $q = \text{maxL} + 2 \max_i c_{0i}$. O sufixo do arquivo é o maxL, e não o próprio $q$.

**Ótimos:** Oliveira, Pessoa & Roboredo resolveram 195 das 196 instâncias do m-CTP. Conferi a transcrição comparando as Tabelas 3 e 4 do suplementar (sem cortes e com cortes), que trazem os mesmos valores.

| Instância | m-CTP-p | m-CTP, maxL = 250 | m-CTP, maxL = 500 |
|---|---|---|---|
| A1-1-25-75-4 | 8479 | 12182 | 12182 |
| A1-1-50-50-4 | 10271 | 12685 | 10271 |
| A1-5-25-75-4 | 10827 | 15194 | 12558 |
| A1-10-50-50-6 | 14064 | 14916 | 14550 |

Os outros 12 valores estão no CSV. Cutoff: `ub = ótimo + 0.01`.

## Formato `.ctp`

```
NOME
|O| |C| |M| p q            (|M| conta o depósito; q = maxL + 2·max c(0,i), conferido nos 192 arquivos)
i j c_ij                    (arestas entre os roteáveis 0..|M|+|O|-1)
k a_1 ... a_|C|             (matriz de cobertura: UMA LINHA POR OPCIONAL)
r_1 ... r_|C|               (multi-cobertura; ignorado no m-CTP)
NODE_COORD_SECTION ... EOF
```

Os ids dos vértices roteáveis são: depósito 0, depois os obrigatórios $1..n_M$, depois os opcionais. **Só os opcionais cobrem clientes**, porque a matriz não tem linhas para os obrigatórios.

## Parser

```julia
include("mctp_parser.jl")
inst = read_mctp(joinpath(@__DIR__, "toy_mctp.ctp"); maxL = 10)
inst.R                       # nº de vértices roteáveis (0..R-1)
inst.mand, inst.opt          # obrigatórios (T \ {0}) e opcionais
inst.nC, inst.cover[k]       # nº de clientes; opcionais que cobrem o cliente k
inst.p, inst.q               # limites por rota (q = Inf se maxL não for dado)
inst.C[i+1, j+1]             # custo da aresta
```

Auto-teste: `julia mctp_parser.jl` → `OK: toy + 192 instâncias da literatura lidas`. Ele confere que o cabeçalho de cada arquivo bate com o nome.

## Instância toy — `toy_mctp.ctp`

Depósito em (0, 0); obrigatório 1 em (10, 0); $p = 3$; raio de cobertura 5; custos EUC_2D arredondados.

| Opcional | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|
| (x, y) | (0, 10) | (−10, 0) | (0, −10) | (−7, 7) | (9, −8) |
| cobre | $w_2, w_3$ | $w_1, w_5$ | $w_4$ | — | $w_6$ |

Para cobrir os 6 clientes, é preciso visitar {2, 3, 4, 6}. O opcional 5 é inútil. $\max_i c_{0i} = 12$, então $q = \text{maxL} + 24$.

**Rode a toy duas vezes:**

| maxL | $q$ | Ótimo (força bruta) | Rotas | Cutoff |
|---|---|---|---|---|
| **10** | 34 | **84** | 0-1-6-0 (30), 0-2-0 (20), 0-3-4-0 (34); ou 0-2-3-0 + 0-4-0, mesmo custo | `84.01` |
| **1000** | 1024 (não limita) | **71** | 0-1-4-6-0 (37), 0-2-3-0 (34) | `71.01` |

Armadilhas:

| Modelo errado | maxL = 10 | maxL = 1000 |
|---|---|---|
| Sem a restrição de cobertura | **20** (só 0-1-0) | 20 |
| Sem o limite $q$ | **71** | 71 |
| Sem o limite $p$ | 84 | **65** (0-2-3-4-6-1-0) |
| Todos os opcionais obrigatórios (grau `== 2`) | **92** | 73 |

## Atenção para a modelagem

1. **O grafo só tem os vértices roteáveis** (0..R−1). Os clientes de $W$ não viram vértices nem arcos.
2. **Grau:** obrigatórios com `== 2`; opcionais com `<= 2`. Não precisa de `y`: o grau do opcional faz esse papel.
3. **Cobertura sem `y`:** para cada cliente $k$, $\sum_{e \in \delta(\text{cover}[k])} x_e \ge 2$, ou seja, as arestas que cruzam a fronteira do conjunto de opcionais que cobrem $k$. É assim que os autores escrevem. Com `y` também dá: $\sum_{i \in \text{cover}[k]} y_i \ge 1$ e grau $= 2y_i$.
4. **Recurso "vértices" (limite $p$):** consumo 1 por arco entre roteáveis e **0.5 nos arcos do depósito**, com limites $[0, p]$. Uma rota com $k$ vértices usa $k-1$ arcos internos e 2 arcos do depósito, o que soma $k$. Com consumo 1 em todo arco, a soma seria $k+1$, e o limite cortaria uma rota válida.
5. **Recurso "comprimento":** consumo $c_{ij}$, com limites $[0, q]$. Só existe no m-CTP; no m-CTP-p, fica de fora.
6. **Limites de caminhos:** $L = 0$, $U = R - 1$ (frota livre). Com $L = \lceil |T \setminus\{0\}| / p \rceil$, como na correção da Lista, também é válido.
7. **Packing sets:** singletons dos roteáveis (obrigatórios e opcionais), com distâncias $c_{ij}$.

## Modelo implementado (2026-10-16)

Arquivo do usuário: `mCTP/mctp_model.jl`, na pasta do WSL.
- **Problema original:** `x[e in E]` inteiro, sem `y`; grau `== 2` nos obrigatórios e `<= 2` nos opcionais; cobertura $\sum_{e \in \text{corte}(\text{cover}[k])} x_e \ge 2$; $L = 0$, $U = R - 1$.
- **Recursos:** `nv`, com consumo 0.5 nos arcos do depósito e 1 nos demais, e limite $[0, p]$; `len`, com consumo $c_{ij}$ e limite $[0, q]$.
- **Packing sets:** singletons dos roteáveis.

**Toy, maxL = 10:** **custo 84**, igual à força bruta. Resolveu na raiz em 0.83 s. Os visitados foram {1, 2, 3, 4, 6}. As rotas foram 0-1-6-0 (30), 0-2-3-0 (34) e 0-4-0 (20, com `x[(0,4)] = 2`), que é a solução empatada com 0-2-0 + 0-3-4-0. O opcional 5, que não cobre nenhum cliente, ficou de fora. As duas rotas de 34 ficam exatamente em $q = 34$, então o limite de comprimento está ativo.

**Toy, maxL = 1000:** **custo 71**, igual à força bruta. Resolveu na raiz em 0.78 s. As rotas foram 0-1-6-4-0 (37) e 0-2-3-0 (34). A primeira tem 3 vértices, o que é exatamente $p$. Sem o limite $p$, o custo cairia para 65, então o recurso `nv`, com 0.5 nos arcos do depósito, está correto.

**A1-1-25-75-4-250** (maxL = 250, $q = 5358$; cutoff 12182.01): **custo 12182**, igual ao ótimo publicado. Resolveu na raiz em 0.73 s. Conferido em Python:

| Rota | Comprimento | Vértices |
|---|---|---|
| 0-2-22-0 | 4837 ≤ 5358 | 2 |
| 0-4-24-0 | 5061 ≤ 5358 | 2 |
| 0-5-18-9-0 | 2284 ≤ 5358 | 3 |

Os 7 opcionais visitados cobrem os 75 clientes, e todas as rotas respeitam $p = 4$ e $q$.

**O último campo do cabeçalho é o $q$.** Conferi nos 192 arquivos que ele é igual a maxL + 2·max $c_{0i}$. O código dos autores ignora esse campo e recalcula $q$ a partir do maxL, mas o valor é o mesmo.

## Fontes

- Oliveira, B. D. M., Pessoa, A. A., Roboredo, M. C. (2025). New cuts and a branch-cut-and-price model for the multi vehicle covering tour problem. *4OR* 23(3). Preprint: <https://optimization-online.org/?p=26190>
- Hà, M. H., Bostel, N., Langevin, A., Rousseau, L.-M. (2013). An exact algorithm and a metaheuristic for the multi-vehicle covering tour problem with a constraint on the number of vertices. *EJOR* 226(2), 211–220.
- Hachicha, M., Hodgson, M. J., Laporte, G., Semet, F. (2000). Heuristics for the multi-vehicle covering tour problem. *Computers & OR* 27(1), 29–42.

## Notas relacionadas

- Lista 1 - Resolução · [GVRP no VRPSolver - Toy e parser](../GVRP/README.md) · [PTP no VRPSolver - Instâncias, toy e parser](../PTP/README.md)
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos · VRPSolver
