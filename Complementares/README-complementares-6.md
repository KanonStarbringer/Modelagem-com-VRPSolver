# Complementares 6 no VRPSolver — GAP e CARP

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos à pasta `Complementares/`.

Data: 2026-10-19
Contexto: primeiro problema da sexta leva, escolhido depois da [Complementares 5 no VRPSolver - Cutting Stock e Vector Packing](README-complementares-5.md). O GAP reaproveita o grafo linear do BPP da [Complementares 4 no VRPSolver - TSPHS, OPHS, VRP-D e BPP](README-complementares-4.md), mas com **um grafo por agente**, cada um com custos, consumos e capacidade próprios. A mesma decomposição já foi testada no Coluna.jl, num toy de 2 máquinas e 4 tarefas: Coluna.jl - Toy GAP.

| Problema | O que muda em relação ao BPP | Ideia nova no VRPSolver |
|---|---|---|
| **GAP** | os "bins" são agentes **diferentes**: cada um tem capacidade $b_i$, e o custo e o consumo de uma tarefa dependem do agente | **vários grafos heterogêneos**, cada um com $L = 0$ e $U = 1$; packing set de cada tarefa **atravessando os grafos**; branching em $x$ completo, sem Ryan-Foster |
| **CARP** | o que se atende são **arestas**, não vértices; o veículo pode atravessar arestas sem atendê-las (*deadheading*) | grafo de **estados** "atendi a aresta $e$ no sentido $o$"; cada arco junta deadheading pelo caminho mínimo e atendimento; packing set com os **dois sentidos** de cada aresta; **cortes de capacidade (RCC)** com `add_capacity_cut_separator!` |

---

## GAP — Generalized Assignment Problem

### Definição

Há $m$ agentes e $n$ tarefas. Atribuir a tarefa $j$ ao agente $i$ custa $c_{ij}$ e consome $r_{ij}$ da capacidade $b_i$ do agente. Cada tarefa vai para exatamente um agente, e a soma dos consumos de cada agente respeita a sua capacidade. Objetivo: minimizar o custo total (Ross & Soland, 1975).

Formulação compacta (de atribuição):

$$\min \sum_{i,j} c_{ij} x_{ij} \quad \text{s.a.} \quad \sum_i x_{ij} = 1 \ \ \forall j, \qquad \sum_j r_{ij} x_{ij} \le b_i \ \ \forall i, \qquad x_{ij} \in \{0, 1\}$$

### Modelo no VRPSolver

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

### Arquivos

Pasta `Complementares/GAP/` do WSL:

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

### Parser

```julia
include("gap_parser.jl")
inst = read_gap(joinpath(@__DIR__, "toy_gap.txt"))
inst = read_gap(joinpath(@__DIR__, "Instancias", "d05100"))
inst.m, inst.n, inst.c[i, j], inst.r[i, j], inst.b[i]
```

Formato: `m n`, depois $m$ linhas de custos, $m$ linhas de consumos e as $m$ capacidades. O nome codifica o tamanho: `d10200` é do tipo D, com 10 agentes e 200 tarefas.

Auto-teste: `julia gap_parser.jl` → `OK: toy + 45 instâncias GAP (tipos C, D e E) lidas`.

### Instância toy — `toy_gap.txt`

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

### Atenção para a modelagem

- **Um grafo por agente**, criado num laço: `G[i] = VrpGraph(gap, collect(0:n), 0, n, (0, 1))`, com o recurso e os arcos de cada um. Os ids dos vértices podem se repetir entre grafos.
- **Packing sets:** `set_arc_packing_sets!(gap, [[(G[i], a⁺[i, j]) for i in 1:m] for j in 1:n])`. Guarde os ids dos arcos "dentro" ao criá-los.
- **Sem Ryan-Foster:** `set_branching_priority!(gap, "x", 1)` basta.
- **Agente sem tarefas** é o caminho só com arcos "fora", com custo 0. É permitido; não é preciso $L = 1$.
- **Leitura da solução:** com $U = 1$, cada caminho tem $\lambda = 1$, e o `get_value(optimizer, x[i, j])` direto é seguro. O problema de multiplicidade do CSP não aparece aqui.

