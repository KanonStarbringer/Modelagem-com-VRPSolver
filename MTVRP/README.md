# MTVRP no VRPSolver — instâncias, toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-15
Contexto: exercício 3 da Lista 1 - Resolução (Multi-trip VRP). Segue o roteiro de [MCVRP no VRPSolver - Instância toy e parser](../MCVRP/README.md) e [DCVRP no VRPSolver - Instâncias, toy e parser](../DCVRP/README.md).

## Definição usada no benchmark

Segundo Mingozzi, Roberti & Toth (2013), cap. 5 da tese de Roberti:
- frota de **$m$ veículos idênticos**, cada um com capacidade $Q$ e **tempo máximo de condução $T$**;
- uma **viagem** (route) é um ciclo elementar no depósito com demanda total ≤ $Q$;
- uma **agenda** (schedule) é um conjunto de viagens de um mesmo veículo com **duração total ≤ $T$**;
- encontrar $m$ agendas de custo mínimo que visitem cada cliente exatamente uma vez;
- custo = tempo de viagem = distância euclidiana **sem arredondamento**; **sem tempo de serviço**.

Na notação da Lista 1: $U = m$, a capacidade vale **por viagem** e $T$ vale **por veículo**.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `../DCVRP/Instancias/CMT/CMT{1,2,3,11,12}.vrp` | Grafos base (os mesmos baixados para o DCVRP) |
| `mtvrp_instances.csv` | As 56 instâncias: base, $n$, fator, $m$, $T$, ótimo ou limite superior, status |
| `toy_mtvrp.vrp` | Instância toy |
| `mtvrp_parser.jl` | `read_mtvrp(path; m, T)`, `mtvrp_table()` e auto-teste |

## Benchmark — Taillard, Laporte & Gendreau (1996)

Não existe um arquivo próprio por instância. Cada instância é um **CVRP do CMT + um par $(m, T)$**:
$$T = \left[\frac{f \cdot z_{RT}}{m}\right], \quad f \in \{1.05,\ 1.10\},$$
em que $[\cdot]$ é o arredondamento para o inteiro mais próximo e $z_{RT}$ é o custo CVRP de Rochat & Taillard (1995): 524.61, 835.26, 826.14, 1042.11 e 819.56 para CMT1, 2, 3, 11 e 12.

- **56 instâncias**, com 50 a 120 clientes. Mingozzi et al. **provaram o ótimo de 42**. Há 10 só com limite superior e 4 sem nenhuma solução viável conhecida em 2012.
- O auto-teste confere a fórmula de $T$ em todas as 56 linhas do CSV, o que confirma a transcrição das tabelas 5.1 a 5.3.
- **35 das 42** têm o mesmo ótimo do CVRP correspondente, porque as viagens do ótimo CVRP já cabem nas $m$ agendas. Então elas não testam o recurso de tempo. As 7 em que o ótimo do MTVRP é maior que o do CVRP são as boas para validar o modelo:

| Instância | $m$ | $T$ | Ótimo MTVRP | Ótimo CVRP |
|---|---|---|---|---|
| CMT1 | 2 | 275 | 533.00 | 524.61 |
| CMT1 | 2 | 289 | 529.85 | 524.61 |
| CMT1 | 4 | 144 | 546.29 | 524.61 |
| CMT2 | 5 | 175 | 835.80 | 835.26 |
| CMT2 | 6 | 153 | 839.22 | 835.26 |
| CMT12 | 5 | 180 | 824.78 | 819.56 |
| CMT12 | 6 | 150 | 823.14 | 819.56 |

Os limites superiores são de 2012 e podem ter sido melhorados ou provados ótimos depois. Não verifiquei a literatura mais recente.

## Parser

```julia
include("mtvrp_parser.jl")      # inclui ../DCVRP/dcvrp_parser.jl
inst = read_mtvrp(joinpath(@__DIR__, "toy_mtvrp.vrp"))               # m, T lidos do arquivo
inst = read_mtvrp("…/CMT1.vrp"; m = 2, T = 275)                      # m, T da tabela
```

Campos: os mesmos do `read_cvrplib` (`n`, `Q`, `d[i+1]`, `C[i+1, j+1]`, …) mais `m` e `T`. O parser aborta se o arquivo tiver `DISTANCE` ou `SERVICE_TIME`, porque o MTVRP usa a versão CVRP do CMT.

`mtvrp_table()` devolve as linhas do CSV (`base`, `n`, `fator`, `m`, `T`, `z`, `status`, `nota`), para montar laços sobre o benchmark.

Auto-teste: `julia mtvrp_parser.jl` → `OK: toy + 56 instâncias do benchmark (42 com ótimo conhecido)`.

