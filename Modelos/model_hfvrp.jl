# ============================================================
#  HFVRP no VRPSolver — 4 clientes, 2 tipos de veículo (base: CVRP)
#  Mudança: um grafo por tipo (capacidade Q^k e U^k = 1 de cada);
#  variável x[k,e] por tipo, e o grau soma sobre os tipos.
# ============================================================
using VrpSolver, JuMP

ub = 24.1

n  = 4
V  = collect(0:n)              # depósito 0 + clientes 1..4
V⁺ = collect(1:n)
K  = [1, 2]                    # tipos de veículo

d  = Dict(0 => 0, 1 => 5, 2 => 4, 3 => 3, 4 => 6)
Qk = Dict(1 => 10, 2 => 12)    # capacidade por tipo
Uk = Dict(1 => 1,  2 => 1)     # nº de veículos por tipo (1 de cada)

C = Float64[ 0  4  5  5  4 ;
             4  0  3  6  7 ;
             5  3  0  4  8 ;
             5  6  4  0  3 ;
             4  7  8  3  0 ]
c(i, j) = C[i + 1, j + 1]

E = [(i, j) for i in V for j in V if i < j]
δ = Dict(
    0 => [(0, 1), (0, 2), (0, 3), (0, 4)],
    1 => [(0, 1), (1, 2), (1, 3), (1, 4)],
    2 => [(0, 2), (1, 2), (2, 3), (2, 4)],
    3 => [(0, 3), (1, 3), (2, 3), (3, 4)],
    4 => [(0, 4), (1, 4), (2, 4), (3, 4)],
)

function build_model()
    m = VrpModel()
    @variable(m.formulation, x[k in K, e in E], Int)          # variável por tipo e aresta
    @objective(m.formulation, Min, sum(c(i, j) * x[k, (i, j)] for k in K for (i, j) in E))
    @constraint(m.formulation, deg[i in V⁺],
        sum(x[k, e] for k in K for e in δ[i]) == 2.0)

    graphs = VrpGraph[]
    for k in K
        G = VrpGraph(m, V, 0, 0, (0, Uk[k]))     # depósito 0; no máx. U^k veículos
        cap = add_resource!(G, main = true)
        for i in V
            set_resource_bounds!(G, i, cap, 0.0, Qk[k])       # capacidade do tipo k
        end
        for (i, j) in E
            for (u, v) in ((i, j), (j, i))
                a = add_arc!(G, u, v)
                add_arc_var_mapping!(G, a, x[k, (i, j)])
                set_arc_consumption!(G, a, cap, (d[i] + d[j]) / 2)
            end
        end
        add_graph!(m, G)
        push!(graphs, G)
    end

    # Packing sets: as duas cópias de cada cliente (uma por grafo/tipo)
    set_vertex_packing_sets!(m, [[(graphs[k], i) for k in 1:length(K)] for i in V⁺])
    for G in graphs
        define_elementarity_sets_distance_matrix!(m, G,
            [[float(c(i, j)) for j in V⁺] for i in V⁺])
    end
    set_branching_priority!(m, "x", 1)
    return (m, x)
end

(model, x) = build_model()
optimizer = VrpOptimizer(model, "HFVRP.cfg", "exemplo_hfvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for k in K, e in E
        if get_value(optimizer, x[k, e]) > 0.5
            println("x[tipo $k, $e] = ", round(get_value(optimizer, x[k, e])))
        end
    end
end
