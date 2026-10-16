# PTP no VRPSolver — instâncias, toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-16
Contexto: exercício 5 da Lista 1 - Resolução (Profitable Tour Problem com capacidade). Segue o roteiro de [TOP no VRPSolver - Instâncias, toy e parser](../TOP/README.md).

## Definição

Pelo enunciado da Lista 1: depósito 0; cada cliente $i$ tem lucro $p_i$ e demanda $d_i$; cada arco tem custo $c_{ij}$; capacidade $Q$; **visitar é opcional**. O objetivo é **maximizar o lucro dos visitados menos o custo de roteamento**, com demanda ≤ $Q$ em cada rota.

Na literatura, esse problema é o **Capacitated Profitable Tour Problem (CPTP)** de Archetti, Feillet, Hertz & Speranza (2009). A única diferença em relação à Lista é que o benchmark fixa a frota em **$m$ veículos** (`MAXVEHICLES`), enquanto a Lista usa $U = n$. Com $U = m$, o mesmo modelo serve para os dois casos.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/p*.cri` | As 10 instâncias-base de Archetti et al. (OR@Brescia) |
| `toy_ptp.cri` | Instância toy |
| `ptp_parser.jl` | `read_ptp(path)` e auto-teste |

A pasta `PTP/` do WSL já tem o parser, a toy, o `CVRP.cfg` e as instâncias.

Fonte: <https://or-brescia.unibs.it/instances>, link do artigo de Archetti, Bianchessi & Speranza (2013). O `p15.cri` original estava em UTF-16 e foi convertido para UTF-8.

## Benchmark

Os arquivos são as instâncias de Christofides et al. (CMT) com uma coluna de lucro. Comparei coordenadas e demandas com os `.vrp` do DCVRP:

| Arquivo | $n$ | $m$ | $Q$ | Base | $\sum p_i$ |
|---|---|---|---|---|---|
| p06 | 50 | 10 | 160 | CMT1 (idêntico) | 761 |
| p07 | 75 | 20 | 140 | CMT2 (idêntico) | 1327 |
| p03, p08 | 100 | 15 | 200 | CMT3 (idêntico) | 1409 |
| p09 | 150 | 10 | 200 | CMT4 (idêntico) | 2194 |
| p15 | 150 | 15 | 200 | outro arranjo de 150 clientes | 2159 |
| p10 | 199 | 20 | 200 | CMT5 (idêntico) | 3048 |
| p16 | 199 | 20 | 200 | outro arranjo de 199 clientes | 3066 |
| p13 | 120 | 15 | 200 | CMT11 (idêntico) | 1287 |
| p14 | 100 | 10 | 200 | CMT12 (idêntico) | 1710 |

Formato: um cabeçalho com `MAXVEHICLES`, `MAXCAPACITY`, `MAXTIME`, `DEPOT x y` e `CUSTOMERS n`, seguido de `CUSTOMERDATA` e de $n$ linhas `x y d s p`. O `MAXTIME` e o tempo de serviço `s` pertencem ao CTOP; **o CPTP ignora os dois**. O custo é a distância euclidiana sem arredondar.

**Ótimos publicados:** estão em Archetti, Bianchessi & Speranza (2013), mas não consegui o texto completo. Nos artigos, cada arquivo-base gera várias instâncias, variando $m$ e $Q$. Para validar o modelo, usamos três referências que não dependem dessa tabela (ver abaixo).

## Parser

```julia
include("ptp_parser.jl")
inst = read_ptp(joinpath(@__DIR__, "toy_ptp.cri"))
inst.n, inst.m, inst.Q, inst.d[i+1], inst.p[i+1], inst.C[i+1, j+1]
```

O depósito é o vértice 0 e o $k$-ésimo cliente é o vértice $k$. Auto-teste: `julia ptp_parser.jl` → `OK: toy + 10 instâncias de Archetti et al. lidas`.

## Instância toy — `toy_ptp.cri`

Depósito em (0, 0); $Q = 10$; $m = 6$, ou seja, a frota não limita.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (10, 0) | (12, 4) | (−10, 0) | (0, 30) | (−11, 3) | (0, −30) |
| $d_i$ | 6 | 6 | 4 | 9 | 3 | 9 |
| $p_i$ | 30 | 30 | 25 | 10 | 8 | 10 |

**Ótimo (força bruta e MIP): 23.1377.** Com o objetivo $\min \sum c x - \sum p y$, o VRPSolver imprime **−23.1377**. Cutoff: `ub = -23.13`.

| Rota | Custo | Lucro | Saldo |
|---|---|---|---|
| $0\!-\!1\!-\!0$ | 20.00 | 30 | 10.00 |
| $0\!-\!2\!-\!0$ | 25.30 | 30 | 4.70 |
| $0\!-\!3\!-\!5\!-\!0$ | 24.56 | 33 | 8.44 |

Os clientes 4 e 6, os mais distantes, ficam de fora. Os clientes 1 e 2 não cabem juntos ($6 + 6 > 10$), então **as arestas $(0,1)$ e $(0,2)$ ficam com $x = 2$**.

Armadilhas que a toy pega:

| Modelo errado | Valor (lucro − custo) |
|---|---|
| Grau `== 2` (visita obrigatória, como no CVRP) | **−76.86** |
| Sem capacidade | **42.34**: uma única rota 0-1-2-3-5-0 |
| Um veículo só ($U = 1$, o PTP clássico) | **15.00**: 0-1-3-0 |
| $L = \lceil \sum d / Q \rceil = 4$ | **4.90**: força a quarta rota, separando 3 e 5 |

## Atenção para a modelagem

1. **Objetivo:** $\min \sum_{e} c_e x_e - \sum_i p_i y_i$. Isso corrige o sinal trocado do modelo do aluno na Lista. O VRPSolver imprime o negativo do saldo.
2. **Acoplamento:** grau $\sum_{e\in\delta(i)} x_e = 2y_i$, com `y` binária, igual ao TOP.
3. **Grafo:** volta a ser o do CVRP, com source = sink = 0 e `VrpGraph(model, V, 0, 0, (0, U))`. Os arcos são os dois sentidos de cada aresta, inclusive as do depósito.
4. **$L = 0$:** não sair nenhum veículo é uma solução válida, com saldo 0.
5. **Recurso:** volta a ser a capacidade, com limites $[0, Q]$ e consumo $d_j$. Não há tempo.
6. **$U$:** `inst.m` no benchmark; na versão da Lista, $U = n$. Na toy, os dois coincidem.

## Modelo implementado (2026-10-16)

Arquivo do usuário: `PTP/ptp_model.jl`, na pasta do WSL.
- **Problema original:** `x[e in E]` inteiro e `y[i in V⁺]` binário; objetivo $\min \sum c_e x_e - \sum p_i y_i$; grau $= 2y_i$; $L = 0$, $U = m$.
- **Grafo:** o do CVRP, com source = sink = 0 e os dois sentidos de cada aresta.
- **Recurso:** capacidade (`main`), com limites $[0, Q]$ e consumo $d_j$.
- **Packing sets** e **branching:** iguais aos do TOP.

**Toy:** **saldo 23.1377**, igual à força bruta. Resolveu na raiz em 0.65 s. As arestas foram `x[(0,1)] = 2`, `x[(0,2)] = 2`, $(0,3)$, $(3,5)$ e $(0,5)$, ou seja, exatamente as rotas 0-1-0, 0-2-0 e 0-3-5-0. O modelo não caiu em nenhuma armadilha: os clientes 4 e 6 ficaram de fora, a capacidade separou 1 e 2, e $L = 0$ não forçou uma rota extra.

## Referências para validar no benchmark

- **Lucros enormes:** se `p(i) = 1000`, visitar todos compensa e o problema vira o CVRP. No **p06**, que é o CMT1, o esperado é $50\,000 - 524.61 = $ **49 475.39**, impresso como −49475.39. Cutoff: `-49475.38`.
- **Lucro zero:** se `p(i) = 0`, o ótimo é **0**, sem nenhuma rota. Isso testa $L = 0$.
- **Lucros reais do p06** ($m = 10$, $Q = 160$): **saldo ótimo 259.2402**, encontrado e provado pelo VRPSolver.
  - A "referência" de **173.36 estava errada**. O CBC parou no limite de 3000 s com uma solução só viável, e o PuLP reportou `Optimal` mesmo assim, porque `pr.status` não distingue esse caso. O que diz se o ótimo foi provado é `pr.sol_status == 1`. O script já foi corrigido.
  - Execução do VRPSolver: cutoff −173.36 (folgado demais, mas sem efeito no resultado). Cota da raiz −264.15, 3 nós, 6.65 s.
  - Rotas conferidas em Python: 5 rotas, 42 dos 50 clientes, todas as cargas ≤ 160.

| Rota | Carga | Custo | Lucro |
|---|---|---|---|
| 0-1-8-31-28-3-35-20-2-32-0 | 158 | 101.15 | 153 |
| 0-5-49-10-39-33-45-15-44-37-12-0 | 155 | 99.12 | 153 |
| 0-6-14-25-24-43-7-23-48-27-0 | 152 | 98.45 | 144 |
| 0-11-16-50-34-30-9-38-46-0 | 120 | 72.41 | 121 |
| 0-18-13-41-19-4-47-0 | 134 | 75.63 | 135 |

  Para rodar de novo, use `ub = -259.23`.

## Fontes

- Archetti, C., Feillet, D., Hertz, A., Speranza, M. G. (2009). The capacitated team orienteering and profitable tour problems. *JORS* 60(6), 831–842.
- Archetti, C., Bianchessi, N., Speranza, M. G. (2013). Optimal solutions for routing problems with profits. *Discrete Applied Mathematics* 161(4–5), 547–557.
- Feillet, D., Dejax, P., Gendreau, M. (2005). Traveling salesman problems with profits. *Transportation Science* 39(2), 188–205.

## Notas relacionadas

- Lista 1 - Resolução · TSP with Profits · Prize-Collecting VRP
- [TOP no VRPSolver - Instâncias, toy e parser](../TOP/README.md) · [DCVRP no VRPSolver - Instâncias, toy e parser](../DCVRP/README.md) · VRPSolver
