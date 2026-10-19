# CARP — Capacitated Arc Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF). Nota completa da leva: [`README-complementares-6.md`](../README-complementares-6.md).

## Definição

Grafo não direcionado $G = (N, E)$, com depósito no nó 0 e custo $c_e$ em cada aresta. As arestas com demanda $d_e > 0$ são **requeridas** ($E_R$) e precisam ser **atendidas** por exatamente um veículo, de capacidade $Q$. Um veículo pode atravessar qualquer aresta sem atendê-la, pagando $c_e$ (*deadheading*), inclusive uma aresta requerida que outro veículo atende. Frota livre. Objetivo: minimizar o custo total, atendimento mais deadheading (Golden & Wong, 1981).

É o problema da coleta de lixo, da limpeza de ruas e da leitura de medidores: a demanda está **ao longo** das ruas.


## Como rodar

```bash
julia carp_parser.jl     # auto-teste do parser
julia carp_model.jl
```

No topo do `carp_model.jl`, escolha a instância e o cutoff `ub` (custo ótimo + 0.01; ver `referencias.csv`).

## Por que não usar os nós do grafo como vértices do pricing

A ideia direta seria: vértices = nós de $G$, arcos de atendimento $(u, v)$ e $(v, u)$ por aresta requerida, e arcos de deadheading com consumo 0. Isso esbarra em uma regra do VrpSolver (página *Resources* da documentação): **não pode haver ciclo com consumo zero em todos os recursos principais**. Dois arcos de deadheading $u \to v \to u$ já formam esse ciclo. Além disso, atender $(v, u)$ e terminar no mesmo nó de onde se saiu gera laços.

## Modelo no VRPSolver: grafo de estados

**Vértices:** o depósito 0 e, para cada aresta requerida $e = \{u, v\}$, dois **estados**: $s_{e,0}$ = "acabei de atender $e$ de $u$ para $v$" (estou em $v$) e $s_{e,1}$ = "acabei de atender de $v$ para $u$" (estou em $u$). São $2|E_R|$ estados. Source = sink = 0, $L = 0$, $U = |E_R|$.

**Arcos:** de cada vértice $s$ (no nó físico $p$) para cada estado $s_{f,o}$ de outra aresta $f$, com início no nó $q$:
- significado: deadheading de $p$ até $q$ pelo **caminho mínimo**, depois atendimento de $f$;
- consumo $d_f > 0$: todo ciclo passa por atendimentos, então a regra do consumo zero é respeitada;
- mapeamento: $x_f$ (atendimento) e $y_{pq}$ (deadheading), este só se $p \ne q$.

E de cada estado $s$ para o depósito: volta pelo caminho mínimo, consumo 0, mapeado em $y_{p0}$.

Variáveis auxiliares de custo zero, só para o RCC (ver o aviso abaixo): $\mathit{sai}_f$ nos arcos que saem do depósito para atender $f$, e $\mathit{volta}_e$ nos arcos que voltam ao depósito vindos de um estado de $e$.

**Mestre** ($x$ e $y$ inteiras):

$$\min \sum_{e \in E_R} c_e\, x_e + \sum_{(p, q)} \mathrm{sp}(p, q)\, y_{pq} \qquad \text{s.a.} \qquad x_e = 1 \quad \forall e \in E_R$$

**Packing sets em vértices:** $\{s_{e,0}, s_{e,1}\}$ para cada aresta requerida: a aresta é atendida uma vez, em um dos dois sentidos. A matriz de elementaridade usa a menor distância entre as pontas das arestas.

**Cortes de capacidade (RCC):** `add_capacity_cut_separator!(model, [(PS[e], d_e)], Q)`, com cada packing set e sua demanda. É a primeira vez que usamos os RCC nas complementares; o VrpSolver só os aceita com packing sets em **vértices**, o que o grafo de estados permite.

> [!warning] O RCC exige uma variável "própria" em cada arco
> A primeira versão deu `BaPCod error : cannot build the model`. A causa estava no separador RCC: ele precisa, **em cada arco do grafo, de exatamente uma variável mapeada só em arcos entre o mesmo par de packing sets** (o depósito conta como um packing set à parte). Aqui `x_f` e `y_{pq}` aparecem em arcos de muitos pares, então não servem para isso.
> - Para os arcos entre duas arestas requeridas, o VrpSolver cria sozinho as variáveis internas `RCCsepX` (o aviso `adding 15 internal variables mapping to 118 arcs`).
> - Para os arcos que saem do depósito ou voltam a ele, ele **não** cria nada. É preciso declarar `sai[e]` e `volta[e]`, inteiras, de custo zero, e mapeá-las junto com `x` e `y`. Antes, o arco de volta de um estado que termina no próprio depósito (aresta 0–1 atendida de 1 para 0) não tinha variável nenhuma, e o BaPCod também recusava o modelo por isso.
> - Sem `add_capacity_cut_separator!`, o modelo original já dava 52. O problema era só a preparação dos cortes.

