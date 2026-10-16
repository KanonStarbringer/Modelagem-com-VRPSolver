using VrpSolver, JuMP
include("mtvrp_parser.jl")

inst = read_mtvrp(joinpath(@__DIR__, "..", "DCVRP", "Instancias", "CMT", "CMT1.vrp"); m = 4, T = 144)

n, Q, m, T = inst.n, inst.Q, inst.m, inst.T     # sai P; Q vira escalar; entram m e T
c(i, j) = inst.C[i + 1, j + 1]                  # igual (no benchmark, custo = tempo)
d(i)    = inst.d[i + 1]                         # era d(i, p)

V  = collect(0:n)                               # igual (vértices do problema original)
V⁺ = collect(1:n)                               # igual

L  = 1                                          # era o nº mínimo de VIAGENS
U  = m                                          # era n: agora a frota é dada
ub = 546.30                                     # cutoff do CMT1, m = 2, T = 275 (ótimo = 533.00); toy: 105.23

E = [(i, j) for i in V for j in V if i < j]     # igual
δ = Dict(i => [e for e in E if i in e] for i in V)   # igual

# ---------- Grafo em camadas (uma camada por viagem) ----------
idas_voltas = sort([2 * c(0, i) for i in V⁺])       # duração mínima de uma viagem
K = max(1, count(<=(T), cumsum(idas_voltas)))            # nº máximo de viagens por veículo

cli(i, k) = (k - 1) * n + i                    # id do vértice (i, k): cliente i na viagem k
dep(k)    = K * n + k                          # id da cópia 0_k do depósito (k = 1..K-1)
VG = [0; [cli(i, k) for k in 1:K for i in V⁺]; [dep(k) for k in 1:K-1]]

aresta(i, j) = (min(i, j), max(i, j))          # aresta original de E que um arco representa

# ---------- Modelo ----------
function build_model()
    cvrp = VrpModel()
    @variable(cvrp.formulation, x[e in E], Int)
    @objective(cvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))
    @constraint(cvrp.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2.0)

    # 1. Grafo: vértices em camadas; source = sink = 0
    G = VrpGraph(cvrp, VG, 0, 0, (L, U))

    # 3. Recursos
    cap = add_resource!(G, main = true)              # capacidade, "zerada" por viagem
    tim = add_resource!(G, main = true)              # tempo, acumula na agenda inteira
    set_resource_bounds!(G, 0, cap, 0.0, K * Q)
    set_resource_bounds!(G, 0, tim, 0.0, T)
    for k in 1:K, i in V⁺
        set_resource_bounds!(G, cli(i, k), cap, (k - 1) * Q, k * Q)   # viagem k: carga em [(k-1)Q, kQ]
        set_resource_bounds!(G, cli(i, k), tim, 0.0, T)
    end
    for k in 1:K-1
        set_resource_bounds!(G, dep(k), cap, k * Q, k * Q)            # sobe a carga para kQ: "reset"
        set_resource_bounds!(G, dep(k), tim, 0.0, T)
    end

    # 2. Arcos: (u, v) no grafo G representa a aresta original (i, j)
    function arco!(u, v, i, j)
        a = add_arc!(G, u, v)
        add_arc_var_mapping!(G, a, x[aresta(i, j)])
        set_arc_consumption!(G, a, cap, float(d(j)))     # d(0) = 0
        set_arc_consumption!(G, a, tim, c(i, j))
    end
    for j in V⁺
        arco!(0, cli(j, 1), 0, j)                        # começa a 1ª viagem
    end
    for k in 1:K, i in V⁺
        for j in V⁺
            i != j && arco!(cli(i, k), cli(j, k), i, j)  # segue na viagem k
        end
        arco!(cli(i, k), 0, i, 0)                        # encerra a agenda
        if k < K
            arco!(cli(i, k), dep(k), i, 0)               # volta ao depósito no fim da viagem k
            arco!(dep(k), cli(i, k + 1), 0, i)           # sai para a viagem k+1
        end
    end
    add_graph!(cvrp, G)

    # 4. Packing sets: cada cliente = conjunto das suas K cópias
    set_vertex_packing_sets!(cvrp, [[(G, cli(i, k)) for k in 1:K] for i in V⁺])
    define_elementarity_sets_distance_matrix!(cvrp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

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