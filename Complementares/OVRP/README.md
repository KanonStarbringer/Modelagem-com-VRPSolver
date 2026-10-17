# OVRP — Open Vehicle Routing Problem

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF).

Como o CVRP, mas os veículos **não voltam ao depósito**: a rota termina no último cliente, e a volta não tem custo.

## Como rodar

```bash
julia ../cvrp_parser.jl   # auto-teste do parser compartilhado
julia ovrp_model.jl
```

O modelo usa o parser e as instâncias da pasta de cima (`../cvrp_parser.jl`, `../Instancias/`).

## Atenção para a modelagem

- Variáveis `y[i in V⁺]` indicam que "a rota termina em $i$". O grau fica `sum(x[e] for e in δ[i]) + y[i] == 2`.
- Os dois sentidos das arestas entre clientes são mapeados para `x[(i,j)]`. A saída $(0,i)$ é mapeada **só** para `x[(0,i)]`. O retorno $(i,0)$ é mapeado para **`y[i]`**, que não entra no objetivo, então a volta custa 0.
- Recurso, packing sets e branching são os mesmos do CVRP.
- **Para o benchmark de Letchford et al.:** use **exatamente $K$ veículos** ($L = U = K$, com `inst.K`) e **custo real** (`read_cvrp(...; arred = false)`). A toy usa frota livre.

## Instância toy — `toy_comp.vrp`

A mesma toy do CVRP ($Q = 11$, frota livre). **Ótimo: 67**, com rotas abertas 0-1-2-3 (30), 0-4-5 (22) e 0-6 (15).

| Modelo errado | Resultado |
|---|---|
| Custo das arestas do depósito zerado (nas duas direções) | **0**: cada cliente numa rota sozinho |
| OVRP fechado (o retorno mapeado em `x[(0,i)]`) | **134**, que é o CVRP |
| Exatamente $K = 2$ veículos | **96** |

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy (frota livre) | **67** | 67 | 0.80 s |
| A-n32-k5 ($L = U = 5$, custo real) | **487.3058**, raiz, 1 nó | 487.306 | 0.75 s |

A-n32-k5, conferido em Python: 0-6-3-2-23-28-4-11 (129.04; carga 95), 0-20-5-25-10-29-15-22-9-18-8 (191.17; 98), 0-26-7-13-21-31-19-17 (86.01; 98), 0-27-24-14 (37.02; 47) e 0-30-16-12-1 (44.06; 72).

Os ótimos de 20 instâncias estão em [`../otimos.csv`](../otimos.csv), na coluna `ovrp_real`. Por exemplo: P-n16-k8 = 235.06, E-n22-k4 = 252.614 e E-n51-k5 = 416.063.

## Fontes

- Letchford, A. N., Lysgaard, J., Eglese, R. W. (2007). A branch-and-cut algorithm for the capacitated open vehicle routing problem. *JORS* 58(12), 1642–1651. <https://www.lancaster.ac.uk/staff/letchfoa/articles/2007-covrp.pdf>
- CVRPLIB: <https://galgos.inf.puc-rio.br/cvrplib/>
