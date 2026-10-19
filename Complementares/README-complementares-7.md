# Complementares 7 no VRPSolver — CLRP e 2E-CVRP

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos à pasta `Complementares/`.

Data: 2026-10-19
Contexto: sétima leva, escolhida depois da [Complementares 6 no VRPSolver - GAP e CARP](README-complementares-6.md). Os dois problemas partem do MDVRP da [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md) (um grafo por depósito, clientes compartilhados). O CLRP acrescenta a **decisão de abrir depósitos**; o 2E-CVRP troca os depósitos por **satélites abastecidos por um 1º nível de caminhões**.

| Problema | O que muda em relação ao MDVRP | Ideia nova no VRPSolver |
|---|---|---|
| **CLRP** | os depósitos são **candidatos**: abrir custa $f_k$ e cada um tem capacidade $W_k$; cada rota paga um custo fixo $F$ | variáveis **fora dos grafos** ($y_k$, abertura) ligadas aos grafos por uma variável mapeada com **coeficiente** ($u_k$ soma $d_j$ ao entrar em $j$); RCC |
| **2E-CVRP** | os "depósitos" são **satélites**; a carga que sai de cada satélite tem de chegar a ele por caminhões vindos do depósito central, com **entrega fracionada** | o 1º nível **inteiro no mestre**: uma variável por rota de caminhão (subconjunto de satélites) e um **problema de transporte** que reparte a carga; o 2º nível é o CLRP sem abertura |

---

## CLRP — Capacitated Location-Routing Problem

### Definição

Dados clientes $J$ com demanda $d_j$ e depósitos candidatos $K$, cada um com custo de abertura $f_k$ e capacidade $W_k$, escolher quais depósitos abrir e montar rotas (capacidade $Q$, custo fixo $F$ por rota) que começam e terminam no mesmo depósito aberto, de modo que:
- cada cliente seja visitado por exatamente uma rota;
- a demanda total atendida a partir de $k$ não passe de $W_k$;
- o custo total (abertura + custo fixo das rotas + distância) seja mínimo.

É o MDVRP com custos de abertura e capacidade nos depósitos. Sem a capacidade $W_k$, a solução tende a abrir um só depósito.

### Modelo no VRPSolver

**Grafos:** um por depósito candidato $k$, igual ao MDVRP: vértices $\{k\} \cup J$, source = sink = $k$, $L = 0$, $U = n$ (frota livre), recurso de capacidade com consumo $(d_i + d_j)/2$ em cada arco.

**Variáveis do mestre:**
- $x_e$ (inteira): uso da aresta $e$. As arestas cliente–cliente aparecem em **todos** os grafos; as depósito–cliente $(k, i)$, só no grafo de $k$ (igual ao MDVRP).
- $y_k \in \{0, 1\}$: depósito $k$ aberto. **Não é mapeada** em arco nenhum.
- $u_k \ge 0$: carga total atendida a partir de $k$. **Mapeada com coeficiente $d_j$** em todo arco do grafo de $k$ que entra no cliente $j$: `add_arc_var_mapping!(G, a, [(x[e], 1.0), (u[k], d_j)])`. Assim, $u_k = \sum_{\text{rotas de } k} \text{carga}$.

**Mestre:**

$$\min \sum_{k} f_k\, y_k + \sum_{e \in E_{cc}} c_e\, x_e + \sum_{(k,i)} \left(c_{ki} + \tfrac{F}{2}\right) x_{ki}$$

$$\text{s.a.} \quad x(\delta(i)) = 2 \;\; \forall i \in J, \qquad u_k \le W_k\, y_k \;\; \forall k, \qquad x_{ki} \le 2\, y_k \;\; \forall (k, i)$$

- O custo fixo $F$ entra como $F/2$ em cada aresta do depósito: toda rota usa duas (ou a mesma duas vezes, se tiver um só cliente).
- $u_k \le W_k y_k$ é a **capacidade do depósito** e também o elo principal entre os grafos e $y$: depósito fechado não atende ninguém.
- $x_{ki} \le 2 y_k$ é redundante para o inteiro, mas reforça o LP: sem ela, $y_k$ fracionário pode pagar só a fração $u_k / W_k$ da abertura.

