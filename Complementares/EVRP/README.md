# E-VRP — Electric Vehicle Routing Problem com recarga completa

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-3.md`](../README-complementares-3.md).

Veículos elétricos com autonomia $\beta$ e duração máxima $T$; estações de recarga opcionais e **revisitáveis** recarregam a bateria por completo em tempo fixo $g_s$. Benchmark: o G-VRP de Erdoğan & Miller-Hooks (2012).

## Como rodar

```bash
julia evrp_parser.jl      # auto-teste do parser
julia evrp_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/{consec,non-consec}/*.vrp` | 96 instâncias do **G-VRP** (Erdoğan & Miller-Hooks, 2012), versão da UNICAMP (Fusberti): 48 `consec` e 48 `non-consec` |
| (no vault, não no repositório) `Solucoes/{Cubic,KK,LH,MD_4,MD_5}/` | Soluções publicadas por método |
| `referencias_consec.csv` | Melhor custo publicado por instância `consec`, com o indicador "MD_4 = MD_5" |
| `evrp_parser.jl` | `read_evrp(path)` e auto-teste |
| `toy_evrp.vrp` | Toy no mesmo formato |

Esta pasta tem também o modelo e o `CVRP.cfg`.

O **G-VRP** é exatamente o E-VRP do enunciado: recarga completa, tempo fixo de recarga $g_s$, duração máxima $T$ e consumo proporcional à distância. A única diferença é que ele **não tem capacidade de carga**: o parser não devolve $Q$ nem $d$, e o recurso de carga pode ser omitido.
- **`consec`:** permite estações consecutivas. **É o exercício**, em que as estações são livremente revisitáveis.
- **`non-consec`:** proíbe arcos estação → estação, como no G-VRP original.

## Parser

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

## Instância toy — `toy_evrp.vrp`

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

## Atenção para a modelagem

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

## Resultados

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

## Referências para o benchmark (`consec`)

| Instância | Clientes / estações | $\beta$ | Melhor publicado | MD_4 = MD_5? |
|---|---|---|---|---|
| 10c5f23 (P-n16-k8) | 10 / 5 | 23 | **284**, **ótimo provado pelo VRPSolver** | sim (Cubic também) |
| 11c4f25 (P-n16-k8) | 11 / 4 | 25 | **277** | sim (Cubic também) |
| 13c2f55 (P-n16-k8) | 13 / 2 | 55 | **228** | sim |
| 13c5f21 (P-n19-k2) | 13 / 5 | 21 | **377** | sim (Cubic também) |
| 15c7f19 (P-n23-k8) | 15 / 7 | 19 | **282** | sim (Cubic também) |

As tabelas completas estão no CSV, com 48 instâncias de 10 a 88 clientes. Não verifiquei quais métodos são exatos. Quando dois ou três métodos concordam, provavelmente o valor é ótimo, mas isso **não é prova**. Nas instâncias grandes, os métodos divergem e os valores são só limites superiores. O nome codifica clientes, estações e $\beta$: `10c5f23` = 10 clientes, 5 estações, $\beta = 23$.

## Fontes

- Erdoğan, S., Miller-Hooks, E. (2012). A green vehicle routing problem. *Transportation Research Part E* 48(1), 100–114.
- Instâncias e soluções do G-VRP (consec / non-consec): <https://www.ic.unicamp.br/~fusberti/problems/gvrp/>.
