# Complementares 3 no VRPSolver — VRPB, SDVRP, FSMVRP, PDPTW, E-VRP e Rich VRP

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos à pasta `Complementares/`.

Data: 2026-10-17
Contexto: Exercícios complementares 3 da Lista 1. Cada exercício tem sua pasta em `Complementares/` e segue o roteiro de [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md). O **VRPB** é o exercício da apresentação na disciplina e é implementado nas duas formulações de Queiroga et al., F1 e F2.

## VRPB

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `VRPB/Instancias/Instancias TV convertidas/*.vrpb` | 33 instâncias de Toth & Vigo (1997), já usadas no Experimento VRPB com Coluna e CPLEX |
| `VRPB/Instancias/Instancias GJB/*.xml` | 68 instâncias de Goetschalckx & Jacobs-Blecha (1989), grupos A a O |
| `VRPB/referencias_tv_artigo.csv`, `referencias_gjb_artigo.csv` | $z_{IP}$ das Tabelas de Queiroga et al. |
| `VRPB/vrpb_parser.jl` | `read_vrpb(path)` e auto-teste |
| `VRPB/toy_vrpb.vrpb` | Toy no formato `.vrpb` |

A pasta `VRPB/` tem também o modelo e o `CVRP.cfg`.

### Parser

```julia
include("vrpb_parser.jl")
inst = read_vrpb(joinpath(@__DIR__, "toy_vrpb.vrpb"))
inst = read_vrpb(joinpath(@__DIR__, "Instancias", "Instancias TV convertidas", "EIL22_50.vrpb"))
inst = read_vrpb(joinpath(@__DIR__, "Instancias", "Instancias GJB", "GA1.xml"))
inst.L, inst.B            # linehauls 1..nL e backhauls nL+1..nL+nB (depósito = 0)
inst.Q, inst.K            # capacidade e frota fixa (nothing nas X = frota livre)
inst.d[i+1], inst.C[i+1, j+1]
```

**Convenções:**
- **TV (`.vrpb`):** custo arredondado, $\lfloor d + 0.5 \rfloor$, com ótimos inteiros. A frota é fixa, `VEHICLES`.
- **GJB (`.xml`):** custo **real**. A frota é fixa.
- **Fronteira no XML das GJB:** o arquivo marca o último linehaul como backhaul. O GA1, por exemplo, vem com 19 linehauls e 6 backhauls, mas o artigo usa 20 e 5. O parser corrige isso, como o leitor do Experimento VRPB.
- **Numeração:** os vértices são renumerados, com o depósito em 0, os linehauls primeiro e os backhauls depois.

Auto-teste: `julia vrpb_parser.jl` → `OK: toy + 33 TV + 68 GJB lidas`.

### Instância toy — `toy_vrpb.vrpb`

Depósito em (0, 0); $Q = 10$; **frota fixa $K = 3$**; custo arredondado.

| Cliente | 1 (L) | 2 (L) | 3 (L) | 4 (B) | 5 (B) | 6 (B) |
|---|---|---|---|---|---|---|
| (x, y) | (−6, 20) | (−11, 13) | (4, −20) | (−16, −10) | (17, −18) | (−1, −19) |
| $d_i$ / $p_i$ | 3 | 3 | 3 | 5 | 5 | 5 |

**Ótimo (força bruta): 170**, com cutoff `170.01`:

| Rota | Custo | Entregas / coletas |
|---|---|---|
| 0-1-0 | 42 | 3 / 0 (rota só com linehaul: permitida) |
| 0-2-4-0 | 60 | 3 / 5 |
| 0-3-6-5-0 | 68 | 3 / 10 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem precedência: backhaul antes de linehaul permitido | **164**: 0-5-3-6-0 |
| Rota só com backhauls permitida (arco 0 → B) | **153**: 0-4-0 |
| Frota livre no lugar de $K = 3$ | **141**: duas rotas, 0-1-2-4-0 e 0-3-6-5-0 |
| Uma capacidade só para entregas + coletas ($\sum d + \sum p \le Q$) | **194** |

### F1 — um grafo, recurso de capacidade com "salto"

É a formulação do script `run_vrpb_vrpsolver.jl` do Experimento VRPB (fora do repositório). Ela reproduziu os 33 ótimos TV no experimento.

- **Variáveis:** $x_a \in \mathbb{Z}_+$ por **arco**. A estrutura é dirigida, então não se usa a formulação por arestas.
- **Arcos:** $A = \{(0,j): j \in L\} \cup (L \times L) \cup (L \times B) \cup (B \times B) \cup \{(i, 0): i \in L \cup B\}$. Não existem arcos $B \to L$ nem $0 \to B$.
- **Mestre:** $\sum_{a \in \delta^-(j)} x_a = 1$ para todo cliente $j$.
- **Grafo:** único, com source = sink = 0 e $L = U = K$.
- **Recurso de capacidade:** consumo $d_j$ no arco $(i, j)$, com 0 na volta ao depósito. Limites por vértice:

| Vértice | $[l, u]$ |
|---|---|
| depósito | $[0, 2Q]$ |
| $i \in L$ | $[0, Q]$ |
| $i \in B$ | $[Q + p_i,\ 2Q]$ |

- **Por que funciona:** o recurso é descartável. Ao entrar no primeiro backhaul $j$, a carga de entregas, que é no máximo $Q$, sobe até o limite inferior $Q + p_j$. A partir daí, o recurso acumula só as coletas, e o limite $2Q$ impõe $\sum p \le Q$. Um recurso só controla as duas capacidades separadamente.
- **Packing sets:** um singleton por cliente, com a matriz de distâncias $C$.

### F2 — dois grafos emparelhados por $z_i = w_i$

É a correção do exercício, segundo a Seção 3.2 e o Apêndice B.2 de Queiroga et al.

