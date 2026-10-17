# Modelagem com VRPSolver

Exercícios de sala de aula da disciplina **Modelagem com VRPSolver**, do Programa de Pós-Graduação em Engenharia de Produção da **Universidade Federal Fluminense (UFF)**, ministrada pelo **Prof. Marcos Roboredo**.

Os modelos usam o [VRPSolver](https://vrpsolver.math.u-bordeaux.fr/) (Julia, `VrpSolver.jl` + JuMP) e seguem a **formulação por arestas** do exemplo de CVRP visto em aula: variáveis `x[e]` sobre as arestas, os dois sentidos de cada aresta mapeados para a mesma variável, recursos no grafo do subproblema e packing sets.

## Conteúdo

| Pasta | Problema | Instância toy | Benchmark |
|---|---|---|---|
| [`Modelos/`](Modelos) | Exemplos das aulas: CVRP (simétrico e assimétrico), VRPTW, HFVRP, MDVRP | — | — |
| [`MCVRP/`](MCVRP/README.md) | Multi-Compartment VRP | ✓ | 189 instâncias (Sets 1–5); 2 conferidas por DP exata |
| [`DCVRP/`](DCVRP/README.md) | Distance-Constrained VRP | ✓ | CMT1–14 (CVRPLIB); CMT1, 6, 7, 14 batem com os ótimos publicados |
| [`MTVRP/`](MTVRP/README.md) | Multi-Trip VRP | ✓ | 56 instâncias de Taillard et al. (1996); 2 batem com Mingozzi et al. (2013) |
| [`TOP/`](TOP/README.md) | Team Orienteering Problem | ✓ | 387 instâncias de Chao et al. (1996); p2.2.e e p1.2.p batem |
| [`PTP/`](PTP/README.md) | Profitable Tour Problem com capacidade (CPTP) | ✓ | 10 instâncias de Archetti et al.; p06 resolvido |
| [`GVRP/`](GVRP/README.md) | Generalized VRP | ✓ | Ótimos de Bektaş et al. (2011) catalogados; arquivos originais indisponíveis |
| [`mCTP/`](mCTP/README.md) | Multi-vehicle Covering Tour Problem | ✓ | 192 instâncias da literatura; A1-1-25-75-4-250 bate com Oliveira et al. |
| [`Complementares/`](Complementares/README.md) | CVRP simétrico, Open VRP e VRP com custo fixo | ✓ | 85 instâncias A/B/E/P (CVRPLIB); A-n32-k5 bate com a CVRPLIB e com Letchford et al. (2007) |

Cada pasta de exercício tem:

- `*_model.jl`: o modelo no VRPSolver;
- `*_parser.jl`: o leitor de instâncias, com um auto-teste (`julia *_parser.jl`);
- uma **instância toy**, com ótimo conhecido por força bruta e "armadilhas" (o valor que um modelo errado produziria);
- as instâncias de benchmark (quando disponíveis);
- `README.md`: a nota de estudo, com a definição do problema, o formato das instâncias, os pontos de atenção na modelagem e os resultados obtidos.

## Como rodar

O VRPSolver roda em Linux (aqui, no WSL). Dentro da pasta de um exercício:

```bash
julia dcvrp_parser.jl     # auto-teste do parser
julia dcvrp_model.jl      # resolve a instância configurada no topo do arquivo
```

No topo de cada `*_model.jl`, escolha a instância e ajuste o **cutoff** (`ub`) para o ótimo conhecido mais 0.01. Os caminhos são montados com `joinpath(@__DIR__, ...)`, então funcionam a partir de qualquer diretório. O `MTVRP/` usa o parser e as instâncias CMT da pasta `DCVRP/`, e o `Complementares/` usa o parser dela, então mantenha as pastas lado a lado.

## Fontes das instâncias

As instâncias de benchmark pertencem aos seus autores e estão aqui só para reprodutibilidade acadêmica. As referências completas estão no README de cada pasta.

- MCVRP: Sets 1–5 usados na disciplina (ver o survey de Ostermeier, Henke, Hübner & Wäscher, 2021, *EJOR*).
- DCVRP e MTVRP: Christofides, Mingozzi & Toth (CMT), via [CVRPLIB](https://galgos.inf.puc-rio.br/cvrplib/).
- TOP: Chao, Golden & Wasil (1996), via [KU Leuven](https://www.mech.kuleuven.be/en/cib/op).
- PTP: Archetti, Feillet, Hertz & Speranza (2009), via [OR@Brescia](https://or-brescia.unibs.it/instances).
- Complementares: Augerat et al. (A, B, P), Christofides & Eilon (E), via [CVRPLIB](https://galgos.inf.puc-rio.br/cvrplib/); ótimos do OVRP de Letchford, Lysgaard & Eglese (2007).
- m-CTP: Hà et al. (2013), via [Oliveira, Pessoa & Roboredo](https://github.com/brunomattos1/m-ctp_instances).
