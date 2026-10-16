using VrpSolver, JuMP
include("gvrp_parser.jl")

inst = read_gvrp(joinpath(@__DIR__, "toy_gvrp.gvrp"))

n, m, Q = inst.n, inst.m, inst.Q                # igual
P       = inst.p                                # NOVO: nº de clusters (não é lucro!)
c(i, j) = inst.C[i + 1, j + 1]                  # igual (custo EUC_2D arredondado)
d(i)    = inst.d[i + 1]                         # demanda do CLUSTER de i
cl(i)   = inst.cl[i + 1]                        # NOVO: cluster do vértice i (0 = depósito)
C_g     = inst.clusters                         # NOVO: C_g[g] = vértices do cluster g

V  = collect(0:n)                               # igual
V⁺ = collect(1:n)                               # igual

L  = ceil(Int, sum(d(C_g[g][1]) for g in 1:P) / Q)   # volta a cota inferior: todo cluster é atendido
U  = m                                          # igual (na versão da Lista, U = P)
ub = 96.01                                      # cutoff da toy (ótimo = 96; objetivo é custo, positivo)

E = [(i, j) for i in V for j in V if i < j && (i == 0 || cl(i) != cl(j))]   # sem arestas dentro de um cluster
δ = Dict(i => [e for e in E if i in e] for i in V)                          # igual

aresta(i, j) = (min(i, j), max(i, j))           # igual

# ---------- Modelo ----------
function build_model()
    gvrp = VrpModel()
    @variable(gvrp.formulation, x[e in E], Int)
    # sai y: a escolha do nó de cada cluster fica a cargo da restrição de grau por cluster
    @objective(gvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))   # só custo
    @constraint(gvrp.formulation, deg[g in 1:P],
        sum(x[e] for i in C_g[g] for e in δ[i]) == 2)                             # por CLUSTER

    # 1. Grafo: igual (source = sink = 0)
    G = VrpGraph(gvrp, V, 0, 0, (L, U))

    # 3. Recursos: igual (d(j) agora é a demanda do cluster de j)
    cap = add_resource!(G, main = true)
    for i in V
        set_resource_bounds!(G, i, cap, 0.0, Q)
    end

    # 2. Arcos: igual (E já não tem arestas dentro de um cluster)
    function arco!(i, j)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[aresta(i, j)])
        set_arc_consumption!(G, a, cap, float(d(j)))
    end
    for (i, j) in E
        arco!(i, j)
        arco!(j, i)
    end
    add_graph!(gvrp, G)

    # 4. Packing sets: um por CLUSTER (não por cliente)
    set_vertex_packing_sets!(gvrp, [[(G, i) for i in C_g[g]] for g in 1:P])
    define_elementarity_sets_distance_matrix!(gvrp, G,
        [[g == h ? 0.0 : float(minimum(c(i, j) for i in C_g[g] for j in C_g[h]))
          for h in 1:P] for g in 1:P])                                           # P × P

    set_branching_priority!(gvrp, "x", 1)            # sai a prioridade de y
    return (gvrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Solução ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Nós escolhidos: ", [i for i in V⁺ if sum(get_value(optimizer, x[e]) for e in δ[i]) > 0.5])
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end