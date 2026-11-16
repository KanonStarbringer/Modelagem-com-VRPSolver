# PRUO — Roteamento de USVs com offloading

> Pesquisa de doutorado (PPGEP/UFF), fora dos exercícios da disciplina. Artigo em preparação para a *Computers & Operations Research*, com o título provisório "A branch-price-and-cut algorithm for routing unmanned surface vehicles with computation offloading". No artigo, o problema se chama **URPO** (*USV Routing Problem with Offloading*).

## O problema

Uma frota de USVs sai de uma base e visita pontos de interesse, onde coleta vídeo e sonar. A análise dos dados de cada ponto tem de estar pronta antes de o veículo sair dele e pode ser feita de dois modos:

- **a bordo**: é lenta, alonga o serviço e gasta energia;
- **no servidor** (um navio-mãe com alcance de comunicação): é rápida, mas o servidor tem capacidade limitada por período e o enlace pode cair em alguns períodos.

O modo de cada tarefa é decidido junto com as rotas, sob janelas de tempo, horizonte e bateria. A capacidade do servidor em cada período é dividida entre as tarefas descarregadas de todas as rotas.

## Modelo no VRPSolver

- **Grafo de pricing expandido**: uma cópia de cada tarefa por modo e, no modo servidor, por período. A cópia fixa o tempo de serviço, a energia e o período que a tarefa ocupa no servidor.
- **Recursos**: tempo, energia e um recurso de carga por período em cada rota, que reforça a relaxação linear. A capacidade global de cada período é uma restrição do mestre.
- **Packing sets por cópia**, e não por tarefa. Com packing sets por tarefa, a enumeração final guardaria só a rota mais barata entre as que visitam as mesmas tarefas e poderia descartar justamente a rota que usa o servidor em outro período, que é a necessária. A elementaridade por tarefa vem da partição e das vizinhanças ng, que juntam todas as cópias de cada tarefa.
- **Ramificação**: primeiro no número de veículos, depois no fluxo agregado $x_{ij}$ e por último nas cópias, que fixam o modo e o período.

Detalhes em [`vrpsolver/README.md`](vrpsolver/README.md).

## Arquivos

| Arquivo | Conteúdo |
|---|---|
| `prototipo_pruo.py` | Protótipo em PuLP: gerador de instâncias pequenas, formulação compacta (C) e reformulação por enumeração |
| `geracao_colunas.py` | Geração de colunas no nó raiz com rotulagem exata, para conferir o limitante |
| `exportar_instancias.py` | Escreve as instâncias de validação (`instancias/pruo_*.txt`) com a referência do CBC |
| `gerar_benchmark.py` | Gera as 72 instâncias de benchmark (`instancias/bench_*.txt`) e os lotes `bench_n*.batch` |
| `compacto_cplex.py` | (C) no CPLEX 22.1.1 (`cplex.exe`, um thread, árvore limitada a 8 GB) |
| `sequencial.py` | Abordagens sequenciais otimista e pessimista: `gerar` escreve as instâncias e os lotes, `avaliar` confere a fase 2 e compara com a melhor solução conhecida |
| `vrpsolver/src/` | Modelo no VRPSolver (`model.jl`, `data.jl`, `solution.jl`, `run.jl`) |
| `vrpsolver/teste/valida_modelo.jl` | Verificação sem o BaPCod: as rotas são enumeradas e a formulação completa vai para o HiGHS |
| `vrpsolver/config/` | Parâmetros do BaPCod para cada configuração do artigo |
| `vrpsolver/hexaly_pruo.py` | Modelo no Hexaly 14.5 (variáveis de lista) com verificador independente da solução |
| `vrpsolver/rodar_lote.sh` | Roda um lote no WSL, um processo Julia por instância, e retoma de onde parou |
| `vrpsolver/gerar_lote_ub.py` | Monta `bench_ub.batch`, com o valor do Hexaly + 0,01 como limitante superior inicial |
| `vrpsolver/tabela*.py` | Geram as tabelas do artigo a partir das saídas |
| `vrpsolver/saida_*.txt` | Resultados de cada rodada (ver abaixo) |

## Instâncias

São 72 instâncias, `bench_<família>_n<n>_c<C>_s<semente>.txt`, inspiradas nas famílias de Solomon:

- **distribuição**: R (uniforme), C (clusters) ou RC (metade de cada);
- **janelas**: E (estreitas) ou L (largas);
- **tarefas**: $n \in \{25, 50, 100\}$;
- **capacidade do servidor**: $C_t \in \{1, 2\}$ tarefas por período;
- **sementes**: 2.

