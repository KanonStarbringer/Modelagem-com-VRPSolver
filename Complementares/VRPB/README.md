# VRPB — Vehicle Routing Problem with Backhauls

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-3.md`](../README-complementares-3.md).

Clientes *linehaul* (entregas) e *backhaul* (coletas): em cada rota todas as entregas vêm antes das coletas, e cada uma das duas cargas respeita $Q$ separadamente. Implementado nas duas formulações de Queiroga et al. (2020): **F1** (`vrpb1_model.jl`, um grafo) e **F2** (`vrpb2_model.jl`, dois grafos emparelhados), mais uma proposta própria, **F3** (`vrpb3_model.jl`, F2 com o primeiro backhaul declarado em $G^L$).

## Como rodar

```bash
julia vrpb_parser.jl      # auto-teste do parser
julia vrpb1_model.jl
julia vrpb2_model.jl
julia vrpb3_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/Instancias TV convertidas/*.vrpb` | 33 instâncias de Toth & Vigo (1997), já usadas no Experimento VRPB com Coluna e CPLEX |
| `Instancias/Instancias GJB/*.xml` | 68 instâncias de Goetschalckx & Jacobs-Blecha (1989), grupos A a O |
| `referencias_tv_artigo.csv`, `referencias_gjb_artigo.csv` | $z_{IP}$ das Tabelas de Queiroga et al. |
| `vrpb_parser.jl` | `read_vrpb(path)` e auto-teste |
| `toy_vrpb.vrpb` | Toy no formato `.vrpb` |

Esta pasta tem também o modelo e o `CVRP.cfg`.

## Parser

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

## Instância toy — `toy_vrpb.vrpb`

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

## F1 — um grafo, recurso de capacidade com "salto"

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

## F2 — dois grafos emparelhados por $z_i = w_i$

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

## Resultados

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

## Comparação F1 × F2

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

## F3 (proposta) — F2 com o primeiro backhaul declarado em $G^L$

**Motivação:** pela Prop. 1 de Queiroga et al., as relaxações de F1 e F2 sem cortes são iguais. Pela Prop. 2, os cortes rank-1 da F1 são mais fortes nos subconjuntos **mistos**, com linehauls e backhauls juntos. A F2 não os enxerga, porque cada coluna só vê um dos lados. A F3 tenta recuperar parte desses cortes sem perder o pricing barato da F2: o caminho de $G^L$ passa a "declarar" o primeiro backhaul da rota.

- **Variáveis:** $x_a$ como na F2, mais $z_{(l,b)} \in \mathbb{Z}_+$ para $l \in L$ e $b \in B \cup \{0\}$. O valor $b = 0$ indica rota só com linehauls.
- **Mestre:** cobertura como na F2, mais o emparelhamento por arco de cruzamento, $z_{(l,b)} = x_{(l,b)}$.
- **Grafo $G^L$:** o da F2, mais uma **sombra** $\hat b$ por backhaul, que usa o id do próprio $b$.
  - $(l, l')$: sem mapeamento.
  - $(l', \hat b)$: mapeado em $z_{(l,b)}$.
  - $(l', 0')$: mapeado em $z_{(l,0)}$.
  - $(\hat b, 0')$: sem mapeamento.
- **Grafo $G^B$:** o da F2, mas $(0', l)$ fica **sem mapeamento**. Os arcos $(l, b)$ e $(l, 0)$ continuam em $x$, e é por eles que $G^B$ se amarra a $z$.
- **Packing sets:** os da F2, mais um singleton $\{\hat b\}$ em $G^L$ para cada $b \in B$. Assim, um rank-1 de $G^L$ pode conter linehauls e o primeiro backhaul.
- **Arquivo:** `vrpb3_model.jl`, gerado a partir do `vrpb2_model.jl`.

Armadilhas, conferidas por enumeração de colunas na toy:

| Modelo errado | Resultado |
|---|---|
| $x_{(l,b)}$ mapeado também no arco $(l', \hat b)$ | **220**: o cruzamento é contado duas vezes |
| Sem o arco $(l', 0')$ | **194**: a rota 0-1-0 fica impossível |

**Na Figura 2 do artigo** (3-SRC em {1, 2, 3}), o corte vale 1.5 na F1 (violado), 1.0 na F2 (não violado) e **1.5 na F3 (violado)**. A F3 recupera esse corte.

### Resultados da F3

| Instância | Obtido | Raiz / nós / tempo |
|---|---|---|
| toy | **170** — cruzamentos (1, 0), (2, 4), (3, 6) | 170.00 / 1 / 0.66 s |
| EIL22_50 | **371** — cruzamentos (1, 12), (2, 13), (11, 21) | 371.00 / 1 / 0.82 s |
| EILB101_66 | **982** — 9 rotas, uma só com linehauls (39) | 973.00 / 29 / 353.09 s (raiz em 101.11 s) |
| GJ4 (custo real) | **296533.1646** — 7 rotas, uma só com linehauls (5) | 293530.74 / 23 / 842.53 s (raiz em 318.50 s) |

### Comparação F1 × F2 × F3

| Instância | F1: raiz / nós / tempo | F2: raiz / nós / tempo | F3: raiz / nós / tempo |
|---|---|---|---|
| EILB101_66 | 978.00 / 9 / 269.41 s | 972.00 / 27 / 193.71 s | 973.00 / 29 / 353.09 s |
| GJ4 | 294229.19 / 5 / 200.60 s | 293291.97 / 25 / 189.25 s | 293530.74 / 23 / 842.53 s |

| Instância | Gap da raiz: F1 / F2 / F3 | Tempo da raiz: F1 / F2 / F3 |
|---|---|---|
| EILB101_66 | 0.41% / 1.02% / 0.92% | 114.26 / 34.55 / 101.11 s |
| GJ4 | 0.78% / 1.09% / 1.01% | 68.78 / 35.73 / 318.50 s |

**Conclusão: a F3 é dominada.**
- **Limite:** recupera só uma parte pequena da diferença entre F2 e F1, cerca de 17% na EILB101_66 e 25% na GJ4. Na prática, empata com a F2 em número de nós.
- **Custo:** a raiz fica de 3× (EILB101_66) a 9× (GJ4) mais lenta que a da F2, e mais lenta até que a da F1. $G^L$ ganha $|L| \cdot |B|$ arcos de sombra e $|B|$ packing sets, e o pricing de $G^L$ deixa de ser "só linehauls".
- **Leitura:** os rank-1 que fecham o gap da F1 envolvem vários backhauls de uma vez, e não só o primeiro. Declarar um vértice além do cruzamento basta para o corte da Figura 2, mas não para as instâncias de 100 clientes. A variante simétrica, com $G^B$ declarando o último linehaul, tem a mesma limitação. Declarar $k$ backhauls faz $G^L$ crescer até virar a F1.

## Referências para o benchmark

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

## Fontes

- Queiroga, E., Frota, Y., Sadykov, R., Subramanian, A., Uchoa, E., Vidal, T. (2020). On the exact solution of vehicle routing problems with backhauls. *European Journal of Operational Research* 287(1), 76–89.
- Toth, P., Vigo, D. (1997). An exact algorithm for the vehicle routing problem with backhauls. *Transportation Science* 31(4), 372–385.
- Goetschalckx, M., Jacobs-Blecha, C. (1989). The vehicle routing problem with backhauls. *EJOR* 42(1), 39–51.