**Branching:** Ryan-Foster nos packing sets, como no BPP: os veículos são idênticos.

## Arquivos

Pasta `esta pasta/` do WSL:

| Caminho | Conteúdo |
|---|---|
| `Instancias/gdb*.dat` | 23 instâncias de Golden, DeArmon & Baker (1983); todas as arestas são requeridas |
| `Instancias/val*.dat` | 34 instâncias de Benavent et al. (1992) |
| `Instancias/egl-{e,s}*.dat` | 24 instâncias de Li & Eglese (1996), de 77 e 140 nós |
| `Instancias/kshs*.dat` | 6 instâncias de Kiuchi et al. (1995) |
| `referencias.csv` | limites inferior e superior de cada instância, como vêm nos arquivos |
| `carp_parser.jl` | `read_carp(path)`, com caminhos mínimos (Floyd-Warshall), e auto-teste |
| `toy_carp.dat` | toy |
| `carp_model.jl` | o modelo |

As instâncias vêm do pacote [CARPData.jl](https://github.com/rafaelmartinelli/CARPData.jl), de Rafael Martinelli, que reúne os conjuntos clássicos num formato único. **Ótimos provados:** os 23 gdb, os 34 val e os 6 kshs; dos 24 egl, 12 (os demais têm `lb < ub`). O número de veículos dos arquivos é só informativo: os valores de referência são para frota livre.

## Parser

```julia
include("carp_parser.jl")
inst = read_carp(joinpath(@__DIR__, "toy_carp.dat"))
inst = read_carp(joinpath(@__DIR__, "Instancias", "gdb1.dat"))
inst.nv, inst.Q, inst.R[k]        # R[k] = (u, v, custo, demanda) da k-ésima aresta requerida
inst.sp[i+1, j+1]                 # caminho mínimo de i a j (vértices 0-based no arquivo)
inst.lb, inst.ub
```

Auto-teste: `julia carp_parser.jl` → `OK: toy + 87 instâncias CARP lidas (gdb, val, egl e kshs)`.

## Instância toy — `toy_carp.dat`

6 nós, 9 arestas, 6 requeridas, $Q = 6$.

| Aresta | (1, 4) | (2, 3) | (1, 2) | (0, 5) | (0, 3) | (2, 4) | (0, 1) | (3, 4) | (2, 5) |
|---|---|---|---|---|---|---|---|---|---|
| $c_e$ | 8 | 2 | 6 | 9 | 1 | 7 | 3 | 8 | 7 |
| $d_e$ | 1 | 4 | 1 | — | — | 3 | 2 | — | 2 |

**Ótimo (força bruta: partição das arestas em rotas e, em cada rota, melhor ordem e sentido): 52**, com cutoff `52.01`:

| Rota | Percurso (`~>` deadheading, `=` atendimento) | Custo | Carga |
|---|---|---|---|
| 1 | 0 ~> 1 = 4 = 2 = 5 ~> 0 | 3 + (8 + 7 + 7) + 9 = 34 | 6 |
| 2 | 0 ~> 3 = 2 = 1 ~> 0 | 1 + (2 + 6) + 3 = 12 | 5 |
| 3 | 0 = 1 ~> 0 | 3 + 3 = 6 | 2 |

A rota 1 começa atravessando sem atender a aresta (0, 1), que a rota 3 atende. A rota 3 volta pela mesma aresta que atendeu.

Armadilhas (força bruta):

| Modelo errado | Resultado |
|---|---|
| Só um sentido de atendimento por aresta (o do arquivo) | **65** |
| Sem o custo da volta ao depósito (arco $s \to 0$ sem mapeamento) | **37** |
| Sem deadheading (arcos mapeados só em $x$) | **33**: só a soma dos $c_e$ requeridos |
| $x$ e $y$ contínuas | **48**: a relaxação por rotas elementares |

## Atenção para a modelagem

- **Ids:** estado $s_{e,o}$ = `2(e-1) + o + 1`; o depósito é 0.
- **Não ligar um estado de $e$ a outro estado de $e$**: seria atender a mesma aresta duas vezes.
- **Mapeamento com vetor:** `add_arc_var_mapping!(G, a, [x[f], y[(p, q)]])`, como o `x[0]` do BPP.
- **Variáveis $y$:** só os pares $(p, q)$ realmente usados (nó onde se está, nó onde começa o próximo atendimento, ou o depósito). São no máximo (nº de nós)² pares: 19 600 nas egl-s, de 140 nós.
- **Impressão:** `get_path_arcs(optimizer, p)` devolve os arcos do caminho; um dicionário `id do arco => (nó de saída, aresta, sentido)`, montado ao criar os arcos, traduz cada um.

## Referências para o benchmark (`referencias.csv`)

| Instância | Nós | Requeridas | $Q$ | Ótimo | cutoff |
|---|---|---|---|---|---|
| gdb1 | 12 | 22 | 5 | 316 | `316.01` |
| gdb8 | 27 | 46 | 27 | 348 | `348.01` |
| gdb23 | 11 | 55 | 27 | 233 | `233.01` |
| kshs1 | 8 | 15 | 150 | 14661 | `14661.01` |
| val1A | 24 | 39 | 200 | 173 | `173.01` |
| val10A | 50 | 97 | 250 | 428 | `428.01` |
| egl-e1-A | 77 | 51 | 305 | 3548 | `3548.01` |

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy | **52** — raiz 52.00, 1 nó; 3 rotas: `0 ~> 1 = 2 = 3 ~> 0` (12), `0 ~> 2 = 4 = 1 = 0` (21), `0 ~> 5 = 2 ~> 0` (19) | 52 | 0.67 s |
| gdb1 | **316** — raiz 316.00, 1 nó; 5 rotas (56 + 33 + 58 + 66 + 103), quatro com carga 5/5 | 316 | 3.91 s |
| val1A | **não resolveu**: busca interrompida, sem solução. LP da raiz 146 → 166 com RCC e rank-1 (gap de 4%); strong branching a ~22 s por candidato; depois de 5 nós, `labelling time has exploded` e `SEARCH IS INTERRUPTED due to the pricing problem return status` | 173 | 4057 s |
| val1C | **245** — raiz 241.00 (gap 1,6%), 3 nós; 9 rotas, cargas de 26 a 45/45. Mesmo grafo da val1A, mas com Q = 45: rotas curtas e o modelo resolve em segundos | 245 | 13.54 s |
| val3C | **138** — raiz 138.00, 1 nó; 7 rotas, cinco com carga 20/20 | 138 | 3.94 s |
| kshs1 | **14661** — raiz 14661.00, 1 nó; 4 rotas | 14661 | 1.76 s |
| egl-e1-C | **5595** — raiz 5595.00, 1 nó; 10 rotas, sete com carga ≥ 156/160. A maior resolvida (77 nós, 51 arestas requeridas, 98 no grafo); o grafo original tem arestas não requeridas, só atravessadas em vazio | 5595 | 112.19 s |

> [!note] Rotas longas (val\*A, val10A)
> Com Q = 200 e só 2 veículos, cada rota atende ~20 arestas. A rotulagem do pricing explode, o enumerador não fecha e os cortes de capacidade quase não pesam, porque a capacidade mal aperta. O que provavelmente falta à raiz (hipótese, não testada) são as restrições de **paridade** (*odd-cut*, Belenguer e Benavent): em todo corte com número ímpar de arestas requeridas, alguma travessia em vazio é obrigatória. O modelo de estados não as enxerga, porque o deadheading vem agregado em caminhos mínimos. As instâncias com muitos veículos (val\*C, egl-\*-C) têm rotas curtas e são o alvo natural deste modelo.

## Fontes (da leva)

- Ross, G. T., Soland, R. M. (1975). A branch and bound algorithm for the generalized assignment problem. *Mathematical Programming* 8, 91–103.
- Savelsbergh, M. (1997). A branch-and-price algorithm for the generalized assignment problem. *Operations Research* 45(6), 831–841.
- Chu, P. C., Beasley, J. E. (1997). A genetic algorithm for the generalised assignment problem. *Computers & Operations Research* 24(1), 17–23.
- Yagiura, M., Ibaraki, T., Glover, F. (2004). An ejection chain approach for the generalized assignment problem. *INFORMS Journal on Computing* 16(2), 133–151. Instâncias: <http://www.al.cm.is.nagoya-u.ac.jp/~yagiura/gap/>
- Beasley, J. E. OR-Library: <http://people.brunel.ac.uk/~mastjjb/jeb/orlib/gapinfo.html>
- Golden, B. L., Wong, R. T. (1981). Capacitated arc routing problems. *Networks* 11(3), 305–315.
- Golden, B. L., DeArmon, J. S., Baker, E. K. (1983). Computational experiments with algorithms for a class of routing problems. *Computers & Operations Research* 10(1), 47–59. (gdb)
- Benavent, E., Campos, V., Corberán, A., Mota, E. (1992). The capacitated arc routing problem: lower bounds. *Networks* 22, 669–690. (val)
- Li, L. Y. O., Eglese, R. W. (1996). An interactive algorithm for vehicle routeing for winter-gritting. *Journal of the Operational Research Society* 47, 217–228. (egl)
- Kiuchi, M., Shinano, Y., Hirabayashi, R., Saruwatari, Y. (1995). An exact algorithm for the capacitated arc routing problem using parallel branch and bound method. *Abstracts of the 1995 Spring National Conference of the Operations Research Society of Japan*, 28–29. (kshs)
- Martinelli, R. CARPData.jl: <https://github.com/rafaelmartinelli/CARPData.jl> (instâncias e limites).
- Pessoa, A., Sadykov, R., Uchoa, E., Vanderbeck, F. (2020). A generic exact solver for vehicle routing and related problems. *Mathematical Programming* 183, 483–523.
