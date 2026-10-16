using VrpSolver, JuMP
include("dcvrp_parser.jl")                                       # era mcvrp_parser.jl
inst = read_cvrplib(joinpath(@__DIR__, "Instancias", "CMT", "CMT14.vrp"))          # era read_mcvrp(...)

n, Q, D = inst.n, inst.Q, inst.D                                  # sai P; Q vira escalar; entra D
c(i, j) = inst.C[i + 1, j + 1]                                    # igual
d(i)    = inst.d[i + 1]                                           # era d(i, p)
s(i)    = i == 0 ? 0.0 : inst.s                                   # novo: tempo de serviço (s₀ = 0)

V  = collect(0:n)                                                 # igual
V⁺ = collect(1:n)                                                 # igual
E  = [(i, j) for i in V for j in V if i < j]                      # igual
δ  = Dict(i => [e for e in E if i in e] for i in V)               # igual

L  = ceil(Int, sum(d(i) for i in V⁺) / Q)                         # era o máximo sobre p
U  = n                                                            # igual
ub = 866.38                                                        # ótimo da toy = 80.0

# ---------- Modelo ----------
function build_model()
    cvrp = VrpModel()
    @variable(cvrp.formulation, x[e in E], Int)
    @objective(cvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))
    @constraint(cvrp.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2.0)

    v_source = v_sink = 0
    G = VrpGraph(cvrp, V, v_source, v_sink, (L, U))
    # Um recurso de capacidade por produto/compartimento
    Dmax = isinf(D) ? 1e6 : D                        # CMT1 etc. não têm limite de rota

    cap  = add_resource!(G, main = true)             # recurso 1: capacidade
    dist = add_resource!(G, main = true)            # recurso 2: distância (+ serviço) default false
    for i in V
        set_resource_bounds!(G, i, cap,  0.0, Q)     # [0, Q]
        set_resource_bounds!(G, i, dist, 0.0, Dmax)  # [0, D]
    end

   for (i, j) in E
        for (u, v) in ((i, j), (j, i))
            a = add_arc!(G, u, v)
            add_arc_var_mapping!(G, a, x[(i, j)])
            set_arc_consumption!(G, a, cap,  d(v))             # q_{(u,v),cap}  = d_v
            set_arc_consumption!(G, a, dist, c(u, v) + s(v))   # q_{(u,v),dist} = ℓ_uv = c_uv + s_v
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
set_cutoff!(optimizer, ub)
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