using VrpSolver, JuMP
include(joinpath(@__DIR__, "..", "cvrp_parser.jl"))
inst = read_cvrp(joinpath(@__DIR__, "..", "Instancias", "A-n32-k5.vrp"))     # benchmark: read_cvrp(joinpath(@__DIR__, "..", "Instancias", "A-n32-k5.vrp"))

n, Q = inst.n, inst.Q
c(i, j) = inst.C[i + 1, j + 1]
d(i) = inst.d[i + 1]

V  = collect(0:n)
V⁺ = collect(1:n)

f  = 1000                                       # inst.f   # 20 na toy
L  = ceil(Int, sum(inst.d) / Q)                 # frota livre
U  = n
ub = 5784.01                                           # 784.01

E = [(i, j) for i in V for j in V if i < j]     # igual
δ = Dict(i => [e for e in E if i in e] for i in V)

aresta(i, j) = (min(i, j), max(i, j))

# ---------- Modelo ----------
function build_model()
    fcvrp = VrpModel()
    @variable(fcvrp.formulation, x[e in E], Int)
    @variable(fcvrp.formulation, z, Int)                                            # NOVO: nº de veículos usados
    @objective(fcvrp.formulation, Min,
        sum(c(i, j) * x[(i, j)] for (i, j) in E) + f * z)                          # NOVO: + f·z

    @constraint(fcvrp.formulation, grau[i in V⁺], sum(x[e] for e in δ[i]) == 2)     # volta o grau do CVRP (sem y)

    # 1. Grafo: igual
    G = VrpGraph(fcvrp, V, 0, 0, (L, U))

    # 3. Recurso: igual (capacidade)
    cap = add_resource!(G, main = true)
    for i in V
        set_resource_bounds!(G, i, cap, 0.0, Q)
    end

    # 2. Arcos
    function arco!(i, j, vars)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, vars)
        set_arc_consumption!(G, a, cap, (d(i) + d(j)) / 2)
    end
    for (i, j) in E
        if i == 0
            arco!(0, j, [x[(0, j)], z])     # saída: conta a aresta E um veículo
            arco!(j, 0, x[(0, j)])          # volta: só a aresta
        else
            arco!(i, j, x[(i, j)])
            arco!(j, i, x[(i, j)])
        end
    end
    add_graph!(fcvrp, G)

    # 4. Packing sets: igual
    set_vertex_packing_sets!(fcvrp, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(fcvrp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(fcvrp, "x", 1)
    return (fcvrp, x, z)
end

# ---------- Resolução ----------
(model, x, z) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Veículos (z): ", round(get_value(optimizer, z)))
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end