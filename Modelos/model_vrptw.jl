# ============================================================
#  VRPTW no VRPSolver — 4 clientes (base: exemplo do CVRP)
#  Mudança em relação ao CVRP: um segundo recurso (tempo),
#  com janela [l_i, u_i] em cada vértice e consumo t_ij = c_ij.
# ============================================================
using VrpSolver, JuMP

ub = 24.1

n  = 4
V  = collect(0:n)      # 0 (depósito) e 1..n (clientes)
V⁺ = collect(1:n)
Q  = 10

d = Dict(0 => 0, 1 => 5, 2 => 4, 3 => 3, 4 => 6)

C = Float64[ 0  4  5  5  4 ;
             4  0  3  6  7 ;
             5  3  0  4  8 ;
             5  6  4  0  3 ;
             4  7  8  3  0 ]
c(i, j) = C[i + 1, j + 1]
t(i, j) = c(i, j)                       # tempo de viagem = custo

# Janelas de tempo [l_i, u_i]  (depósito com horizonte [0,20])
tw = Dict(0 => (0.0, 20.0), 1 => (2.0, 6.0), 2 => (5.0, 9.0),
          3 => (3.0, 7.0),  4 => (6.0, 10.0))

E = [(i, j) for i in V for j in V if i < j]
δ = Dict(
    0 => [(0, 1), (0, 2), (0, 3), (0, 4)],
    1 => [(0, 1), (1, 2), (1, 3), (1, 4)],
    2 => [(0, 2), (1, 2), (2, 3), (2, 4)],
    3 => [(0, 3), (1, 3), (2, 3), (3, 4)],
    4 => [(0, 4), (1, 4), (2, 4), (3, 4)],
)

L = ceil(Int, sum(d[i] for i in V⁺) / Q)
U = n

function build_model()
    m = VrpModel()
    @variable(m.formulation, x[e in E], Int)
    @objective(m.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))
    @constraint(m.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2.0)

    G = VrpGraph(m, V, 0, 0, (L, U))
    cap  = add_resource!(G, main = true)        # recurso 1: capacidade
    time = add_resource!(G, main = true)        # recurso 2: tempo (novo)
    for i in V
        set_resource_bounds!(G, i, cap,  0.0, Q)
        set_resource_bounds!(G, i, time, tw[i][1], tw[i][2])   # janela de tempo
    end

    for (i, j) in E
        for (u, v) in ((i, j), (j, i))
            a = add_arc!(G, u, v)
            add_arc_var_mapping!(G, a, x[(i, j)])
            set_arc_consumption!(G, a, cap,  (d[i] + d[j]) / 2)
            set_arc_consumption!(G, a, time, t(u, v))          # tempo do arco
        end
    end
    add_graph!(m, G)

    set_vertex_packing_sets!(m, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(m, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])
    set_branching_priority!(m, "x", 1)
    return (m, x)
end

(model, x) = build_model()
optimizer = VrpOptimizer(model, "VRPTW.cfg", "exemplo_vrptw")
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