**No WSL:** o `mtvrp_parser.jl` procura o parser do DCVRP em `../DCVRP/`. Mantenha as pastas `MTVRP/` e `DCVRP/` lado a lado.

## Instância toy — `toy_mtvrp.vrp`

Depósito em (0, 0); $Q = 10$; todas as demandas iguais a 5, ou seja, **no máximo 2 clientes por viagem**; **$m = 2$, $T = 54$**. Os campos `VEHICLES` e `TMAX` são extensões minhas do formato CVRPLIB.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (−5, 15) | (−11, −3) | (5, −14) | (−13, 11) | (2, −12) | (−4, 3) |

**Ótimo (força bruta): 105.2257.** Cutoff sugerido: `ub = 105.23`.

| Veículo | Viagens | Duração |
|---|---|---|
| 1 | $0\!-\!1\!-\!4\!-\!0$ (41.79) + $0\!-\!6\!-\!0$ (10.00) | 51.79 ≤ 54 |
| 2 | $0\!-\!2\!-\!0$ (22.80) + $0\!-\!3\!-\!5\!-\!0$ (30.64) | 53.44 ≤ 54 |

São 4 viagens em 2 veículos, e **cada veículo faz duas**.

Armadilhas que a toy pega:

| Modelo errado | Resultado |
|---|---|
| Sem limite $T$, ou $T$ aplicado por viagem em vez de por veículo | **98.0435**: viagens {1,4}, {2,6}, {3,5}, que somam 98 de duração e não cabem em 2 × 54 |
| Sem multi-viagem (cada caminho = uma viagem, $U = 2$) | **inviável**: 6 clientes com no máximo 2 por viagem exigem ≥ 3 viagens |
| Capacidade sem "reset" (acumula na agenda inteira) | **inviável**: cada veículo levaria no máximo 10, ou seja, 4 clientes no total |

## Atenção para a modelagem (antes de escrever o código)

A correção da Lista 1 fala em `reset_at[0, r_cap] = true`. **Esse comando não existe no VRPSolver**, que não tem a noção de zerar um recurso no meio do caminho. Duas consequências:

1. A ideia da correção está certa (uma agenda é um caminho, a capacidade vale por viagem e o tempo vale por veículo), mas o "reset" precisa ser **emulado com o grafo**.
2. A ferramenta que o VRPSolver oferece para isso: em um **recurso descartável**, se o consumo acumulado chega a um vértice **abaixo** do limite inferior $l_v$, ele sobe para $l_v$. É o mecanismo de "esperar" nas janelas de tempo do VRPTW. Com **cópias do depósito** entre as viagens e limites $[l_v, u_v]$ escolhidos para cada viagem, dá para fazer a capacidade "recomeçar" a cada viagem. Confira essa semântica na documentação do VrpSolver.jl antes de contar com ela.

Outras consequências para o modelo: os packing sets continuam sendo os clientes, mas um cliente pode ter **várias cópias** no grafo, e aí o packing set de cada cliente é o conjunto das suas cópias, como no GVRP. O $x_{ij}$ dos arcos do depósito deixa de ser binário, e a matriz de distâncias dos packing sets continua sendo $c_{ij}$.

## Modelo implementado — grafo em camadas (2026-10-15)

- **Problema original:** igual ao do MCVRP e do DCVRP (`x[e in E]` inteiro, objetivo, grau `== 2` nos clientes); $L = 1$, $U = m$.
- **Grafo do VRPSolver:** $K$ camadas (uma por viagem). Os vértices são as cópias $(i,k)$ dos clientes, com id `(k-1)*n + i`, e as cópias $0_k$ do depósito entre viagens, com id `K*n + k`. Source e sink são o 0.
- **Arcos:** $0 \to (j,1)$, $(i,k) \to (j,k)$, $(i,k) \to 0_k$, $0_k \to (j,k+1)$ e $(i,k) \to 0$. Cada arco é mapeado para a aresta original `x[(min(i,j), max(i,j))]`.
- **Recursos:**
  - tempo em $[0, T]$ com consumo $c_{ij}$;
  - capacidade com limites por camada: $[(k-1)Q, kQ]$ em $(i,k)$ e $[kQ, kQ]$ em $0_k$. O **"reset"** sai do recurso descartável: ao chegar em $0_k$ abaixo de $kQ$, a carga sobe para $kQ$.
- **Packing sets:** cliente $i$ = $\{(i,1), \dots, (i,K)\}$, como os clusters no GVRP.

