# GAP — Generalized Assignment Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-6.md`](../README-complementares-6.md).

## Definição

Há $m$ agentes e $n$ tarefas. Atribuir a tarefa $j$ ao agente $i$ custa $c_{ij}$ e consome $r_{ij}$ da capacidade $b_i$ do agente. Cada tarefa vai para exatamente um agente, e a soma dos consumos de cada agente respeita a sua capacidade. Objetivo: minimizar o custo total (Ross & Soland, 1975).

Formulação compacta (de atribuição):

$$\min \sum_{i,j} c_{ij} x_{ij} \quad \text{s.a.} \quad \sum_i x_{ij} = 1 \ \ \forall j, \qquad \sum_j r_{ij} x_{ij} \le b_i \ \ \forall i, \qquad x_{ij} \in \{0, 1\}$$


## Como rodar

```bash
julia gap_parser.jl      # auto-teste do parser
julia gap_model.jl
```

No topo do `gap_model.jl`, escolha a instância e o cutoff `ub` (custo ótimo + 0.01; ver `referencias_cplex.csv`).

## Modelo no VRPSolver

É a decomposição de Dantzig-Wolfe por agente (Savelsbergh, 1997): cada coluna é o conjunto de tarefas de um agente, uma mochila.

**Grafos:** um por agente $i$, $G_i$, igual ao grafo do BPP. Vértices $v_0, \dots, v_n$, source $v_0$, sink $v_n$, e dois arcos paralelos entre $v_{j-1}$ e $v_j$:
- $a_{ij}^+$: a tarefa $j$ vai para o agente $i$; consome $r_{ij}$; mapeado em $x_{ij}$;
- $a_{ij}^-$: a tarefa fica fora; consome 0; sem mapeamento.

Recurso de capacidade principal com limites $[0, b_i]$, diferente em cada grafo. **Multiplicidade $L = 0$, $U = 1$**: cada agente tem no máximo um caminho, isto é, uma única mochila.

**Mestre** ($x_{ij}$ **inteiras**, `Int`):

$$\min \sum_{i,j} c_{ij}\, x_{ij} \qquad \text{s.a.} \qquad \sum_{i} x_{ij} = 1 \quad \forall j$$

O custo $c_{ij}$ fica no objetivo do mestre, sobre a variável mapeada; o VrpSolver o leva para o arco $a_{ij}^+$.

**Packing sets em arcos:** um por tarefa, $P_j = \{a_{1j}^+, a_{2j}^+, \dots, a_{mj}^+\}$, juntando os arcos "tarefa dentro" de **todos os grafos**. Cada tarefa é atendida uma vez na solução, por um único agente, então $P_j$ é packing set. É a primeira vez que um packing set atravessa grafos diferentes; no BPP, havia um grafo só.

**Branching em $x$ é completo.** Com $U = 1$, cada agente tem no máximo uma coluna. Se todos os $x_{ij}$ são inteiros, o conjunto de tarefas de cada agente fica determinado, e a coluna dele também. No BPP isso não valia, porque os bins são idênticos e um único grafo gera todos eles (daí o Ryan-Foster). Aqui, os agentes são distinguíveis.

**Elementaridade:** os grafos são acíclicos; não é preciso `define_elementarity_sets_distance_matrix!`.

## Arquivos

Pasta `esta pasta/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/{c,d,e}*` | 45 instâncias de Yagiura: tipos C, D e E, com $m \in \{5, 10, 15, 20, 30, 40, 60, 80\}$ e $n \in \{100, 200, 400, 900, 1600\}$. Todas de **minimização** |
| `referencias_cplex.csv` | MIP de atribuição no CPLEX, para as 18 instâncias com $n \le 200$ |
| `gap_parser.jl` | `read_gap(path)` e auto-teste |
| `toy_gap.txt` | toy, no mesmo formato |
| `CVRP.cfg` | o mesmo do BPP |

Os tipos C, D e E são os usados na literatura de métodos exatos (Chu & Beasley, 1997; Yagiura et al., 2004). Os tipos A e B são fáceis e ficaram de fora. Os arquivos `gap1` a `gap12` da OR-Library são de **maximização** e também ficaram de fora.

**Tipos** (Chu & Beasley, 1997; Yagiura et al., 2004):
- **C:** $r_{ij} \in [5, 25]$ e $c_{ij} \in [10, 50]$, aleatórios e independentes.
- **D:** $r_{ij} \in [1, 100]$ e $c_{ij}$ **inversamente correlacionado** com $r_{ij}$: tarefa barata consome muito. É o tipo mais difícil.
- **E:** variante de D com consumos de distribuição exponencial e custo $\approx 1000 / r_{ij}$.
- Nos três, $b_i = \lfloor 0.8 \sum_j r_{ij} / m \rfloor$ (conferido em c05100, d05100 e e05100).

