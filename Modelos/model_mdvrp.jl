# ============================================================
#  MDVRP no VRPSolver — 4 clientes, 2 depósitos (base: CVRP)
#  Mudança: um grafo por depósito (source=sink=depósito, 1 veículo cada);
#  arestas cliente-cliente mapeiam nos dois grafos, as do depósito só no seu.
# ============================================================
using VrpSolver, JuMP

ub = 24.1

n  = 4
V⁺ = collect(1:n)              # clientes
depots = [n + 1, n + 2]        # depósitos 5 e 6
Q  = 10

d = Dict(1 => 5, 2 => 4, 3 => 3, 4 => 6, 5 => 0, 6 => 0)

# Custos sobre os vértices 1..6 (clientes 1..4, depósitos 5,6)
C = Float64[
#    1  2  3  4  5  6
     0  3  6  7  4  8 ;   # 1
     3  0  4  8  5  9 ;   # 2
     6  4  0  3  8  5 ;   # 3
     7  8  3  0  9  4 ;   # 4
     4  5  8  9  0  0 ;   # 5 (depósito)
     8  9  5  4  0  0 ]   # 6 (depósito)
c(i, j) = C[i, j]

Ecc = [(i, j) for i in V⁺ for j in V⁺ if i < j]     # cliente-cliente
Edc = [(k, i) for k in depots for i in V⁺]          # depósito-cliente
E   = vcat(Ecc, Edc)

# δ[i] = arestas incidentes ao cliente i
δ = Dict(i => vcat([e for e in Ecc if i in e], [(k, i) for k in depots]) for i in V⁺)

function build_model()
    m = VrpModel()
    @variable(m.formulation, x[e in E], Int)
    @objective(m.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))
    @constraint(m.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2.0)

    graphs = VrpGraph[]
    for k in depots
        Vk = vcat([k], V⁺)                     # depósito k + clientes
        G = VrpGraph(m, Vk, k, k, (0, 1))      # source=sink=k; no máx. 1 veículo
        cap = add_resource!(G, main = true)
        for i in Vk
            set_resource_bounds!(G, i, cap, 0.0, Q)
        end
        # arestas cliente-cliente -> arcos neste grafo
        for (i, j) in Ecc
            for (u, v) in ((i, j), (j, i))
                a = add_arc!(G, u, v)
                add_arc_var_mapping!(G, a, x[(i, j)])
                set_arc_consumption!(G, a, cap, (d[i] + d[j]) / 2)
            end
        end
        # arestas do depósito k -> arcos só neste grafo
        for i in V⁺
            for (u, v) in ((k, i), (i, k))
                a = add_arc!(G, u, v)
                add_arc_var_mapping!(G, a, x[(k, i)])
                set_arc_consumption!(G, a, cap, (d[k] + d[i]) / 2)
            end
        end
        add_graph!(m, G)
        push!(graphs, G)
    end

    # Packing sets: as duas cópias de cada cliente
    set_vertex_packing_sets!(m, [[(graphs[g], i) for g in 1:length(depots)] for i in V⁺])
    for G in graphs
        define_elementarity_sets_distance_matrix!(m, G,
            [[float(c(i, j)) for j in V⁺] for i in V⁺])
    end
    set_branching_priority!(m, "x", 1)
    return (m, x)
end

(model, x) = build_model()
optimizer = VrpOptimizer(model, "MDVRP.cfg", "exemplo_mdvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for e in E
        if get_value(optimizer, x[e]) > 0.5
            println("x[$e] = ", round(get_value(optimizer, x[e])))
        end
    end
end