**Toy:** **105.2257**, igual à força bruta. Resolveu no nó raiz em 0.66 s.
- Arestas: `x[(0,2)] = 2` e `x[(0,6)] = 2` (viagens de um cliente, $0\!-\!2\!-\!0$ e $0\!-\!6\!-\!0$), mais $0\!-\!1\!-\!4\!-\!0$ e $0\!-\!3\!-\!5\!-\!0$. São as 4 viagens da força bruta.
- Duas confirmações:
  - **o "reset" funcionou:** cada veículo leva 15 > $Q$ = 10 no total;
  - **$T$ vale por veículo:** o modelo não caiu em 98.04.
- O `x` não diz qual veículo faz qual viagem. A divisão em agendas fica implícita nas colunas.

**Limite $K$ mais justo.** O $K = \lfloor T / t_{min} \rfloor$ fica enorme no CMT (CMT1 com $m = 2$, $T = 275$: $t_{min} = 4.47$, $K = 61$, mais de 3000 vértices). Um limite melhor, que continua válido pela desigualdade triangular: cada viagem passa por um cliente diferente $j$ e dura pelo menos $2c_{0j}$, então
$$K = \max\Big\{k : \textstyle\sum_{\text{os } k \text{ menores}} 2c_{0j} \le T\Big\}.$$
Isso dá $K = 2$ na toy, 12 no CMT1 com ($m = 2$, $T = 275$ ou $289$) e 7 no CMT1 com ($m = 4$, $T = 144$).

## Resultados no benchmark

**CMT1, $m = 2$, $T = 275$** (cutoff 533.01): **532.9958**, que bate com o ótimo publicado (533.00). A cota da raiz foi 529.01 (gap de 0.75%) e a raiz levou 6147 s. Foram 3 nós, com 6285 s no total.

Viagens reconstruídas das arestas e conferidas em Python ($Q = 160$):

| Viagem | Carga | Duração |
|---|---|---|
| 0-1-22-28-31-8-26-7-43-24-23-48-27-0 | 158 | 124.62 |
| 0-4-13-41-40-19-42-44-45-33-15-37-17-0 | 159 | 141.76 |
| 0-5-49-10-39-30-34-50-9-38-46-0 | 144 | 93.93 |
| 0-6-14-25-18-47-12-0 | 159 | 61.41 |
| 0-11-16-21-29-20-35-36-3-2-32-0 | 157 | 111.29 |

- Os 50 clientes são cobertos e todas as cargas são ≤ 160.
- As viagens se dividem em 2 agendas: viagens {3, 4, 5}, com 266.63, e {1, 2}, com 266.37, ambas ≤ 275. A divisão foi achada por força bruta, porque o `x` não a informa.
- O ótimo CVRP (524.61) também usa 5 viagens, mas não cabe em 2 × 275. Por isso o custo sobe 8.39.
- O gargalo é a raiz, que tem K = 12 camadas e cerca de 600 vértices. As outras instâncias de validação (CMT2, CMT12, com 75 e 100 clientes) devem demorar mais.

**CMT1, $m = 4$, $T = 144$** (cutoff 546.30): **546.2924**, que bate com o ótimo publicado (546.29). Resolveu na raiz, sem gap, em 88.6 s. Com $K = 7$, o modelo foi cerca de 70 vezes mais rápido que o caso $m = 2$.

| Viagem | Carga | Duração |
|---|---|---|
| 0-1-22-3-36-35-20-29-21-34-30-39-10-0 | 160 | 141.79 |
| 0-4-13-41-40-19-42-44-45-33-15-37-17-0 | 159 | 141.76 |
| 0-6-23-24-43-7-26-31-28-8-48-27-0 | 158 | 122.80 |
| 0-12-47-18-25-14-0 | 144 | 57.82 |
| 0-32-2-16-50-9-49-5-38-11-46-0 | 156 | 82.12 |

- Agendas: {1} 141.79, {2} 141.76, {3} 122.80 e {4, 5} 139.94, todas ≤ 144. Só um veículo faz duas viagens.
- Por isso o $T$ aperta tanto: três viagens quase encostam em 144, o que força rotas diferentes das do caso $m = 2$.

## Fontes

- Roberti, R. (2012). *Exact algorithms for different classes of vehicle routing problems*. Tese, Univ. de Bolonha, cap. 5. <https://amsdottorato.unibo.it/id/eprint/4350/>
- Mingozzi, A., Roberti, R., Toth, P. (2013). An exact algorithm for the multitrip vehicle routing problem. *INFORMS Journal on Computing* 25(2). <https://doi.org/10.1287/ijoc.1110.0495>
- Taillard, É., Laporte, G., Gendreau, M. (1996). Vehicle routeing with multiple use of vehicles. *JORS* 47(8), 1065–1070.

## Notas relacionadas

- Lista 1 - Resolução · Multi-Trip CVRP · Capacitated VRP
- [DCVRP no VRPSolver - Instâncias, toy e parser](../DCVRP/README.md) · VRP Clusterizado e Generalizado
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos · VRPSolver
