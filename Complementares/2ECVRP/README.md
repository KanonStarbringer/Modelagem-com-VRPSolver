# 2E-CVRP — Two-Echelon Capacitated Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-7.md`](../README-complementares-7.md).

## Definição

Um depósito central 0, satélites $S$ e clientes $J$ com demanda $d_j$. A entrega é em dois níveis:
- **1º nível:** até $m_1$ caminhões de capacidade $Q_1$ saem do depósito, visitam satélites e voltam. A carga de um satélite pode ser **fracionada** entre vários caminhões.
- **2º nível:** até $m_2$ *city freighters* de capacidade $Q_2$ (no máximo $m_s$ por satélite) saem de um satélite, atendem clientes e voltam ao **mesmo** satélite. Cada cliente é atendido por exatamente uma rota, sem fracionar.
- Cada satélite recebe do 1º nível pelo menos o que entrega no 2º.

Objetivo: custo total das rotas dos dois níveis (distância euclidiana real; nos conjuntos 2 a 6 não há custo fixo nem custo de manuseio).


## Como rodar

```bash
julia twoe_parser.jl     # auto-teste do parser
julia twoe_model.jl
```

No topo do `twoe_model.jl`, escolha a instância e o cutoff `ub` (BKS + 0.01; ver `referencias.csv`).

## Modelo no VRPSolver

**2º nível = CLRP sem abertura:** um grafo por satélite $k$ (vértices $\{k\} \cup J$, source = sink = $k$, $L = 0$, $U = m_s$), recurso de capacidade com $Q_2$, $x_e$ nas arestas, e a carga $w_k$ mapeada com coeficiente $d_j$ nos arcos que entram em $j$, exatamente como o $u_k$ do CLRP.

**1º nível no mestre, sem grafo:** como $|S| \le 10$, cada **subconjunto** $r \subseteq S$ é uma rota de caminhão possível, com custo $c^1_r$ = menor ciclo depósito → satélites de $r$ → depósito (Held-Karp, calculado antes do modelo).
- $z_r \in \mathbb{Z}_+$: nº de caminhões que fazem a rota $r$;
- $q_{rs} \ge 0$: quanto a rota $r$ entrega no satélite $s \in r$ (contínua: é aqui que entra o fracionamento).

**Mestre:**

$$\min \sum_r c^1_r\, z_r + \sum_e c_e\, x_e$$

$$\text{s.a.} \quad x(\delta(i)) = 2 \;\; \forall i \in J, \qquad \sum_r z_r \le m_1, \qquad \sum_{s \in r} q_{rs} \le Q_1\, z_r \;\; \forall r,$$

$$\sum_{r \ni s} q_{rs} \ge w_s \;\; \forall s \in S, \qquad \sum_{(k, i)} x_{ki} \le 2\, m_2$$

- As duas restrições do meio são um **problema de transporte**: os caminhões (oferta $Q_1$ cada) abastecem os satélites (demanda $w_s$), e a rota $r$ só alcança os satélites que visita. É o fracionamento exato: um satélite com $w_s > Q_1$ é abastecido por dois caminhões.
- $\sum x_{ki} \le 2 m_2$ limita o total de city freighters (cada rota usa duas arestas do satélite). O limite por satélite, $m_s$, fica no $U$ de cada grafo.

**Packing sets, RCC e elementaridade:** iguais ao CLRP. **Branching:** prioridade 2 em $z$ (os caminhões), 1 em $x$.

**Tamanho do 1º nível:** $2^{|S|} - 1$ rotas e $|S| \cdot 2^{|S|-1}$ variáveis $q$: com 2 satélites, 3 rotas e 4 variáveis $q$; com 10 satélites (conjunto 5), 1023 rotas e 5120 variáveis $q$. Para mais satélites, o 1º nível teria de virar um grafo próprio.

## Arquivos

Pasta `esta pasta/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/Set2a_*`, `Set2b_*`, `Set2c_*` | Perboli, Tadei & Vigo (2011): 21, 32 e 50 clientes, 2 ou 4 satélites. O 2c é o 2b com os satélites corrigidos por Breunig |
| `Instancias/Set3_*` | Perboli et al. (2011): satélites na borda |
| `Instancias/Set4a_*`, `Set4b_*` | Crainic et al. (2010): 50 clientes, 2, 3 ou 5 satélites; o 4b não limita os city freighters por satélite |
| `Instancias/Set5_*` | Hemmelmayr, Cordeau & Crainic (2012): 100 e 200 clientes, 5 ou 10 satélites |
| `Instancias/Set6_*` | Baldacci et al. (2013): 50 a 100 clientes, 4 a 6 satélites (versão sem custo de manuseio, a "6a") |
| `referencias.csv` | BKS de 202 das 207 instâncias (5 do Set4a não têm solução publicada no pacote) |
| `twoe_parser.jl` | `read_2ecvrp(path)` e auto-teste |
| `toy_2ecvrp.dat` | toy |
| `twoe_model.jl` | o modelo |

