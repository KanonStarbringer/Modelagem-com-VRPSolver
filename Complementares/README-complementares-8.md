# Complementares 8 no VRPSolver — VRPTWMD-2R

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos à pasta `Complementares/`.

Data: 2026-10-20
Contexto: oitava leva, saída do artigo de Senna, Coelho, Morabito e Munari (TR-C, 2027) sobre o **VRPTWMD-C2R**. O site do Munari só traz instâncias e resultados da versão anterior, o **VRPTWMD-2R** (relatório CIRRELT-2023-35). Por isso, o exercício fecha no 2R, e o C2R fica como extensão. O ponto de partida é o VRPTW da [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md).

| Problema | O que muda em relação ao VRPTW | Ideia nova no VRPSolver |
|---|---|---|
| **VRPTWMD-2R** | o veículo para num **parking** de cada cluster e de lá até $l \le 3$ **entregadores** atendem os clientes **a pé**; o veículo espera todos voltarem | as rotas a pé ficam **fora do pricing**: o parser enumera **padrões** (partição dos clientes do cluster em até $l$ rotas a pé), e cada padrão vira um arco com consumo de tempo $\Delta$ e janela $[E, \cdot]$; um grafo por tamanho de equipe $l$ |

---

## Definição

Um depósito, $n$ clusters (cada um com um parking e seus clientes), frota de $K = 25$ veículos de capacidade $Q = 200$. Cada cliente tem demanda, janela $[a_c, b_c]$ e tempo de serviço; cada parking tem janela $[a_i, b_i]$. Cada veículo sai com $l \in \{1, 2, 3\}$ entregadores e:
- visita uma sequência de parkings; em cada um, os entregadores saem a pé (velocidade 1/3 da do veículo) e atendem **todos** os clientes daquele cluster;
- o veículo só parte quando o último entregador volta;
- cada cluster é atendido por exatamente um veículo, numa única parada ("2R": dois níveis de rota, veículo e a pé).

Custo: $f_v = 1000$ por veículo, $f_d = 100$ por entregador, $c_v = 10$ por unidade de distância do veículo e $c_d = 1$ por unidade a pé.

## Modelo no VRPSolver

**Padrões (no parser).** Para cada cluster $i$, enumero as partições dos seus clientes em até 3 rotas ordenadas. Uma rota a pé que sai do parking em $s$:
- volta em $\max(s + \delta, \varepsilon)$, onde $\delta$ é a duração sem espera e $\varepsilon$ o retorno mais cedo possível, por causa das aberturas de janela;
- só é viável se $s \le L$ (sair depois de $L$ fura a janela de algum cliente).

Um padrão junta suas rotas: $\Delta = \max \delta$, $E = \max \varepsilon$, $L = \min L$ e dist = soma das distâncias a pé. Em $P[l]$ ficam só os padrões com até $l$ rotas que nenhum outro domina (dist, $\Delta$, $E$ menores e $L$ maior). Nas 145 instâncias, o maior $|P[l]|$ por cluster somado é 43, 95 e 121 para $l = 1, 2, 3$.

**Grafos:** um $G_l$ por $l = 1..3$. Vértices: depósito 0; chegada $i$ e saída $n+i$ de cada parking; início e fim de cada padrão $k$ de $P[l]$.
- Arco do veículo $(\text{saída de } i) \to j$: consumo de tempo $d_{ij}$ e de capacidade $q_j$.
- Padrão: $i \to \text{ini}(k) \to \text{fim}(k) \to \text{saída de } i$. O arco do meio consome $\Delta_k$.
- Janelas do recurso de tempo: $[a_i, b_i]$ na chegada, $[a_i, L_k]$ em ini$(k)$ e $[E_k, b_0]$ em fim$(k)$. Com isso, a saída do parking fica em $\max(s + \Delta, E)$, como na rota a pé.

**Variáveis:** $x_{l,(i,j)}$ (inteira) para os arcos do veículo e $y_{l,k}$ (inteira) para os padrões. O custo do arco que sai do depósito inclui $f_v + l f_d$.

**Mestre:**

$$\min \sum_{l,(i,j)} \big([i = 0](f_v + l f_d) + c_v d_{ij}\big)\, x_{l,ij} + \sum_{l,k} c_d\, \text{dist}_k\, y_{l,k}$$

$$\text{s.a.} \quad \sum_l \sum_j x_{l,(j,i)} = 1 \;\; \forall i, \qquad \sum_l \sum_j x_{l,(0,j)} \le K$$

**Packing sets:** a chegada a cada parking, em todos os $G_l$. ng-paths com a matriz $d$. Branching: prioridade 2 em $x$, 1 em $y$. Sem RCC: com $Q = 200$, a capacidade quase não aperta.

### Convenções (validadas pelos ótimos publicados)

- Distância euclidiana **truncada** e **Floyd–Warshall separado por nível**: depósito e parkings para o veículo; parking e clientes de cada cluster para os entregadores.
- Tempo a pé = 3 × distância. Sem tempo de serviço no parking. Os entregadores saem na chegada do veículo, e a espera é permitida.
- Sem reclustering: uso os clusters do arquivo.

