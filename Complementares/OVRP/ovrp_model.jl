using VrpSolver, JuMP
include(joinpath(@__DIR__, "..", "cvrp_parser.jl"))   # parser único, compartilhado pelos três complementares

inst = read_cvrp(joinpath(@__DIR__, "..", "Instancias", "A-n32-k5.vrp"); arred = false)     # benchmark: read_cvrp(joinpath(@__DIR__, "..", "Instancias", "A-n32-k5.vrp"); arred = false)

n, Q = inst.n, inst.Q                           # volta Q; saem p e q
c(i, j) = inst.C[i + 1, j + 1]                  # igual
d(i) = inst.d[i + 1]                            # volta a demanda

V  = collect(0:n)                               # todos os clientes são vértices do grafo
V⁺ = collect(1:n)

L  = inst.K                                           # ceil(Int, sum(inst.d) / Q)                 # toy: 2, com frota livre; benchmark: L = U = inst.K
U  = inst.K                                             # n
ub = 487.316                                      # toy; A-n32-k5 com custo real: 487.316

E = [(i, j) for i in V for j in V if i < j]     # igual
δ = Dict(i => [e for e in E if i in e] for i in V)

aresta(i, j) = (min(i, j), max(i, j))

# ---------- Modelo ----------
function build_model()
    ovrp = VrpModel()
    @variable(ovrp.formulation, x[e in E], Int)
    @variable(ovrp.formulation, y[i in V⁺], Int)                                   # NOVO: a rota termina em i
    @objective(ovrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))     # igual: y não entra (a volta custa 0)

    @constraint(ovrp.formulation, grau[i in V⁺], sum(x[e] for e in δ[i]) + y[i] == 2)   # todos obrigatórios; y fecha o grau

    # 1. Grafo: igual (source = sink = 0)
    G = VrpGraph(ovrp, V, 0, 0, (L, U))

    # 3. Recurso: só a capacidade
    cap = add_resource!(G, main = true)
    for i in V
        set_resource_bounds!(G, i, cap, 0.0, Q)
    end

    # 2. Arcos
    function arco!(i, j, var)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, var)
        set_arc_consumption!(G, a, cap, (d(i) + d(j)) / 2)
    end
    for (i, j) in E
        if i == 0
            arco!(0, j, x[(0, j)])      # saída: paga c(0,j)
            arco!(j, 0, y[j])           # volta: vai para y[j], custo 0
        else
            arco!(i, j, x[(i, j)])
            arco!(j, i, x[(i, j)])
        end
    end
    add_graph!(ovrp, G)

    # 4. Packing sets: singletons (igual)
    set_vertex_packing_sets!(ovrp, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(ovrp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(ovrp, "x", 1)
    set_branching_priority!(ovrp, "y", 1)    # opcional
    return (ovrp, x, y)
end

# ---------- Resolução ----------
(model, x, y) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Fins de rota: ", [i for i in V⁺ if get_value(optimizer, y[i]) > 0.5])
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end