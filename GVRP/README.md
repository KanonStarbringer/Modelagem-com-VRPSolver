# GVRP no VRPSolver — toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-16
Contexto: exercício 6 da Lista 1 - Resolução (Generalized VRP). Segue o roteiro de [PTP no VRPSolver - Instâncias, toy e parser](../PTP/README.md).

## Definição

Os clientes são particionados em clusters $C_1, \dots, C_p$, e cada cluster tem uma demanda $q_g$, **atendida por qualquer nó dele**. O problema é escolher rotas de custo mínimo, saindo de 0 e voltando a 0, que visitem **exatamente um nó de cada cluster**, com carga ≤ $Q$ em cada rota. No benchmark de Bektaş et al. (2011), a frota é fixa em $m$ veículos.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `toy_gvrp.gvrp` | Instância toy |
| `gvrp_parser.jl` | `read_gvrp(path)` e auto-teste |

A pasta `GVRP/` do WSL já tem o parser, a toy e o `CVRP.cfg`.

## Benchmark — situação

- **Bektaş, Erdoğan & Røpke (2011)**, *Transportation Science* 45(3). As instâncias derivam das instâncias A, B, P etc. da CVRPLIB, com $\theta \in \{2, 3\}$ (cerca de $n/\theta$ clusters), e têm nomes como `A-n32-k5-C16-V2`, cujo ótimo publicado é **519**.
- **Os arquivos não estão disponíveis.** A página original (`personal.soton.ac.uk/tb12v07/gvrp.html`) responde com 403. O Wayback Machine guardou a página, de 2017, mas não os zips `T2_Rx.zip` e `T3_Rx.zip`. O artigo é pago e não encontrei o texto completo.
- **Gerador (seção 6.1 do artigo, PDF fornecido pelo usuário):**
  - $\Omega = \lceil n/\theta \rceil$ clusters. As sementes são escolhidas o mais longe possível umas das outras, e cada nó vai para um cluster pelo procedimento CLUSTERING de Fischetti, González & Toth (1997).
  - A demanda do cluster é $q_k = \gamma \sum_{i \in C_k} \omega_i$, com "$\gamma = 1/m$". O excesso acima da capacidade é cortado.
  - O número de veículos $\Phi$ vem de um bin packing das demandas dos clusters.
  - Os custos são euclidianos, arredondados para o inteiro mais próximo.
- **Tentei reproduzir o gerador e não consegui** (2026-10-16). Usei as 74 instâncias A/B/P da CVRPLIB.
  - Com $\gamma = 1/\theta$ e arredondamento para cima, o bin packing reproduz o $\Phi$ do nome em **98 de 109** instâncias.
  - Mas os casos que não batem são contraditórios. Em `A-n32-k5-C16-V2`, $\Phi = 2$ exige $\gamma \le 0.488$; em `P-n19-k2-C10-V2`, $\Phi = 2$ exige $\gamma > 0.516$.
  - Os ótimos também não batem. Com o meu gerador e o CBC, P-n19 dá 122 ou 125 (publicado: **147**) e P-n23 dá 270 (publicado: **312**).
  - Conclusão: o "$\gamma = 1/m$" do texto e/ou os detalhes do CLUSTERING não estão descritos o suficiente. **As instâncias que eu gerar não são as de Bektaş et al.**, e comparar com os ótimos publicados não valida nada.
- **Ótimos publicados** (Tabelas A.1 e A.2, coluna $v_{IP}$): `gvrp_bektas_otimos.csv`, com 109 instâncias resolvidas. Ficam guardados para quando os arquivos originais aparecerem.
- As instâncias do **VRPRDL** do usuário (`Programação Inteira - Uchoa/Problema VRPRDL`) **não são** as de Bektaş. O VRPRDL é um caso particular do GVRP **com janelas de tempo** (Ozbaygin et al., 2017). Sem as janelas, essas instâncias viram GVRP puro, mas aí não há ótimo publicado.

## Formato (estilo TSPLIB)

```
DIMENSION : 10        VEHICLES : 4        GVRP_SETS : 5        CAPACITY : 10
EDGE_WEIGHT_TYPE : EUC_2D
NODE_COORD_SECTION    id x y            (id 1 = depósito)
GVRP_SET_SECTION      k id id ... -1    (o cluster 1 contém só o depósito)
DEMAND_SECTION        k q_k             (demanda do cluster)
```

## Parser

```julia
include("gvrp_parser.jl")
inst = read_gvrp(joinpath(@__DIR__, "toy_gvrp.gvrp"))
inst.n, inst.m, inst.Q, inst.p          # clientes, veículos, capacidade, nº de clusters
inst.clusters[g]                        # vértices do cluster g (g = 1..p)
inst.cl[i+1]                            # cluster do vértice i (0 = depósito)
inst.d[i+1]                             # demanda do cluster de i
inst.C[i+1, j+1]                        # custo EUC_2D arredondado (nint da TSPLIB)
```

O id TSPLIB $k$ vira o vértice $k-1$. Os clusters de clientes são renumerados de 1 a $p$. O parser confere que os clusters particionam os clientes.

