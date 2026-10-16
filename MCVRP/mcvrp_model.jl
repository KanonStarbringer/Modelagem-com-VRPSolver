using VrpSolver, JuMP
include("mcvrp_parser.jl")

inst = read_mcvrp(joinpath(@__DIR__, "MCVRP Set 1", "10-2", "2.txt"))

n, P, Q = inst.n, inst.P, inst.Q
c(i, j) = inst.C[i + 1, j + 1]
d(i, p) = inst.d[i + 1, p]

V  = collect(0:n)              # vértices: 0 (depósito) e 1..n (clientes)
V⁺ = collect(1:n)              # clientes

L  = maximum(ceil(Int, sum(d(i, p) for i in V⁺) / Q[p]) for p in 1:P)   # nº mínimo de veículos
U  = n                                                                   # nº máximo de veículos
# ub = 285.16                                                              # cutoff (ótimo da toy = 285.1502)

# Arestas do grafo de entrada
E = [(i, j) for i in V for j in V if i < j]

# Dicionário δ[i] = arestas incidentes ao vértice i
δ = Dict(i => [e for e in E if i in e] for i in V)

# ---------- Modelo ----------
function build_model()
    cvrp = VrpModel()
    @variable(cvrp.formulation, x[e in E], Int)
    @objective(cvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))
    @constraint(cvrp.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2.0)

    v_source = v_sink = 0
    G = VrpGraph(cvrp, V, v_source, v_sink, (L, U))
    # Um recurso de capacidade por produto/compartimento
    caps = [add_resource!(G, main = (p == 1)) for p in 1:P]
    for p in 1:P, i in V
        set_resource_bounds!(G, i, caps[p], 0.0, Q[p])     # [0, Q_p] em cada vértice
    end

    

   for (i, j) in E
        for (u, v) in ((i, j), (j, i))
            a = add_arc!(G, u, v)
            add_arc_var_mapping!(G, a, x[(i, j)])
            for p in 1:P
                set_arc_consumption!(G, a, caps[p], d(v, p))   # q_{(u,v),p} = d_{v,p}
            end
        end
    end
    add_graph!(cvrp, G)

    # Packing sets em vértices: cada cliente é um packing set
    set_vertex_packing_sets!(cvrp, [[(G, i)] for i in V⁺])

    # Matriz de distâncias entre elementarity sets (precisa ser Float64)
    define_elementarity_sets_distance_matrix!(cvrp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    # Branching nos arcos
    set_branching_priority!(cvrp, "x", 1)

    return (cvrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
# set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Solução ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for e in E
        if get_value(optimizer, x[e]) > 0.5
            println("x[$e] = ", round(get_value(optimizer, x[e])))
        end
    end
end