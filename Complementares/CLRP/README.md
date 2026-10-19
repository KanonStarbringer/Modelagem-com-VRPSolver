# CLRP — Capacitated Location-Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-7.md`](../README-complementares-7.md).

## Definição

Dados clientes $J$ com demanda $d_j$ e depósitos candidatos $K$, cada um com custo de abertura $f_k$ e capacidade $W_k$, escolher quais depósitos abrir e montar rotas (capacidade $Q$, custo fixo $F$ por rota) que começam e terminam no mesmo depósito aberto, de modo que:
- cada cliente seja visitado por exatamente uma rota;
- a demanda total atendida a partir de $k$ não passe de $W_k$;
- o custo total (abertura + custo fixo das rotas + distância) seja mínimo.

É o MDVRP com custos de abertura e capacidade nos depósitos. Sem a capacidade $W_k$, a solução tende a abrir um só depósito.


## Como rodar

```bash
julia clrp_parser.jl     # auto-teste do parser
julia clrp_model.jl
```

No topo do `clrp_model.jl`, escolha a instância e o cutoff `ub` (BKS + 0.01; ver `referencias.csv`).

## Modelo no VRPSolver

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

## Arquivos

Pasta `esta pasta/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/Prodhon/coord*.dat` | 30 instâncias de Prins, Prodhon & Wolfler Calvo (2006): 20 a 200 clientes, 5 ou 10 depósitos; o sufixo `b` tem $Q = 150$ em vez de 70 |
| `Instancias/Barreto/coord*.dat` | 13 instâncias de Barreto et al. (2007), na versão de Prodhon: 21 a 150 clientes |
| `referencias.csv` | melhor solução conhecida (BKS) de cada instância |
| `clrp_parser.jl` | `read_clrp(path)` e auto-teste |
| `toy_clrp.dat` | toy |
| `clrp_model.jl` | o modelo |

As instâncias vêm do repositório [lrp-instances](https://github.com/alberto-santini/lrp-instances) (Cavagnini, Santini & Schneider), e as BKS, do [NEO-LRP](https://github.com/Subramanyam-Lab/NEO-LRP). Deixei de fora a `coordOr117` de Barreto: tem 28 números a mais que o formato e não entra no conjunto de 13 usado na literatura.

## Parser

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

## Instância toy — `toy_clrp.dat`

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

## Atenção para a modelagem

- **Variável com coeficiente no mapeamento:** `[(x[e], 1.0), (u[k], float(d(j)))]`. O coeficiente de $u_k$ é a demanda do cliente em que o arco **entra**; nos arcos que voltam ao depósito, só $x$.
- **$y$ fora dos grafos:** o VrpSolver aceita variáveis não mapeadas; elas ficam só no mestre.
- **Impressão das rotas:** `get_path_arcs` devolve o grafo e os arcos; no grafo de $k$, o vértice interno $i+1$ é o cliente $i$, e a volta ao depósito cai num **sink interno** (outro índice), não no 1.

## Referências para o benchmark (`referencias.csv`)

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

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy (custos truncados) | **21376** — raiz 21376.00, 1 nó; a solução da força bruta: depósitos 9 (24/25) e 11 (34/35), rotas 9-4-3-7-9, 9-6-9, 11-1-2-11 e 11-5-8-11 (distância 12776 + 4 × 1000 de rotas + 4600 de abertura) | 21376 | 1.05 s |
| coord20-5-1 (custos truncados) | **54769** — raiz 48561.00 (gap 11%), 13 nós; depósitos 22, 23 e 25, 5 rotas. Com $\lceil \cdot \rceil$, as mesmas rotas custam 54793 = BKS: foi isso que mostrou a convenção certa | 54793 | 7.11 s |
| coord20-5-1 | **54793** = BKS — raiz 48572.00 (gap 11,4%), 13 nós; depósitos 22 (138/140), 23 (107/140) e 25 (70/140), 5 rotas. A raiz fraca provavelmente vem da abertura: o LP pode abrir depósitos "em fração" (hipótese, não verificada) | 54793 | 7.21 s |
| coord50-5-1 | **90111** = BKS — raiz 81343.00 (gap 9,7%), 17 nós; depósitos 51, 53 e 54, 12 rotas de 4 ou 5 clientes, nenhum depósito cheio | 90111 | 37.35 s |
| coord50-5-1b | **63242** = BKS — raiz 59978.00 (gap 5,2%), 39 nós; só 2 depósitos (51 cheio, 420/420; 53 com 336/350), 6 rotas de até 10 clientes. Com $Q = 150$ a raiz é mais forte (o gap cai), mas cada nó custa mais: rotas longas pesam no pricing | 63242 | 604.30 s |
| coordGaspelle (Barreto) | **424.899** = BKS 424,9 — raiz 424.90, 1 nó; depósitos 22 e 23, 4 rotas. Custos reais e $F = 0$: o cutoff BKS + 0,1 funcionou | 424.9 | 1.30 s |

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
