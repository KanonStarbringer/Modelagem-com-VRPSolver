# TSPHS — Traveling Salesperson Problem with Hotel Selection

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-4.md`](../README-complementares-4.md).

## Definição

Um vendedor visita todos os clientes $C$ numa viagem de vários dias. Cada dia é uma **trip**, de duração máxima $T$ (viagem + serviço $s_j$ dos clientes), que começa e termina num hotel de $H$; a trip seguinte começa no hotel em que a anterior terminou. O tour começa e termina no hotel 1. Objetivo **hierárquico**: 1º minimizar o nº de trips; 2º minimizar a distância total.


## Como rodar

```bash
julia mincut.jl          # auto-teste do corte mínimo
julia tsphs_parser.jl    # auto-teste do parser
julia tsphs_model.jl
```

No topo do `tsphs_model.jl`, escolha a instância, o nº de trips `K` e o cutoff `ub` (ótimo + 0.01). O 1º objetivo (nº de trips) é o menor `K` viável.

## Modelo no VRPSolver (slides 103 a 108)

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

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/instancias_c{50,75,100}/*.txt` | 267 instâncias de Barbosa (2018), copiadas do repositório do professor |
| `referencias_barbosa2018.csv` | trips e comprimento das Tabelas 6.13 a 6.30 da tese (240 instâncias: 90 ótimas, 74 só viáveis, 57 sem solução, 19 inviáveis) |
| `tsphs_parser.jl` | `read_tsphs(path)` e auto-teste |
| `mincut.jl` | `mincut(cap, s, t)` (Edmonds-Karp) para o callback; também usado pelo OPHS |
| `toy_tsphs.txt` | toy |

Na pasta `esta pasta/` há tudo isso e mais o `TSPHS.cfg`: o `CVRP.cfg` com `RCSPmaxNumOfEnumSolutionsForMIP = 0`, como o `TSPHS.cfg` do professor. É uma precaução: o MIP sobre as rotas enumeradas não deve dispensar o callback de conectividade.

## Parser

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

## Instância toy — `toy_tsphs.txt`

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

## Atenção para a modelagem

- **Duas cópias de cada hotel**: $v_h$ só recebe arco do source e $\bar v_h$ só sai para o sink. Assim, cada caminho é exatamente uma trip hotel → clientes → hotel.
- **Arcos $v_h \to \bar v_{h'}$ (trip vazia) consomem $t_{hh'}$.** No `model.jl` do repositório, esses arcos estão sem consumo. Pela definição, uma trip vazia também respeita $T$.
- **Cortes no callback**:
  - monte `cap[i, j] = cap[j, i] = get_value(model.optimizer, x[(i, j)])`;
  - para cada cliente $j$, rode `mincut(cap, 1, j)`; se o fluxo for $< 2$, adicione (1g) com as arestas de $\delta(S)$;
  - para cada hotel $h \neq 1$, compare com $2\bar y_h/(K-1)$ e adicione (1h) como `[x...; y[h]]` com coeficientes `[1...; -2/(K-1)]` e `>= 0`;
  - o nome usado em `add_dynamic_constr!` tem de ser o mesmo de `add_cut_callback!`.
- **`get_value` funciona no callback** para $x$ (mapeada) e para $y$ (não mapeada). Variáveis de caminho ($\lambda$) não podem ser consultadas.
- **$K$ entra no grafo**: `VrpGraph(model, VG, 0, sink, (K, K))`.

## Referências para o benchmark (`referencias_barbosa2018.csv`)

| Instância | $K^*$ | Comprimento ótimo | Tempo na tese | cutoff |
|---|---|---|---|---|
| h05_c50_l150_09 | 9 | 722.2 | 1 s | `722.21` |
| h10_c50_l200_05 | 6 | 601.7 | 7 s | `601.71` |
| h05_c50_l150_02 | 10 | 823.8 | 8 s | `823.81` |
| h10_c50_l200_03 | 6 | 557.4 | 16 s | `557.41` |
| h05_c50_l200_05 | 6 | 677.1 | 135 s | `677.11` |
| h05_c100_l150_08 | 16 | 1196.8 | 110 s | `1196.81` |

Os tempos são do BCP próprio de Barbosa (2018), não do VRPSolver. A coluna `trips_lb` do CSV é o limite inferior de trips da tese. Rodar com $K^* - 1$ deve dar inviável. Roboredo et al. (2024) relatam ótimos para 85 das 102 instâncias que estavam abertas, mas esses valores estão no artigo (pago), não no repositório.

## Resultados

| Instância | $K$ | Obtido | Esperado | Tempo |
|---|---|---|---|---|
| toy | 3 | 76.2 (raiz, 1 nó; $y_2 = 2$) | 76.2 | 1.41 s |
| h05_c50_l150_09 | 9 | 722.2 (raiz, 1 nó; $y = (1, 2, 3, 2, 1)$) | 722.2 | 1.36 s |

## Fontes (da leva)

- Roboredo, M., Lima, D., Silva, J. M. P., Uchoa, E. (2024). Branch-cut-and-price algorithms for two routing problems with hotel selection. *Computers & Industrial Engineering* 196, 110467. <https://doi.org/10.1016/j.cie.2024.110467> · código e instâncias: <https://github.com/mcroboredo/TSPHS_OPHS>
- Barbosa, L. H. S. (2018). *A branch-cut-and-price algorithm for the traveling salesperson problem with hotel selection*. Tese (Doutorado em Engenharia de Produção), UFF. <https://app.uff.br/riuff/handle/1/7606> · Barbosa, L. H., Uchoa, E. (2020). *Computers & Operations Research*, <https://doi.org/10.1016/j.cor.2020.104986>
- Vansteenwegen, P., Souffriau, W., Sörensen, K. (2012). The travelling salesperson problem with hotel selection. *JORS* 63(2), 207–217.
- Divsalar, A., Vansteenwegen, P., Cattrysse, D. (2013). A variable neighborhood search method for the orienteering problem with hotel selection. *International Journal of Production Economics* 145(1), 150–160. Instâncias: <https://www.mech.kuleuven.be/en/mim/op/OPHSinstances>
- Sohrabi, S., Ziarati, K., Keshtkaran, M. (2021). New instances for the Orienteering Problem with Hotel Selection. Mendeley Data, <https://doi.org/10.17632/bct4g4w9y2.1>
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
- Delorme, M., Iori, M., Martello, S. (2018). BPPLIB: a library for bin packing and cutting stock problems. *Optimization Letters* 12(2), 235–250. <https://github.com/mdelorme2/BPPLIB>
- Falkenauer, E. (1996). A hybrid grouping genetic algorithm for bin packing. *Journal of Heuristics* 2(1), 5–30 (OR-Library, `binpack1`, `binpack2`, `binpack5`).
- Reinelt, G. (1991). TSPLIB — A traveling salesman problem library. *ORSA Journal on Computing* 3(4), 376–384.
