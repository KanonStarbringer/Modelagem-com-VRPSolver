using VrpSolver, JuMP
include(joinpath(@__DIR__, "vrptw_parser.jl"))  # muda: parser na própria pasta
inst = read_vrptw(joinpath(@__DIR__, "Instancias", "R101.txt"))     # benchmark: inst = read_vrptw(joinpath(@__DIR__, "toy_vrptw.txt")) 

n, Q = inst.n, inst.Q
c(i, j) = inst.C[i + 1, j + 1]                  # igual (já truncado em 1 casa)
t(i, j) = inst.T[i + 1, j + 1]                  # NOVO: tempo do arco i→j = s_i + c_ij (assimétrico)
d(i) = inst.d[i + 1]
l(i) = inst.l[i + 1]                            # NOVO: início da janela
u(i) = inst.u[i + 1]                            # NOVO: fim da janela

V  = collect(0:n)
V⁺ = collect(1:n)

L  = ceil(Int, sum(inst.d) / Q)                 # igual
U  = inst.K                                     # muda: frota de Solomon (toy: 6)
ub = 1637.71                                     # toy; R101 com n = 25: 617.11

E = [(i, j) for i in V for j in V if i < j]     # igual
δ = Dict(i => [e for e in E if i in e] for i in V)

aresta(i, j) = (min(i, j), max(i, j))

# ---------- Modelo ----------
function build_model()
    vrptw = VrpModel()
    @variable(vrptw.formulation, x[e in E], Int)
    @objective(vrptw.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))   # igual

    @constraint(vrptw.formulation, grau[i in V⁺], sum(x[e] for e in δ[i]) == 2)     # igual

    # 1. Grafo: igual
    G = VrpGraph(vrptw, V, 0, 0, (L, U))

    # 3. Recursos: capacidade + tempo
    cap  = add_resource!(G, main = true)
    time = add_resource!(G, main = true)                 # NOVO
    for i in V
        set_resource_bounds!(G, i, cap,  0.0, Q)
        set_resource_bounds!(G, i, time, l(i), u(i))     # NOVO: janela do vértice (inclusive o depósito)
    end

    # 2. Arcos: os dois sentidos de cada aresta → x
    function arco!(i, j)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[aresta(i, j)])
        set_arc_consumption!(G, a, cap,  (d(i) + d(j)) / 2)
        set_arc_consumption!(G, a, time, t(i, j))        # NOVO: t(i,j) ≠ t(j,i)
    end
    for (i, j) in E
        arco!(i, j)
        arco!(j, i)
    end
    add_graph!(vrptw, G)

    # 4. Packing sets: igual
    set_vertex_packing_sets!(vrptw, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(vrptw, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(vrptw, "x", 1)
    return (vrptw, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_vrptw")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end