**Packing sets:** as cópias de cada cliente em todos os grafos, como no MDVRP. **RCC:** `add_capacity_cut_separator!` sobre esses packing sets. Aqui não há o problema do CARP: cada arco já tem uma variável "própria" ($x_{ij}$ liga sempre o mesmo par de clientes; $x_{ki}$, o mesmo par depósito–cliente).

**Branching:** prioridade 2 em $y$ (decide os depósitos primeiro), 1 em $x$.

### Arquivos

Pasta `Complementares/CLRP/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/Prodhon/coord*.dat` | 30 instâncias de Prins, Prodhon & Wolfler Calvo (2006): 20 a 200 clientes, 5 ou 10 depósitos; o sufixo `b` tem $Q = 150$ em vez de 70 |
| `Instancias/Barreto/coord*.dat` | 13 instâncias de Barreto et al. (2007), na versão de Prodhon: 21 a 150 clientes |
| `referencias.csv` | melhor solução conhecida (BKS) de cada instância |
| `clrp_parser.jl` | `read_clrp(path)` e auto-teste |
| `toy_clrp.dat` | toy |
| `clrp_model.jl` | o modelo |

As instâncias vêm do repositório [lrp-instances](https://github.com/alberto-santini/lrp-instances) (Cavagnini, Santini & Schneider), e as BKS, do [NEO-LRP](https://github.com/Subramanyam-Lab/NEO-LRP). Deixei de fora a `coordOr117` de Barreto: tem 28 números a mais que o formato e não entra no conjunto de 13 usado na literatura.

### Parser

```julia
include("clrp_parser.jl")
inst = read_clrp(joinpath(@__DIR__, "toy_clrp.dat"))
inst = read_clrp(joinpath(@__DIR__, "Instancias", "Prodhon", "coord20-5-1.dat"))
inst.n, inst.t, inst.Q, inst.F      # clientes, depósitos, capacidade do veículo, custo por rota
inst.W[k], inst.f[k]                # capacidade e abertura do k-ésimo depósito
inst.d[i], inst.C[i, j]             # clientes 1..n, depósitos n+1..n+t (d = 0 nos depósitos)
```

**Custos:** o último número do arquivo diz como calcular. Código 0 (Prodhon): $\lceil 100 \cdot \text{dist} \rceil$, inteiro. **Atenção:** o arquivo de formato diz "multiplicado por 100 e truncado", mas as BKS da literatura usam o arredondamento **para cima** (ver o aviso abaixo). Código 1 (Barreto): a distância real, com $F = 0$.

Auto-teste: `julia clrp_parser.jl` → `OK: toy + 43 instâncias CLRP lidas (Prodhon e Barreto)`.

### Instância toy — `toy_clrp.dat`

8 clientes, 3 depósitos, $Q = 20$, $F = 1000$, custos $\lceil 100 \cdot \text{dist} \rceil$ (formato de Prodhon, código 0).

| Depósito | Coordenadas | $W_k$ | $f_k$ |
|---|---|---|---|
| 9 | (7, 18) | 25 | 1900 |
| 10 | (17, 4) | 30 | 3100 |
| 11 | (11, 29) | 35 | 2700 |

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Coordenadas | (19, 15) | (20, 18) | (2, 19) | (0, 29) | (26, 15) | (8, 17) | (7, 6) | (22, 15) |
| Demanda | 8 | 8 | 7 | 7 | 9 | 5 | 5 | 9 |

**Ótimo (força bruta: todas as atribuições de clientes a depósitos e, em cada depósito, o CVRP exato por partição em rotas): 21386**, com cutoff `21386.01`:
- depósitos **9** e **11** abertos (4600 de abertura);
- depósito 9: rotas {3, 4, 7} e {6}, carga 24/25;
- depósito 11: rotas {1, 2} e {5, 8}, carga 34/35.

Armadilhas (força bruta):

| Erro | Valor |
|---|---|
| sem a capacidade dos depósitos ($u_k \le W_k y_k$) | 17809 (só o 9 aberto, com 4 rotas) |
| sem o custo de abertura | 15522 |
| sem o custo fixo $F$ das rotas | 17386 |

### Atenção para a modelagem

- **Variável com coeficiente no mapeamento:** `[(x[e], 1.0), (u[k], float(d(j)))]`. O coeficiente de $u_k$ é a demanda do cliente em que o arco **entra**; nos arcos que voltam ao depósito, só $x$.
- **$y$ fora dos grafos:** o VrpSolver aceita variáveis não mapeadas; elas ficam só no mestre.
- **Impressão das rotas:** `get_path_arcs` devolve o grafo e os arcos; no grafo de $k$, o vértice interno $i+1$ é o cliente $i$, e a volta ao depósito cai num **sink interno** (outro índice), não no 1.

### Referências para o benchmark (`referencias.csv`)

| Instância | Clientes | Depósitos | $Q$ | BKS | cutoff |
|---|---|---|---|---|---|
| coord20-5-1 | 20 | 5 | 70 | 54793 | `54793.01` |
| coord20-5-1b | 20 | 5 | 150 | 39104 | `39104.01` |
| coord20-5-2 | 20 | 5 | 70 | 48908 | `48908.01` |
| coord50-5-1 | 50 | 5 | 70 | 90111 | `90111.01` |
| coord50-5-1b | 50 | 5 | 150 | 63242 | `63242.01` |
| coord100-5-1 | 100 | 5 | 70 | 274814 | `274814.01` |
| Gaspelle (Barreto) | 21 | 5 | 6000 | 424.9 | `425.0` |
| Christ50 (Barreto) | 50 | 5 | 160 | 565.6 | `565.7` |

Nas de Barreto os custos são reais e a BKS vem arredondada em uma casa; por isso o cutoff é BKS + 0,1.

> [!warning] Custos: arredondar para cima, não truncar
> A primeira versão do parser seguiu o arquivo de formato ($\lfloor 100 \cdot \text{dist} \rfloor$), e a coord20-5-1 deu **54769**, abaixo da BKS 54793. As mesmas 5 rotas, recalculadas com $\lceil \cdot \rceil$, custam exatamente **54793**; com arredondamento comum, 54777. A diferença de 24 vem do arredondamento das 25 arestas. Conclusão: as BKS de Prodhon usam $\lceil 100 \cdot \text{dist} \rceil$, e o parser foi corrigido. A toy também mudou, de 21376 para 21386 (mesma solução).

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy (custos truncados) | **21376** — raiz 21376.00, 1 nó; a solução da força bruta: depósitos 9 (24/25) e 11 (34/35), rotas 9-4-3-7-9, 9-6-9, 11-1-2-11 e 11-5-8-11 (distância 12776 + 4 × 1000 de rotas + 4600 de abertura) | 21376 | 1.05 s |
| coord20-5-1 (custos truncados) | **54769** — raiz 48561.00 (gap 11%), 13 nós; depósitos 22, 23 e 25, 5 rotas. Com $\lceil \cdot \rceil$, as mesmas rotas custam 54793 = BKS: foi isso que mostrou a convenção certa | 54793 | 7.11 s |
| coord20-5-1 | **54793** = BKS — raiz 48572.00 (gap 11,4%), 13 nós; depósitos 22 (138/140), 23 (107/140) e 25 (70/140), 5 rotas. A raiz fraca provavelmente vem da abertura: o LP pode abrir depósitos "em fração" (hipótese, não verificada) | 54793 | 7.21 s |
| coord50-5-1 | **90111** = BKS — raiz 81343.00 (gap 9,7%), 17 nós; depósitos 51, 53 e 54, 12 rotas de 4 ou 5 clientes, nenhum depósito cheio | 90111 | 37.35 s |
| coord50-5-1b | **63242** = BKS — raiz 59978.00 (gap 5,2%), 39 nós; só 2 depósitos (51 cheio, 420/420; 53 com 336/350), 6 rotas de até 10 clientes. Com $Q = 150$ a raiz é mais forte (o gap cai), mas cada nó custa mais: rotas longas pesam no pricing | 63242 | 604.30 s |
| coordGaspelle (Barreto) | **424.899** = BKS 424,9 — raiz 424.90, 1 nó; depósitos 22 e 23, 4 rotas. Custos reais e $F = 0$: o cutoff BKS + 0,1 funcionou | 424.9 | 1.30 s |

---

## 2E-CVRP — Two-Echelon Capacitated Vehicle Routing Problem

### Definição

Um depósito central 0, satélites $S$ e clientes $J$ com demanda $d_j$. A entrega é em dois níveis:
- **1º nível:** até $m_1$ caminhões de capacidade $Q_1$ saem do depósito, visitam satélites e voltam. A carga de um satélite pode ser **fracionada** entre vários caminhões.
- **2º nível:** até $m_2$ *city freighters* de capacidade $Q_2$ (no máximo $m_s$ por satélite) saem de um satélite, atendem clientes e voltam ao **mesmo** satélite. Cada cliente é atendido por exatamente uma rota, sem fracionar.
- Cada satélite recebe do 1º nível pelo menos o que entrega no 2º.

Objetivo: custo total das rotas dos dois níveis (distância euclidiana real; nos conjuntos 2 a 6 não há custo fixo nem custo de manuseio).

### Modelo no VRPSolver

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

### Arquivos

Pasta `Complementares/2ECVRP/` do WSL:

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

### Parser

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

### Instância toy — `toy_2ecvrp.dat`

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

### Atenção para a modelagem

- **$z$ e $q$ fora dos grafos:** como o $y$ do CLRP, ficam só no mestre. $z$ é inteira (branching), $q$ é contínua.
- **Máscaras de bits:** a rota $r$ é um inteiro de 1 a $2^t - 1$; o satélite $s$ está em $r$ se o bit $s - 1$ estiver ligado (`noR(r, s)`).
- **Held-Karp em ordem crescente de máscara:** ao estender $r$ com um novo satélite, a máscara só cresce, então um laço simples de 1 a $2^t - 1$ basta.

### Referências para o benchmark (`referencias.csv`)

| Instância | Clientes | Satélites | BKS | cutoff |
|---|---|---|---|---|
| Set2a_E-n22-k4-s6-17 | 21 | 2 | 417.0693 | `417.08` |
| Set2a_E-n33-k4-s1-9 | 32 | 2 | 730.1625 | `730.17` |
| Set2b_E-n51-k5-s2-17 | 50 | 2 | 597.4914 | `597.50` |
| Set3_E-n22-k4-s13-14 | 21 | 2 | 526.1482 | `526.16` |
| Set4b_Instance50-1 | 50 | 2 | 156941.7168 | `156941.72` |
| Set5_100-5-1 | 100 | 5 | 1564.4604 | `1564.47` |

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **184.3243** — raiz 184.32, 1 nó; caminhões {8} (entrega 7 em 8) e {8, 9} (9 em 8 e 6 em 9): o satélite 8 recebe 16 de dois caminhões; rotas 8-7-2-6-8, 8-1-5-8 e 9-4-3-9, iguais à força bruta | 184.3243 | 1.06 s |
| Set2a_E-n22-k4-s6-17 | **417.0693** = BKS — raiz 417.07, 1 nó; um caminhão por satélite (11000 e 11500), 4 rotas de city freighter, as mesmas do arquivo `.psf` de Breunig | 417.0693 | 1.17 s |
| Set2b_E-n51-k5-s2-17 | **597.4914** = BKS — raiz 563.48 (gap 5,7%), 17 nós; o satélite 52 entrega 469 > $Q_1 = 400$ e recebe de **dois** caminhões ({52} com 377 e {51, 52} com 92): entrega fracionada numa instância real | 597.4914 | 116.20 s |
| Set5_100-5-1 | **1564.4604** = BKS — raiz 1524.76 (gap 2,5%), **1105 nós**, quase 2 h; 3 caminhões de rota única ({102}, {104}, {105}), cada um com a capacidade cheia (528); 25 rotas de city freighter, quase todas com 64 a 70 de 70. A raiz é boa em percentual, mas faltam 40 unidades, e a árvore cresceu muito. A hipótese, não verificada, é que rotas curtas e cheias deixam muitas soluções quase empatadas | 1564.4604 | 6858.84 s |

---

## Fontes

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

## Notas relacionadas

- [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md) (o MDVRP, base dos dois modelos) · [Complementares 6 no VRPSolver - GAP e CARP](README-complementares-6.md) (RCC e variáveis só para os cortes)
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos
