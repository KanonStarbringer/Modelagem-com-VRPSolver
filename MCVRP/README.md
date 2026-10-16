# MCVRP no VRPSolver — instância toy e parser

> Nota de estudo escrita originalmente no Obsidian. Os caminhos citados são relativos a esta pasta. Os PDFs mencionados (artigos e teses) **não** estão no repositório, por direitos autorais: consulte as referências.

Data: 2026-10-15
Contexto: exercício 1 da Lista 1 - Resolução (MCVRP). O objetivo é transformar o modelo consolidado da correção em código Julia e rodar no VRPSolver, partindo do exemplo CVRP do professor.

**Divisão do trabalho:**
- Feito: instância toy + parser (esta nota).
- Próximo passo (meu): escrever `build_model()` do MCVRP a partir do modelo da Lista 1.
- Depois: Claude verifica se o código bate com a matemática.

## Arquivos

Pasta: ``

| Arquivo | Conteúdo |
|---|---|
| `toy_4-2.txt` | Instância toy: 4 clientes, 2 produtos, mesmo formato das instâncias do benchmark |
| `mcvrp_parser.jl` | `read_mcvrp(path)` + auto-teste |

Benchmark: `MCVRP Set 1..5/<n>-<P>/<k>.txt` (189 arquivos).

## Formato das instâncias

```
N                 nº total de nós no arquivo (= 1 + P·n)
P                 nº de produtos (= compartimentos)
Q_1 ... Q_P       capacidade de cada compartimento
n_1 ... n_P       nº de clientes por produto (sempre iguais a n)
id x y d          N linhas; nó 0 = depósito
```

Cada cliente aparece **uma vez por produto**, com as mesmas coordenadas: o nó $(p-1)\,n + i$ é o cliente $i$ no produto $p$. Exemplo (Set 1, `10-2/1.txt`): nós 1 e 11 estão em (5.4742, 13.6639), com demandas 4 (produto 1) e 3 (produto 2).

Interpretei a linha 3 como capacidades e a linha 4 como nº de clientes porque é a única leitura consistente em todos os sets: no Set 2 (`40-3`) temos `15 15 15` / `40 40 40`, e $N = 121 = 1 + 3 \cdot 40$. O parser aborta se $N \neq 1 + P n$ ou se as coordenadas repetidas não baterem, e as 189 instâncias passaram nessas checagens.

## Parser — `read_mcvrp(path)`

Retorna uma NamedTuple, com índices deslocados de +1 (como no `C[i+1, j+1]` do exemplo do professor):

| Campo | Significado | Na matemática |
|---|---|---|
| `n` | nº de clientes | $\lvert V_+ \rvert$ |
| `P` | nº de produtos | $\lvert P \rvert$ |
| `Q[p]` | capacidade do compartimento $p$ | $Q_p$ |
| `d[i+1, p]` | demanda do cliente $i$ no produto $p$; `d[1, :] = 0` | $d_{ip}$, $d_{0p}=0$ |
| `C[i+1, j+1]` | distância euclidiana, **sem arredondamento** | $c_{ij}$ |
| `coord[i+1, :]` | (x, y) | — |

Uso típico:

```julia
include("mcvrp_parser.jl")
inst = read_mcvrp("toy_4-2.txt")
n, P, Q = inst.n, inst.P, inst.Q
V  = collect(0:n);  V⁺ = collect(1:n)
c(i, j)    = inst.C[i + 1, j + 1]
d(i, p)    = inst.d[i + 1, p]
L = maximum(ceil(Int, sum(d(i, p) for i in V⁺) / Q[p]) for p in 1:P)
```

Auto-teste: `julia mcvrp_parser.jl` → `OK: toy + 189 instâncias lidas`.

## Instância toy — `toy_4-2.txt`

Depósito em (50, 50); $Q = (10, 10)$.

| Cliente | (x, y) | $d_{i1}$ | $d_{i2}$ |
|---|---|---|---|
| 1 | (10, 60) | 6 | 2 |
| 2 | (45, 10) | 3 | 5 |
| 3 | (90, 60) | 4 | 4 |
| 4 | (55, 10) | 2 | 6 |

- $L = \max(\lceil 15/10 \rceil, \lceil 17/10 \rceil) = 2$, $U = 4$.
- **Ótimo (força bruta): 285.1502**, rotas $0\!-\!1\!-\!2\!-\!0$ e $0\!-\!3\!-\!4\!-\!0$ (em qualquer sentido). Cutoff sugerido: `ub = 285.16`.
- **Por que ela é útil:** os clientes 2 e 4 estão a 10 unidades um do outro, e a solução $\{2,4\},\{1,3\}$ custaria **253.08**. Ela é inviável **só por causa do compartimento 2** ($5 + 6 = 11 > 10$); no compartimento 1 cabe ($3 + 2 = 5$). Então:
  - se o modelo resultar em **253.08**, o recurso do produto 2 não está sendo aplicado (por exemplo, só um recurso foi criado);
  - um modelo de capacidade única com $Q = 20$ e demanda agregada $d_i = \sum_p d_{ip}$ também aceitaria $\{2,4\}$ ($8 + 5 = 13 \le 20$) e erraria da mesma forma.

## Resultado do modelo na toy (2026-10-15)

Modelo `mcvrp_model.jl`: formulação por **arestas**, como no exemplo do professor, com um recurso descartável por produto (`main` só no produto 1) e consumo $d_{v,p}$.

- VRPSolver: **285.1502**, igual ao ótimo da força bruta. Resolveu no nó raiz (1 nó, cota da raiz igual ao ótimo, 0.61 s).
- Arestas usadas: 0–1, 1–2, 0–2, 0–3, 3–4, 0–4, ou seja, as rotas $0\!-\!1\!-\!2\!-\!0$ e $0\!-\!3\!-\!4\!-\!0$.
- A armadilha $\{2,4\}$ (253.08) foi evitada, o que confirma que o recurso do produto 2 está ativo.

## Resultado no benchmark — Set 1, `10-2/1.txt`

- VRPSolver: **503.3044**, sem cutoff, resolvido no nó raiz em 0.63 s.
- Rotas: $0\!-\!1\!-\!3\!-\!0$, $0\!-\!4\!-\!8\!-\!9\!-\!0$, $0\!-\!5\!-\!2\!-\!6\!-\!0$, $0\!-\!7\!-\!10\!-\!0$. São 4 rotas, $= L = \max(\lceil 35/10\rceil, \lceil 32/10\rceil)$.
- Cargas $(p_1, p_2)$: (6, 7), (9, 10), (10, 9), (10, 6). Todas cabem em $Q = (10, 10)$.
- Conferido por programação dinâmica exata em Python (Held–Karp por subconjunto + partição de conjuntos): **503.3044**, o mesmo valor.
- Ainda não comparado com o valor publicado (falta checar a variante e o arredondamento das distâncias, ver abaixo).
- **`10-2/2.txt`:** **410.2322** (raiz, 0.59 s). Rotas $0\!-\!1\!-\!9\!-\!2\!-\!0$, $0\!-\!4\!-\!8\!-\!5\!-\!6\!-\!0$, $0\!-\!7\!-\!3\!-\!10\!-\!0$, com cargas (7, 7), (10, 10), (6, 10). São 3 rotas, $= L = \max(\lceil 2.3\rceil, \lceil 2.7\rceil)$. A programação dinâmica exata confirma o valor.
- Ao rodar no WSL: passe o caminho com `joinpath(@__DIR__, "MCVRP Set 1", "10-2", "1.txt")`. Uma string `"C:\Users\..."` dá erro de escape em Julia e, além disso, não existe no Linux.

## Atenção ao comparar com o benchmark

O arquivo traz um nó por par (cliente, produto). Em parte da literatura de MCVRP isso significa que **cada produto de um cliente pode ser entregue por um veículo diferente**. O modelo da Lista 1 faz outra coisa: cada cliente recebe **uma visita**, com todos os produtos juntos ($d_{ip}$ agregado pelo parser). Antes de comparar com os valores publicados, confira no artigo de origem das instâncias qual variante foi resolvida e se as distâncias foram arredondadas. Se for a variante com entregas separadas, basta usar os $P \cdot n$ nós do arquivo como clientes, cada um consumindo só o seu recurso.

## Notas relacionadas

- Lista 1 - Resolução · Multi-Compartment VRP · Capacitated VRP
- Como modelar no VRPSolver - Subproblemas, recursos e conjuntos
- VRPSolver