Recalculei as soluções sem Floyd–Warshall e 113 das 121 com log deixam de bater (o custo muda e algumas janelas estouram por 1). Com Floyd–Warshall, as 131 com ótimo conhecido batem exatamente, o que mostra que os autores usam a mesma convenção.

## Arquivos

Pasta `Complementares/VRPTWMD/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/Solomon_<tam>/` | 145 instâncias (5 tamanhos × 29: 10_40, 15_60, 15_85, 20_80, 25_125 = clusters_clientes), do [site do Munari](https://www.dep.ufscar.br/munari/vrptwmd/) |
| `referencias.csv` | LB, UB e status de ótimo de Senna et al. (planilha `VRPTWMD2R_Results.xlsx`); 131 ótimas e 14 abertas |
| `vrptwmd_parser.jl` | `read_vrptwmd(path)`: leitura, Floyd–Warshall e geração de padrões; auto-teste com a toy e as 145 |
| `toy_vrptwmd.txt` | toy: 3 clusters, 8 clientes; ótimo 2918 por força bruta |
| `vrptwmd_model.jl` | o modelo (roda uma instância; imprime veículos, horários e rotas a pé e confere o custo) |
| `vrptwmd_batch.jl` | `julia vrptwmd_batch.jl [filtro] [limite_s]`: roda o modelo em todas, grava `resultados.csv` e `logs/<inst>.log` |
| `verifica_vrptwmd.py` | verificador independente: refaz horários, janelas, capacidade e custo a partir das rotas do log, sem padrões |

## Resultados

Todas com cutoff = UB publicado + 0,01 e limite de 3600 s.

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **2918**, 1 nó | 2918 (força bruta) | 0,74 s |
| C101_10_40 | **5138**: 3 veículos, 6 entregadores, distâncias 131/228 | 5138 | 0,77 s |
| R101_10_40 | **10602**: 6 veículos, 13 entregadores, 312/182 | 10602 | 0,83 s |
| RC101_10_40 | **10022**: 5 veículos, 10 entregadores, 381/212 | 10022 | 0,72 s |

### Batch das 145

**Todas as 145 com ótimo provado**, em cerca de 22 min no total. 141 fecharam na raiz. Só 4 ramificaram: C104_20_80 (39 nós), C109_20_80 (11), C104_25_125 (7) e C109_25_125 (3).

| Tamanho | Tempo total | Mais lenta |
|---|---|---|
| 10_40 | 7 s | RC104_10_40, 1,4 s |
| 15_60 | 45 s | C104_15_60, 25 s |
| 15_85 | 24 s | C109_15_85, 5,7 s |
| 20_80 | 1221 s | C104_20_80, 1156 s |
| 25_125 | 32 s | C104_25_125, 16 s |

| Comparação com Senna et al. | Instâncias |
|---|---|
| igual ao ótimo publicado | 131 |
| aberta no artigo; provamos que o UB publicado é ótimo | 9 |
| aberta no artigo; achamos solução melhor e provamos o ótimo | **5** |

**Comparação com o melhor método do artigo** (BBC3 = branch-and-Benders-cut com path cuts e rounded capacity inequalities, Tabela 3 do EJOR; Gurobi 10.0.2, 8 threads, 7200 s):

| Tamanho | BBC3: UB médio | BBC3: gap | BBC3: tempo | BBC3: ótimos | VRPSolver: UB médio | VRPSolver: gap | VRPSolver: tempo | VRPSolver: ótimos |
|---|---|---|---|---|---|---|---|---|
| 10–40 | 7.131 | 0,00% | 25 s | 29 | 7.131 | 0 | 0,24 s | 29 |
| 15–60 | 10.228 | 0,56% | 448 s | 28 | 10.228 | 0 | 1,5 s | 29 |
| 15–85 | 12.116 | 0,51% | 382 s | 28 | 12.116 | 0 | 0,8 s | 29 |
| 20–80 | 13.975 | 5,06% | 2.010 s | 22 | 13.968 | 0 | 42 s | 29 |
| 25–125 | 19.045 | 5,30% | 2.032 s | 22 | 19.005 | 0 | 1,1 s | 29 |
| **Total** | 12.499 | 2,29% | 980 s | 129 | **12.490** | **0** | **9,2 s** | **145** |

Média de veículos e de entregadores nas soluções (colunas # veh e # del do EJOR):

| Tamanho | BBC3: # veh | BBC3: # del | VRPSolver: # veh | VRPSolver: # del |
|---|---|---|---|---|
| 10–40 | 3,69 | 8,41 | 3,69 | 8,41 |
| 15–60 | 5,10 | 12,55 | 5,10 | 12,55 |
| 15–85 | 6,14 | 15,69 | 6,14 | 15,69 |
| 20–80 | 6,90 | 16,62 | 6,90 | 16,59 |
| 25–125 | 9,34 | 24,03 | 9,34 | 24,03 |
| **Total** | 6,23 | 15,46 | 6,23 | 15,46 |

Iguais em tudo, exceto 20–80, onde temos um entregador a menos no total (16,59 × 29 = 481, contra 482). No agregado, as melhorias de custo vêm quase todas de distâncias menores, e não de frota ou equipe menores. Caso a caso, não dá para afirmar: o artigo só publica médias.

O nosso tempo é o do BaPCod (`bcTimeMain`) e não inclui a geração de padrões no parser, que leva 0,34 s por instância em média e no máximo 1,05 s. As máquinas são diferentes. A Tabela 1 (CF1–CF3) e a Tabela 2 (BBC1 vs. BBC2) são ablações internas do artigo; todas ficam abaixo do BBC3. A Tabela 4 (cortes de Benders) não tem equivalente aqui: 141 das 145 fecharam na raiz, e a maior árvore teve 39 nós.

**As 14 abertas** (artigo: formulação compacta e branch-and-Benders-cut no Gurobi, 7200 s):

| Instância | LB publ. | UB publ. | Ótimo aqui | Tempo (s) |
|---|---|---|---|---|
| C104_15_60 | 4862,35 | 5801 | 5801 | 25,4 |
| C104_15_85 | 6393,43 | 7500 | 7500 | 3,4 |
| C103_20_80 | 5655,15 | 8361 | **8357** | 20,3 |
| C104_20_80 | 4544,25 | 8008 | **7906** | 1156,2 |
| R104_20_80 | 13546 | 15567 | 15567 | 0,7 |
| R108_20_80 | 11720,7 | 13934 | 13934 | 0,3 |
| RC104_20_80 | 16207,2 | 16724 | 16724 | 0,3 |
| RC108_20_80 | 13262 | 14876 | 14876 | 0,2 |
| C103_25_125 | 7850,24 | 10667 | **10333** | 1,0 |
| C104_25_125 | 6407 | 10627 | **10062** | 15,9 |
| C109_25_125 | 7706 | 10550 | **10290** | 5,3 |
| R104_25_125 | 16824 | 19962 | 19962 | 0,9 |
| RC104_25_125 | 17498 | 21086 | 21086 | 0,4 |
| RC108_25_125 | 18651 | 21204 | 21204 | 0,4 |

**Verificação independente.** `verifica_vrptwmd.py` simula cada solução do zero a partir das rotas do log, sem usar os padrões. Ele confere janelas de parkings, clientes e depósito, capacidade, cobertura exata de clusters e clientes e o limite de veículos, e recalcula o custo. Resultado: **145 soluções verificadas, 0 erros**, com o custo igual ao do log em todas. As 24 primeiras 10_40 rodaram antes de o batch gravar logs; elas foram rodadas de novo numa cópia, para gerar os logs, e deram o mesmo ótimo.

As 5 melhorias são soluções viáveis, com o custo indicado, sob a convenção que reproduz os 131 ótimos. "Ótimo" vale para este modelo, ou seja, B&P do VRPSolver sobre os padrões não dominados.

**Por que o VRPSolver vai tão bem aqui:** a parte difícil (rotas a pé com janelas) sai do pricing e vira um conjunto pequeno de padrões por cluster. O que sobra é um VRPTW com até 25 clusters, e o pricing com recursos fecha quase tudo na raiz. As instâncias C (clientes agrupados, janelas largas) são as que ramificam: muitos padrões ficam quase empatados.

---

## Extensão: VRPTWMD-C2R

No C2R, os clientes não vêm agrupados: escolher os parkings e os clusters faz parte do problema, que vira location-routing de dois níveis. Faltam os conjuntos $H_i$ (parkings candidatos de cada cliente), que não estão no site e precisariam ser pedidos aos autores. Também falta outra forma de gerar rotas a pé: enumerar as rotas a pé da R101 não terminou em 10 min.

## Fontes

- Senna, F., Coelho, L. C., Morabito, R., Munari, P. (2024). An exact method for a last-mile delivery routing problem with multiple deliverymen. *European Journal of Operational Research* 317(2), 550–562. (VRPTWMD-2R; formulação compacta e branch-and-Benders-cut, Gurobi 10.0.2, 7200 s). Versão de trabalho: relatório técnico CIRRELT-2023-35 (2023). As tabelas citadas aqui vêm do EJOR, cuja Tabela 3 traz o BBC3 (ausente no relatório).
- Senna, F., Coelho, L. C., Morabito, R., Munari, P. (2027). Last-mile delivery with multiple deliverypersons: formulation and exact solution methods for a two-echelon location-routing problem. *Transportation Research Part C* 194, 106069. (VRPTWMD-C2R)
- Instâncias e resultados: <https://www.dep.ufscar.br/munari/vrptwmd/>
- Solomon, M. M. (1987). Algorithms for the vehicle routing and scheduling problems with time window constraints. *Operations Research* 35(2), 254–265. (origem das coordenadas e janelas)
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.

## Notas relacionadas

- [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md) (o VRPTW, base do recurso de tempo) · [Complementares 7 no VRPSolver - CLRP e 2E-CVRP](README-complementares-7.md) (dois níveis, mas com o 1º nível no mestre)
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos
