# VRP com custo fixo (FCVRP)

> Parte dos [exercícios complementares](../README.md) da disciplina **Modelagem com VRPSolver** (PPGEP/UFF).

Como o CVRP, mas cada veículo usado paga um **custo fixo** $f$. O objetivo passa a ser $\sum c\,x + f \cdot (\text{nº de rotas})$, e o modelo pode preferir menos rotas, mais longas.

## Como rodar

```bash
julia ../cvrp_parser.jl   # auto-teste do parser compartilhado
julia fcvrp_model.jl
```

O modelo usa o parser e as instâncias da pasta de cima (`../cvrp_parser.jl`, `../Instancias/`). O custo fixo da toy vem do campo `FIXED_COST` (`inst.f`).

## Atenção para a modelagem

- Variável `z` inteira (o número de veículos), com objetivo `Σ c·x + f·z`.
- Cada arco de **saída** $(0,i)$ é mapeado para `x[(0,i)]` **e** para `z`: `add_arc_var_mapping!(G, a, [x[(0,i)], z])`. O retorno $(i,0)$ é mapeado **só** para `x[(0,i)]`. Assim, cada rota soma exatamente 1 em `z`.

## Instância toy — `toy_comp.vrp`

A mesma toy do CVRP, com $f = 20$. **Ótimo: 184** = 144 de roteamento + 2·20, com rotas 0-1-5-6-0 (70) e 0-2-3-4-0 (74). Com $f = 20$, compensa usar 2 rotas em vez das 3 do CVRP, que custariam 134 + 3·20 = 194.

| Modelo errado | Resultado |
|---|---|
| `z` mapeado nos dois sentidos das arestas do depósito | **224** = 144 + 2·(2·20) |
| Custo fixo ignorado | **134**, as rotas do CVRP |

## Resultados

| Instância | Obtido | Esperado | Tempo |
|---|---|---|---|
| toy ($f = 20$) | **184**, $z = 2$ | 184 | 0.75 s |
| A-n32-k5 ($f = 0$, arredondado) | **784**, $z = 5$ | 784 (= CVRP) | 0.87 s |
| A-n32-k5 ($f = 1000$) | **5784**, $z = 5$, mesmas rotas | 784 + 5·1000 | 0.88 s |

Não há benchmark padrão para custo fixo com frota homogênea. As duas verificações exatas são:
- com $f = 0$, o modelo vira o CVRP;
- com $f$ grande, a frota cai ao mínimo. No A-n32-k5, o ótimo do CVRP já usa o mínimo de 5 veículos.

## Fontes

- CVRPLIB: <https://galgos.inf.puc-rio.br/cvrplib/>
