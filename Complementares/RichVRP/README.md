# Rich VRP — múltiplos depósitos, frota heterogênea, janelas e clientes opcionais

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-3.md`](../README-complementares-3.md).

Combina vários depósitos (cada tipo de veículo tem uma base), frota heterogênea com custo fixo e disponibilidade, compatibilidade cliente–tipo, janelas de tempo e clientes **opcionais** que, se não atendidos, pagam penalidade $\rho_i$.

## Como rodar

```bash
julia rich_parser.jl      # auto-teste do parser
julia richvrp_model.jl
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o cutoff `ub` para o ótimo conhecido + 0.01.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `rich_parser.jl` | `read_rich(path)` e auto-teste (formato próprio `.rvrp`) |
| `toy_rich.rvrp` | Toy: 2 depósitos, 3 tipos, 6 clientes, 2 opcionais |
| `rich_R101_25.rvrp` | **Regressão VRPTW:** R101 com 25 clientes, convertido (1 depósito, 1 tipo, $f = 0$, `DIST trunc1`) |
| `rich_p01.rvrp` | **Regressão MDVRP:** p01 de Cordeau, convertido (4 depósitos, 1 tipo por depósito com $u = 4$, sem janelas) |
| `rich_mix15.rvrp` | **Instância rica:** 15 primeiros clientes do R101, 2 depósitos, 3 tipos, 3 opcionais, compatibilidades |

Esta pasta tem também o modelo e o `CVRP.cfg`.

Não existe um benchmark padrão com todos esses ingredientes juntos. A validação tem três partes:
- a toy, com força bruta;
- duas **regressões**, em que o modelo genérico precisa reproduzir ótimos já conhecidos;
- uma instância rica média, com ótimo provado no CBC.

## Formato `.rvrp` e parser

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

## Instância toy — `toy_rich.rvrp`

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

## Atenção para a modelagem

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

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **197.6854** — frota $z = [1, 0, 1]$; tipo 1: 7-1-2-7; tipo 3: 8-5-4-3-8; opcional 6 não atendido; raiz, 1 nó | 197.6854 | 0.78 s |

## Referências para o benchmark

| Instância | O que testa | Ótimo | Fonte |
|---|---|---|---|
| `rich_R101_25.rvrp` | modelo reduzido a VRPTW | **617.1** | Solomon/Kohl; também o CBC sobre o `.rvrp` (ótimo provado) |
| `rich_p01.rvrp` | modelo reduzido a MDVRP | **576.8657** | VRPSolver nos Complementares 2 (ótimo provado) |
| `rich_mix15.rvrp` | tudo junto | **622.5386** | CBC, ótimo provado. 2 rotas do tipo 1, 0 do tipo 2, 2 do tipo 3; opcionais 14 e 15 **não** atendidos |

O MIP do CBC (por tipo, com MTZ para tempo e carga, e $y_i$ nos opcionais) foi validado antes na toy (197.6854) e no R101 com 25 clientes (617.1).