As instâncias e as BKS vêm da [coleção de U. Breunig](https://prolog.univie.ac.at/research/TwoEVRP/) (Univ. de Viena), que unificou o formato dos conjuntos 2 a 6 e publicou as melhores soluções (Breunig, Schmid, Hartl & Vidal, 2016). A BKS é o `totalcost` de cada arquivo `.psf`.

## Parser

```julia
include("twoe_parser.jl")
inst = read_2ecvrp(joinpath(@__DIR__, "toy_2ecvrp.dat"))
inst = read_2ecvrp(joinpath(@__DIR__, "Instancias", "Set2a_E-n22-k4-s6-17.dat"))
inst.n, inst.t                     # clientes 1..n, satélites n+1..n+t; o depósito é o 0
inst.m1, inst.Q1                   # caminhões: quantidade e capacidade
inst.ms, inst.m2, inst.Q2          # city freighters: máximo por satélite, total e capacidade
inst.d[i], inst.C[i+1, j+1]        # demanda; distância euclidiana real (a matriz inclui o depósito)
```

Auto-teste: `julia twoe_parser.jl` → `OK: toy + 207 instâncias 2E-CVRP lidas (conjuntos 2 a 6)`.

Nos conjuntos 2 e 3, os satélites ficam **sobre clientes** (o satélite 22 da E-n22-k4-s6-17 é o cliente 6): a distância entre os dois é 0, e o cliente continua tendo de ser atendido por uma rota do 2º nível.

## Instância toy — `toy_2ecvrp.dat`

Depósito em (0, 0); satélites **8** = (19, 11) e **9** = (27, 9); 7 clientes. $m_1 = 2$, $Q_1 = 15$; $m_s = 2$, $m_2 = 3$, $Q_2 = 10$.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Coordenadas | (9, 2) | (12, 23) | (26, 17) | (32, 13) | (18, 2) | (16, 17) | (14, 15) |
| Demanda | 2 | 3 | 4 | 2 | 5 | 4 | 2 |

Rotas de caminhão possíveis: {8} custa 43,91; {9}, 56,92; {8, 9}, 58,66.

**Ótimo (força bruta: atribuição dos clientes aos satélites, CVRP exato em cada satélite com o nº de rotas, e todas as combinações de caminhões com a condição de transporte): 184,3243**, com cutoff `184.33`:
- 2º nível (81,75): satélite 8 com as rotas {1, 5} e {6, 2, 7}, carga **16**; satélite 9 com {3, 4}, carga 6;
- 1º nível (102,57): um caminhão {8} e um caminhão {8, 9}. O satélite 8 precisa de 16 > $Q_1 = 15$: recebe dos **dois** caminhões.

Armadilhas (força bruta):

| Erro | Valor |
|---|---|
| sem fracionar (cada satélite abastecido por um só caminhão) | 190,79 |
| sem o custo do 1º nível | 81,75 |
| sem o limite $m_s$ por satélite | 177,48 |

## Atenção para a modelagem

- **$z$ e $q$ fora dos grafos:** como o $y$ do CLRP, ficam só no mestre. $z$ é inteira (branching), $q$ é contínua.
- **Máscaras de bits:** a rota $r$ é um inteiro de 1 a $2^t - 1$; o satélite $s$ está em $r$ se o bit $s - 1$ estiver ligado (`noR(r, s)`).
- **Held-Karp em ordem crescente de máscara:** ao estender $r$ com um novo satélite, a máscara só cresce, então um laço simples de 1 a $2^t - 1$ basta.

## Referências para o benchmark (`referencias.csv`)

| Instância | Clientes | Satélites | BKS | cutoff |
|---|---|---|---|---|
| Set2a_E-n22-k4-s6-17 | 21 | 2 | 417.0693 | `417.08` |
| Set2a_E-n33-k4-s1-9 | 32 | 2 | 730.1625 | `730.17` |
| Set2b_E-n51-k5-s2-17 | 50 | 2 | 597.4914 | `597.50` |
| Set3_E-n22-k4-s13-14 | 21 | 2 | 526.1482 | `526.16` |
| Set4b_Instance50-1 | 50 | 2 | 156941.7168 | `156941.72` |
| Set5_100-5-1 | 100 | 5 | 1564.4604 | `1564.47` |

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **184.3243** — raiz 184.32, 1 nó; caminhões {8} (entrega 7 em 8) e {8, 9} (9 em 8 e 6 em 9): o satélite 8 recebe 16 de dois caminhões; rotas 8-7-2-6-8, 8-1-5-8 e 9-4-3-9, iguais à força bruta | 184.3243 | 1.06 s |
| Set2a_E-n22-k4-s6-17 | **417.0693** = BKS — raiz 417.07, 1 nó; um caminhão por satélite (11000 e 11500), 4 rotas de city freighter, as mesmas do arquivo `.psf` de Breunig | 417.0693 | 1.17 s |
| Set2b_E-n51-k5-s2-17 | **597.4914** = BKS — raiz 563.48 (gap 5,7%), 17 nós; o satélite 52 entrega 469 > $Q_1 = 400$ e recebe de **dois** caminhões ({52} com 377 e {51, 52} com 92): entrega fracionada numa instância real | 597.4914 | 116.20 s |
| Set5_100-5-1 | **1564.4604** = BKS — raiz 1524.76 (gap 2,5%), **1105 nós**, quase 2 h; 3 caminhões de rota única ({102}, {104}, {105}), cada um com a capacidade cheia (528); 25 rotas de city freighter, quase todas com 64 a 70 de 70. A raiz é boa em percentual, mas faltam 40 unidades, e a árvore cresceu muito. A hipótese, não verificada, é que rotas curtas e cheias deixam muitas soluções quase empatadas | 1564.4604 | 6858.84 s |

## Fontes (da leva)

- Prins, C., Prodhon, C., Wolfler Calvo, R. (2006). Solving the capacitated location-routing problem by a GRASP complemented by a learning process and a path relinking. *4OR* 4, 221–238. (Prodhon)
- Barreto, S., Ferreira, C., Paixão, J., Sousa Santos, B. (2007). Using clustering analysis in a capacitated location-routing problem. *European Journal of Operational Research* 179(3), 968–977. (Barreto)
- Cavagnini, R., Santini, A., Schneider, M. (2026). Recent developments in location-routing problems: deterministic single-echelon, single-objective, single-period problems. *European Journal of Operational Research* 332(3), 711–729. Instâncias: <https://github.com/alberto-santini/lrp-instances>
- Prodhon, C. Página das instâncias e BKS: <http://prodhonc.free.fr/Instances/instances_us.htm>
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
- Perboli, G., Tadei, R., Vigo, D. (2011). The two-echelon capacitated vehicle routing problem: models and math-based heuristics. *Transportation Science* 45(3), 364–380. (conjuntos 2 e 3)
- Crainic, T. G., Perboli, G., Mancini, S., Tadei, R. (2010). Two-echelon vehicle routing problem: a satellite location analysis. *Procedia – Social and Behavioral Sciences* 2(3), 5944–5955. (conjunto 4)
- Hemmelmayr, V. C., Cordeau, J.-F., Crainic, T. G. (2012). An adaptive large neighborhood search heuristic for two-echelon vehicle routing problems arising in city logistics. *Computers & Operations Research* 39(12), 3215–3228. (conjunto 5)
- Baldacci, R., Mingozzi, A., Roberti, R., Wolfler Calvo, R. (2013). An exact algorithm for the two-echelon capacitated vehicle routing problem. *Operations Research* 61(2), 298–314. (conjunto 6)
- Breunig, U., Schmid, V., Hartl, R. F., Vidal, T. (2016). A large neighbourhood based heuristic for two-echelon routing problems. *Computers & Operations Research* 76, 208–225. Instâncias unificadas e BKS: <https://prolog.univie.ac.at/research/TwoEVRP/>
- Marques, G., Sadykov, R., Deschamps, J.-C., Dupas, R. (2020). An improved branch-cut-and-price algorithm for the two-echelon capacitated vehicle routing problem. *Computers & Operations Research* 114, 104833.

Referências do 2E-CVRP citadas de memória (exceto o link de Breunig): conferir volume e páginas.
