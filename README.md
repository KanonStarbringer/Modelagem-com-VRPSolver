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
| [`Complementares/` (2)](Complementares/README-complementares-2.md) | VRPTW, Multi-Depot VRP e Heterogeneous Fleet VRP | ✓ | Solomon (56), Cordeau (23), Golden/Taillard (8); R101, p01, p02 e c50_14hd batem com os ótimos |
| [`Complementares/` (3)](Complementares/README-complementares-3.md) | VRPB (formulações F1 e F2 de Queiroga et al.), Site-Dependent VRP, Fleet Size and Mix VRP, PDPTW, E-VRP e Rich VRP | ✓ | Toth-Vigo (33) e GJB (68); Chao et al. (23); Golden FSM (24); Li & Lim (56); G-VRP (96); Rich VRP com regressões em VRPTW/MDVRP |
| [`Complementares/` (4)](Complementares/README-complementares-4.md) | Aula 5: TSPHS e OPHS (cortes de conectividade sob demanda), VRP com drone (arcos paralelos, packing sets em arcos) e Bin Packing (Ryan-Foster) | ✓ | Barbosa (2018) (267); Divsalar/Sohrabi (90); TSPLIB (5); BPPLIB (88); h05_c50_l150_09, eil51-H4-T3-S3 e u120_00 batem |

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
- VRPTW: Solomon (1987), soluções da CVRPLIB via [PyVRP/VRPLIB](https://github.com/PyVRP/VRPLIB).
- MDVRP: Cordeau, Gendreau & Laporte (1997), via [fboliveira/MDVRP-Instances](https://github.com/fboliveira/MDVRP-Instances).
- HFVRP e FSMVRP: Golden et al. (1984) / Taillard (1999), via [VRPSolverEasy](https://github.com/inria-UFF/VRPSolverEasy).
- VRPB: Toth & Vigo (1997) e Goetschalckx & Jacobs-Blecha (1989), nas versões usadas por Queiroga et al. (2020).
- SDVRP: Chao, Golden & Wasil (1999), formato de Cordeau, via [espelho](https://github.com/pauljmello/HGSADC-vs-ACS-on-SDVRP).
- PDPTW: Li & Lim (2001), dados do SINTEF via [zhu-he/pdptw-data](https://github.com/zhu-he/pdptw-data).
- E-VRP: G-VRP de Erdoğan & Miller-Hooks (2012), versão da [UNICAMP](https://www.ic.unicamp.br/~fusberti/problems/gvrp/).
- TSPHS: Barbosa (2018), via [mcroboredo/TSPHS_OPHS](https://github.com/mcroboredo/TSPHS_OPHS).
- OPHS: Divsalar, Vansteenwegen & Cattrysse (2013) e Sohrabi, Ziarati & Keshtkaran (2021, [Mendeley Data](https://doi.org/10.17632/bct4g4w9y2.1)).
- VRP-D: TSPLIB (Reinelt, 1991), com alcance e custo do drone definidos aqui.
- BPP: Falkenauer (1996) e Hard28 (Schoenfield), via [BPPLIB](https://github.com/mdelorme2/BPPLIB).
- m-CTP: Hà et al. (2013), via [Oliveira, Pessoa & Roboredo](https://github.com/brunomattos1/m-ctp_instances).
