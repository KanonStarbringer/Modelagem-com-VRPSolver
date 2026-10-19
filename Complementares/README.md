# Complementares no VRPSolver — CVRP, OVRP e custo fixo

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta.
>
> A segunda leva de complementares (VRPTW, MDVRP e HFVRP, nas subpastas `VRPTW/`, `MDVRP/` e `HFVRP/`) está em [README-complementares-2.md](README-complementares-2.md).
>
> A terceira leva (VRPB, SDVRP, FSMVRP, PDPTW, E-VRP e Rich VRP, nas subpastas `VRPB/`, `SDVRP/`, `FSMVRP/`, `PDPTW/`, `EVRP/` e `RichVRP/`) está em [README-complementares-3.md](README-complementares-3.md).
>
> A quarta leva (TSPHS, OPHS, VRP-D e BPP, da Aula 5, nas subpastas `TSPHS/`, `OPHS/`, `VRPD/` e `BPP/`) está em [README-complementares-4.md](README-complementares-4.md).
>
> A quinta leva (Cutting Stock e Vector Packing 2D, extensões do BPP, nas subpastas `CSP/` e `VPP/`) está em [README-complementares-5.md](README-complementares-5.md).

## Índice dos modelos

| Leva | Problema | Pasta |
|---|---|---|
| 1 | CVRP simétrico | [`CVRP/`](CVRP/README.md) |
| 1 | Open VRP | [`OVRP/`](OVRP/README.md) |
| 1 | VRP com custo fixo | [`FCVRP/`](FCVRP/README.md) |
| 2 | VRP com janelas de tempo | [`VRPTW/`](VRPTW/README.md) |
| 2 | Multi-Depot VRP | [`MDVRP/`](MDVRP/README.md) |
| 2 | Heterogeneous Fleet VRP | [`HFVRP/`](HFVRP/README.md) |
| 3 | VRP with Backhauls (F1 e F2) | [`VRPB/`](VRPB/README.md) |
| 3 | Site-Dependent VRP | [`SDVRP/`](SDVRP/README.md) |
| 3 | Fleet Size and Mix VRP | [`FSMVRP/`](FSMVRP/README.md) |
| 3 | Pickup and Delivery com janelas | [`PDPTW/`](PDPTW/README.md) |
| 3 | Electric VRP (recarga completa) | [`EVRP/`](EVRP/README.md) |
| 3 | Rich VRP | [`RichVRP/`](RichVRP/README.md) |
| 4 | TSP with Hotel Selection | [`TSPHS/`](TSPHS/README.md) |
| 4 | Orienteering Problem with Hotel Selection | [`OPHS/`](OPHS/README.md) |
| 4 | VRP com drone (1 caminhão + 1 drone) | [`VRPD/`](VRPD/README.md) |
| 4 | Bin Packing | [`BPP/`](BPP/README.md) |
| 5 | Cutting Stock (arc-flow) | [`CSP/`](CSP/README.md) |
| 5 | Vector Packing 2D | [`VPP/`](VPP/README.md) |