O cenário é uma área de 30 × 30 km, com a base no meio da borda sul, o servidor no centro (alcance de 12 km) e uma missão de 8 h. **Formato.** Primeiro vêm os escalares:
- `n`: tarefas;
- `K`: frota;
- `F`: custo fixo por veículo;
- `H`: horizonte (min);
- `D`: duração do período (min);
- `P`: número de períodos;
- `E`: bateria;
- `cE`: energia por km;
- `v`: velocidade (km/min).

Depois vêm os vetores por período: `C`, a capacidade do servidor, e `gam`, o enlace (1 = disponível). Por fim, depois da linha `nos`, há uma linha por nó: índice, $x$, $y$, $a$, $b$, carga no servidor $w$, tempo e energia a bordo ($\tau^L$, $\varepsilon^L$) e no servidor ($\tau^S$, $\varepsilon^S$; −1 se a tarefa não pode ser descarregada). O nó 0 é a base. O sensoriamento dura 10 min em toda tarefa e não aparece no arquivo.

As instâncias `otim_*` e `pess_*` são as das abordagens sequenciais, e as `pruo_*` são as de validação (7 a 50 tarefas).

## Como reproduzir

O VRPSolver roda no WSL (Julia 1.12, BaPCod 0.84, CPLEX 22.1.1). Dentro de `vrpsolver/`:

```bash
bash rodar_lote.sh bench_n25.batch saida_bench25.txt       # 1ª configuração: busca em profundidade
bash rodar_lote.sh teste_busca.batch saida_teste_busca.txt # 2ª: melhor limitante nas abertas
bash rodar_lote.sh bench_ub.batch saida_bench_ub.txt       # 3ª: melhor limitante + UB do Hexaly
bash rodar_lote.sh seq_pess.batch saida_seq_pess.txt       # sequencial pessimista
bash rodar_lote.sh seq_otim.batch saida_seq_otim.txt       # sequencial otimista
```

No Windows, a partir desta pasta:

```
python -X utf8 vrpsolver\hexaly_pruo.py vrpsolver\bench_n25.batch 3600 vrpsolver\saida_hexaly25.txt
python -X utf8 compacto_cplex.py vrpsolver\bench_n25.batch 3600 vrpsolver\saida_compacto25.txt
python -X utf8 sequencial.py avaliar
```

O caminho do `cplex.exe` fica no topo de `compacto_cplex.py`. O Hexaly tem um único token de licença, então roda uma instância por vez.

Para refazer as tabelas, rode dentro de `vrpsolver/` os scripts `python tabela.py`, `tabela_busca.py`, `tabela_ub.py`, `tabela_hexaly.py` e `tabela_compacto.py`.

As saídas `saida_*.txt` do BaPCod guardam só as linhas `statistics:`, `RESULTADO;` e `Rota #` dos logs completos, que somam ~300 MB e ficam fora do repositório. Com essas linhas, as tabelas saem idênticas às feitas a partir dos logs completos.

## Resultados (uma hora por instância, um thread)

| Método | Ótimos provados (de 72) |
|---|---|
| Branch-price-and-cut, melhor das três configurações | **58** |
| Branch-price-and-cut, busca em profundidade | 54 |
| Branch-price-and-cut, melhor limitante + UB do Hexaly | 55 |
| Formulação compacta (C) no CPLEX | 27 |

- **Dificuldade:** vem mais da largura das janelas e da capacidade do servidor do que do número de tarefas. O grupo difícil, em todos os tamanhos, é o de janelas largas com $C_t = 2$.
- **Gap da raiz do branch-price-and-cut:** abaixo de 9% em todos os grupos.
- **Relaxação linear de (C):** fica de 84% a 91% abaixo da melhor solução conhecida com janelas largas, porque as constantes big-M de tempo crescem com a largura da janela.
- **Hexaly em 1 h:** em média, 6,3% acima da melhor solução conhecida.
- **Abordagem sequencial otimista** (rotas sem o tempo de processamento): inviável em todas as 68 instâncias em que as rotas foram encontradas.
- **Abordagem sequencial pessimista** (tudo a bordo): em média, 9,7% acima da melhor solução conhecida.
- **Melhores soluções conhecidas:** estão em `vrpsolver/melhor_conhecido.csv` e `vrpsolver/tabela_instancias.tex`.
