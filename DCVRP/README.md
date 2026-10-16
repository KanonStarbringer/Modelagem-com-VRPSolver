# DCVRP no VRPSolver — instâncias, toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-15
Contexto: exercício 2 da Lista 1 - Resolução (DCVRP). Segue o mesmo roteiro de [MCVRP no VRPSolver - Instância toy e parser](../MCVRP/README.md): dados prontos aqui, e eu escrevo o modelo depois.

## Arquivos

| Caminho | Conteúdo |
|---|---|
| `Instancias/CMT/CMT1..14.vrp` | Set CMT (Christofides, Mingozzi & Toth, 1979), baixado do CVRPLIB |
| `toy_dcvrp.vrp` | Instância toy no mesmo formato |
| `dcvrp_parser.jl` | `read_cvrplib(path)` + auto-teste |

Fonte: [CVRPLIB](https://galgos.inf.puc-rio.br/cvrplib/index.php/en/instances).

## Instâncias CMT

As instâncias com limite de rota são cópias de outras instâncias do mesmo set, acrescidas de `DISTANCE` (limite $D$) e `SERVICE_TIME` (tempo de serviço $s$). Conferi isso nos cabeçalhos baixados e no auto-teste (CMT6 e CMT1 têm a mesma matriz $C$).

| DCVRP | $n$ | $Q$ | $D$ | $s$ | Ótimo | CVRP base | Ótimo base |
|---|---|---|---|---|---|---|---|
| CMT6 | 50 | 160 | 200 | 10 | 555.43 | CMT1 | 524.61 |
| CMT7 | 75 | 140 | 160 | 10 | 909.68 | CMT2 | 835.26 |
| CMT8 | 100 | 200 | 230 | 10 | 865.94 | CMT3 | 826.14 |
| CMT9 | 150 | 200 | 200 | 10 | 1162.55 | CMT4 | 1028.42 |
| CMT10 | 199 | 200 | 200 | 10 | 1395.85 | CMT5 | 1291.29 |
| CMT13 | 120 | 200 | 720 | 50 | 1541.14 | CMT11 | 1042.12 |
| CMT14 | 100 | 200 | 1040 | 90 | 866.37 | CMT12 | 819.56 |

Os ótimos são os listados no CVRPLIB (marcados como provados).

**Convenção do tempo de serviço:** o limite vale para comprimento + serviço,
$$\sum_{(i,j) \in \text{rota}} c_{ij} + s \cdot |\text{clientes da rota}| \le D,$$
mas o **custo publicado é só a distância**. No modelo da Lista 1, isso dá $\ell_{ij} = c_{ij} + s_j$ (com $s_0 = 0$) no recurso de distância, enquanto a função objetivo continua com $c_{ij}$.

**Distâncias:** euclidianas **sem arredondamento**. O campo `EDGE_WEIGHT_TYPE : EUC_2D` sugeriria arredondar (convenção TSPLIB), mas os ótimos do CMT (ex.: 555.43) são em reais.

Outros conjuntos, grandes demais para começar: Golden et al. (1998), instâncias 1–8, com 200 a 480 clientes e `DISTANCE` sem tempo de serviço; Li, Golden & Wasil (2005), com 560 a 1200 clientes.

## Parser — `read_cvrplib(path)`

Lê o formato CVRPLIB/TSPLIB. O id TSPLIB $k$ vira o vértice $k-1$, então o depósito é o vértice 0, como no exemplo do professor.

| Campo | Significado | Na matemática |
|---|---|---|
| `n` | nº de clientes | $\lvert V_+ \rvert$ |
| `Q` | capacidade | $Q$ |
| `D` | limite por rota; `Inf` se ausente | $D$ |
| `s` | tempo de serviço; `0.0` se ausente | $s_j$ ($j \in V_+$) |
| `d[i+1]` | demanda; `d[1] = 0` | $d_i$ |
| `C[i+1, j+1]` | distância euclidiana | $c_{ij}$ |

O parser aborta se o arquivo não for `EUC_2D`, se houver mais de um depósito, se o depósito não for o nó 1 ou se as seções não tiverem `DIMENSION` linhas.

Auto-teste: `julia dcvrp_parser.jl` → `OK: toy + 14 instâncias CMT lidas`.

Esboço do bloco de dados:

```julia
include("dcvrp_parser.jl")
inst = read_cvrplib(joinpath(@__DIR__, "toy_dcvrp.vrp"))
n, Q, D = inst.n, inst.Q, inst.D
c(i, j) = inst.C[i + 1, j + 1]
d(i)    = inst.d[i + 1]
s(i)    = i == 0 ? 0.0 : inst.s
```

## Instância toy — `toy_dcvrp.vrp`

Depósito em (0, 0); $Q = 10$; $D = 80$; $s = 5$; todas as demandas iguais a 2.

| Cliente | (x, y) |
|---|---|
| 1 | (10, 0) |
| 2 | (20, 0) |
| 3 | (0, 10) |
| 4 | (0, 20) |

A capacidade não limita: $L = \lceil 8/10 \rceil = 1$, então uma rota só caberia. O que obriga a usar duas rotas é o limite $D$.

| Modelo | Ótimo (força bruta) | Rotas |
|---|---|---|
| **Correto** ($D = 80$, $\ell = c + s$) | **80.0** | $0\!-\!1\!-\!2\!-\!0$, $0\!-\!3\!-\!4\!-\!0$ (cada uma: 40 + 10 = 50) |
| Sem tempo de serviço no recurso | 68.28 | $0\!-\!1\!-\!2\!-\!4\!-\!3\!-\!0$ (68.28 ≤ 80) |
| Sem recurso de distância | 68.28 | idem |

- Se o modelo der **68.28**, o recurso de distância falta ou está sem o $s_j$. Para separar os dois casos, rode com $D = 60$: sem o $s_j$, o modelo passa a dar 80; sem o recurso, continua em 68.28.
- A rota única tem comprimento 68.28 + 4·5 = 88.28 > 80, por isso é inviável.
- Cutoff sugerido para a toy: `ub = 80.01`.

## Resultado do modelo na toy (2026-10-15)

Modelo: formulação por arestas, como no professor, com dois recursos descartáveis: `cap` (main, consumo $d_v$) e `dist` (secundário, consumo $c_{uv} + s_v$, limite $[0, D]$).

- VRPSolver: **80.0**, igual à força bruta. Resolveu no nó raiz, em 0.60 s e sem cutoff.
- Arestas: 0–1, 1–2, 0–2, 0–3, 3–4, 0–4, ou seja, as rotas $0\!-\!1\!-\!2\!-\!0$ e $0\!-\!3\!-\!4\!-\!0$.
- A solução não caiu na rota única (68.28), o que confirma que o recurso de distância está ativo e soma o tempo de serviço.

## Resultado no benchmark — CMT1 (CVRP, sem $D$)

- VRPSolver: **524.6111**, igual ao ótimo do CVRPLIB (524.61). Resolveu no nó raiz em 1.76 s, com `Dmax = 1e6`.
- 5 rotas, reconstruídas das arestas e conferidas em Python: os 50 clientes cobertos uma vez, cargas 152, 149, 159, **160**, 157 (≤ Q = 160).
- Se as mesmas rotas fossem avaliadas com os limites do CMT6 ($D = 200$, $s = 10$), o comprimento + serviço daria 188.45, **228.52**, 199.33, **209.25**, 199.06. Duas rotas estourariam, então o ótimo do CMT1 é inviável no CMT6, e o custo tem que subir (para 555.43).
- Ao rodar no WSL: as instâncias ficam em `DCVRP/Instancias/CMT/`, então o caminho é `joinpath(@__DIR__, "Instancias", "CMT", "CMT1.vrp")`.

## Resultado no benchmark — CMT6 (DCVRP, $D = 200$, $s = 10$)

- Sem cutoff: muito mais lento que o CMT1. Com `set_cutoff!(optimizer, 555.44)`: **555.4302**, igual ao ótimo do CVRPLIB (555.43). Resolveu no nó raiz, em 6.6 s. A distância continuou como recurso secundário.
- **6 rotas**, contra 5 no CMT1, conferidas em Python: os 50 clientes cobertos uma vez. Comprimento + serviço: 198.08, 199.12, 190.64, 189.94, 82.33, 195.33 (todas ≤ 200). Cargas: 137, 155, 133, 131, 80, 141 (todas ≤ 160, nenhuma lotada).
- **Leitura:** no CMT1 era a capacidade que limitava (uma rota com carga 160). No CMT6 o que limita é $D$: quatro rotas ficam a menos de 10 do limite, e é preciso um veículo a mais, com a rota curta $0\!-\!18\!-\!4\!-\!47\!-\!46\!-\!0$. O custo extra pelo limite de rota é $555.43 - 524.61 = 30.82$.
- **Lição prática:** quando há um ótimo ou um bom limite superior conhecido, passar o cutoff faz uma diferença enorme no DCVRP, porque permite descartar rotas e fixar arcos por custo reduzido logo no início.

## Resultado no benchmark — CMT7 ($n = 75$, $Q = 140$, $D = 160$, $s = 10$)

- Com cutoff 909.69: **909.6751**, igual ao ótimo do CVRPLIB (909.68). Resolveu no nó raiz em 3.9 s.
- **11 rotas**, conferidas em Python: os 75 clientes cobertos uma vez. Comprimento + serviço entre 127.16 e **159.92** (≤ 160). Duas rotas com carga **140** (= Q).
- **Leitura:** aqui os dois recursos apertam ao mesmo tempo. Seis rotas ficam a menos de 10 do limite $D$, e duas lotam a capacidade.

## Resultado no benchmark — CMT14 ($n = 100$, $Q = 200$, $D = 1040$, $s = 90$)

- Com cutoff 866.38: **866.3652**, igual ao ótimo do CVRPLIB (866.37). Mas foi bem mais pesado: **21 nós**, raiz em 396.85 s e total de **2962 s (~49 min)**.
- Cota da raiz: 841.86, ou seja, gap de $(866.37 - 841.86)/866.37 \approx$ **2.8%**. Em todas as instâncias anteriores a raiz fechou o gap.
- **11 rotas**, conferidas em Python: os 100 clientes cobertos uma vez. Comprimento + serviço até **1028.04** (≤ 1040). Cinco rotas com carga **200** (= Q).
- **O que domina é o serviço:** cada rota gasta de 450 a 900 em serviço e só de 45 a 128 em deslocamento. Na prática, $D = 1040$ funciona como um limite de **no máximo 10 clientes por rota** ($11 \cdot 90 = 990$, e sobram 50 para o deslocamento, o que não basta). Oito rotas têm 9 ou 10 clientes.
- Custo do limite de rota: $866.37 - 819.56$ (CMT12) $= 46.81$.
- **Por que demorou:** como o recurso de distância é secundário, o pricing não consegue organizar os rótulos por ele, justamente quando é ele que mais limita. A relaxação também fica mais fraca, porque os cortes de capacidade não capturam o limite "≤ 10 clientes". Vale testar `dist` com `main = true` nessa instância.

### CMT14 — teste dos recursos principais (cutoff 866.38 nos dois casos)

| Config. | `cap` | `dist` | Cota da raiz | Gap raiz | Tempo raiz | Nós | Tempo total |
|---|---|---|---|---|---|---|---|
| A | main | secund. | 841.86 | 2.8% | 396.85 s | 21 | 2962 s |
| B | main | main | 844.89 | 2.5% | 506.10 s | 23 | 2914 s |

- Mesmo ótimo (866.3652) e **as mesmas arestas** nas duas configurações.
- Os dois recursos como principais quase não mudaram o tempo total (−1.6%, dentro do que pode variar entre execuções). A raiz ficou mais lenta, a cota da raiz um pouco melhor e a árvore praticamente igual.
- **Conclusão:** minha hipótese de que a escolha do `main` era o gargalo **não se confirmou**. O custo está no gap da raiz (~2.5–2.8%), que obriga a ramificar. Isso vem da relaxação, porque os cortes não capturam o limite de "≤ 10 clientes" induzido por $D$ e $s$. Para avançar, os candidatos são os parâmetros de corte e de branching no `CVRP.cfg`, não a declaração dos recursos.

## Validação planejada no benchmark

1. Rodar **CMT1** (CVRP, 524.61) e **CMT6** (DCVRP, 555.43) com o mesmo código. A diferença entre os dois resultados mede o efeito do recurso de distância.
2. Depois CMT7 (909.68) e CMT14 (866.37). CMT14 tem $s = 90$, o que testa bem a convenção do tempo de serviço.

## Notas relacionadas

- Lista 1 - Resolução · Distance Constrained VRP · Capacitated VRP
- [MCVRP no VRPSolver - Instância toy e parser](../MCVRP/README.md)
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos · VRPSolver