## Parser

```julia
include("gap_parser.jl")
inst = read_gap(joinpath(@__DIR__, "toy_gap.txt"))
inst = read_gap(joinpath(@__DIR__, "Instancias", "d05100"))
inst.m, inst.n, inst.c[i, j], inst.r[i, j], inst.b[i]
```

Formato: `m n`, depois $m$ linhas de custos, $m$ linhas de consumos e as $m$ capacidades. O nome codifica o tamanho: `d10200` é do tipo D, com 10 agentes e 200 tarefas.

Auto-teste: `julia gap_parser.jl` → `OK: toy + 45 instâncias GAP (tipos C, D e E) lidas`.

## Instância toy — `toy_gap.txt`

$m = 3$, $n = 8$, $b = (6, 6, 6)$.

| Tarefa | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| $c_{1j}$ / $r_{1j}$ | 2 / 2 | 4 / 4 | 3 / 1 | 5 / 3 | 4 / 1 | 8 / 1 | 1 / 5 | 1 / 1 |
| $c_{2j}$ / $r_{2j}$ | 2 / 6 | 6 / 2 | 9 / 4 | 6 / 1 | 1 / 4 | 9 / 1 | 8 / 1 | 6 / 5 |
| $c_{3j}$ / $r_{3j}$ | 1 / 3 | 9 / 2 | 3 / 2 | 9 / 4 | 1 / 3 | 8 / 6 | 4 / 4 | 5 / 2 |

**Ótimo (força bruta sobre as $3^8$ atribuições, conferido no CPLEX): 32**, com cutoff `32.01`. A solução é **única**:

| Agente | Tarefas | Custo | Consumo / $b_i$ |
|---|---|---|---|
| 1 | 2, 6, 8 | 4 + 8 + 1 = 13 | 6 / 6 |
| 2 | 4, 5, 7 | 6 + 1 + 8 = 15 | 6 / 6 |
| 3 | 1, 3 | 1 + 3 = 4 | 5 / 6 |

**Limites da toy:**
- LP da formulação de atribuição: **27.88**.
- LP do mestre do VRPSolver (Dantzig-Wolfe): **30.5**, arredondado para **31**. Ainda abaixo do ótimo: a toy precisa de corte ou de branching para provar 32.

Armadilhas (força bruta):

| Modelo errado | Resultado |
|---|---|
| Sem o recurso de capacidade | **24**: cada tarefa no agente mais barato |
| $U = 2$ no lugar de $U = 1$ (dois caminhos por agente) | **25**: a capacidade de cada agente vira duas mochilas de $b_i$ |
| O mesmo consumo $r_{1j}$ em todos os grafos | **29** |
| $x$ contínuas (sem `Int`) | **30.5**: o VrpSolver aceita a relaxação, como no BPP |

## Atenção para a modelagem

- **Um grafo por agente**, criado num laço: `G[i] = VrpGraph(gap, collect(0:n), 0, n, (0, 1))`, com o recurso e os arcos de cada um. Os ids dos vértices podem se repetir entre grafos.
- **Packing sets:** `set_arc_packing_sets!(gap, [[(G[i], a⁺[i, j]) for i in 1:m] for j in 1:n])`. Guarde os ids dos arcos "dentro" ao criá-los.
- **Sem Ryan-Foster:** `set_branching_priority!(gap, "x", 1)` basta.
- **Agente sem tarefas** é o caminho só com arcos "fora", com custo 0. É permitido; não é preciso $L = 1$.
- **Leitura da solução:** com $U = 1$, cada caminho tem $\lambda = 1$, e o `get_value(optimizer, x[i, j])` direto é seguro. O problema de multiplicidade do CSP não aparece aqui.

## Referências para o benchmark (`referencias_cplex.csv`)

MIP de atribuição no CPLEX, 300 s e 4 threads por instância, para as 18 instâncias com $n \le 200$. **Os tipos C e E fecharam todos, em menos de 5 s. Nenhuma do tipo D com $n \ge 200$ ou $m \ge 10$ fechou**: a única provada do tipo D é a d05100. Nas não provadas, o ótimo está entre `limite_inferior` e `melhor`, e o cutoff usa a melhor solução do CPLEX.