### Referências para o benchmark (`referencias_cplex.csv`)

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

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **32** — a solução única; raiz 32.00, 1 nó (o LP de 30.5 foi fechado na raiz, pelos cortes rank-1 sobre os packing sets $P_j$) | 32 | 0.89 s |
| c05100 | **1931** — raiz 1931.00, 1 nó; os 5 agentes com 20 tarefas cada, quase no limite (220/221, 224/224, 254/254, 233/235, 231/232) | 1931 | 4.08 s |
| d05100 | **6353** — raiz 6353.00, 1 nó; 4 dos 5 agentes exatamente cheios. Tipo D: a raiz leva 30 s, contra 4 s no tipo C de mesmo tamanho; o CPLEX levou 23.9 s | 6353 | 30.48 s |
| d05200 | **12742** (ótimo provado; fecha o intervalo [12741, 12744] do CPLEX) — raiz 12741.00 em 361.8 s, 37 nós; os 5 agentes exatamente cheios. A raiz já dava o limite do CPLEX; o branching levou ~1,5 h para fechar 1 unidade | [12741, 12744] | 5841.17 s |

---

## CARP — Capacitated Arc Routing Problem

### Definição

Grafo não direcionado $G = (N, E)$, com depósito no nó 0 e custo $c_e$ em cada aresta. As arestas com demanda $d_e > 0$ são **requeridas** ($E_R$) e precisam ser **atendidas** por exatamente um veículo, de capacidade $Q$. Um veículo pode atravessar qualquer aresta sem atendê-la, pagando $c_e$ (*deadheading*), inclusive uma aresta requerida que outro veículo atende. Frota livre. Objetivo: minimizar o custo total, atendimento mais deadheading (Golden & Wong, 1981).

É o problema da coleta de lixo, da limpeza de ruas e da leitura de medidores: a demanda está **ao longo** das ruas.

### Por que não usar os nós do grafo como vértices do pricing

A ideia direta seria: vértices = nós de $G$, arcos de atendimento $(u, v)$ e $(v, u)$ por aresta requerida, e arcos de deadheading com consumo 0. Isso esbarra em uma regra do VrpSolver (página *Resources* da documentação): **não pode haver ciclo com consumo zero em todos os recursos principais**. Dois arcos de deadheading $u \to v \to u$ já formam esse ciclo. Além disso, atender $(v, u)$ e terminar no mesmo nó de onde se saiu gera laços.

### Modelo no VRPSolver: grafo de estados

**Vértices:** o depósito 0 e, para cada aresta requerida $e = \{u, v\}$, dois **estados**: $s_{e,0}$ = "acabei de atender $e$ de $u$ para $v$" (estou em $v$) e $s_{e,1}$ = "acabei de atender de $v$ para $u$" (estou em $u$). São $2|E_R|$ estados. Source = sink = 0, $L = 0$, $U = |E_R|$.

**Arcos:** de cada vértice $s$ (no nó físico $p$) para cada estado $s_{f,o}$ de outra aresta $f$, com início no nó $q$:
- significado: deadheading de $p$ até $q$ pelo **caminho mínimo**, depois atendimento de $f$;
- consumo $d_f > 0$: todo ciclo passa por atendimentos, então a regra do consumo zero é respeitada;
- mapeamento: $x_f$ (atendimento) e $y_{pq}$ (deadheading), este só se $p \ne q$.

E de cada estado $s$ para o depósito: volta pelo caminho mínimo, consumo 0, mapeado em $y_{p0}$.

Variáveis auxiliares de custo zero, só para o RCC (ver o aviso abaixo): $\mathit{sai}_f$ nos arcos que saem do depósito para atender $f$, e $\mathit{volta}_e$ nos arcos que voltam ao depósito vindos de um estado de $e$.

**Mestre** ($x$ e $y$ inteiras):

$$\min \sum_{e \in E_R} c_e\, x_e + \sum_{(p, q)} \mathrm{sp}(p, q)\, y_{pq} \qquad \text{s.a.} \qquad x_e = 1 \quad \forall e \in E_R$$

**Packing sets em vértices:** $\{s_{e,0}, s_{e,1}\}$ para cada aresta requerida: a aresta é atendida uma vez, em um dos dois sentidos. A matriz de elementaridade usa a menor distância entre as pontas das arestas.

**Cortes de capacidade (RCC):** `add_capacity_cut_separator!(model, [(PS[e], d_e)], Q)`, com cada packing set e sua demanda. É a primeira vez que usamos os RCC nas complementares; o VrpSolver só os aceita com packing sets em **vértices**, o que o grafo de estados permite.

> [!warning] O RCC exige uma variável "própria" em cada arco
> A primeira versão deu `BaPCod error : cannot build the model`. A causa estava no separador RCC: ele precisa, **em cada arco do grafo, de exatamente uma variável mapeada só em arcos entre o mesmo par de packing sets** (o depósito conta como um packing set à parte). Aqui `x_f` e `y_{pq}` aparecem em arcos de muitos pares, então não servem para isso.
> - Para os arcos entre duas arestas requeridas, o VrpSolver cria sozinho as variáveis internas `RCCsepX` (o aviso `adding 15 internal variables mapping to 118 arcs`).
> - Para os arcos que saem do depósito ou voltam a ele, ele **não** cria nada. É preciso declarar `sai[e]` e `volta[e]`, inteiras, de custo zero, e mapeá-las junto com `x` e `y`. Antes, o arco de volta de um estado que termina no próprio depósito (aresta 0–1 atendida de 1 para 0) não tinha variável nenhuma, e o BaPCod também recusava o modelo por isso.
> - Sem `add_capacity_cut_separator!`, o modelo original já dava 52. O problema era só a preparação dos cortes.

**Branching:** Ryan-Foster nos packing sets, como no BPP: os veículos são idênticos.

### Arquivos

Pasta `Complementares/CARP/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/gdb*.dat` | 23 instâncias de Golden, DeArmon & Baker (1983); todas as arestas são requeridas |
| `Instancias/val*.dat` | 34 instâncias de Benavent et al. (1992) |
| `Instancias/egl-{e,s}*.dat` | 24 instâncias de Li & Eglese (1996), de 77 e 140 nós |
| `Instancias/kshs*.dat` | 6 instâncias de Kiuchi et al. (1995) |
| `referencias.csv` | limites inferior e superior de cada instância, como vêm nos arquivos |
| `carp_parser.jl` | `read_carp(path)`, com caminhos mínimos (Floyd-Warshall), e auto-teste |
| `toy_carp.dat` | toy |
| `carp_model.jl` | o modelo |

