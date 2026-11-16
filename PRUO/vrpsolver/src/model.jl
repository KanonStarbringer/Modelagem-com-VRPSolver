# Modelo do PRUO no VRPSolver (§3 e §4 da nota "Formalização - Roteamento de USVs com offloading").
#
# - Vértices do grafo de pricing: depósito (0) e cópias tarefa-modo-período (1..nc).
# - x[(i,j)]: arco físico (agregado sobre as cópias); y[c]: cópia c usada (modo e período).
# - Packing sets POR CÓPIA, não por tarefa: na enumeração final, o VRPSolver guarda só a rota
#   mais barata entre as que visitam os mesmos packing sets; duas rotas com as mesmas tarefas
#   e offloading em períodos diferentes têm coeficientes diferentes na capacidade (9).
# - Elementaridade por tarefa vem da partição (cobre) e da vizinhança ng, que junta as cópias
#   de cada tarefa vizinha.
function build_model(data::DataPRUO, app)
    cop = copias(data)
    nc, n = length(cop), data.n
    porta = [[c for c in 1:nc if cop[c].tarefa == i] for i in 1:n]
    fis(u) = u == 0 ? 0 : cop[u].tarefa

    # arcos do grafo expandido, já filtrados pelas janelas (cauda, cabeça)
    arcos = Tuple{Int,Int}[]
    for c in 1:nc
        tt(data, 0, cop[c].tarefa) <= cop[c].hi && push!(arcos, (0, c))
    end
    for c in 1:nc, c2 in 1:nc
        i, j = cop[c].tarefa, cop[c2].tarefa
        i != j && cop[c].lo + cop[c].dur + tt(data, i, j) <= cop[c2].hi && push!(arcos, (c, c2))
    end
    for c in 1:nc
        cop[c].lo + cop[c].dur + tt(data, cop[c].tarefa, 0) <= data.H && push!(arcos, (c, 0))
    end
    Af = unique([(fis(u), fis(w)) for (u, w) in arcos])
    Pcap = sort(unique([cop[c].periodo for c in 1:nc if cop[c].modo == 'S']))

    # Formulação (C) em variáveis agregadas
    pruo = VrpModel()
    @variable(pruo.formulation, x[e in Af] >= 0, Int)
    @variable(pruo.formulation, y[c in 1:nc] >= 0, Int)
    @expression(pruo.formulation, nveic, sum(x[e] for e in Af if e[1] == 0))
    @objective(pruo.formulation, Min, data.F * nveic + sum(dist(data, e[1], e[2]) * x[e] for e in Af))
    @constraint(pruo.formulation, cobre[i in 1:n], sum(y[c] for c in porta[i]) == 1.0)
    @constraint(pruo.formulation, cap[t in Pcap],
        sum(carga(data, cop[c].tarefa) * y[c] for c in 1:nc if cop[c].periodo == t) <= data.C[t+1])

    # Grafo de pricing: rotas que saem e voltam ao depósito, de 1 a K USVs
    G = VrpGraph(pruo, collect(0:nc), 0, 0, (1, data.K))
    rt = add_resource!(G, main=true)       # tempo: início do serviço (espera permitida, H6)
    re = add_resource!(G)                  # energia acumulada
    # capacidade por período dentro de cada rota (como no protótipo): uma rota sozinha
    # não pode exceder C_t. Não muda o ótimo; só fortalece o LP.
    rq = app["sem_recurso_periodo"] ? Dict{Int,Int}() : Dict{Int,Int}(t => add_resource!(G) for t in Pcap)
    set_resource_bounds!(G, 0, rt, 0.0, data.H)
    for c in 1:nc
        set_resource_bounds!(G, c, rt, cop[c].lo, cop[c].hi)
    end
    for u in 0:nc, (t, r) in rq
        set_resource_bounds!(G, u, r, 0.0, data.C[t+1])
    end
    for u in 0:nc
        set_resource_bounds!(G, u, re, 0.0, data.E)
    end

    arco = Dict{Int,Tuple{Int,Int}}()      # id do arco -> (cauda, cabeça), para ler as rotas
    for (u, w) in arcos
        i, j = fis(u), fis(w)
        id = add_arc!(G, u, w, w == 0 ? [x[(i, j)]] : [x[(i, j)], y[w]])
        arco[id] = (u, w)
        dur, ener = u == 0 ? (0.0, 0.0) : (cop[u].dur, cop[u].ener)
        set_arc_consumption!(G, id, rt, dur + tt(data, i, j))
        set_arc_consumption!(G, id, re, ener + data.cE * dist(data, i, j))
        if w != 0 && haskey(rq, cop[w].periodo)
            set_arc_consumption!(G, id, rq[cop[w].periodo], carga(data, j))
        end
    end
    add_graph!(pruo, G)

    set_vertex_packing_sets!(pruo, [[(G, c)] for c in 1:nc])
    define_elementarity_sets_distance_matrix!(pruo, G,
        [[dist(data, cop[c].tarefa, cop[c2].tarefa) for c2 in 1:nc] for c in 1:nc])

    # vizinhança ng inicial explícita (como no demo PDPTW): todas as cópias da própria tarefa
    # e das tarefas mais próximas, até app["ng"] cópias
    for c in 1:nc
        total = 0
        for j in sort(collect(1:n), by=j -> dist(data, cop[c].tarefa, j))   # a própria tarefa vem primeiro
            j != cop[c].tarefa && total + length(porta[j]) > app["ng"] && break
            for c2 in porta[j]
                add_elem_set_to_vertex_init_ng_neighbourhood!(pruo, G, c, c2)
            end
            total += length(porta[j])
        end
    end

    # ramificação: frota primeiro (fecha quase todo o gap; §7 da nota), depois arcos, depois modo
    set_branching_priority!(pruo, nveic, "nveic", 3)
    set_branching_priority!(pruo, "x", 2)
    set_branching_priority!(pruo, "y", 1)

    return (pruo, cop, arco, x, y)
end