Auto-teste: `julia gvrp_parser.jl` → `OK: toy lida (4 clusters, 9 clientes)`.

## Instância toy — `toy_gvrp.gvrp`

Depósito em (0, 0); $Q = 10$; $m = 4$; custos EUC_2D arredondados.

| Cluster | $q_g$ | Nós (vértice: coordenadas) |
|---|---|---|
| $C_1$ | 4 | 1: (10, 0) · 2: (20, 6) |
| $C_2$ | 5 | 3: (21, −4) · 4: (30, 0) |
| $C_3$ | 3 | 5: (0, 15) · 6: (−14, 10) · 7: (−4, 25) |
| $C_4$ | 6 | 8: (−12, −10) · 9: (0, −18) |

**Ótimo (força bruta): 96.** Cutoff: `ub = 96.01`.

| Rota | Carga | Custo |
|---|---|---|
| $0\!-\!1\!-\!3\!-\!0$ | 4 + 5 = 9 | 43 |
| $0\!-\!6\!-\!8\!-\!0$ | 3 + 6 = 9 | 53 |

Em $C_3$, o ótimo escolhe o nó 6 (distância 17 do depósito), e não o 5, que é o mais próximo (15). Assim, $C_3$ e $C_4$ cabem na mesma rota. Por isso, escolher o nó mais próximo de cada cluster antes de rotear não dá o ótimo.

Armadilhas que a toy pega:

| Modelo errado | Resultado |
|---|---|
| Grau `== 2` por cliente (visita todos os nós, como no CVRP) | **241**, com 4 rotas |
| $L = \lceil \sum_{\text{todos os nós}} d_i / Q \rceil = 4$ | **124**: força 4 rotas de um cliente cada |
| $U = 1$ | **inviável**: $\sum q_g = 18 > Q$ |

Packing sets singleton, em vez dos clusters, não mudam o valor ótimo, porque a restrição do mestre por cluster já impede dois nós do mesmo cluster. Eles só enfraquecem a relaxação. A toy não pega esse erro.

## Atenção para a modelagem

1. **Grau agregado por cluster:** $\sum_{i \in C_g} \sum_{e \in \delta(i)} x_e = 2$ para $g = 1..p$, na formulação por arestas. Não há `y`.
2. **Packing sets = clusters:** `(G, i) for i in inst.clusters[g for g in 1:p]`.
3. **Distâncias entre packing sets:** a matriz é $p \times p$, com $\min_{i \in C_g, j \in C_h} c_{ij}$. Não é a matriz $c$ dos vértices.
4. **Capacidade:** consumo $d_j$ = demanda do cluster de $j$ (`inst.d[j+1]`), com limites $[0, Q]$.
5. **Limites de caminhos:** $L = \lceil \sum_g q_g / Q \rceil$ (no GVRP, $q_g$ é único por cluster, então isso equivale a usar o mínimo da correção da Lista) e $U = m$ (na versão da Lista, $U = p$).
6. **Grafo:** o do CVRP (source = sink = 0, os dois sentidos de cada aresta). Arestas entre dois nós do mesmo cluster podem ficar de fora, porque nunca são usadas.

## Modelo implementado (2026-10-16)

Arquivo do usuário: `GVRP/gvrp_model.jl`, na pasta do WSL.
- **Problema original:** `x[e in E]` inteiro, sem `y`; objetivo $\min \sum c_e x_e$; grau por cluster $\sum_{i\in C_g}\sum_{e\in\delta(i)} x_e = 2$ para $g = 1..P$; $L = \lceil \sum_g q_g / Q \rceil$, $U = m$.
- **Grafo:** o do CVRP, sem arestas entre nós do mesmo cluster.
- **Recurso:** capacidade, com consumo igual à demanda do cluster do nó de chegada.
- **Packing sets:** um por cluster. A matriz de distâncias é $P \times P$, com a menor distância entre os nós de cada par de clusters.

**Toy:** **custo 96**, igual à força bruta. Resolveu na raiz em 0.63 s. Os nós escolhidos foram {1, 3, 6, 8}, e as arestas formam exatamente as rotas 0-1-3-0 e 0-6-8-0. No cluster 3, o modelo escolheu o nó 6, e não o 5, que é o mais próximo do depósito. Isso confirma que a escolha do nó e o roteamento são decididos juntos.

## Fontes

- Bektaş, T., Erdoğan, G., Røpke, S. (2011). Formulations and branch-and-cut algorithms for the generalized vehicle routing problem. *Transportation Science* 45(3), 299–316. <https://doi.org/10.1287/trsc.1100.0352>
- Ghiani, G., Improta, G. (2000). An efficient transformation of the generalized vehicle routing problem. *EJOR* 122(1), 11–17.
- Ozbaygin, G., et al. (2017). A branch-and-price algorithm for the vehicle routing problem with roaming delivery locations. *Transportation Research Part B* 100, 115–137.

## Notas relacionadas

- Lista 1 - Resolução · VRP Clusterizado e Generalizado
- [PTP no VRPSolver - Instâncias, toy e parser](../PTP/README.md) · Como modelar no VRPSolver - Subproblemas, recursos e conjuntos · VRPSolver
