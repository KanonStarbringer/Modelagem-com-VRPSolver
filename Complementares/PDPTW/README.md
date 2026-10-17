# PDPTW — Pickup and Delivery Problem with Time Windows

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-3.md`](../README-complementares-3.md).

Cada requisição tem um ponto de coleta e um de entrega, atendidos pelo **mesmo veículo**, com a coleta **antes** da entrega e janelas de tempo em todos os vértices. A carga fica em $[0, Q]$ ao longo da rota.

## Como rodar

```bash
julia pdptw_parser.jl      # auto-teste do parser
julia pdptw_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/*.txt` e `*.sol` | 56 instâncias de Li & Lim (2001) com 100 vértices (≈ 50 requisições) e as soluções do SINTEF, via zhu-he/pdptw-data |
| `pdptw_parser.jl` | `read_pdptw(path; r)` e auto-teste |
| `toy_pdptw.txt` | Toy no formato de Li & Lim |

Esta pasta tem também o modelo e o `CVRP.cfg`.

## Parser

```julia
include("pdptw_parser.jl")
inst = read_pdptw(joinpath(@__DIR__, "toy_pdptw.txt"))
inst = read_pdptw(joinpath(@__DIR__, "Instancias", "lc101.txt"); r = 10)   # só as 10 primeiras requisições
inst.r, inst.K, inst.Q          # nº de requisições, frota, capacidade
inst.q[v+1]                     # demanda ASSINADA: +q_h na coleta h, -q_h na entrega h + r (= d̄ do enunciado)
inst.l[v+1], inst.u[v+1], inst.s[v+1]
inst.C[v+1, w+1]                # custo (distância real)
inst.T[v+1, w+1]                # tempo do arco v→w = s_v + c_vw (assimétrico)
```

**Renumeração:** igual à do enunciado. O depósito é o 0, as coletas são $P = \{1..r\}$, e a entrega da coleta $h$ é $h + r$.

**Convenção:** distância euclidiana **real**, com tempo = serviço + distância. Conferi em Python as 56 `.sol`: todas são viáveis (janelas, capacidade, precedência e mesmo veículo).

**Atenção:** as `.sol` do SINTEF são **hierárquicas**: minimizam primeiro o número de veículos e depois a distância. Para o nosso objetivo, só a distância, elas são **limites superiores**.

Auto-teste: `julia pdptw_parser.jl` → `OK: toy + 56 instâncias de Li & Lim lidas`.

## Instância toy — `toy_pdptw.txt`

São 3 requisições, com $Q = 10$, serviço $s = 5$ e frota $K = 3$. O depósito tem janela [0, 300].

| Requisição $h$ | Coleta $h$ (x, y) [l, u] | Entrega $h + 3$ (x, y) [l, u] | $q_h$ |
|---|---|---|---|
| 1 | (−17, −1) [25, 65] | (−18, −7) [19, 44] | 4 |
| 2 | (−5, 11) [2, 17] | (7, 10) [34, 74] | 5 |
| 3 | (−11, 12) [38, 53] | (−12, 13) [45, 85] | 6 |

**Ótimo (força bruta, conferido também no CBC): 114.1414**, com cutoff `114.15`. São três rotas, uma por requisição:

| Rota | Custo | Início do serviço |
|---|---|---|
| 0-1-4-0 | 42.4254 | 1: 25 (espera) · 4: 36.1 |
| 0-2-5-0 | 36.3312 | 2: 12.1 · 5: 34 (espera) |
| 0-3-6-0 | 35.3848 | 3: 38 (espera) · 6: 45 (espera) |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem limite inferior 0 nos recursos de requisição (entrega antes da coleta) | **95.151**: 0-**4-1**-3-6-0 entrega a requisição 1 antes de coletá-la |
| Tempo sem o serviço ($t_{ij} = c_{ij}$) | **98.7978**: 0-1-4-3-6-0 fica viável (com serviço, chega em 3 no instante 61.3 > 53) |
| Sem $[0, 0]$ no depósito para os recursos de requisição | **71.7921**: as entregas são omitidas (0-1-3-0 e 0-2-0) |

## Atenção para a modelagem

É o modelo da Seção 4.6 de Pessoa et al. (2020), com **um único grafo**:
- **Variáveis e mestre:** $x_a$ por **arco**, porque a precedência quebra a simetria. O mestre tem a cobertura **só das coletas**, $\sum_{a \in \delta^-(h)} x_a = 1$ para $h \in P$.
- **Recurso de tempo:** é o principal (`main = true`), com limites $[l_v, u_v]$ e consumo `T[v+1, w+1]`.
- **Recurso de carga:** consumo $\bar d_w$ = `q[w+1]`, com limites $[0, Q]$ nos clientes. Tem consumo negativo, então é secundário, e o modelo o declara **não descartável**.
  - **No depósito, use $[0, 0]$.** O BaPCod recusa um intervalo não pontual no source de um recurso não descartável, com o erro `the res.cons. bounds are not the same in the source for a non-disposable resource` (ocorreu na toy, com $[0, Q]$).
- **Recursos de requisição:** um por requisição $h$, **binários e não descartáveis**, com `add_resource!(G, binary = true, disposable = false)`.
  - Consumo $+1$ ao entrar na coleta $h$, $-1$ ao entrar na entrega $h + r$, e 0 nos demais arcos.
  - Limites $[0, 1]$ nos clientes e **$[0, 0]$ no depósito**.
  - O código-fonte do VrpSolver.jl (`add_resource!`, conferido no WSL) mostra que um recurso binário já nasce com $[0, 1]$ em todos os vértices. Basta fixar `set_resource_bounds!(G, 0, rh, 0.0, 0.0)`. Recursos binários não podem ser `main` nem descartáveis. Como no depósito source = sink, o VRPSolver **recusa** $[0, 1]$ ali para um binário não descartável e só aceita $[0,0]$ ou $[1,1]$. Isso impede, por construção, o erro do "sem $[0,0]$".
- **Packing sets:** **só as coletas**, um singleton por coleta. A matriz de distâncias fica $r \times r$, entre as coletas.
- **Frota:** $L = 0$ e $U = K$ (o artigo usa $U = \infty$; com $K$ do arquivo, as `.sol` continuam viáveis).
- **Opcional:** cortar arcos que nunca podem ser usados: $0 \to$ entrega, coleta $\to 0$, entrega $h + r \to$ coleta $h$, e arcos com $l_v + t_{vw} > u_w$.
- **Tamanho do grafo:** cada requisição é um recurso. Com $r = 50$, são 52 recursos, o que deixa o pricing pesado. Por isso a sequência sugerida usa instâncias reduzidas.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **114.1414** — 0-1-4-0, 0-2-5-0, 0-3-6-0; raiz, 1 nó | 114.1414 | 0.63 s |
| lc101, $r = 10$ | **155.5028** — 2 rotas; raiz, 1 nó | 155.5028 (CBC) | 0.65 s |

lc101 com $r = 10$, conferido em Julia: 0-2-1-12-4-14-6-5-3-15-13-16-11-0 (59.62) e 0-7-17-9-10-20-8-18-19-0 (95.88). São 20 vértices, com janelas, carga, precedência e mesmo veículo ok.

| lc101, $r = 20$ | **301.8858** — 4 rotas; raiz, 1 nó (conferido: 40 vértices, todas as restrições ok) | 301.8858 (CBC) | 0.68 s |
|---|---|---|---|

As duas primeiras rotas da lc101 com $r = 20$ têm a mesma sequência física e o mesmo custo (59.62 e 95.88) das rotas com $r = 10$. Só a numeração das entregas muda: a entrega de $h$ passa de $h + 10$ para $h + 20$. As requisições 11–20 formam outras duas rotas (50.80 e 95.58).

## Referências para o benchmark

| Instância | $r$ | Ótimo (min distância) | Rotas | Fonte |
|---|---|---|---|---|
| lc101 | 10 | **155.5028** | 2 | CBC, ótimo provado |
| lr101 | 10 | **553.0489** | 8 | CBC, ótimo provado |
| lrc101 | 10 | **425.6099** | 4 | CBC, ótimo provado |
| lc101 | 20 | **301.8858** | 4 | CBC, ótimo provado |
| lr101 | 20 | **930.399** | 12 | CBC, ótimo provado |
| lc101 | 53 (completa) | ≤ **828.94** | 10 | `.sol` do SINTEF (hierárquica) |
| lr101 | 53 | ≤ **1650.80** | 19 | `.sol` (hierárquica) |

A formulação do CBC é compacta, com arcos, MTZ para tempo e carga, e índice de rota para o mesmo veículo. Ela reproduziu o ótimo da toy (114.1414).

## Fontes

- Li, H., Lim, A. (2001). A metaheuristic for the pickup and delivery problem with time windows. *Proceedings of the 13th IEEE ICTAI*, 160–167.
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523 (Seção 4.6).
- Instâncias PDPTW: <https://github.com/zhu-he/pdptw-data> (cópia dos dados do SINTEF, pasta `100`).
