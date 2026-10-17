# FSMVRP — Fleet Size and Mix Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-3.md`](../README-complementares-3.md).

Frota heterogênea **não fixada**: o modelo escolhe quantos veículos de cada tipo usar. O tipo $k$ tem capacidade $Q^k$, custo fixo $f^k$ por veículo e custo variável $\alpha_k$ por distância (variante FSMFD de Golden et al.).

## Como rodar

```bash
julia fsmvrp_parser.jl      # auto-teste do parser
julia fsmvrp_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/c*_*{fsmfd,fsmf,fsmd}.txt` | As instâncias 13–20 de Golden et al. (1984) nas três variantes FSM (24 arquivos), dos demos do VRPSolverEasy |
| `fsmvrp_parser.jl` | Inclui o `read_hfvrp` de `../HFVRP` e tem o auto-teste |
| `toy_fsmvrp.txt` | Toy no mesmo formato |

Esta pasta tem também o modelo e o `CVRP.cfg`.

**Variantes:**
- **`fsmfd`:** custo fixo $f^k$ mais custo variável $\alpha_k \ell$. **É o exercício.**
- **`fsmf`:** só custo fixo, com $\alpha = 1$. É o FSM clássico de Golden.
- **`fsmd`:** só custo variável, com $f = 0$.

Nas três, `max = n`, ou seja, frota livre (o enunciado fala em "no máximo $n$ de cada tipo").

## Parser

```julia
include("fsmvrp_parser.jl")            # = read_hfvrp do HFVRP
inst = read_hfvrp(joinpath(@__DIR__, "toy_fsmvrp.txt"))
inst = read_hfvrp(joinpath(@__DIR__, "Instancias", "c50_14fsmfd.txt"))
inst.K, inst.Q[k], inst.f[k], inst.α[k], inst.u[k]   # u[k] = n
```

Auto-teste: `julia fsmvrp_parser.jl` → `OK: toy + 24 instâncias FSM (fsmfd, fsmf, fsmd) lidas`.

## Instância toy — `toy_fsmvrp.txt`

As posições e demandas são as de sempre. Há dois tipos, com frota livre ($u^k = 6$):

| Tipo | $Q^k$ | $f^k$ | $\alpha_k$ |
|---|---|---|---|
| 1 | 7 | 10 | 1.0 |
| 2 | 11 | 35 | 1.1 |

**Ótimo (força bruta): 209.2567**, com cutoff `209.26`. A frota ótima tem 2 veículos do tipo 1 e 1 do tipo 2:

| Tipo | Rota | Distância | Custo ($\alpha \ell + f$) |
|---|---|---|---|
| 2 | 0-1-5-4-0 | 57.9942 | 63.7936 + 35 |
| 1 | 0-2-3-0 | 60 | 60 + 10 |
| 1 | 0-6-0 | 30.4631 | 30.4631 + 10 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem o custo fixo (é o `fsmd`) | **145.5714**: frota de 2× tipo 2 e 1× tipo 1, com outras rotas |
| Custo fixo nas duas pontas da rota (`z` mapeado em $(0,i)$ e em $(i,0)$, ou seja, $2f$ por rota) | **252.2206**: 4 veículos do tipo 1 |
| Sem $\alpha$ (custo variável igual para todos os tipos) | **203.4573**: mesma frota, valor diferente |

## Atenção para a modelagem

É o **HFVRP com o custo fixo do complementar "VRP com custo fixo"**:
- **Grafos e variáveis:** um grafo por tipo, `x[k, e]`, custo `α[k] * ℓ(i, j)`, capacidade `Q[k]` e limites `(0, u[k])`, com `u[k] = n`.
- **Custo fixo:** uma variável `z[k]` por tipo, com `+ f[k] * z[k]` no objetivo. Ela é mapeada **só no arco de saída** $(0, j)$ do grafo $k$: `add_arc_var_mapping!(G[k], a, [x[k, (0, j)], z[k]])`. O arco de volta $(j, 0)$ fica mapeado só para `x[k, (0, j)]`.
- **Alternativa equivalente, sem `z`:** somar **$f^k / 2$** ao custo de cada aresta do depósito $(0, j)$ no tipo $k$. Toda rota usa exatamente duas "pontas" no depósito: duas arestas distintas, ou a mesma aresta com $x = 2$. Somar $f^k$ inteiro cobraria $2f$ por rota, que é a armadilha de 252.2206. Com `z`, a contagem fica explícita, e `z[k]` mostra direto quantos veículos de cada tipo foram usados.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **209.2567** — frota $z = [2, 1]$; tipo 1: 0-2-3-0, 0-6-0; tipo 2: 0-1-5-4-0; raiz, 1 nó | 209.2567 | 0.66 s |
| c50_14fsmfd | **9126.8973** — frota $z = [7, 1, 0]$; raiz 8770.93 (gap 3.9%), **13 nós** | 9126.90 | 242.87 s |

c50_14fsmfd conferido em Julia:
- **Tipo 1** ($f = 1000$, $\alpha = 1.0$, $Q = 120$): 7 rotas, com cargas de 110 a 120.
- **Tipo 2** ($f = 1500$, $\alpha = 1.1$): 1 rota, com carga 156 / 160.
- **Tipo 3:** não é usado.

São 50 clientes, e o custo $\sum (\alpha \ell + f)$ = 9126.8973. A referência **9126.90 fica confirmada**, com ótimo provado. O custo fixo domina: 8500 dos 9126.90 são custos fixos.

## Referências para o benchmark

| Instância | Tipos | Valor de referência (FSMFD) |
|---|---|---|
| c50_13fsmfd | 6 | **2964.65** |
| c50_14fsmfd | 3 | **9126.90** |
| c50_15fsmfd | 3 | **2634.96** |
| c50_16fsmfd | 3 | **3168.92** |
| c75_17fsmfd | 4 | **2004.48** |
| c75_18fsmfd | 6 | **3147.99** |
| c100_19fsmfd | 3 | **8661.81** |
| c100_20fsmfd | 3 | **4153.02** |

**Atenção:** esses valores vêm da **minha memória** da literatura (BKS/ótimos de Choi & Tcha 2007 e de Baldacci & Mingozzi 2009) e **não foram confirmados** numa fonte nesta sessão. A **c50_14fsmfd foi confirmada** pelo VRPSolver (9126.8973, ótimo provado); as demais seguem a confirmar.

## Fontes

- Chao, I-M., Golden, B., Wasil, E. (1999). A computational study of a new heuristic for the site-dependent vehicle routing problem. *INFOR* 37(3), 319–336.
- Choi, E., Tcha, D.-W. (2007). A column generation approach to the heterogeneous fleet vehicle routing problem. *Computers & Operations Research* 34(7), 2080–2095.
- Instâncias FSMVRP: <https://github.com/inria-UFF/VRPSolverEasy> (`VRPSolverEasy/demos/data/HFVRP`, sufixos `fsmfd`, `fsmf`, `fsmd`).