- **Variáveis:** $x_a \in \mathbb{Z}_+$ para $a \in A$, o mesmo $A$ da F1; $z_i, w_i \in \mathbb{Z}_+$ para $i \in L$.
- **Mestre:** cobertura $\sum_{a \in \delta^-(j)} x_a = 1$ e emparelhamento $z_i = w_i$ para $i \in L$.
- **Grafo $G^L$:** source $0$, sink $0'$, $L = U = K$.
  - arcos $(0, j)$ e $(i, j)$ em $L$, mapeados para $x$, com consumo $d_j$;
  - arco $(i, i')$, mapeado para **$z_i$**, com consumo 0;
  - arco $(i', 0')$, sem mapeamento, com consumo 0.
- **Grafo $G^B$:** source $0'$, sink $0$, $L = U = K$.
  - arco $(0', i)$ com $i \in L$, mapeado para **$w_i$**, com consumo 0;
  - arcos $(i, b)$, $(b, b')$ e $(\cdot, 0)$, mapeados para $x$, com consumo $p_j$ nos backhauls e 0 no depósito.
- **Capacidade:** $[0, Q]$ nos dois grafos. As entregas são limitadas em $G^L$ e as coletas em $G^B$.
- **Ids dos vértices:** cada grafo tem os seus. As cópias $i'$ e o $0'$ precisam de ids próprios, por exemplo $i' = i + n$ e $0' = 2n + 1$.
- **Packing sets:** um singleton para cada vértice que não é depósito, nos dois grafos, contados como distintos. Em $G^L$ são os $i$ e os $i'$; em $G^B$, os conectores $i \in L$ e os $b \in B$.
- **Arcos $(0', b)$ com $b \in B$:** são dispensáveis. Como $\sum z = K = \sum w$, todo caminho de $G^B$ começa num conector linehaul.
- **Exemplo na toy:** a rota 0-3-6-5-0 é o par $G^L$: 0 → 3 → 3′ → 0′ com $z_3 = 1$, mais $G^B$: 0′ → 3 → 6 → 5 → 0 com $w_3 = 1$. A rota 0-1-0 é o par 0 → 1 → 1′ → 0′ e 0′ → 1 → 0.

### Resultados

| Formulação | Instância | Obtido | Esperado | Tempo |
|---|---|---|---|---|
| F1 | toy | **170** — 0-1-0, 0-2-4-0, 0-3-6-5-0; raiz, 1 nó | 170 | 0.66 s |
| F1 | EIL22_50 | **371** — 3 rotas; raiz, 1 nó | 371 | 0.74 s |
| F2 | toy | **170** — mesmos arcos da F1; conectores $z = w$ em {1, 2, 3}; raiz, 1 nó | 170 | 0.58 s |
| F2 | EIL22_50 | **371** — 3 rotas; conectores {1, 2, 9}; raiz, 1 nó | 371 | 0.59 s |
| F1 | GA1 (custo real) | **229885.6454** — 8 rotas; raiz, 1 nó (conferido: 25 clientes, precedência e cargas ok) | 229885.65 | 0.67 s |
| F2 | EIL51_50 | **559** — 3 rotas; conectores {10, 16, 20}; raiz, 1 nó (conferido: 50 clientes, cargas ≤ 160) | 559 | 1.07 s |
| F1 | EIL51_50 | **559** — 3 rotas (ótimo alternativo ao da F2); raiz, 1 nó (conferido) | 559 | 1.35 s |
| F1 | EILA76_50 | **739** — 6 rotas; raiz, 1 nó (conferido: 75 clientes, precedência e cargas ok) | 739 | 3.91 s |
| F2 | EILA76_50 | **739** — 6 rotas; conectores {21, 28, 30, 31, 33, 36}; raiz, 1 nó (conferido) | 739 | 1.66 s |
| F1 | EILB101_66 | **982** — 9 rotas; raiz 978.00, **9 nós** (conferido: 100 clientes, precedência e cargas ok) | 982 | 269.41 s |
| F2 | EILB101_66 | **982** — mesmos arcos da F1; raiz 972.00, **27 nós** | 982 | 193.71 s |
| F1 | GJ4 (custo real) | **296533.1646** — 7 rotas; raiz 294229.19, **5 nós** (conferido: 94 clientes, precedência e cargas ok) | 296533.16 | 200.60 s |
| F2 | GJ4 (custo real) | **296533.1646** — mesmos arcos da F1; raiz 293291.97, **25 nós** | 296533.16 | 189.25 s |

### Comparação F1 × F2

| Instância | F1: raiz / nós / tempo | F2: raiz / nós / tempo |
|---|---|---|
| EIL22_50 | 371.00 / 1 / 0.74 s | 371.00 / 1 / 0.59 s |
| EIL51_50 | 559.00 / 1 / 1.35 s | 559.00 / 1 / 1.07 s |
| EILA76_50 | 739.00 / 1 / 3.91 s (repetição: 3.62 s) | 739.00 / 1 / 1.66 s |
| EILB101_66 | 978.00 / 9 / 269.41 s (raiz em 114.26 s) | 972.00 / 27 / 193.71 s (raiz em 34.55 s) |
| GJ4 | 294229.19 / 5 / 200.60 s (raiz em 68.78 s) | 293291.97 / 25 / 189.25 s (raiz em 35.73 s) |

**GJ4:** o padrão da EILB101_66 se repete com custo real.
- **Raiz:** a F1 é mais forte, com gap de 0.78% contra 1.09% da F2.
- **Tempo da raiz:** a F2 é 1.9× mais rápida.
- **Nós:** a F2 precisa de 5× mais (25 contra 5).
- **Tempo total:** praticamente empatam, com a F2 6% mais rápida.

Quanto maior o gap da raiz, mais a árvore maior da F2 consome a vantagem do pricing.

**Leitura da comparação (para a apresentação):**
- **Até 76 clientes:** as duas fecham na raiz com o mesmo limite, e a F2 é mais rápida (até 2.4× na EILA76_50).
- **EILB101_66:** aparece o compromisso entre as duas.
  - A **F1 tem raiz mais forte**: 978 contra 972, um gap de 0.41% contra 1.02%.
  - A **F2 tem pricing mais barato**: a raiz leva 34.55 s contra 114.26 s, 3.3× mais rápida.
  - Com a raiz mais fraca, a F2 precisa de 3× mais nós (27 contra 9). Mesmo assim, termina **28% mais rápido** (193.71 s contra 269.41 s).
- **Coerência com o artigo:** a raiz da F2 também é mais fraca lá (973.95 contra 976.22, segundo a nota do experimento). A ordem de qualidade dos limites se repete.
- **Por que a F1 tem limite melhor:** na F1, cada coluna é uma rota completa, e os cortes (rank-1, RCC) atuam sobre rotas inteiras. Na F2, as colunas são **meias-rotas** emparelhadas por $z_i = w_i$. A relaxação pode combinar frações de segmentos que não formam rotas inteiras, o que deixa o limite mais fraco. Em troca, cada pricing explora um grafo menor, só com linehauls ou só com backhauls.

Na EILB101_66, o Experimento VRPB (F1, outro `.cfg`) teve raiz 977.00, 9 nós e 261 s. Segundo a nota do experimento, o artigo relata raiz de 976.22 (BCP-F1) e 973.95 (BCP-F2), e 7 nós.

EIL22_50 (F2) conferido em Julia: mesmas rotas da F1, exceto o fim da terceira, 0-10-11-9-21-20-**19-18**-0 no lugar de …-**18-19**-0, com o mesmo custo 118. É um ótimo alternativo. Os conectores são o último linehaul de cada rota (2, 1 e 9).

**F1 × F2 na EIL22_50:** as duas fecham na raiz com o limite igual ao ótimo, 371.00. A F2 levou 0.59 s e a F1, 0.74 s. Numa instância desse tamanho a diferença é ruído; para comparar as formulações, use instâncias maiores (EIL51, EILx76, EILx101).

Na F2, a matriz de `define_elementarity_sets_distance_matrix!` foi passada com dimensão $3n_L + n_B$ (um índice por packing set, na ordem de `ps_fis`), uma chamada por grafo. O VRPSolver aceitou.

EIL22_50 (F1) conferido em Julia: 0-7-6-2-13-15-0 (102; entrega 3300, coleta 1500), 0-8-5-4-3-1-12-14-16-17-0 (151; 5400 / 3000), 0-10-11-9-21-20-18-19-0 (118; 4200 / 5100). São 21 clientes, linehauls sempre antes dos backhauls, e as duas cargas ≤ Q = 6000.

### Referências para o benchmark

| Instância | $n_L$ / $n_B$ | $K$ | $Q$ | $z_{IP}$ |
|---|---|---|---|---|
| EIL22_50 (TV) | 11 / 10 | 3 | 6000 | **371** |
| EIL22_66 | 14 / 7 | 3 | 6000 | **366** |
| EIL23_50 | 11 / 11 | 2 | 4500 | **682** |
| EIL30_50 | 15 / 14 | 2 | 4500 | **501** |
| EIL33_50 | 16 / 16 | 3 | 8000 | **738** |
| EIL51_50 | 25 / 25 | 3 | 160 | **559** |
| GA1 (GJB) | 20 / 5 | 8 | 1550 | **229885.65** |
| GA2 | 20 / 5 | 5 | 2550 | **180119.21** |
| GB1 | 20 / 10 | 7 | 1600 | **239080.16** |

As tabelas completas estão nos CSVs, nas colunas `z_ip` e `route_count`. O VRPSolver (F1) do Experimento VRPB já reproduziu esses valores:
- **TV:** 33 de 33, todos com ótimo certificado;
- **GJB:** 68 de 68, com 67 certificados. A **GM3** ficou sem certificado.

**Cuidado com a GL1:** o XML tem $Q = 4000$, mas o artigo usa $Q = 4400$, com $z_{IP}$ = 417896.71. Para comparar com o artigo, sobrescreva a capacidade.

## SDVRP

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `SDVRP/Instancias/p01..p23` | 23 instâncias SDVRP de Chao, Golden & Wasil (1999), no formato de Cordeau (type 3), via espelho em pauljmello/HGSADC-vs-ACS-on-SDVRP. Todas **sem limite de duração** |
| `SDVRP/sdvrp_parser.jl` | `read_sdvrp(path)` e auto-teste |
| `SDVRP/toy_sdvrp` | Toy no mesmo formato |

O conjunto "new" de Cordeau & Laporte (pr01–pr12) tem duração máxima D = 500, por isso ficou de fora: o exercício não tem esse limite. A pasta `SDVRP/` tem também o modelo e o `CVRP.cfg`.

### Parser

```julia
include("sdvrp_parser.jl")
inst = read_sdvrp(joinpath(@__DIR__, "toy_sdvrp"))
inst = read_sdvrp(joinpath(@__DIR__, "Instancias", "p07"))
inst.n, inst.K, inst.m     # clientes, nº de tipos, veículos POR tipo (u^k = m para todo k)
inst.Q[k]                  # capacidade do tipo k
inst.comp[i]               # Set dos tipos que podem visitar o cliente i (𝒦_i)
inst.d[i+1], inst.ℓ[i+1, j+1]   # demanda e distância (depósito = 0)
```

**Convenções:**
- **Custo:** é a distância real, **igual para todos os tipos** ($c^k = \ell$). O formato não tem $\alpha_k$.
- **Compatibilidade:** vem como uma bit string lida da esquerda para a direita. Com $t = 3$, o código 4 = 100 significa o tipo 1; o código 2 = 010, o tipo 2; o código 1 = 001, o tipo 3.
- **Frota:** o mesmo $m$ vale para todos os tipos. A p01 tem 5 clientes nas coordenadas do depósito, com demanda 160 e só o tipo 3 permitido, uma herança da construção de Chao et al. Outras instâncias também têm clientes nas coordenadas do depósito; não conferi as demandas deles. O parser lê todos como clientes comuns.

Auto-teste: `julia sdvrp_parser.jl` → `OK: toy + 23 instâncias SDVRP lidas`.

### Instância toy — `toy_sdvrp`

As posições e demandas são as da toy dos complementares. Há dois tipos, com **$m = 1$ veículo de cada**: o tipo 1 tem $Q = 10$ e o tipo 2 tem $Q = 12$. O custo é a distância.

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| $\mathcal{K}_i$ | **{2}** | {1, 2} | {1, 2} | **{1}** | {1, 2} | {1, 2} |

**Ótimo (força bruta): 144.5129**, com cutoff `144.52`:

| Tipo | Rota | Custo | Carga |
|---|---|---|---|
| 2 | 0-1-5-6-0 | 70.2019 | 11 / 12 |
| 1 | 0-2-3-4-0 | 74.3110 | 10 / 10 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem compatibilidade (todos os clientes em todos os grafos) | **117.0883**: tipo 1 0-1-2-3-0 e tipo 2 0-4-5-6-0, que é exatamente o que a compatibilidade proíbe |
| Sem o limite de veículos por tipo ($U^k = n$ no lugar de $m$) | **135.107**: três rotas, duas do tipo 1 |

### Atenção para a modelagem

É o **HFVRP com compatibilidade**: um grafo por tipo, `x[k, e]`, grau somando sobre os tipos, limites $(0, m)$ e capacidade `Q[k]`.
- **Compatibilidade:** o grafo do tipo $k$ só contém os clientes $i$ com $k \in \mathcal{K}_i$. Os outros clientes **não entram** no grafo, e as arestas que tocam neles também não.
- **Arestas e variáveis:** a forma mais simples é criar `x[k, e]` só para as arestas compatíveis, com `E_k = [(i, j) for (i, j) in E if (i == 0 || k in comp[i]) && j in ...]`. A outra opção é criar todas e fixar em zero as incompatíveis.
- **Grau:** `sum(x[k, e] for k in K for e in δ[i] if e in E_k) == 2`.
- **Packing sets:** cada cliente reúne só as cópias dos grafos compatíveis, `[(G[k], i) for k in comp[i]]`.
- **Custo:** `ℓ(i, j)` em todos os tipos. Se quiser treinar o $c^k$ do enunciado, multiplique por um $\alpha_k$ seu.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **144.5129** — tipo 1: 0-2-3-4-0; tipo 2: 0-1-5-6-0; raiz, 1 nó | 144.5129 | 0.74 s |
| p07 | **391.3022** — uma rota por tipo; raiz, 1 nó | 391.3022 (CBC) | 0.90 s |

p07 conferido em Julia. Cada tipo faz uma rota de custo 130.434 com 9 clientes, todos compatíveis:

| Tipo | Clientes | Carga |
|---|---|---|
| 1 | 1–8 e 25 | 130 / 150 |
| 2 | 9–16 e 26 | 170 / 200 |
| 3 | 17–24 e 27 | 210 / 250 |

A instância é simétrica, em "estrela": três pétalas geometricamente iguais, e a compatibilidade define qual tipo atende cada pétala.

| p08 | **664.4632** — 6 rotas, 2 por tipo; raiz, 1 nó | ≤ 1056.29 (CBC, não provado) | 1.08 s |
|---|---|---|---|

p08 conferido em Julia: 6 pétalas de custo 110.744 cada, 2 por tipo ($m = 2$), 54 clientes, todos compatíveis. As cargas são 130 / 150 (tipo 1), 170 / 200 (tipo 2) e 210 / 250 (tipo 3). O **VRPSolver provou o ótimo 664.4632**. A solução do CBC (1056.29) estava 59% acima, o que mostra quão fraca é a formulação MTZ para esse problema.

### Referências para o benchmark

| Instância | $n$ | Tipos (Q) | $m$ | Referência | Fonte |
|---|---|---|---|---|---|
| p07 | 27 | 150 / 200 / 250 | 1 | **391.3022** | CBC, **ótimo provado**; uma rota de cada tipo |
| p08 | 54 | 150 / 200 / 250 | 2 | **664.4632** | **VRPSolver, ótimo provado** na raiz. O CBC tinha parado em 1056.29 com `sol_status = 2` |

Não encontrei online os valores publicados para o conjunto de Chao et al. Comece pela **p07**.

## FSMVRP

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `FSMVRP/Instancias/c*_*{fsmfd,fsmf,fsmd}.txt` | As instâncias 13–20 de Golden et al. (1984) nas três variantes FSM (24 arquivos), dos demos do VRPSolverEasy |
| `FSMVRP/fsmvrp_parser.jl` | Inclui o `read_hfvrp` de `../HFVRP` e tem o auto-teste |
| `FSMVRP/toy_fsmvrp.txt` | Toy no mesmo formato |

A pasta `FSMVRP/` tem também o modelo e o `CVRP.cfg`.

**Variantes:**
- **`fsmfd`:** custo fixo $f^k$ mais custo variável $\alpha_k \ell$. **É o exercício.**
- **`fsmf`:** só custo fixo, com $\alpha = 1$. É o FSM clássico de Golden.
- **`fsmd`:** só custo variável, com $f = 0$.

Nas três, `max = n`, ou seja, frota livre (o enunciado fala em "no máximo $n$ de cada tipo").

### Parser

```julia
include("fsmvrp_parser.jl")            # = read_hfvrp do HFVRP
inst = read_hfvrp(joinpath(@__DIR__, "toy_fsmvrp.txt"))
inst = read_hfvrp(joinpath(@__DIR__, "Instancias", "c50_14fsmfd.txt"))
inst.K, inst.Q[k], inst.f[k], inst.α[k], inst.u[k]   # u[k] = n
```

Auto-teste: `julia fsmvrp_parser.jl` → `OK: toy + 24 instâncias FSM (fsmfd, fsmf, fsmd) lidas`.

### Instância toy — `toy_fsmvrp.txt`

As posições e demandas são as de sempre. Há dois tipos, com frota livre ($u^k = 6$):

| Tipo | $Q^k$ | $f^k$ | $\alpha_k$ |
|---|---|---|---|
| 1 | 7 | 10 | 1.0 |
| 2 | 11 | 35 | 1.1 |

**Ótimo (força bruta): 209.2567**, com cutoff `209.26`. A frota ótima tem 2 veículos do tipo 1 e 1 do tipo 2:

| Tipo | Rota | Distância | Custo ($\alpha \ell + f$) |
|---|---|---|---|
| 2 | 0-1-5-4-0 | 57.9942 | 63.7936 + 35 |
| 1 | 0-2-3-0 | 60 | 60 + 10 |
| 1 | 0-6-0 | 30.4631 | 30.4631 + 10 |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem o custo fixo (é o `fsmd`) | **145.5714**: frota de 2× tipo 2 e 1× tipo 1, com outras rotas |
| Custo fixo nas duas pontas da rota (`z` mapeado em $(0,i)$ e em $(i,0)$, ou seja, $2f$ por rota) | **252.2206**: 4 veículos do tipo 1 |
| Sem $\alpha$ (custo variável igual para todos os tipos) | **203.4573**: mesma frota, valor diferente |

### Atenção para a modelagem

É o **HFVRP com o custo fixo do complementar "VRP com custo fixo"**:
- **Grafos e variáveis:** um grafo por tipo, `x[k, e]`, custo `α[k] * ℓ(i, j)`, capacidade `Q[k]` e limites `(0, u[k])`, com `u[k] = n`.
- **Custo fixo:** uma variável `z[k]` por tipo, com `+ f[k] * z[k]` no objetivo. Ela é mapeada **só no arco de saída** $(0, j)$ do grafo $k$: `add_arc_var_mapping!(G[k], a, [x[k, (0, j)], z[k]])`. O arco de volta $(j, 0)$ fica mapeado só para `x[k, (0, j)]`.
- **Alternativa equivalente, sem `z`:** somar **$f^k / 2$** ao custo de cada aresta do depósito $(0, j)$ no tipo $k$. Toda rota usa exatamente duas "pontas" no depósito: duas arestas distintas, ou a mesma aresta com $x = 2$. Somar $f^k$ inteiro cobraria $2f$ por rota, que é a armadilha de 252.2206. Com `z`, a contagem fica explícita, e `z[k]` mostra direto quantos veículos de cada tipo foram usados.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **209.2567** — frota $z = [2, 1]$; tipo 1: 0-2-3-0, 0-6-0; tipo 2: 0-1-5-4-0; raiz, 1 nó | 209.2567 | 0.66 s |
| c50_14fsmfd | **9126.8973** — frota $z = [7, 1, 0]$; raiz 8770.93 (gap 3.9%), **13 nós** | 9126.90 | 242.87 s |

c50_14fsmfd conferido em Julia:
- **Tipo 1** ($f = 1000$, $\alpha = 1.0$, $Q = 120$): 7 rotas, com cargas de 110 a 120.
- **Tipo 2** ($f = 1500$, $\alpha = 1.1$): 1 rota, com carga 156 / 160.
- **Tipo 3:** não é usado.

São 50 clientes, e o custo $\sum (\alpha \ell + f)$ = 9126.8973. A referência **9126.90 fica confirmada**, com ótimo provado. O custo fixo domina: 8500 dos 9126.90 são custos fixos.

### Referências para o benchmark

| Instância | Tipos | Valor de referência (FSMFD) |
|---|---|---|
| c50_13fsmfd | 6 | **2964.65** |
| c50_14fsmfd | 3 | **9126.90** |
| c50_15fsmfd | 3 | **2634.96** |
| c50_16fsmfd | 3 | **3168.92** |
| c75_17fsmfd | 4 | **2004.48** |
| c75_18fsmfd | 6 | **3147.99** |
| c100_19fsmfd | 3 | **8661.81** |
| c100_20fsmfd | 3 | **4153.02** |

**Atenção:** esses valores vêm da **minha memória** da literatura (BKS/ótimos de Choi & Tcha 2007 e de Baldacci & Mingozzi 2009) e **não foram confirmados** numa fonte nesta sessão. A **c50_14fsmfd foi confirmada** pelo VRPSolver (9126.8973, ótimo provado); as demais seguem a confirmar.

## PDPTW

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `PDPTW/Instancias/*.txt` e `*.sol` | 56 instâncias de Li & Lim (2001) com 100 vértices (≈ 50 requisições) e as soluções do SINTEF, via zhu-he/pdptw-data |
| `PDPTW/pdptw_parser.jl` | `read_pdptw(path; r)` e auto-teste |
| `PDPTW/toy_pdptw.txt` | Toy no formato de Li & Lim |

A pasta `PDPTW/` tem também o modelo e o `CVRP.cfg`.

### Parser

```julia
include("pdptw_parser.jl")
inst = read_pdptw(joinpath(@__DIR__, "toy_pdptw.txt"))
inst = read_pdptw(joinpath(@__DIR__, "Instancias", "lc101.txt"); r = 10)   # só as 10 primeiras requisições
inst.r, inst.K, inst.Q          # nº de requisições, frota, capacidade
inst.q[v+1]                     # demanda ASSINADA: +q_h na coleta h, -q_h na entrega h + r (= d̄ do enunciado)
inst.l[v+1], inst.u[v+1], inst.s[v+1]
inst.C[v+1, w+1]                # custo (distância real)
inst.T[v+1, w+1]                # tempo do arco v→w = s_v + c_vw (assimétrico)
```

**Renumeração:** igual à do enunciado. O depósito é o 0, as coletas são $P = \{1..r\}$, e a entrega da coleta $h$ é $h + r$.

**Convenção:** distância euclidiana **real**, com tempo = serviço + distância. Conferi em Python as 56 `.sol`: todas são viáveis (janelas, capacidade, precedência e mesmo veículo).

**Atenção:** as `.sol` do SINTEF são **hierárquicas**: minimizam primeiro o número de veículos e depois a distância. Para o nosso objetivo, só a distância, elas são **limites superiores**.

Auto-teste: `julia pdptw_parser.jl` → `OK: toy + 56 instâncias de Li & Lim lidas`.

### Instância toy — `toy_pdptw.txt`

São 3 requisições, com $Q = 10$, serviço $s = 5$ e frota $K = 3$. O depósito tem janela [0, 300].

| Requisição $h$ | Coleta $h$ (x, y) [l, u] | Entrega $h + 3$ (x, y) [l, u] | $q_h$ |
|---|---|---|---|
| 1 | (−17, −1) [25, 65] | (−18, −7) [19, 44] | 4 |
| 2 | (−5, 11) [2, 17] | (7, 10) [34, 74] | 5 |
| 3 | (−11, 12) [38, 53] | (−12, 13) [45, 85] | 6 |

**Ótimo (força bruta, conferido também no CBC): 114.1414**, com cutoff `114.15`. São três rotas, uma por requisição:

| Rota | Custo | Início do serviço |
|---|---|---|
| 0-1-4-0 | 42.4254 | 1: 25 (espera) · 4: 36.1 |
| 0-2-5-0 | 36.3312 | 2: 12.1 · 5: 34 (espera) |
| 0-3-6-0 | 35.3848 | 3: 38 (espera) · 6: 45 (espera) |

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Sem limite inferior 0 nos recursos de requisição (entrega antes da coleta) | **95.151**: 0-**4-1**-3-6-0 entrega a requisição 1 antes de coletá-la |
| Tempo sem o serviço ($t_{ij} = c_{ij}$) | **98.7978**: 0-1-4-3-6-0 fica viável (com serviço, chega em 3 no instante 61.3 > 53) |
| Sem $[0, 0]$ no depósito para os recursos de requisição | **71.7921**: as entregas são omitidas (0-1-3-0 e 0-2-0) |

### Atenção para a modelagem

É o modelo da Seção 4.6 de Pessoa et al. (2020), com **um único grafo**:
- **Variáveis e mestre:** $x_a$ por **arco**, porque a precedência quebra a simetria. O mestre tem a cobertura **só das coletas**, $\sum_{a \in \delta^-(h)} x_a = 1$ para $h \in P$.
- **Recurso de tempo:** é o principal (`main = true`), com limites $[l_v, u_v]$ e consumo `T[v+1, w+1]`.
- **Recurso de carga:** consumo $\bar d_w$ = `q[w+1]`, com limites $[0, Q]$ nos clientes. Tem consumo negativo, então é secundário, e o modelo o declara **não descartável**.
  - **No depósito, use $[0, 0]$.** O BaPCod recusa um intervalo não pontual no source de um recurso não descartável, com o erro `the res.cons. bounds are not the same in the source for a non-disposable resource` (ocorreu na toy, com $[0, Q]$).
- **Recursos de requisição:** um por requisição $h$, **binários e não descartáveis**, com `add_resource!(G, binary = true, disposable = false)`.
  - Consumo $+1$ ao entrar na coleta $h$, $-1$ ao entrar na entrega $h + r$, e 0 nos demais arcos.
  - Limites $[0, 1]$ nos clientes e **$[0, 0]$ no depósito**.
  - O código-fonte do VrpSolver.jl (`add_resource!`, conferido no WSL) mostra que um recurso binário já nasce com $[0, 1]$ em todos os vértices. Basta fixar `set_resource_bounds!(G, 0, rh, 0.0, 0.0)`. Recursos binários não podem ser `main` nem descartáveis. Como no depósito source = sink, o VRPSolver **recusa** $[0, 1]$ ali para um binário não descartável e só aceita $[0,0]$ ou $[1,1]$. Isso impede, por construção, o erro do "sem $[0,0]$".
- **Packing sets:** **só as coletas**, um singleton por coleta. A matriz de distâncias fica $r \times r$, entre as coletas.
- **Frota:** $L = 0$ e $U = K$ (o artigo usa $U = \infty$; com $K$ do arquivo, as `.sol` continuam viáveis).
- **Opcional:** cortar arcos que nunca podem ser usados: $0 \to$ entrega, coleta $\to 0$, entrega $h + r \to$ coleta $h$, e arcos com $l_v + t_{vw} > u_w$.
- **Tamanho do grafo:** cada requisição é um recurso. Com $r = 50$, são 52 recursos, o que deixa o pricing pesado. Por isso a sequência sugerida usa instâncias reduzidas.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **114.1414** — 0-1-4-0, 0-2-5-0, 0-3-6-0; raiz, 1 nó | 114.1414 | 0.63 s |
| lc101, $r = 10$ | **155.5028** — 2 rotas; raiz, 1 nó | 155.5028 (CBC) | 0.65 s |

lc101 com $r = 10$, conferido em Julia: 0-2-1-12-4-14-6-5-3-15-13-16-11-0 (59.62) e 0-7-17-9-10-20-8-18-19-0 (95.88). São 20 vértices, com janelas, carga, precedência e mesmo veículo ok.

| lc101, $r = 20$ | **301.8858** — 4 rotas; raiz, 1 nó (conferido: 40 vértices, todas as restrições ok) | 301.8858 (CBC) | 0.68 s |
|---|---|---|---|

As duas primeiras rotas da lc101 com $r = 20$ têm a mesma sequência física e o mesmo custo (59.62 e 95.88) das rotas com $r = 10$. Só a numeração das entregas muda: a entrega de $h$ passa de $h + 10$ para $h + 20$. As requisições 11–20 formam outras duas rotas (50.80 e 95.58).

### Referências para o benchmark

| Instância | $r$ | Ótimo (min distância) | Rotas | Fonte |
|---|---|---|---|---|
| lc101 | 10 | **155.5028** | 2 | CBC, ótimo provado |
| lr101 | 10 | **553.0489** | 8 | CBC, ótimo provado |
| lrc101 | 10 | **425.6099** | 4 | CBC, ótimo provado |
| lc101 | 20 | **301.8858** | 4 | CBC, ótimo provado |
| lr101 | 20 | **930.399** | 12 | CBC, ótimo provado |
| lc101 | 53 (completa) | ≤ **828.94** | 10 | `.sol` do SINTEF (hierárquica) |
| lr101 | 53 | ≤ **1650.80** | 19 | `.sol` (hierárquica) |

A formulação do CBC é compacta, com arcos, MTZ para tempo e carga, e índice de rota para o mesmo veículo. Ela reproduziu o ótimo da toy (114.1414).

## E-VRP

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `EVRP/Instancias/{consec,non-consec}/*.vrp` | 96 instâncias do **G-VRP** (Erdoğan & Miller-Hooks, 2012), versão da UNICAMP (Fusberti): 48 `consec` e 48 `non-consec` |
| (no vault, não no repositório) `Solucoes/{Cubic,KK,LH,MD_4,MD_5}/` | Soluções publicadas por método |
| `EVRP/referencias_consec.csv` | Melhor custo publicado por instância `consec`, com o indicador "MD_4 = MD_5" |
| `EVRP/evrp_parser.jl` | `read_evrp(path)` e auto-teste |
| `EVRP/toy_evrp.vrp` | Toy no mesmo formato |

A pasta `EVRP/` tem também o modelo e o `CVRP.cfg`.

O **G-VRP** é exatamente o E-VRP do enunciado: recarga completa, tempo fixo de recarga $g_s$, duração máxima $T$ e consumo proporcional à distância. A única diferença é que ele **não tem capacidade de carga**: o parser não devolve $Q$ nem $d$, e o recurso de carga pode ser omitido.
- **`consec`:** permite estações consecutivas. **É o exercício**, em que as estações são livremente revisitáveis.
- **`non-consec`:** proíbe arcos estação → estação, como no G-VRP original.

### Parser

```julia
include("evrp_parser.jl")
inst = read_evrp(joinpath(@__DIR__, "toy_evrp.vrp"))
inst = read_evrp(joinpath(@__DIR__, "Instancias", "consec", "mlsa_flow_10c5f23.000000B-P-n16-k8.vrp"))
inst.C, inst.S             # ids dos clientes e das estações (depósito = 0; ids 0..N-1)
inst.β, inst.ρ             # autonomia e taxa de consumo: e_ij = ρ·c_ij
inst.T, inst.ξ             # duração máxima e velocidade: t_ij = c_ij / ξ
inst.s[v+1]                # serviço (cliente) ou tempo de recarga g_s (estação)
inst.c[v+1, w+1]           # custo = distância nint
```

**Convenção, conferida em 107 soluções publicadas:** a distância é arredondada (nint) e vale para custo, energia e tempo. O serviço é contado no vértice de chegada. A energia volta a zero nas estações e no depósito.

Auto-teste: `julia evrp_parser.jl` → `OK: toy + 96 instâncias G-VRP lidas`.

### Instância toy — `toy_evrp.vrp`

Depósito em (0, 0). Autonomia $\beta = 26$, consumo $\rho = 1$, velocidade $\xi = 1$ e $T = 80$. Serviço 2 nos clientes e recarga $g_s = 10$.

| Vértice | 1 | 2 | 3 | estação 4 | estação 5 |
|---|---|---|---|---|---|
| (x, y) | (6, 10) | (12, −1) | (−5, 20) | (4, 20) | (23, −20) |

**Ótimo (força bruta): 106**, com cutoff `106.01`:

| Rota | Custo | Observação |
|---|---|---|
| 0-1-0 | 24 | |
| 0-2-0 | 24 | |
| 0-**4**-3-**4**-0 | 58 | **revisita a estação 4**. O cliente 3 está a 21 do depósito, e ida e volta (42) excede $\beta$. A rota termina no instante **80 = T** |

A estação 5 é uma isca e não é usada.

Armadilhas:

| Modelo errado | Resultado |
|---|---|
| Estações no packing set (no máximo uma visita por rota) | **inviável**: o cliente 3 exige duas passagens pela estação 4 |
| Reset da bateria no arco de chegada (consumo $e_{is} - \beta$, sem o par $s^- / s^+$) | **76**: 0-3-4-1-0 chega à estação com 30 > 26 e o excesso some no reset |
| Recarga sem tempo ($g_s$ ignorado) | **84**: 0-1-4-3-4-0 passa a caber em $T$ |
| Sem o recurso de bateria | **61**: uma rota só, 0-2-1-3-0 |

### Atenção para a modelagem

Segue a correção do exercício (desdobramento $s^- / s^+$):
- **Vértices:** depósito 0, clientes $C$, $s^-$ = o id da estação e $s^+$ = um id novo, por exemplo `s + N`.
- **Arcos de viagem:** de out($i$) para in($j$), com out($s$) = $s^+$ e in($s$) = $s^-$.
  - Cada um é mapeado para `x[(i, j)]`, com custo `c` e variável **inteira ≥ 0**, porque o mesmo arco de estação pode ser usado mais de uma vez.
  - Remova o arco $s^+ \to s^-$ da mesma estação, que é um ciclo inútil.
- **Arco de recarga $(s^-, s^+)$:** sem mapeamento. Consome $-\beta$ de energia e $g_s$ de tempo.
- **Recursos:**
  - **Tempo:** é o principal, com $[0, T]$. O consumo é $c_{ij}/\xi + s_j$ nos arcos que chegam a clientes e $c_{ij}/\xi$ nos que chegam a $s^-$ ou ao depósito.
  - **Energia:** é secundária e descartável, com $[0, \beta]$ em todos os vértices. O consumo é $\rho c_{ij}$ nas viagens e $-\beta$ na recarga. Por ser descartável, $\max\{0, E - \beta\} = 0$ faz o reset, e o limite $\beta$ é testado em $s^-$ **antes** dele.
- **Packing sets:** **só os clientes**. As estações ficam fora, para poderem ser revisitadas. A matriz de distâncias é $|C| \times |C|$.
- **Mestre:** $\sum_{a \in \delta^-(j)} x_a = 1$ para $j \in C$. Use $L = 0$ e $U = |C|$.
- **Ponto a confirmar no solver:** o recurso de energia tem consumo negativo, como a carga do PDPTW. No PDPTW, o recurso não descartável exigiu $[0, 0]$ no depósito. Aqui ele é **descartável**, então $[0, \beta]$ no depósito deve ser aceito. Se o BaPCod reclamar, use $[0, 0]$ no depósito.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **106** — 0-1-0, 0-2-0, 0-4-3-4-0 (estação 4 revisitada); raiz, 1 nó | 106 | 0.70 s |
| 10c5f23 (P-n16-k8) | **284** — 3 rotas; raiz, 1 nó | 284 (Cubic = MD_4 = MD_5) | 0.69 s |

10c5f23, conferido em Julia:

| Rota | Custo | Energia máx. / $\beta$ | Tempo / $T$ |
|---|---|---|---|
| 0-6-**7**-13-**7**-9-**7**-5-**7**-2-**7**-0 | 116 | 22 / 23 | 9.86 / 10 |
| 0-**10**-12-**3**-8-**10**-4-**11**-15-**10**-0 | 126 | 23 / 23 | 9.77 / 10 |
| 0-**10**-1-0 | 42 | 21 / 23 | 2.16 / 10 |

As estações estão em negrito. A estação 7 é visitada **5 vezes** numa só rota. São as mesmas rotas publicadas pelo método Cubic; a segunda está no sentido inverso. O VRPSolver **provou o ótimo 284**.

O arco (15,10) não apareceu na saída colada: é o último na ordem de impressão. Ele é necessário para o balanço de fluxo, e 271 + c(15,10) = 284.

A energia, secundária e descartável, foi aceita com $[0, \beta]$ no depósito, sem o erro que apareceu na carga não descartável do PDPTW.

### Referências para o benchmark (`consec`)

| Instância | Clientes / estações | $\beta$ | Melhor publicado | MD_4 = MD_5? |
|---|---|---|---|---|
| 10c5f23 (P-n16-k8) | 10 / 5 | 23 | **284**, **ótimo provado pelo VRPSolver** | sim (Cubic também) |
| 11c4f25 (P-n16-k8) | 11 / 4 | 25 | **277** | sim (Cubic também) |
| 13c2f55 (P-n16-k8) | 13 / 2 | 55 | **228** | sim |
| 13c5f21 (P-n19-k2) | 13 / 5 | 21 | **377** | sim (Cubic também) |
| 15c7f19 (P-n23-k8) | 15 / 7 | 19 | **282** | sim (Cubic também) |

As tabelas completas estão no CSV, com 48 instâncias de 10 a 88 clientes. Não verifiquei quais métodos são exatos. Quando dois ou três métodos concordam, provavelmente o valor é ótimo, mas isso **não é prova**. Nas instâncias grandes, os métodos divergem e os valores são só limites superiores. O nome codifica clientes, estações e $\beta$: `10c5f23` = 10 clientes, 5 estações, $\beta = 23$.

## Rich VRP

### Arquivos

| Caminho | Conteúdo |
|---|---|
| `RichVRP/rich_parser.jl` | `read_rich(path)` e auto-teste (formato próprio `.rvrp`) |
| `RichVRP/toy_rich.rvrp` | Toy: 2 depósitos, 3 tipos, 6 clientes, 2 opcionais |
| `RichVRP/rich_R101_25.rvrp` | **Regressão VRPTW:** R101 com 25 clientes, convertido (1 depósito, 1 tipo, $f = 0$, `DIST trunc1`) |
| `RichVRP/rich_p01.rvrp` | **Regressão MDVRP:** p01 de Cordeau, convertido (4 depósitos, 1 tipo por depósito com $u = 4$, sem janelas) |
| `RichVRP/rich_mix15.rvrp` | **Instância rica:** 15 primeiros clientes do R101, 2 depósitos, 3 tipos, 3 opcionais, compatibilidades |

A pasta `RichVRP/` tem também o modelo e o `CVRP.cfg`.

Não existe um benchmark padrão com todos esses ingredientes juntos. A validação tem três partes:
- a toy, com força bruta;
- duas **regressões**, em que o modelo genérico precisa reproduzir ótimos já conhecidos;
- uma instância rica média, com ótimo provado no CBC.

### Formato `.rvrp` e parser

```text
NAME nome
DIST real | trunc1                 # trunc1 = ⌊10·dist⌋/10 (Solomon)
CUSTOMERS n
DEPOTS m
TYPES t
id x y l u                          # m depósitos, ids n+1..n+m
k depósito Q u f α                  # t tipos
id x y d s l u ρ tipos...           # n clientes; ρ = penalidade (−1 = obrigatório); tipos = 𝒦_i
```

```julia
include("rich_parser.jl")
inst = read_rich(joinpath(@__DIR__, "toy_rich.rvrp"))
inst.n, inst.depots, inst.K
inst.b[k], inst.Q[k], inst.u[k], inst.f[k], inst.α[k]       # base, capacidade, disponibilidade, custo fixo, custo/dist.
inst.d[i], inst.s[i], inst.l[i], inst.u_tw[i], inst.ρ[i], inst.comp[i]
inst.ℓ[i, j], inst.T[i, j]          # SEM o +1: vértices 1..n+m (como no MDVRP); T = s_i + ℓ_ij
```

Auto-teste: `julia rich_parser.jl` → `OK: toy + instâncias .rvrp da pasta lidas`.

### Instância toy — `toy_rich.rvrp`

Depósitos 7 em (0, 0) e 8 em (30, 0), ambos com janela [0, 200]. Serviço 2 em todo cliente.

| Tipo | Base | $Q$ | $u$ | $f$ | $\alpha$ |
|---|---|---|---|---|---|
| 1 | 7 | 10 | 1 | 20 | 1.0 |
| 2 | 7 | 15 | 1 | 40 | 1.2 |
| 3 | 8 | 12 | 2 | 25 | 1.0 |

| Cliente | 1 | 2 | 3 | 4 | 5 | 6 |
|---|---|---|---|---|---|---|
| (x, y) | (4, −4) | (14, −11) | (2, 7) | (−8, −13) | (−2, −8) | (22, −9) |
| $d$ | 4 | 5 | 3 | 4 | 4 | 4 |
| $[l, u]$ | [24, 64] | [36, 56] | [57, 97] | [5, 45] | [14, 34] | [44, 84] |
| $\rho$ | obrig. | obrig. | obrig. | obrig. | **30** | **25** |
| $\mathcal{K}_i$ | todos | todos | todos | **{3}** | todos | todos |

**Ótimo (força bruta e CBC): 197.6854**, com cutoff `197.69`:

| Tipo | Rota | Custo ($f + \alpha\ell$) | Carga |
|---|---|---|---|
| 1 | 7-1-2-7 | 20 + 35.6679 | 9 / 10 |
| 3 | 8-5-4-3-8 | 25 + 92.0175 | 11 / 12 |
| — | opcional 6 não atendido | penalidade **25** | |

O cliente 4 só aceita o tipo 3, então uma rota sai do depósito 8 para atender clientes perto do depósito 7. O opcional 5 é atendido no caminho.

Armadilhas, todas com valores distintos:

| Modelo errado | Resultado |
|---|---|
| Opcionais tratados como obrigatórios | **202.8838** |
| Penalidade ignorada (opcional deixado de graça) | **172.0525**: os dois opcionais ficam de fora |
| Sem custo fixo | **136.2423**: 3 rotas |
| Sem compatibilidade | **163.1997** |
| Sem janelas de tempo | **183.8438** |
| Rota pode voltar a outro depósito | **160.6532** |

### Atenção para a modelagem

Combine o que já foi validado nos exercícios anteriores:
- **Grafos (do MDVRP e do SDVRP):** um grafo por **tipo** $k$, com $V^k = \{b(k)\} \cup \{i : k \in \mathcal{K}_i\}$, source = sink = $b(k)$ e limites $(0, u_k)$. Dois tipos com a mesma base usam o mesmo id de depósito em grafos diferentes.
- **Variáveis e arcos:** `x[k, e]` só nas arestas compatíveis, com custo $\alpha_k \ell$.
- **Recursos (do VRPTW):**
  - **tempo:** é o principal, com $[l_i, u_i]$ em cada vértice e consumo `T[i, j]`, que é assimétrico, nos dois sentidos de cada aresta;
  - **capacidade:** limites $[0, Q_k]$.
- **Custo fixo (do FSMVRP):** `z[k]` mapeado só nos arcos de saída $(b(k), j)$ do grafo $k$, com $+ f_k z_k$ no objetivo.
- **Clientes opcionais (novo):** variável $\omega_i \in \{0, 1\}$ = "o opcional $i$ **não** é atendido".
  - Grau $\sum x + 2\omega_i = 2$ nos opcionais e $\sum x = 2$ nos obrigatórios.
  - Objetivo $+ \sum_i \rho_i\, \omega_i$.
  - **Não use** $y_i$ com $\rho_i(1 - y_i)$: isso cria uma constante no objetivo, e o VRPSolver dá o erro `constant part of the objective function must be zero` (ocorreu na toy).
- **Packing sets:** todos os clientes, opcionais inclusive, reunindo as cópias dos grafos compatíveis, `[(G[k], i) for k in comp[i]]`.
- **Matriz de distâncias:** $\ell$ entre os clientes, em cada grafo.

### Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **197.6854** — frota $z = [1, 0, 1]$; tipo 1: 7-1-2-7; tipo 3: 8-5-4-3-8; opcional 6 não atendido; raiz, 1 nó | 197.6854 | 0.78 s |

### Referências para o benchmark

| Instância | O que testa | Ótimo | Fonte |
|---|---|---|---|
| `rich_R101_25.rvrp` | modelo reduzido a VRPTW | **617.1** | Solomon/Kohl; também o CBC sobre o `.rvrp` (ótimo provado) |
| `rich_p01.rvrp` | modelo reduzido a MDVRP | **576.8657** | VRPSolver nos Complementares 2 (ótimo provado) |
| `rich_mix15.rvrp` | tudo junto | **622.5386** | CBC, ótimo provado. 2 rotas do tipo 1, 0 do tipo 2, 2 do tipo 3; opcionais 14 e 15 **não** atendidos |

O MIP do CBC (por tipo, com MTZ para tempo e carga, e $y_i$ nos opcionais) foi validado antes na toy (197.6854) e no R101 com 25 clientes (617.1).

## Fontes

- Queiroga, E., Frota, Y., Sadykov, R., Subramanian, A., Uchoa, E., Vidal, T. (2020). On the exact solution of vehicle routing problems with backhauls. *European Journal of Operational Research* 287(1), 76–89.
- Toth, P., Vigo, D. (1997). An exact algorithm for the vehicle routing problem with backhauls. *Transportation Science* 31(4), 372–385.
- Goetschalckx, M., Jacobs-Blecha, C. (1989). The vehicle routing problem with backhauls. *EJOR* 42(1), 39–51.
- Chao, I-M., Golden, B., Wasil, E. (1999). A computational study of a new heuristic for the site-dependent vehicle routing problem. *INFOR* 37(3), 319–336.
- Cordeau, J.-F., Laporte, G. (2001). A tabu search algorithm for the site dependent vehicle routing problem with time windows. *INFOR* 39(3), 292–298.
- Erdoğan, S., Miller-Hooks, E. (2012). A green vehicle routing problem. *Transportation Research Part E* 48(1), 100–114.
- Instâncias e soluções do G-VRP (consec / non-consec): <https://www.ic.unicamp.br/~fusberti/problems/gvrp/>.
- Li, H., Lim, A. (2001). A metaheuristic for the pickup and delivery problem with time windows. *Proceedings of the 13th IEEE ICTAI*, 160–167.
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523 (Seção 4.6).
- Instâncias PDPTW: <https://github.com/zhu-he/pdptw-data> (cópia dos dados do SINTEF, pasta `100`).
- Choi, E., Tcha, D.-W. (2007). A column generation approach to the heterogeneous fleet vehicle routing problem. *Computers & Operations Research* 34(7), 2080–2095.
- Instâncias FSMVRP: <https://github.com/inria-UFF/VRPSolverEasy> (`VRPSolverEasy/demos/data/HFVRP`, sufixos `fsmfd`, `fsmf`, `fsmd`).
- Instâncias SDVRP: espelho dos dados de Cordeau em <https://github.com/pauljmello/HGSADC-vs-ACS-on-SDVRP> (`data/_mirror/sdvrp/old`).

## Notas relacionadas

- Exercícios complementares 3 · Experimento VRPB com Coluna e CPLEX · [Complementares 2 no VRPSolver - VRPTW, MDVRP e HFVRP](README-complementares-2.md)
- VRPSolver · Resource-Constrained Shortest Path
