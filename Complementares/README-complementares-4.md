# Complementares 4 no VRPSolver — TSPHS, OPHS, VRP-D e BPP

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos à pasta `Complementares/`.

Data: 2026-10-18
Contexto: modelos da **Aula 5** do Prof. Roboredo (`Aulas em PDF/VRPSolver_5.pdf`, slides 100 a 127). Cada problema tem sua pasta em `Complementares/` e segue o roteiro de [Complementares 3 no VRPSolver - VRPB, SDVRP, FSMVRP, PDPTW, E-VRP e Rich VRP](README-complementares-3.md): parser com auto-teste, toy resolvida por força bruta e instâncias de benchmark. O TSPHS e o OPHS vêm de Roboredo, Lima, Silva & Uchoa (2024), cujo código está no GitHub do professor (`mcroboredo/TSPHS_OPHS`).

## O que a Aula 5 acrescenta ao VRPSolver

| Recurso | Função no VrpSolver.jl | Usado em |
|---|---|---|
| Cortes robustos sob demanda (em $x$ e $y$) | `add_cut_callback!(model, f, "nome")` e, dentro de `f`, `get_value(model.optimizer, x[e])` e `add_dynamic_constr!(model.optimizer, vars, coefs, >=, rhs, "nome")` | TSPHS, OPHS |
| Arcos paralelos (vários arcos entre o mesmo par de vértices) | `add_arc!` repetido | VRP-D, BPP |
| Packing sets em **arcos** | `set_arc_packing_sets!(model, [[(G, a), ...], ...])` | VRP-D, BPP |
| Branching de Ryan-Foster sobre packing sets | `enable_packset_ryanfoster_branching!(model, prioridade)` | BPP |

Três fatos conferidos no código instalado no WSL (`VrpSolver/rd9z3`):
- **Os callbacks entram como *lazy cuts*** (`register_lazycb!`, tipo `'C'`), então também são chamados nas soluções inteiras. Por isso a separação precisa ser exata nas soluções inteiras: se o callback deixar passar um subtour inteiro, o VRPSolver aceita a solução. Nas fracionárias, separar mais só fortalece o limite.
- **Os packing sets em arcos precisam ser disjuntos**: `add_arc_to_packing_set` dá erro `an arc cannot belong to more than 1 packing set`. O slide do VRP-D diz que "o VRPSolver mais recente aceita interseção", mas a versão instalada não aceita (ver o VRP-D abaixo).
- **Objetivo inteiro**: o VRPSolver arredonda o limite inferior para cima quando todos os coeficientes do objetivo são inteiros e todas as variáveis **não mapeadas** são `Int`/`Bin` (`has_integer_objective`). No BPP e no OPHS isso vale; no TSPHS e no VRP-D, não.

---

## TSPHS — Traveling Salesperson Problem with Hotel Selection

### Definição

Um vendedor visita todos os clientes $C$ numa viagem de vários dias. Cada dia é uma **trip**, de duração máxima $T$ (viagem + serviço $s_j$ dos clientes), que começa e termina num hotel de $H$; a trip seguinte começa no hotel em que a anterior terminou. O tour começa e termina no hotel 1. Objetivo **hierárquico**: 1º minimizar o nº de trips; 2º minimizar a distância total.

### Modelo no VRPSolver (slides 103 a 108)

**Grafo gerador** $G' = (V', A')$, um só, com $L = U = K$ caminhos. Cada caminho é **uma trip**:

| Vértice | Significado | id no código |
|---|---|---|
| $v_{so}$, $v_{si}$ | source e sink | `0` e `N + |H| + 1` |
| $v_h$, $h \in H$ | hotel de **partida** da trip | `h` |
| $v_j$, $j \in C$ | cliente | `j` |
| $\bar v_h$, $h \in H$ | hotel de **chegada** da trip | `N + h` |

| Arco | Consumo do tempo (recurso principal, $[0, T]$ em todos os vértices) | Mapeamento |
|---|---|---|
| $(v_{so}, v_h)$ e $(\bar v_h, v_{si})$ | $0$ | nenhum |
| $(v_h, v_j)$ e $(v_j, \bar v_h)$ | $t_{hj} + s_j$ e $t_{jh}$ | $x_{\{h,j\}}$ nos dois |
| $(v_i, v_j)$, $i \ne j \in C$ | $t_{ij} + s_j$ | $x_{\{i,j\}}$ |
| $(v_h, \bar v_{h'})$, $h \ne h'$ (trip vazia) | $t_{hh'}$ | $x_{\{h,h'\}}$ |

Ou seja, $M(x_e) = \{(v_i, \bar v_j), (v_j, \bar v_i)\}$ se $i, j \in H$; $\{(v_i, v_j), (v_j, v_i)\}$ se $i, j \in C$; $\{(v_i, v_j), (v_j, \bar v_i)\}$ se $i \in H$, $j \in C$.

**Mestre** ($x_e$ = nº de vezes que a aresta $e$ é percorrida; $y_h$ = nº de usos do hotel $h$, inteira e **não mapeada**):

$$\min \sum_{e \in E} t_e\, x_e \tag{1a}$$

$$\sum_{e \in \delta(j)} x_e = 2 \quad \forall j \in C \tag{1b}$$

$$\sum_{e \in \delta(h)} x_e = 2\,y_h \quad \forall h \in H \tag{1c}$$

$$y_1 \ge 1 \tag{1d}$$

$$\textstyle\sum_{p} \lambda_p = K \quad (\text{via } L = U = K) \tag{1f}$$

**Cortes de conectividade**, robustos e separados sob demanda por corte mínimo a partir do hotel 1:

$$\sum_{e \in \delta(S)} x_e \ge 2 \quad \forall j \in C,\ \forall S \subset V : 1 \in S,\ j \notin S \tag{1g}$$

$$\sum_{e \in \delta(S)} x_e \ge \frac{2}{K-1}\, y_h \quad \forall h \in H \setminus \{1\},\ \forall S : 1 \in S,\ h \notin S \tag{1h}$$

Em (1h), $K - 1$ é cota superior de $y_h$ para $h \neq 1$. Se $K = 1$, não há (1h).

**Packing sets:** só os clientes, $\{\{v_j\} : j \in C\}$. Os hotéis ficam fora, porque são revisitáveis. **Branching:** em $x$ e em $y$.

**Objetivo hierárquico:** o modelo fixa $K$. O 1º objetivo é o menor $K$ para o qual o modelo é viável. Roboredo et al. (2024) resolvem o modelo para $K$ crescente. Aqui, $K$ e `ub` são parâmetros no topo do arquivo, como o `ub` dos outros modelos.

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `TSPHS/Instancias/instancias_c{50,75,100}/*.txt` | 267 instâncias de Barbosa (2018), copiadas do repositório do professor |
| `TSPHS/referencias_barbosa2018.csv` | trips e comprimento das Tabelas 6.13 a 6.30 da tese (240 instâncias: 90 ótimas, 74 só viáveis, 57 sem solução, 19 inviáveis) |
| `TSPHS/tsphs_parser.jl` | `read_tsphs(path)` e auto-teste |
| `TSPHS/mincut.jl` | `mincut(cap, s, t)` (Edmonds-Karp) para o callback; também usado pelo OPHS |
| `TSPHS/toy_tsphs.txt` | toy |

Na pasta `Complementares/TSPHS/` há tudo isso e mais o `TSPHS.cfg`: o `CVRP.cfg` com `RCSPmaxNumOfEnumSolutionsForMIP = 0`, como o `TSPHS.cfg` do professor. É uma precaução: o MIP sobre as rotas enumeradas não deve dispensar o callback de conectividade.

### Parser

```julia
include("tsphs_parser.jl")
inst = read_tsphs(joinpath(@__DIR__, "toy_tsphs.txt"))
inst = read_tsphs(joinpath(@__DIR__, "Instancias", "instancias_c50", "h05_c50_l150_09.txt"))
inst.H, inst.C, inst.N    # hotéis 1..h (1 = início e fim), clientes h+1..N
inst.T, inst.s[i], inst.t[i, j]
```

**Convenções** (as do `data.jl` do professor):
- distância euclidiana **truncada** em 1 casa, `floor(sqrt(.), digits = 1)`;
- duração da trip = viagem + serviço $\le T$;
- o comprimento reportado (objetivo) é **só a viagem**. Conferido: na h05_c50_l150_09, o TSP sobre os 50 clientes já dá cerca de 547 de viagem, e o ótimo de 9 trips é 722.2, não 722.2 + 500 de serviço.

Auto-teste: `julia tsphs_parser.jl` → `OK: toy + 267 instâncias de Barbosa (2018) lidas`.

### Instância toy — `toy_tsphs.txt`

$T = 45$, serviço $s_j = 2$ em todos os clientes, distância truncada em 1 casa.

| Vértice | 1 (H, início) | 2 (H) | 3 (H) | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| (x, y) | (0, 0) | (24, 0) | (12, −14) | (5, 6) | (8, −3) | (20, 6) | (28, 5) | (26, −6) | (12, 8) |

**Ótimo (DP exata): $K^* = 3$ trips, custo 76.2**, com `K = 3` e cutoff `76.21`. Com $K = 2$ o modelo é inviável.

| Trip | Sequência | Viagem | Duração |
|---|---|---|---|
| 1 | 1-4-9-6-2 | 30.4 | 36.4 |
| 2 | 2-7-2 | 12.8 | 14.8 |
| 3 | 2-8-5-1 | 33.0 | 37.0 |

O hotel 2 é usado duas vezes ($y_2 = 2$, grau 4), e a trip 2 começa e termina no mesmo hotel. Para outros $K$: $K = 4$ → 80.5; $K = 5$ → 93.9.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| **Sem os cortes de conectividade** | **69.4**: 1-4-9-5-1 + 2-6-7-2 + 2-8-2. Os dois laços no hotel 2 ficam desconexos do hotel 1 (é a figura do slide 107) |
| Duração sem o serviço $s_j$ | $K^*$ cai para **2** (70.6); com $K = 3$ fixo, 74.9 |

### Atenção para a modelagem

- **Duas cópias de cada hotel**: $v_h$ só recebe arco do source e $\bar v_h$ só sai para o sink. Assim, cada caminho é exatamente uma trip hotel → clientes → hotel.
- **Arcos $v_h \to \bar v_{h'}$ (trip vazia) consomem $t_{hh'}$.** No `model.jl` do repositório, esses arcos estão sem consumo. Pela definição, uma trip vazia também respeita $T$.
- **Cortes no callback**:
  - monte `cap[i, j] = cap[j, i] = get_value(model.optimizer, x[(i, j)])`;
  - para cada cliente $j$, rode `mincut(cap, 1, j)`; se o fluxo for $< 2$, adicione (1g) com as arestas de $\delta(S)$;
  - para cada hotel $h \neq 1$, compare com $2\bar y_h/(K-1)$ e adicione (1h) como `[x...; y[h]]` com coeficientes `[1...; -2/(K-1)]` e `>= 0`;
  - o nome usado em `add_dynamic_constr!` tem de ser o mesmo de `add_cut_callback!`.
- **`get_value` funciona no callback** para $x$ (mapeada) e para $y$ (não mapeada). Variáveis de caminho ($\lambda$) não podem ser consultadas.
- **$K$ entra no grafo**: `VrpGraph(model, VG, 0, sink, (K, K))`.

### Referências para o benchmark (`referencias_barbosa2018.csv`)

| Instância | $K^*$ | Comprimento ótimo | Tempo na tese | cutoff |
|---|---|---|---|---|
| h05_c50_l150_09 | 9 | 722.2 | 1 s | `722.21` |
| h10_c50_l200_05 | 6 | 601.7 | 7 s | `601.71` |
| h05_c50_l150_02 | 10 | 823.8 | 8 s | `823.81` |
| h10_c50_l200_03 | 6 | 557.4 | 16 s | `557.41` |
| h05_c50_l200_05 | 6 | 677.1 | 135 s | `677.11` |
| h05_c100_l150_08 | 16 | 1196.8 | 110 s | `1196.81` |

Os tempos são do BCP próprio de Barbosa (2018), não do VRPSolver. A coluna `trips_lb` do CSV é o limite inferior de trips da tese. Rodar com $K^* - 1$ deve dar inviável. Roboredo et al. (2024) relatam ótimos para 85 das 102 instâncias que estavam abertas, mas esses valores estão no artigo (pago), não no repositório.

### Resultados

| Instância | $K$ | Obtido | Esperado | Tempo |
|---|---|---|---|---|
| toy | 3 | 76.2 (raiz, 1 nó; $y_2 = 2$) | 76.2 | 1.41 s |
| h05_c50_l150_09 | 9 | 722.2 (raiz, 1 nó; $y = (1, 2, 3, 2, 1)$) | 722.2 | 1.36 s |

---

## OPHS — Orienteering Problem with Hotel Selection

### Definição

O tour começa no hotel 1 e termina no hotel $m$ ($\neq 1$), com **exatamente $D$ trips**, cada uma de duração $\le T$, e duração total $\le U$. Cada cliente $j$ tem lucro $w_j$, e a visita é **opcional**. Objetivo: maximizar o lucro.

O slide 109 é o **caso particular** de Roboredo et al. (2024), com o mesmo $T$ em todas as trips: um grafo só e $\sum \lambda = D$. No caso geral, com $T_d$ diferente por trip, o artigo usa um grafo por trip e encadeia os hotéis no mestre. As instâncias SET1 a SET3 e SET5 de Divsalar et al. (2013) têm $T_d$ diferentes e **não servem** para o modelo da aula. O parser avisa (`inst.uniforme`).

### Modelo no VRPSolver (slide 110)

Mesmos $G'$, recurso de tempo (sem serviço: as instâncias não têm), mapeamento $M$, $x_e$ e $y_h$ do TSPHS, com $L = U = D$. Variável nova $g_j \in \{0, 1\}$, **não mapeada**: o cliente $j$ é visitado.

$$\max \sum_{j \in C} w_j\, g_j \qquad (\text{no VRPSolver: } \min -\textstyle\sum_j w_j g_j) \tag{3a}$$

$$\sum_{e \in \delta(j)} x_e = 2\,g_j \quad \forall j \in C \tag{3b}$$

$$\sum_{e \in \delta(h)} x_e = 2\,y_h \quad \forall h \in H \setminus \{1, m\} \tag{3c}$$

$$\sum_{e \in \delta(h)} x_e = 2\,y_h - 1 \quad \forall h \in \{1, m\} \tag{3d}$$

$$y_m \ge 1, \qquad \sum_{e \in E} t_e\, x_e \le U, \qquad \textstyle\sum_p \lambda_p = D \tag{3e–3g}$$

(3d): os hotéis 1 e $m$ têm grau **ímpar**, porque o tour é um caminho $1 \to m$, não um ciclo.

**Cortes (3h), (3i).** O tour é um caminho de 1 a $m$. Um corte que separa 1 de $m$ é cruzado só uma vez, então o lado $S$ precisa conter **os dois**:

$$\sum_{e \in \delta(S)} x_e \ge 2\,g_j \quad \forall j \in C,\ \forall S : \{1, m\} \subseteq S,\ j \notin S \tag{3h}$$

$$\sum_{e \in \delta(S)} x_e \ge \frac{2}{D-1}\, y_h \quad \forall h \in H \setminus \{1, m\},\ \forall S : \{1, m\} \subseteq S,\ h \notin S \tag{3i}$$

Na separação, basta "colar" 1 e $m$ no corte mínimo (`cap[1, m] = cap[m, 1] = Inf`) e rodar `mincut(cap, 1, j)`. O código do professor chega ao mesmo resultado com uma trip fictícia $m \to 1$, que fecha o ciclo.

**Packing sets:** os clientes. **Branching:** $x$, $y$ e $g$.

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `OPHS/Instancias/SET_{2-3,4-4,8-4,9-7}_TSP/*.ophs` | 64 instâncias de Sohrabi et al. (2021), derivadas do TSPHS, todas com $T$ uniforme |
| `OPHS/Instancias/SET_4-4_VRP/*.ophs` | 16 instâncias de Sohrabi et al. (2021), derivadas de Solomon/Cordeau, com $T$ uniforme |
| `OPHS/Instancias/SET_4/*.ophs` | 10 instâncias do SET4 de Divsalar et al. (2013), o único conjunto deles com $T$ uniforme |
| `OPHS/referencias_bks.csv` | melhor lucro conhecido das 36 instâncias TSP que o professor rodou no caso uniforme (o `-u` do `symmetric.sh`) |
| `OPHS/ophs_parser.jl` | `read_ophs(path)` e auto-teste |
| `OPHS/toy_ophs.ophs` | toy |

O modelo usa o corte mínimo do TSPHS: `include(joinpath(@__DIR__, "..", "TSPHS", "mincut.jl"))`. A pasta tem o `OPHS.cfg`, igual ao `TSPHS.cfg`.

### Parser

```julia
include("ophs_parser.jl")
inst = read_ophs(joinpath(@__DIR__, "toy_ophs.ophs"))
inst = read_ophs(joinpath(@__DIR__, "Instancias", "SET_2-3_TSP", "eil51-H4-T3-S3.ophs"))
inst.H, inst.C           # hotéis 1..H+2 (inst.ini = 1, inst.fim = 2 = "m"), clientes depois
inst.D, inst.T, inst.U, inst.uniforme, inst.w[i], inst.t[i, j]
```

Distância euclidiana **real**, sem tempo de serviço. O SET_4 termina com uma linha de traços, que o parser ignora.

Auto-teste: `julia ophs_parser.jl` → `OK: toy + 90 instâncias com T uniforme lidas`.

### Instância toy — `toy_ophs.ophs`

$D = 3$ trips, $T = 25$, $U = 60$, distância real.

| Vértice | 1 (início) | 2 (fim, $m$) | 3 (H) | 4 (H) | 5 | 6 | 7 | 8 | 9 | 10 | 11 |
|---|---|---|---|---|---|---|---|---|---|---|---|
| (x, y) | (0, 0) | (30, 0) | (15, 8) | (15, 30) | (6, 5) | (10, −4) | (19, 12) | (24, −5) | (28, 7) | (12, 33) | (18, 33) |
| $w_j$ | | | | | 10 | 15 | 20 | 10 | 15 | 30 | 30 |

**Ótimo (enumeração exata): lucro 55**, com cutoff `ub = -54.99` (objetivo $-\sum w g$). Tempo total: 56.15.

| Trip | Sequência | Duração |
|---|---|---|
| 1 | 1-5-3 | 17.30 |
| 2 | 3-7-9-2 | 23.23 |
| 3 | 2-8-2 | 15.62 |

Os clientes 10 e 11 (lucro 60) estão perto do hotel 4, mas nenhum tour conexo de 3 trips chega até lá e ainda termina no hotel 2.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| **Sem os cortes** | **105**: soma o laço 4-10-11-4, desconexo do caminho 1 → 2 |
| Sem a restrição $\sum t_e x_e \le U$ | **60** (tempo 62.07): 1-6-1, 1-5-3, 3-7-9-2 |
| Grau $2y_h$ também em 1 e $m$ (sem o $-1$) | **inviável**: o modelo passa a exigir um ciclo que sai de 1 e volta a 1 passando por $m$, e não há um com 3 trips |
| Corte com $1 \in S$ mas $m \notin S$ | corte **inválido**: corta o caminho ótimo, que cruza esse $\delta(S)$ uma vez só |

### Atenção para a modelagem

- **Objetivo**: VRPSolver minimiza; use `Min, -sum(w[j] * g[j])`. O cutoff fica negativo: `ub = -(lucro conhecido) + 0.01`.
- $g$ e $y$ são `Int`/`Bin` e não mapeadas. Com lucros inteiros, o objetivo é inteiro e o VRPSolver arredonda o limite.
- **Caso uniforme apenas**: confira `inst.uniforme` e use `T = inst.T`.
- A partida do tour sai de $v_1$ e a chegada final entra em $\bar v_m$. Não é preciso restringir os arcos do source e do sink: (3d) e (3e) garantem isso.

### Referências para o benchmark (`referencias_bks.csv`)

| Instância | Hotéis extras | $D$ | $T$ | Melhor lucro conhecido | cutoff |
|---|---|---|---|---|---|
| eil51-H4-T3-S3 | 2 | 3 | 114 | 2470 | `-2469.99` |
| berlin52-H4-T3-S3 | 2 | 3 | 2041 | 2690 | `-2689.99` |
| st70-H4-T3-S3 | 2 | 3 | 181 | 3300 | `-3299.99` |
| eil51-H6-T4-S3 | 4 | 4 | 79 | 2360 | `-2359.99` |
| eil51-H10-T4-S4 | 8 | 4 | 85.2 | 2600 | `-2599.99` |
| eil51-H11-T7-S3 | 8 | 7 | 46 | 2240 | `-2239.99` |

O "melhor lucro conhecido" é o `-u` passado ao VRPSolver no `symmetric.sh` do repositório do professor (o `run.jl` usa `set_cutoff!(ub + 1.00001)`). É um lucro já atingido; o ótimo é **pelo menos** esse valor. Roboredo et al. (2024) dizem ter resolvido as 44 instâncias uniformes, mas os ótimos estão no artigo. O SET_4 de Divsalar não tem referência aqui.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | 55 (raiz −65, 5 nós; $g = \{5, 7, 8, 9\}$) | 55 | 1.74 s |
| eil51-H4-T3-S3 | **2470, ótimo provado** (raiz −2479, 3 nós; trips 1→3→4→2 com 113.57, 113.93, 113.10 ≤ 114; total 340.6 ≤ 342) | ≥ 2470 | 6.91 s |

---

## VRP-D — VRP com drone (slides 113 a 117)

### Definição

Um caminhão e um drone saem do depósito. O caminhão percorre uma rota; entre duas paradas consecutivas $i$ e $j$, ele vai **direto**, ou lança o drone em $i$ para atender **um** cliente $c$ e o recolhe em $j$ (uma *sortie*). O drone tem alcance $R$ e não recarrega: $d_{ic} + d_{cj} \le R$. O caminhão não para em outros clientes durante a sortie. Cada cliente é atendido uma vez, pelo caminhão ou pelo drone. Objetivo: custo mínimo.

Parâmetros desta implementação:
- custo do caminhão: $c_{ij}$;
- custo do drone na sortie: $d^c_{ij} = \alpha\,(c_{ic} + c_{cj})$;
- alcance: $c_{ic} + c_{cj} \le R$;
- matriz $c$: distância euclidiana arredondada (nint, TSPLIB);
- sorties podem começar ou terminar no depósito ($i = 0$ ou $j = 0$);
- frota de **um** caminhão ($L = U = 1$), como no slide.

### Modelo no VRPSolver

**Grafo:** o grafo do CVRP assimétrico, com source = sink = 0 e $L = U = 1$. Entre cada par $(i, j)$ há **arcos paralelos**: um direto e um arco-sortie $(i, j)^c$ para cada $c$ com $c_{ic} + c_{cj} \le R$.

| Arco | Mapeamento | Consumo do recurso "clientes atendidos" ($[0, n]$, principal) |
|---|---|---|
| direto $(i, j)$ | $x_{ij}$ | $1$ se $j \neq 0$ |
| sortie $(i, j)^c$ | $x_{ij}$ **e** $y^c_{ij}$ | $1 + [j \neq 0]$ |

O recurso não restringe nada (são no máximo $n$ clientes), mas o VRPSolver precisa de um recurso principal que cresça ao longo do caminho, para o conjunto de caminhos ser finito.

**Mestre:**

$$\min \sum_{(i,j)} c_{ij}\, x_{ij} + \sum_{(i,j),\,c} d^c_{ij}\, y^c_{ij}$$

$$\sum_j x_{vj} = \sum_i x_{iv} \quad \forall v \qquad (\text{fluxo do caminhão; redundante, pois cada caminho já é um fluxo})$$

$$\underbrace{\sum_i x_{iv}}_{\text{caminhão para em } v} + \underbrace{\sum_{i,j} y^v_{ij}}_{\text{drone atende } v} = 1 \quad \forall v \in C$$

O fluxo usa só $x$, porque a perna do caminhão é a mesma com ou sem drone (por isso não há $z$). O $y$ aparece só na cobertura.

**Packing sets em arcos.** No slide, o packing set de $v$ tem os arcos que chegam em $v$ **e** os arcos-sortie que atendem $v$. Assim, o arco $(i, j)^c$ fica nos packing sets de $c$ e de $j$, e eles se interceptam. **A versão instalada não aceita isso.** A versão disjunta, válida, é:

$$P_v = \{\text{arcos diretos } (i, v)\} \cup \{\text{arcos-sortie } (i, j)^v\} \quad \forall v \in C$$

Cada arco-sortie fica só no packing set do cliente que o **drone** atende. Cada $P_v$ contém só arcos que atendem $v$, então $\sum_p \sum_{a \in P_v} h^p_a \lambda_p \le 1$ continua valendo. A diferença em relação à versão com interseção é que o pricing não impede, sozinho, que o caminhão chegue em $v$ por um arco-sortie de outro cliente depois de o drone ter atendido $v$. O mestre corta essas rotas (cobertura $= 1$), mas o limite fica um pouco mais fraco.

**Branching:** em $x$ e em $y$.

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `VRPD/Instancias/*.tsp` | eil51, berlin52, st70, eil76 e kroA100 da TSPLIB |
| `VRPD/referencias_cplex.csv` | ótimos calculados com um MIP no CPLEX, para os pares $(R, \alpha)$ da tabela abaixo |
| `VRPD/vrpd_parser.jl` | `read_vrpd(path; R, α)` e auto-teste |
| `VRPD/toy_vrpd.vrp` | toy, com `DRONE_RANGE` e `DRONE_ALPHA` no cabeçalho |

### Parser

```julia
include("vrpd_parser.jl")
inst = read_vrpd(joinpath(@__DIR__, "toy_vrpd.vrp"))                          # R = 20, α = 0.2 do arquivo
inst = read_vrpd(joinpath(@__DIR__, "Instancias", "eil51.tsp"); R = 20, α = 0.2)
inst.n, inst.C, inst.R, inst.α, inst.c[i+1, j+1]                               # depósito 0, clientes 1..n
```

Auto-teste: `julia vrpd_parser.jl` → `OK: toy + 5 instâncias da TSPLIB lidas`.

### Instância toy — `toy_vrpd.vrp`

$R = 20$, $\alpha = 0.2$, custo nint.

| Vértice | 0 (depósito) | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| (x, y) | (0, 0) | (10, 0) | (20, 0) | (30, 0) | (5, 8) | (15, −8) | (25, 9) | (18, −15) |

**Ótimo (DP exata, conferido no CPLEX): 81.6**, com cutoff `81.61`.
- Caminhão: 0-1-2-3-7-5-0, custo 74.
- Sorties: na perna 0 → 1, o drone atende 4 ($9 + 9 = 18 \le 20$, custo $0.2 \cdot 18 = 3.6$); na perna 2 → 3, o drone atende 6 ($10 + 10 = 20$, custo 4). A solução espelhada (sentido inverso) tem o mesmo custo.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem arcos-sortie (só o caminhão; equivale a $R = 0$) | **91**, o TSP |
| Sem o limite de alcance $R$ | **66.6** |
| Custo do drone ignorado ($\alpha = 0$) | **72** |
| $x$ mapeada só nos arcos diretos | a perna do caminhão na sortie sai de graça, e $j$ deixa de ser coberto quando o caminhão chega por um arco-sortie |
| Packing sets com interseção (como no slide) | erro `an arc cannot belong to more than 1 packing set` na versão instalada |

### Atenção para a modelagem

- `add_arc_var_mapping!(G, a, [x[(i, j)], y[(i, j, c)]])` no arco-sortie: um arco, duas variáveis, como o $z$ do custo fixo.
- Gere só os arcos-sortie que respeitam $R$. Para os pares $(R, \alpha)$ do benchmark, isso dá: eil51 com 2550 arcos diretos e 940 sorties, berlin52 com 2652 e 1208 ($R = 200$), st70 com 4830 e 1612, eil76 com 5700 e 3910. Com $R = 400$, o berlin52 tem 7082 sorties, e o MIP de verificação no CPLEX não fechou em 1 h.
- `set_arc_packing_sets!` recebe uma lista de listas de `(G, arc_id)`. Guarde os ids devolvidos por `add_arc!` ao montar os arcos.
- `define_elementarity_sets_distance_matrix!` com a matriz $c$ entre clientes, que também indexa os packing sets em arcos.

### Referências para o benchmark (`referencias_cplex.csv`)

Com $R = 0$ não há sortie, e o resultado é o ótimo do TSP: eil51 = 426, berlin52 = 7542, st70 = 675, eil76 = 538, kroA100 = 21282. É uma boa verificação estrutural.

| Instância | $R$ | $\alpha$ | Ótimo (CPLEX) | Sorties | cutoff |
|---|---|---|---|---|---|
| eil51 | 20 | 0.2 | 367.0 | 17 | `367.01` |

As outras instâncias não têm referência do CPLEX: as rodadas foram interrompidas, e o VRPSolver passa a ser a referência.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | 81.6 (raiz, 1 nó; caminhão 0-1-2-3-7-5-0, sorties 0→4→1 e 2→6→3) | 81.6 | 0.65 s |
| eil51 ($R = 20$, $\alpha = 0.2$) | interrompida, sem resultado: pesada demais com 2550 arcos diretos + 940 sorties | 367.0 (CPLEX, 61.5 s) | — |

---

## BPP — Bin Packing (slides 122 a 127)

### Definição

Itens $T$ com pesos $w_t$ e bins idênticos de capacidade $Q$. O objetivo é empacotar todos os itens usando o menor número de bins.

### Modelo no VRPSolver

**Grafo** (um caminho = um bin): vértices $v_0, \dots, v_{|T|}$, source $v_0$, sink $v_{|T|}$, $L = 0$, $U = |T|$. Entre $v_{t-1}$ e $v_t$ há dois arcos paralelos:
- $a_t^+$: o item $t$ entra no bin; consome $w_t$;
- $a_t^-$: o item fica fora; consome 0.

O recurso de capacidade (principal) tem limites $[0, Q]$.

**Mestre** (variáveis **inteiras**, `Int`):

$$\min\ x_0 \qquad \text{s.a.} \qquad x_t = 1 \quad \forall t \in T$$

- $M(x_t) = \{a_t^+\}$: cada item é empacotado uma vez.
- $M(x_0) = \{a_1^+, a_1^-\}$: todo caminho passa por exatamente um dos dois arcos do item 1, então $x_0 = \sum_p \lambda_p$ = nº de bins.

**Packing sets em arcos:** $\{\{a_t^+\} : t \in T\}$; cada arco "item dentro" aparece no máximo uma vez.

**Branching:** em $x$ não há onde ramificar. $x_t = 1$ é fixo, e $x_0$ pode ser inteiro com $\lambda$ fracionário. Por isso o **Ryan-Foster** sobre os packing sets (itens $i$ e $j$ juntos ou separados) é necessário e suficiente para a corretude: `enable_packset_ryanfoster_branching!(model, 1)`.

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `BPP/Instancias/Falkenauer_U120/*.txt` | 20 instâncias, $n = 120$, $Q = 150$ |
| `BPP/Instancias/Falkenauer_U250/*.txt` | 20 instâncias, $n = 250$, $Q = 150$ |
| `BPP/Instancias/Falkenauer_T60/*.txt` | 20 *triplets*, $n = 60$; empacotamento perfeito, com cada bin cheio. Convertidas para inteiros: $\times 10$, $Q = 1000$ |
| `BPP/Instancias/Hard28/*.txt` | 28 instâncias difíceis de Schoenfield, $n$ de 160 a 200, $Q = 1000$ |
| `BPP/otimos.csv` | ótimos da BPPLIB (`Solutions.xlsx`) e $\lceil \sum w / Q \rceil$ |
| `BPP/bpp_parser.jl` | `read_bpp(path)` e auto-teste |
| `BPP/toy_bpp.txt` | toy do slide 123 |

### Parser

```julia
include("bpp_parser.jl")
inst = read_bpp(joinpath(@__DIR__, "toy_bpp.txt"))
inst = read_bpp(joinpath(@__DIR__, "Instancias", "Falkenauer_U120", "u120_00.txt"))
inst.n, inst.Q, inst.w[t]
```

O cabeçalho da OR-Library traz o melhor valor conhecido **de 1996**, que está desatualizado em u120_08 (51, mas o ótimo é 50), u120_19 (50 → 49), u250_07 (104 → 103) e u250_12 (106 → 105). O `otimos.csv` usa os ótimos da BPPLIB.

Auto-teste: `julia bpp_parser.jl` → `OK: toy + 88 instâncias da BPPLIB lidas (Falkenauer U120/U250/T60 e Hard28)`.

### Instância toy — `toy_bpp.txt`

$w = (6, 5, 4, 3, 2)$, $Q = 8$. **Ótimo: 3 bins**: {6, 2}, {5, 3}, {4}, com cutoff `3.01`. O peso total é 20, então $\lceil 20/8 \rceil = 3$.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| $x_0$ mapeada só em $a_1^+$ | **1**: só conta o bin que leva o item 1 |
| $x_0$ mapeada em todos os arcos | **15** $= 5 \cdot 3$: cada caminho passa por $n$ arcos |
| Packing sets nos vértices $v_t$ | **inválido**: todo caminho passa por todos os $v_t$, então a propriedade de packing set não vale |
| **$x$ contínuas** (sem `Int`) | **47 na u120_00** ($< \lceil \sum w/Q \rceil = 48$): o VrpSolver passa as colunas mapeadas como `'C'`, o BaPCod não vê nada inteiro a exigir e aceita a solução da relaxação como incumbente. Os "bins" impressos repetem itens (74, 84, 117…), porque os $\lambda$ são fracionários. Na toy não aparece, porque a relaxação já é inteira |
| Sem Ryan-Foster | o modelo fica sem regra de branching correta. Vale testar na toy e numa Falkenauer para ver o que o VRPSolver faz |

### Atenção para a modelagem

- O objetivo $\min x_0$ tem coeficiente inteiro e todas as variáveis são mapeadas, então o VRPSolver arredonda o limite para cima. Um LP de 47.3 já prova 48.
- $U = n$ no lugar do $\infty$ do slide.
- Não é preciso `define_elementarity_sets_distance_matrix!`: o grafo é acíclico, e o ng não tem o que relaxar.

### Referências para o benchmark (`otimos.csv`)

| Instância | $n$ | $Q$ | Ótimo | $\lceil \sum w/Q \rceil$ | cutoff |
|---|---|---|---|---|---|
| u120_00 | 120 | 150 | 48 | 48 | `48.01` |
| u120_08 | 120 | 150 | 50 | 50 | `50.01` |
| u250_00 | 250 | 150 | 99 | 99 | `99.01` |
| u250_13 | 250 | 150 | 103 | 102 | `103.01` |
| t60_00 | 60 | 1000 | 20 | 20 | `20.01` |
| Hard28 BPP14 | 160 | 1000 | 62 | 61 | `62.01` |
| Hard28 BPP832 | 160 | 1000 | 60 | 60 | `60.01` |

As T60 e a Hard28 são as difíceis. Nas T60 todo bin fica exatamente cheio no ótimo. A Hard28 é o conjunto clássico de instâncias difíceis para métodos baseados em LP. Em BPP14 e u250_13, $\lceil \sum w/Q \rceil$ é menor que o ótimo.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | 3 (raiz, 1 nó; {4, 3}, {5, 2}, {6}) | 3 | 0.70 s |
| u120_00 | 48 (raiz 48 arredondada, 35 nós; cada item em exatamente um bin) | 48 | 119.31 s |

---

## Fontes

- Roboredo, M., Lima, D., Silva, J. M. P., Uchoa, E. (2024). Branch-cut-and-price algorithms for two routing problems with hotel selection. *Computers & Industrial Engineering* 196, 110467. <https://doi.org/10.1016/j.cie.2024.110467> · código e instâncias: <https://github.com/mcroboredo/TSPHS_OPHS>
- Barbosa, L. H. S. (2018). *A branch-cut-and-price algorithm for the traveling salesperson problem with hotel selection*. Tese (Doutorado em Engenharia de Produção), UFF. <https://app.uff.br/riuff/handle/1/7606> · Barbosa, L. H., Uchoa, E. (2020). *Computers & Operations Research*, <https://doi.org/10.1016/j.cor.2020.104986>
- Vansteenwegen, P., Souffriau, W., Sörensen, K. (2012). The travelling salesperson problem with hotel selection. *JORS* 63(2), 207–217.
- Divsalar, A., Vansteenwegen, P., Cattrysse, D. (2013). A variable neighborhood search method for the orienteering problem with hotel selection. *International Journal of Production Economics* 145(1), 150–160. Instâncias: <https://www.mech.kuleuven.be/en/mim/op/OPHSinstances>
- Sohrabi, S., Ziarati, K., Keshtkaran, M. (2021). New instances for the Orienteering Problem with Hotel Selection. Mendeley Data, <https://doi.org/10.17632/bct4g4w9y2.1>
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
- Delorme, M., Iori, M., Martello, S. (2018). BPPLIB: a library for bin packing and cutting stock problems. *Optimization Letters* 12(2), 235–250. <https://github.com/mdelorme2/BPPLIB>
- Falkenauer, E. (1996). A hybrid grouping genetic algorithm for bin packing. *Journal of Heuristics* 2(1), 5–30 (OR-Library, `binpack1`, `binpack2`, `binpack5`).
- Reinelt, G. (1991). TSPLIB — A traveling salesman problem library. *ORSA Journal on Computing* 3(4), 376–384.

## Notas relacionadas

- [Complementares 3 no VRPSolver - VRPB, SDVRP, FSMVRP, PDPTW, E-VRP e Rich VRP](README-complementares-3.md) · [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md) · [Complementares no VRPSolver - CVRP, OVRP e custo fixo](README.md)
- [TOP no VRPSolver - Instâncias, toy e parser](../TOP/README.md) (visitas opcionais com lucro, como o OPHS) · Como modelar no VRPSolver - Subproblemas, recursos e conjuntos