Data: 2026-10-16
Contexto: Exercícios complementares da Lista 1: **CVRP simétrico**, **Open VRP (OVRP)** e **VRP com custo fixo**. Os três usam o mesmo grafo do CVRP, então compartilham parser, toy e instâncias. Segue o roteiro de [mCTP no VRPSolver - Instâncias, toy e parser](../mCTP/README.md).

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/*.vrp` | 85 instâncias da CVRPLIB, conjuntos A, B, E e P (sem E-n13-k4 e E-n31-k7, que usam matriz explícita) |
| `cvrp_parser.jl` | `read_cvrp(path; arred)` e auto-teste |
| `toy_comp.vrp` | Toy dos três exercícios |
| `otimos.csv` | Ótimos de 20 instâncias: OVRP e CVRP com custo real, e CVRP com custo arredondado |

Os modelos ficam em `CVRP/scvrp_model.jl`, `OVRP/ovrp_model.jl` e `FCVRP/fcvrp_model.jl`, e incluem o parser da pasta de cima (`include(joinpath(@__DIR__, "..", "cvrp_parser.jl"))`). O parser, por sua vez, inclui `../DCVRP/dcvrp_parser.jl`.

## Parser

```julia
include("cvrp_parser.jl")                       # inclui ../DCVRP/dcvrp_parser.jl
inst = read_cvrp(joinpath(@__DIR__, "toy_comp.vrp"))                       # custo arredondado
inst = read_cvrp(joinpath(@__DIR__, "Instancias", "A-n32-k5.vrp"); arred = false)   # custo real
inst.n, inst.Q, inst.d[i+1], inst.C[i+1, j+1]
inst.K      # nº de veículos do nome (-kK)
inst.opt    # "Optimal value" do COMMENT (CVRP fechado, arredondado)
inst.f      # custo fixo (FIXED_COST; 0 se ausente)
```

**Arredondamento — atenção:**
- Os ótimos da **CVRPLIB** usam custo EUC_2D **arredondado** (`arred = true`, o padrão): A-n32-k5 = **784**.
- Os ótimos do **OVRP** de Letchford et al. (2007) usam custo **real** (`arred = false`): A-n32-k5 aberto = **487.306**, e fechado = 787.082.

Auto-teste: `julia cvrp_parser.jl` → `OK: toy + 85 instâncias da CVRPLIB (A, B, E, P) lidas`.

## Instância toy — `toy_comp.vrp`

Depósito em (0, 0); $Q = 11$; custo fixo $f = 20$; custos arredondados.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (10, 0) | (20, 0) | (30, 0) | (0, 12) | (−3, 22) | (−14, 6) |
| $d_i$ | 3 | 3 | 3 | 4 | 4 | 4 |

$L = \lceil 21 / 11 \rceil = 2$ e $U = n$, frota livre, como no enunciado.

| Exercício | Ótimo (força bruta) | Rotas | Cutoff |
|---|---|---|---|
| **CVRP simétrico** | **134** | 0-1-2-3-0 (60), 0-4-5-0 (44), 0-6-0 (30) | `134.01` |
| **OVRP** | **67** | 0-1-2-3 (30), 0-4-5 (22), 0-6 (15), sem volta | `67.01` |
| **VRP com custo fixo** ($f = 20$) | **184** = 144 + 2·20 | 0-1-5-6-0 e 0-2-3-4-0 | `184.01` |

Com $f = 20$, compensa usar 2 rotas em vez de 3: a solução do CVRP custaria 134 + 3·20 = 194. As rotas mudam (70 + 74 = 144 de roteamento).

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| OVRP zerando o custo das arestas do depósito (vale nas duas direções) | **0**: cada cliente numa rota sozinho |
| OVRP fechado (o retorno mapeado em `x[(0,i)]`) | **134**, que é o CVRP |
| OVRP com exatamente $K = 2$ veículos | **96**, porque o limite de frota muda o ótimo |
| Custo fixo com `z` mapeado nos dois sentidos das arestas do depósito | **224** = 144 + 2·(2·20) |
| Custo fixo ignorado | 134 (as rotas do CVRP) |

## Atenção para a modelagem

**CVRP simétrico.** É o modelo do professor (`Modelos/model.jl`). O exercício só fixa a nomenclatura: o grau é `== 2`, e não "grau de entrada".

**OVRP.** Use o modelo corrigido da Lista:
- variáveis `y[i in V⁺]`, binárias, que indicam "a rota termina em $i$";
- grau `sum(x[e] for e in δ[i]) + y[i] == 2`;
- arcos: $(i,j)$ e $(j,i)$ entre clientes mapeados para `x[(i,j)]`; $(0,i)$ mapeado **só** para `x[(0,i)]`; o retorno $(i,0)$ mapeado para **`y[i]`**, que não entra no objetivo, então a volta custa 0;
- recurso, packing sets e branching iguais aos do CVRP. Incluir `y` na prioridade de branching é opcional.

Para o benchmark de Letchford et al., use **exatamente $K$ veículos** ($L = U = K$, com `inst.K`) e `arred = false`. A toy usa frota livre.

**VRP com custo fixo.**
- variável `z` inteira, com objetivo `Σ c·x + f·z`;
- cada arco de **saída** $(0,i)$ é mapeado para `x[(0,i)]` **e** para `z`. O VRPSolver aceita mais de uma variável por arco: `add_arc_var_mapping!(G, a, [x[(0,i)], z])`;
- o retorno $(i,0)$ é mapeado **só** para `x[(0,i)]`.

## Referências para o benchmark (`otimos.csv`)

| Instância | $K$ | OVRP (real) | CVRP (real) | CVRP (CVRPLIB, arredondado) |
|---|---|---|---|---|
| P-n16-k8 | 8 | 235.06 | 451.335 | 450 |
| E-n22-k4 | 4 | 252.614 | 375.28 | 375 |
| A-n32-k5 | 5 | 487.306 | 787.082 | 784 |
| E-n51-k5 (= CMT1) | 5 | 416.063 | 524.611 | 521 |

Outras 16 instâncias estão no CSV. Os valores de OVRP e CVRP com custo real vêm das Tabelas 1 a 4 de Letchford et al. (2007), com exatamente $K$ veículos. Os arredondados vêm do COMMENT da CVRPLIB.

**Custo fixo**: não há benchmark padrão para frota homogênea. Duas verificações exatas:
- com $f = 0$, o ótimo é o do CVRP (A-n32-k5: 784);
- com $f$ grande, a frota cai para o mínimo. No A-n32-k5, o ótimo do CVRP já usa o mínimo de 5 veículos, então o resultado deve ser $784 + 5f$.

## Resultados

| Exercício | Instância | Obtido | Esperado | Tempo |
|---|---|---|---|---|
| CVRP simétrico | toy | **134** — 0-1-2-3-0, 0-4-5-0, 0-6-0 (`x[(0,6)] = 2`) | 134 | 0.70 s |
| CVRP simétrico | A-n32-k5 (arredondado) | **784** — raiz, 1 nó; mesmas arestas do custo fixo com $f = 0$ | 784 | 0.88 s |
| OVRP | toy (frota livre) | **67** — 0-1-2-3, 0-4-5, 0-6 | 67 | 0.80 s |
| OVRP | A-n32-k5 ($L = U = 5$, custo real) | **487.3058** — raiz, 1 nó | 487.306 | 0.75 s |
| Custo fixo | toy ($f = 20$) | **184**, $z = 2$ — 0-1-5-6-0, 0-2-3-4-0 | 184 | 0.75 s |
| Custo fixo | A-n32-k5 ($f = 0$, arredondado) | **784**, $z = 5$ — raiz, 1 nó | 784 | 0.87 s |
| Custo fixo | A-n32-k5 ($f = 1000$, arredondado) | **5784**, $z = 5$ — mesmas rotas | 784 + 5·1000 | 0.88 s |

A-n32-k5, conferido em Python: 0-6-3-2-23-28-4-11 (129.04; carga 95), 0-20-5-25-10-29-15-22-9-18-8 (191.17; 98), 0-26-7-13-21-31-19-17 (86.01; 98), 0-27-24-14 (37.02; 47), 0-30-16-12-1 (44.06; 72). São 31 clientes, todos com carga ≤ 100.

## Fontes

- Letchford, A. N., Lysgaard, J., Eglese, R. W. (2007). A branch-and-cut algorithm for the capacitated open vehicle routing problem. *JORS* 58(12), 1642–1651. <https://www.lancaster.ac.uk/staff/letchfoa/articles/2007-covrp.pdf>
- CVRPLIB: <https://galgos.inf.puc-rio.br/cvrplib/>

## Notas relacionadas

- Exercícios complementares · Lista 1 - Resolução · Open VRP · VRP com Custo Fixo · Capacitated VRP
- [DCVRP no VRPSolver - Instâncias, toy e parser](../DCVRP/README.md) · VRPSolver
