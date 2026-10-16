# TOP no VRPSolver — instâncias, toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-16
Contexto: exercício 4 da Lista 1 - Resolução (Team Orienteering Problem). Segue o roteiro de [MTVRP no VRPSolver - Instâncias, toy e parser](../MTVRP/README.md).

## Definição usada no benchmark

Chao, Golden & Wasil (1996):
- um ponto de **início** e um ponto de **fim**, que podem estar em lugares diferentes;
- **$m$ veículos** (caminhos), cada um com **tempo máximo $T$** do início ao fim;
- cada cliente $i$ tem lucro $p_i$ e pode ser visitado **no máximo uma vez**; a visita é opcional;
- **maximizar o lucro coletado**;
- tempo = distância euclidiana **sem arredondamento**; sem tempo de serviço.

Na notação da Lista 1: source $= 0$ (início), sink $= n+1$ (fim), $L = 0$, $U = m$.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/Set1..Set7/*.txt` | As 387 instâncias (KU Leuven). Sets 1–3 são de Tsiligirides (1984) e sets 4–7 são de Chao et al. |
| `toy_top.txt` | Instância toy |
| `top_parser.jl` | `read_top(path)` e auto-teste |

Fonte dos arquivos: <https://www.mech.kuleuven.be/en/cib/op>. No Windows, o `curl` precisou de `--ssl-no-revoke` para baixar.

## Benchmark — Chao, Golden & Wasil (1996)

O nome `pS.m.L` codifica o set `S` (1 a 7), o número de veículos `m` (2, 3 ou 4) e a letra `L`, que cresce com $T$.

| Set | Pontos (com início e fim) | Clientes | Início = fim? | Instâncias |
|---|---|---|---|---|
| 1 | 32 | 30 | não | 54 |
| 2 | 21 | 19 | não | 33 |
| 3 | 33 | 31 | não | 60 |
| 4 | 100 | 98 | não | 60 |
| 5 | 66 | 64 | não | 78 |
| 6 | 64 | 62 | não | 42 |
| 7 | 102 | 100 | sim, (35, 35) | 60 |

Formato: três linhas de cabeçalho, `n N`, `m P` e `tmax T`, seguidas de $N$ linhas `x y S`. A primeira linha de pontos é o início e a última é o fim.

## Parser

```julia
include("top_parser.jl")
inst = read_top(joinpath(@__DIR__, "toy_top.txt"))
inst.n, inst.m, inst.T, inst.p[i+1], inst.C[i+1, j+1]
```

O ponto $k$ do arquivo vira o vértice $k-1$: **início = 0, clientes = $1..n$, fim = $n+1$**, com $n = N - 2$. `C` é a matriz euclidiana sem arredondar, de tamanho $(n+2) \times (n+2)$.

Auto-teste: `julia top_parser.jl` → `OK: toy + 387 instâncias de Chao et al. lidas`. Ele confere que o início e o fim têm lucro 0 e que o $m$ do arquivo bate com o nome.

## Instância toy — `toy_top.txt`

Início em (0, 0), **fim em (10, 0)**; $m = 2$; $T = 14$.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| (x, y) | (2, 3) | (4, 4) | (6, 3) | (5, 0.5) | (3, −3) | (6, −4) | (9, −2) |
| $p_i$ | 10 | 10 | 10 | **30** | 10 | 10 | 10 |

**Ótimo (força bruta e MIP): 70.** Cutoff sugerido, com o objetivo negado: `ub = -69.99`.

| Caminho | Duração | Lucro |
|---|---|---|
| $0\!-\!1\!-\!4\!-\!8$ | 12.54 ≤ 14 | 40 |
| $0\!-\!5\!-\!6\!-\!7\!-\!8$ | 13.25 ≤ 14 | 30 |

Os clientes 2 e 3 ficam de fora: $0\!-\!1\!-\!2\!-\!3\!-\!4\!-\!8$ dura 15.80.

Armadilhas que a toy pega:

| Modelo errado | Resultado |
|---|---|
| Caminho volta ao início (fim = 0) | **60** |
| Cliente pode ser visitado por dois caminhos (lucro contado duas vezes) | **80**: os dois caminhos fazem $0\!-\!1\!-\!4\!-\!8$ |
| Um caminho só ($U = 1$) | **40** |
| $T$ vale para a soma dos caminhos, não por caminho | **90**: um único caminho de 28 pega os 7 clientes |

## Atenção para a modelagem (antes de escrever o código)

1. **O VRPSolver minimiza.** Escreva o objetivo como $\min -\sum p_i y_i$. O valor que ele imprime sai negativo, e o **cutoff também é negativo**: `ub = -(ótimo) + 0.01`.
2. **Início ≠ fim** são dois vértices: `VrpGraph(model, 0:n+1, 0, n+1, (0, m))`. Não há arcos que entram em 0 nem que saem de $n+1$.
3. **Formulação por arestas (como a do professor):** $E$ = pares $i<j$ em $\{0, \dots, n+1\}$, **sem a aresta $(0, n+1)$**, que seria um caminho vazio e não é necessária porque $L = 0$. Os arcos $i \to j$ e $j \to i$ entre clientes mapeiam para o mesmo `x[(i,j)]`. O arco $0 \to j$ mapeia para `x[(0,j)]` e o arco $i \to n+1$ mapeia para `x[(i,n+1)]`.
4. **Visita opcional:** grau $\sum_{e \in \delta(i)} x_e = 2y_i$, com `y[i in V⁺]` binária. O `y` não é mapeado a arcos, e isso é permitido: ele é uma variável comum da formulação.
5. **Recurso:** só o tempo, com limites $[0, T]$ e consumo $c_{ij}$. Não há capacidade.
6. **Packing sets:** um por cliente, com distâncias $c_{ij}$, como no CVRP.

## Modelo implementado (2026-10-16)

Arquivo do usuário: `TOP/top_model.jl`, na pasta do WSL.
- **Problema original:** `x[e in E]` inteiro e `y[i in V⁺]` binário; objetivo $\min -\sum p_i y_i$; grau $\sum_{e\in\delta(i)} x_e = 2y_i$; $L = 0$, $U = m$.
- **Grafo:** $V = \{0, \dots, n+1\}$, com source 0 e sink $n+1$. Os arcos são $0 \to j$, $j \to n+1$ e $i \to j$ entre clientes, cada um mapeado para `x[aresta(i,j)]`.
- **Recurso:** só o tempo (`main`), com limites $[0, T]$ e consumo $c_{ij}$.
- **Packing sets:** clientes singleton, com distâncias $c_{ij}$. A prioridade de branching de `y` (2) é maior que a de `x` (1).

**Toy:** **lucro 70**, igual à força bruta. Resolveu na raiz em 0.68 s. Os visitados foram {1, 4, 5, 6, 7}, e as arestas formam exatamente os caminhos $0\!-\!1\!-\!4\!-\!8$ e $0\!-\!5\!-\!6\!-\!7\!-\!8$. O modelo não caiu em nenhuma armadilha: o fim é $n+1$, nenhum cliente foi contado duas vezes e há dois caminhos.

**p2.2.e** ($m = 2$, $T = 13.5$; cutoff −189.99): **lucro 190**, igual ao MIP. Resolveu na raiz em 0.69 s. Caminhos conferidos em Python:

| Caminho | Duração | Lucro |
|---|---|---|
| 0-6-5-4-2-1-11-20 | 13.32 ≤ 13.5 | 90 |
| 0-10-7-8-9-13-20 | 13.14 ≤ 13.5 | 100 |

**p1.2.p** ($m = 2$, $T = 37.5$; cutoff −249.99): **lucro 250**, igual ao ótimo publicado. Resolveu na raiz em 0.96 s; na literatura, o B-P de Boussier et al. levou 2926 s e o algoritmo de El-Hajj et al. levou 7 s.

| Caminho | Duração | Lucro |
|---|---|---|
| 0-18-19-26-30-25-24-23-22-21-20-11-10-9-8-12-31 | 37.47 ≤ 37.5 | 145 |
| 0-27-16-15-14-13-3-4-2-6-5-17-31 | 36.95 ≤ 37.5 | 105 |

- São 26 clientes distintos visitados, de 30. As 28 arestas formam exatamente esses dois caminhos, sem ciclos soltos.
- O primeiro caminho sobra só 0.03 abaixo de $T$.

## Valores de referência

**Calculados por mim** com um MIP (arcos + MTZ no tempo, CBC), sem consulta à literatura:

Set 2 completo (33 instâncias), **reconferido com `sol_status`**. O status "Optimal" do PuLP não garante otimalidade quando o CBC para no limite de tempo (ver [PTP no VRPSolver - Instâncias, toy e parser](../PTP/README.md)).
- **30 valores têm o ótimo provado.**
- **p2.2.e, p2.2.j e p2.2.k (190, 240, 260)** são só soluções viáveis, porque o CBC parou no limite de 600 s. Mesmo assim, o 190 do p2.2.e foi provado pelo VRPSolver. Os outros dois são apenas limites inferiores do lucro: se o VRPSolver achar um valor maior, ele pode estar certo.

| Letra | a | b | c | d | e | f | g | h | i | j | k |
|---|---|---|---|---|---|---|---|---|---|---|---|
| p2.2 | 90 | 120 | 140 | 160 | 190 | 200 | 200 | 230 | 230 | 240 | 260 |
| p2.3 | 70 | 70 | 105 | 105 | 120 | 120 | 145 | 165 | 200 | 200 | 200 |
| p2.4 | 10 | 70 | 70 | 70 | 70 | 105 | 105 | 120 | 120 | 120 | 180 |

**Publicados** em El-Hajj, Dang & Moukrim (2016), Tabela 3. São instâncias que alguns métodos exatos não resolveram, então são bons testes de desempenho:

| Instância | $m$ | $T$ | Ótimo |
|---|---|---|---|
| p1.2.p | 2 | 37.5 | 250 |
| p1.2.q | 2 | 40 | 265 |
| p1.2.r | 2 | 42.5 | 280 |
| p3.2.l | 2 | 35 | 590 |
| p3.2.m | 2 | 37.5 | 620 |
| p3.2.n | 2 | 40 | 660 |
| p3.3.s | 3 | 35 | 720 |
| p4.3.g | 3 | 36.7 | 653 |

Lembrete: o cutoff é `ub = -(ótimo) + 0.01`.

## Fontes

- Chao, I-M., Golden, B. L., Wasil, E. A. (1996). The team orienteering problem. *EJOR* 88(3), 464–474.
- El-Hajj, R., Dang, D.-C., Moukrim, A. (2016). Solving the team orienteering problem with cutting planes. *Computers & OR* 74, 21–30. <https://arxiv.org/abs/1604.02934>
- Instâncias: <https://www.mech.kuleuven.be/en/cib/op>

## Notas relacionadas

- Lista 1 - Resolução · Team Orienteering Problem · Orienteering Problem
- [MTVRP no VRPSolver - Instâncias, toy e parser](../MTVRP/README.md) · Como modelar no VRPSolver - Subproblemas, recursos e conjuntos · VRPSolver