As instâncias vêm do pacote [CARPData.jl](https://github.com/rafaelmartinelli/CARPData.jl), de Rafael Martinelli, que reúne os conjuntos clássicos num formato único. **Ótimos provados:** os 23 gdb, os 34 val e os 6 kshs; dos 24 egl, 12 (os demais têm `lb < ub`). O número de veículos dos arquivos é só informativo: os valores de referência são para frota livre.

### Parser

```julia
include("carp_parser.jl")
inst = read_carp(joinpath(@__DIR__, "toy_carp.dat"))
inst = read_carp(joinpath(@__DIR__, "Instancias", "gdb1.dat"))
inst.nv, inst.Q, inst.R[k]        # R[k] = (u, v, custo, demanda) da k-ésima aresta requerida
inst.sp[i+1, j+1]                 # caminho mínimo de i a j (vértices 0-based no arquivo)
inst.lb, inst.ub
```

Auto-teste: `julia carp_parser.jl` → `OK: toy + 87 instâncias CARP lidas (gdb, val, egl e kshs)`.

### Instância toy — `toy_carp.dat`

6 nós, 9 arestas, 6 requeridas, $Q = 6$.

| Aresta | (1, 4) | (2, 3) | (1, 2) | (0, 5) | (0, 3) | (2, 4) | (0, 1) | (3, 4) | (2, 5) |
|---|---|---|---|---|---|---|---|---|---|
| $c_e$ | 8 | 2 | 6 | 9 | 1 | 7 | 3 | 8 | 7 |
| $d_e$ | 1 | 4 | 1 | — | — | 3 | 2 | — | 2 |

**Ótimo (força bruta: partição das arestas em rotas e, em cada rota, melhor ordem e sentido): 52**, com cutoff `52.01`:

| Rota | Percurso (`~>` deadheading, `=` atendimento) | Custo | Carga |
|---|---|---|---|
| 1 | 0 ~> 1 = 4 = 2 = 5 ~> 0 | 3 + (8 + 7 + 7) + 9 = 34 | 6 |
| 2 | 0 ~> 3 = 2 = 1 ~> 0 | 1 + (2 + 6) + 3 = 12 | 5 |
| 3 | 0 = 1 ~> 0 | 3 + 3 = 6 | 2 |

A rota 1 começa atravessando sem atender a aresta (0, 1), que a rota 3 atende. A rota 3 volta pela mesma aresta que atendeu.

Armadilhas (força bruta):

| Modelo errado | Resultado |
|---|---|
| Só um sentido de atendimento por aresta (o do arquivo) | **65** |
| Sem o custo da volta ao depósito (arco $s \to 0$ sem mapeamento) | **37** |
| Sem deadheading (arcos mapeados só em $x$) | **33**: só a soma dos $c_e$ requeridos |
| $x$ e $y$ contínuas | **48**: a relaxação por rotas elementares |

### Atenção para a modelagem

- **Ids:** estado $s_{e,o}$ = `2(e-1) + o + 1`; o depósito é 0.
- **Não ligar um estado de $e$ a outro estado de $e$**: seria atender a mesma aresta duas vezes.
- **Mapeamento com vetor:** `add_arc_var_mapping!(G, a, [x[f], y[(p, q)]])`, como o `x[0]` do BPP.
- **Variáveis $y$:** só os pares $(p, q)$ realmente usados (nó onde se está, nó onde começa o próximo atendimento, ou o depósito). São no máximo (nº de nós)² pares: 19 600 nas egl-s, de 140 nós.
- **Impressão:** `get_path_arcs(optimizer, p)` devolve os arcos do caminho; um dicionário `id do arco => (nó de saída, aresta, sentido)`, montado ao criar os arcos, traduz cada um.

### Referências para o benchmark (`referencias.csv`)

| Instância | Nós | Requeridas | $Q$ | Ótimo | cutoff |
|---|---|---|---|---|---|
| gdb1 | 12 | 22 | 5 | 316 | `316.01` |
| gdb8 | 27 | 46 | 27 | 348 | `348.01` |
| gdb23 | 11 | 55 | 27 | 233 | `233.01` |
| kshs1 | 8 | 15 | 150 | 14661 | `14661.01` |
| val1A | 24 | 39 | 200 | 173 | `173.01` |
| val10A | 50 | 97 | 250 | 428 | `428.01` |
| egl-e1-A | 77 | 51 | 305 | 3548 | `3548.01` |

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **52** — raiz 52.00, 1 nó; 3 rotas: `0 ~> 1 = 2 = 3 ~> 0` (12), `0 ~> 2 = 4 = 1 = 0` (21), `0 ~> 5 = 2 ~> 0` (19) | 52 | 0.67 s |
| gdb1 | **316** — raiz 316.00, 1 nó; 5 rotas (56 + 33 + 58 + 66 + 103), quatro com carga 5/5 | 316 | 3.91 s |
| val1A | **não resolveu**: busca interrompida, sem solução. LP da raiz 146 → 166 com RCC e rank-1 (gap de 4%); strong branching a ~22 s por candidato; depois de 5 nós, `labelling time has exploded` e `SEARCH IS INTERRUPTED due to the pricing problem return status` | 173 | 4057 s |
| val1C | **245** — raiz 241.00 (gap 1,6%), 3 nós; 9 rotas, cargas de 26 a 45/45. Mesmo grafo da val1A, mas com Q = 45: rotas curtas e o modelo resolve em segundos | 245 | 13.54 s |
| val3C | **138** — raiz 138.00, 1 nó; 7 rotas, cinco com carga 20/20 | 138 | 3.94 s |
| kshs1 | **14661** — raiz 14661.00, 1 nó; 4 rotas | 14661 | 1.76 s |
| egl-e1-C | **5595** — raiz 5595.00, 1 nó; 10 rotas, sete com carga ≥ 156/160. A maior resolvida (77 nós, 51 arestas requeridas, 98 no grafo); o grafo original tem arestas não requeridas, só atravessadas em vazio | 5595 | 112.19 s |

> [!note] Rotas longas (val\*A, val10A)
> Com Q = 200 e só 2 veículos, cada rota atende ~20 arestas. A rotulagem do pricing explode, o enumerador não fecha e os cortes de capacidade quase não pesam, porque a capacidade mal aperta. O que provavelmente falta à raiz (hipótese, não testada) são as restrições de **paridade** (*odd-cut*, Belenguer e Benavent): em todo corte com número ímpar de arestas requeridas, alguma travessia em vazio é obrigatória. O modelo de estados não as enxerga, porque o deadheading vem agregado em caminhos mínimos. As instâncias com muitos veículos (val\*C, egl-\*-C) têm rotas curtas e são o alvo natural deste modelo.

---

## Fontes

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

## Notas relacionadas

- [Complementares 4 no VRPSolver - TSPHS, OPHS, VRP-D e BPP](README-complementares-4.md) (o grafo do BPP) · [Complementares 5 no VRPSolver - Cutting Stock e Vector Packing](README-complementares-5.md)
- Coluna.jl - Toy GAP (a mesma decomposição no Coluna.jl)
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos
