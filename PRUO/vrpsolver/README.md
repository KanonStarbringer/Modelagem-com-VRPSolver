# PRUO no VRPSolver

O modelo da nota "Formalização - Roteamento de USVs com offloading" (§3 e §4), escrito para o VRPSolver. A estrutura segue o demo VRPTW oficial (github.com/artalvpes/VRPSolverDemos).

## Pré-requisitos

- Julia ≥ 1.11.5 (aqui: 1.12.3).
- CPLEX ≥ 12.9 no `PATH`.
- A biblioteca compartilhada do BaPCod, gerada a partir do código-fonte (licença acadêmica). O caminho dela vai na variável `BAPCOD_RCSP_LIB`. No Windows, é `<BaPCod>\build\Bapcod\Release\bapcod-shared.dll`.

Na primeira execução, o `run.jl` instala o VrpSolver.jl (github.com/tbulhoes/VrpSolver.jl), que roda no Windows sem Docker.

## Como rodar (dentro desta pasta)

```
set BAPCOD_RCSP_LIB=C:\caminho\para\bapcod-shared.dll
julia src/run.jl instancias/pruo_n7_s01.txt                      # uma instância
julia src/run.jl --batch validacao.batch > saida_validacao.txt   # n = 7 a 20, com referência
julia src/run.jl --batch escala.batch > saida_escala.txt         # n = 30, 40 e 50
```

Cada execução termina com uma linha `RESULTADO;instância;n;custo;referência;confere;status;tempo`. Para juntar os resultados: `findstr RESULTADO saida_validacao.txt`. Na coluna `confere`:
- `OK`: o custo é igual ao ótimo provado do compacto no CBC.
- `DIVERGE`: o custo difere desse ótimo, o que indica erro no modelo.
- `melhor`, `igual` ou `pior que o CBC`: comparação com um incumbente não provado (CBC parado em 60 s).

**Opções:**
- `-u <valor>`: limitante superior inicial.
- `--ng <k>`: vizinhança ng inicial, em cópias; deve ser ≤ `RCSPmaxNGneighbourhoodSize` no `.cfg`.
- `--sem_recurso_periodo`: tira a capacidade por período rota a rota. O LP fica mais fraco, mas o ótimo não muda.
- `-c <arquivo.cfg>`: outro arquivo de parâmetros.

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `src/model.jl` | Grafo de pricing (depósito + cópias tarefa-modo-período), recursos (tempo, energia, carga por período), mapeamento, packing sets, vizinhanças ng e prioridades de ramificação (frota > arcos > modo) |
| `src/data.jl` | Leitura das instâncias e construção das cópias |
| `src/solution.jl` | Leitura das rotas e impressão no formato do protótipo em Python |
| `config/PRUO.cfg` | Parâmetros: base no demo VRPTW e mergulho do demo PDPTW (não há limitante superior inicial) |
| `instancias/` | Geradas por `../exportar_instancias.py` a partir do protótipo, com a referência do CBC |
| `teste/valida_modelo.jl` | Verificação sem o BaPCod: um VrpSolver de mentira registra o grafo, as rotas são enumeradas e a formulação completa vai para o HiGHS |

## Decisão de modelagem importante

Os **packing sets são por cópia**, e não por tarefa. Na enumeração final, o VRPSolver guarda só a rota mais barata entre as que visitam os mesmos packing sets. Duas rotas com as mesmas tarefas e offloading em períodos diferentes usam a capacidade de forma diferente, então, com packing sets por tarefa, a enumeração poderia descartar a rota necessária. A elementaridade por tarefa vem da restrição de partição (`cobre`) e das vizinhanças ng, que juntam todas as cópias de cada tarefa vizinha.
