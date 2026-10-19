# VPP — Vector Packing 2D

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-5.md`](../README-complementares-5.md).

## Definição

Cada item $i$ tem peso $w^1_i$ e volume $w^2_i$; o bin tem capacidades $Q_1$ e $Q_2$. Um bin é viável se respeita **as duas** capacidades. Objetivo: empacotar todos os itens no menor número de bins. Nas instâncias de Caprara & Toth, a demanda de cada item é 1.


## Como rodar

```bash
julia vpp_parser.jl      # auto-teste do parser
julia vpp_model.jl
```

No topo do `vpp_model.jl`, escolha a instância e o cutoff `ub` (nº de bins ótimo + 0.01).

## Modelo no VRPSolver

É o modelo do BPP com **um recurso a mais**:

- **grafo:** $v_0 \to v_1 \to \dots \to v_n$, source $v_0$, sink $v_n$, $L = 0$, $U = n$; dois arcos paralelos por item, $a_i^+$ (dentro) e $a_i^-$ (fora);
- **recursos:** peso, com limites $[0, Q_1]$ e consumo $w^1_i$ em $a_i^+$; volume, com limites $[0, Q_2]$ e consumo $w^2_i$ em $a_i^+$. Os dois podem ser principais (`main = true`); com só um principal, o outro entra como secundário. Os dois jeitos são válidos;
- **mestre:** $\min x_0$, $x_i = 1$, com $x_0$ mapeado em $a_1^+$ e $a_1^-$ e $x_i$ em $a_i^+$, como no BPP;
- **packing sets em arcos:** $\{\{a_i^+\}\}$; **branching:** Ryan-Foster.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/CL_X_N_Z.TXT` | 400 instâncias da biblioteca DEIS/Bologna: classes 1 a 3 de Spieksma (1994) e 4 a 10 de Caprara & Toth (2001); $N$ = 25, 50, 100, 200 (classe 10: 24, 51, 99, 201); 10 por (classe, $N$) |
| `referencias_cplex.csv` | ótimos calculados com um MIP de atribuição no CPLEX, para $N \le 51$ |
| `vpp_parser.jl` | `read_vpp(path)` e auto-teste |
| `toy_vpp.txt` | toy, no mesmo formato |

## Parser

```julia
include("vpp_parser.jl")
inst = read_vpp(joinpath(@__DIR__, "toy_vpp.txt"))
inst = read_vpp(joinpath(@__DIR__, "Instancias", "CL_01_25_01.TXT"))
inst.n, inst.Q[1], inst.Q[2], inst.w[1][i], inst.w[2][i]
```

Auto-teste: `julia vpp_parser.jl` → `OK: toy + 400 instâncias 2-VPP lidas`.

## Instância toy — `toy_vpp.txt`

$Q = (10, 10)$.

| Item | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| $(w^1, w^2)$ | (6, 8) | (2, 8) | (3, 8) | (6, 5) | (3, 5) | (4, 4) | (8, 3) | (2, 2) |

**Ótimo (DP exata sobre subconjuntos): 6 bins**, com cutoff `6.01`. Uma solução: {1}, {2}, {3}, {4}, {5, 6}, {7, 8}. A relaxação vale **5.5** e $\max(\lceil 34/10 \rceil, \lceil 43/10 \rceil) = 5$: o ótimo é maior que o limite trivial.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Só o peso (sem o recurso de volume) | **4** |
| Só o volume | **5** |
| Um recurso só com a soma, $w^1 + w^2 \le Q_1 + Q_2$ | **5** |
| $x$ contínuas | **5.5**: a relaxação |

## Referências para o benchmark (`referencias_cplex.csv`)

MIP de atribuição no CPLEX ($x_{ib}$ binárias, bins ordenados, item $i$ só nos bins $1..i$ na ordem FFD), 60 s por instância, para as 200 instâncias com $N \le 51$. **183 têm ótimo provado**. As 17 restantes ficaram com limite inferior e melhor solução: CL_06_50_06 e 07, CL_08_25_01, 05, 08 e 10, CL_08_50_04 e 06 e CL_09_50_01 a 09. As colunas `lb_trivial` ($\max \lceil \sum w^k / Q_k \rceil$), `ffd`, `melhor`, `limite_inferior` e `provado` estão no CSV.

| Instância | Classe | $N$ | $Q$ | $\lceil \sum w / Q \rceil$ | FFD | Ótimo | cutoff |
|---|---|---|---|---|---|---|---|
| CL_01_25_01 | 1 | 25 | (1000, 1000) | 6 | 7 | 6 | `6.01` |
| CL_02_25_01 | 2 | 25 | (1000, 1000) | 11 | 13 | **13** | `13.01` |
| CL_06_25_01 | 6 | 25 | (150, 150) | 9 | 11 | **10** | `10.01` |
| CL_09_25_01 | 9 | 25 | (940, 943) | 6 | 7 | **7** | `7.01` |
| CL_10_24_01 | 10 | 24 | (100, 100) | 8 | 10 | 8 | `8.01` |
| CL_01_50_01 | 1 | 50 | (1000, 1000) | 13 | 14 | 13 | `13.01` |
| CL_10_51_01 | 10 | 51 | (100, 100) | 17 | 20 | 17 | `17.01` |

Em negrito, os casos em que o ótimo fica **acima** do limite trivial: o modelo precisa provar o valor por branching, e não só pela relaxação. Entre as provadas, são 69 casos: 20 na classe 2, 20 na 3, 14 na 8, 11 na 9, 2 na 6 e 2 na 7. Heßler et al. (2018) apontam as classes 4, 5 e 9 como as mais difíceis para branch-and-price, e as classes 2, 3 e 8 como as mais fáceis.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **6** — raiz 6.00 (LP 5.5 arredondado para cima), 1 nó; {3, 8}, {5, 6}, {2}, {1}, {7}, {4}; dois recursos principais aceitos | 6 | 0.82 s |
| CL_06_25_01 | **10** — raiz 10.00, 1 nó (cutoff folgado, `13.01`); ótimo acima do limite trivial (9), provado só pela relaxação | 10 | 0.84 s |
| CL_09_25_01 | **7** — raiz 7.00, mas **5 nós** (Ryan-Foster); o limite já valia 7 na raiz, e o branching serviu para **achar** uma solução inteira de 7 | 7 | 2.47 s |

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
