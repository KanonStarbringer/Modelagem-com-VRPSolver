using VrpSolver, JuMP
include("ptp_parser.jl")

inst = read_ptp(joinpath(@__DIR__, "Instancias", "p06.cri"))

n, m, Q = inst.n, inst.m, inst.Q                # sai T (não há tempo); volta Q
c(i, j) = inst.C[i + 1, j + 1]                  # custo (agora entra no objetivo)
d(i)    = inst.d[i + 1]                         # volta a demanda
p(i)    = inst.p[i + 1]                         # lucro (igual ao TOP)

V  = collect(0:n)                               # depósito único: 0 é início e fim
V⁺ = collect(1:n)                               # igual

L  = 0                                          # igual: visita opcional
U  = m                                          # igual (na versão da Lista, U = n)
ub = -173.36                                     # cutoff da toy (saldo ótimo = 23.1377, objetivo negado)

E = [(i, j) for i in V for j in V if i < j]     # todas as arestas, como no CVRP
δ = Dict(i => [e for e in E if i in e] for i in V)

aresta(i, j) = (min(i, j), max(i, j))           # igual

# ---------- Modelo ----------
function build_model()
    ptp = VrpModel()
    @variable(ptp.formulation, x[e in E], Int)
    @variable(ptp.formulation, y[i in V⁺], Bin)                       # igual
    @objective(ptp.formulation, Min,
        sum(c(i, j) * x[(i, j)] for (i, j) in E) - sum(p(i) * y[i] for i in V⁺))  # custo − lucro
    @constraint(ptp.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2 * y[i])   # igual

    # 1. Grafo: depósito único, source = sink = 0
    G = VrpGraph(ptp, V, 0, 0, (L, U))

    # 3. Recursos: só a capacidade
    cap = add_resource!(G, main = true)
    for i in V
        set_resource_bounds!(G, i, cap, 0.0, Q)
    end

    # 2. Arcos: os dois sentidos de cada aresta, como no CVRP do professor
    function arco!(i, j)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[aresta(i, j)])
        set_arc_consumption!(G, a, cap, float(d(j)))   # d(0) = 0
    end
    for (i, j) in E
        arco!(i, j)
        arco!(j, i)
    end
    add_graph!(ptp, G)

    # 4. Packing sets: igual
    set_vertex_packing_sets!(ptp, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(ptp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(ptp, "y", 2)             # igual
    set_branching_priority!(ptp, "x", 1)
    return (ptp, x, y)
end

# ---------- Resolução ----------
(model, x, y) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Solução ----------
if solution_found
    println("Saldo ótimo (lucro − custo): ", -get_objective_value(optimizer))   # era "Lucro ótimo"
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end