| Instância | LP atribuição | Ótimo / intervalo | Provado | CPLEX | cutoff |
|---|---|---|---|---|---|
| c05100 | 1923.98 | **1931** | ✓ | 0.1 s | `1931.01` |
| c05200 | 3450.77 | **3456** | ✓ | 0.1 s | `3456.01` |
| c10100 | 1387.01 | **1402** | ✓ | 0.1 s | `1402.01` |
| c10200 | 2795.41 | **2806** | ✓ | 0.9 s | `2806.01` |
| c20100 | 1218.99 | **1243** | ✓ | 0.1 s | `1243.01` |
| c20200 | 2376.91 | **2391** | ✓ | 0.5 s | `2391.01` |
| d05100 | 6345.41 | **6353** | ✓ | 23.9 s | `6353.01` |
| d05200 | 12736.20 | [12741, 12744] → **12742** (VRPSolver) | — | 300 s | `12742.01` |
| d10100 | 6323.46 | [6339, 6348] | — | 300 s | `6348.01` |
| d10200 | 12418.36 | [12425, 12435] | — | 300 s | `12435.01` |
| d20100 | 6142.53 | [6168, 6216] | — | 300 s | `6216.01` |
| d20200 | 12217.69 | [12227, 12265] | — | 300 s | `12265.01` |
| e05100 | 12641.42 | **12681** | ✓ | 0.4 s | `12681.01` |
| e05200 | 24922.00 | **24931** | ✓ | 0.8 s | `24931.01` |
| e10100 | 11543.05 | **11577** | ✓ | 1.6 s | `11577.01` |
| e10200 | 23293.86 | **23307** | ✓ | 4.4 s | `23307.01` |
| e20100 | 8359.58 | **8436** | ✓ | 4.4 s | `8436.01` |
| e20200 | 22355.93 | **22379** | ✓ | 2.8 s | `22379.01` |

O tipo D é onde o VRPSolver pode mostrar vantagem: o limite de Dantzig-Wolfe é mais forte que o LP de atribuição, e o CPLEX não fecha nem as instâncias de 100 tarefas com 10 ou 20 agentes.

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **32** — a solução única; raiz 32.00, 1 nó (o LP de 30.5 foi fechado na raiz, pelos cortes rank-1 sobre os packing sets $P_j$) | 32 | 0.89 s |
| c05100 | **1931** — raiz 1931.00, 1 nó; os 5 agentes com 20 tarefas cada, quase no limite (220/221, 224/224, 254/254, 233/235, 231/232) | 1931 | 4.08 s |
| d05100 | **6353** — raiz 6353.00, 1 nó; 4 dos 5 agentes exatamente cheios. Tipo D: a raiz leva 30 s, contra 4 s no tipo C de mesmo tamanho; o CPLEX levou 23.9 s | 6353 | 30.48 s |
| d05200 | **12742** (ótimo provado; fecha o intervalo [12741, 12744] do CPLEX) — raiz 12741.00 em 361.8 s, 37 nós; os 5 agentes exatamente cheios. A raiz já dava o limite do CPLEX; o branching levou ~1,5 h para fechar 1 unidade | [12741, 12744] | 5841.17 s |

## Fontes (da leva)

- Ross, G. T., Soland, R. M. (1975). A branch and bound algorithm for the generalized assignment problem. *Mathematical Programming* 8, 91–103.
- Savelsbergh, M. (1997). A branch-and-price algorithm for the generalized assignment problem. *Operations Research* 45(6), 831–841.
- Chu, P. C., Beasley, J. E. (1997). A genetic algorithm for the generalised assignment problem. *Computers & Operations Research* 24(1), 17–23.
- Yagiura, M., Ibaraki, T., Glover, F. (2004). An ejection chain approach for the generalized assignment problem. *INFORMS Journal on Computing* 16(2), 133–151. Instâncias: <http://www.al.cm.is.nagoya-u.ac.jp/~yagiura/gap/>
- Beasley, J. E. OR-Library: <http://people.brunel.ac.uk/~mastjjb/jeb/orlib/gapinfo.html>
- Golden, B. L., Wong, R. T. (1981). Capacitated arc routing problems. *Networks* 11(3), 305–315.
- Golden, B. L., DeArmon, J. S., Baker, E. K. (1983). Computational experiments with algorithms for a class of routing problems. *Computers & Operations Research* 10(1), 47–59. (gdb)
- Benavent, E., Campos, V., Corberán, A., Mota, E. (1992). The capacitated arc routing problem: lower bounds. *Networks* 22, 669–690. (val)
- Li, L. Y. O., Eglese, R. W. (1996). An interactive algorithm for vehicle routeing for winter-gritting. *Journal of the Operational Research Society* 47, 217–228. (egl)
- Kiuchi, M., Shinano, Y., Hirabayashi, R., Saruwatari, Y. (1995). An exact algorithm for the capacitated arc routing problem using parallel branch and bound method. *Abstracts of the 1995 Spring National Conference of the Operations Research Society of Japan*, 28–29. (kshs)
- Martinelli, R. CARPData.jl: <https://github.com/rafaelmartinelli/CARPData.jl> (instâncias e limites).
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
