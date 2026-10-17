using VrpSolver, JuMP
include(joinpath(@__DIR__, "hfvrp_parser.jl"))  # muda: parser do HFVRP
inst = read_hfvrp(joinpath(@__DIR__, "Instancias", "c50_14hd.txt"))    # benchmark: read_hfvrp(joinpath(@__DIR__, "toy_hfvrp.txt")) 

n = inst.n
K = 1:inst.K                                    # NOVO: tipos de veículo (substitui depots)
Q = inst.Q                                      # muda: vetor, Q[k] por tipo
α = inst.α                                      # NOVO: custo por unidade de distância do tipo k
u = inst.u                                      # NOVO: nº máx. de veículos do tipo k (substitui m)

ℓ(i, j) = inst.ℓ[i + 1, j + 1]                  # muda: distância física; volta o +1 (depósito = 0)
c(k, i, j) = α[k] * ℓ(i, j)                     # NOVO: custo depende do tipo
d(i) = inst.d[i + 1]                            # muda: volta o +1

V  = collect(0:n)                               # volta: depósito único 0
V⁺ = collect(1:n)

ub = 607.54                                     # toy; c50_14hd: 607.54

E = [(i, j) for i in V for j in V if i < j]     # volta o E do CVRP: as arestas são as mesmas em todos os grafos
δ = Dict(i => [e for e in E if i in e] for i in V)

# ---------- Modelo ----------
function build_model()
    hfvrp = VrpModel()
    @variable(hfvrp.formulation, x[k in K, e in E], Int)                               # muda: uma variável por tipo e aresta
    @objective(hfvrp.formulation, Min,
        sum(c(k, i, j) * x[k, (i, j)] for k in K for (i, j) in E))                     # muda: custo α_k·ℓ

    @constraint(hfvrp.formulation, grau[i in V⁺],
        sum(x[k, e] for k in K for e in δ[i]) == 2)                                    # muda: soma sobre os tipos

    graphs = VrpGraph[]
    for k in K                                           # muda: um grafo por TIPO
        G = VrpGraph(hfvrp, V, 0, 0, (0, u[k]))          # muda: depósito 0; até u[k] veículos do tipo k

        cap = add_resource!(G, main = true)
        for i in V
            set_resource_bounds!(G, i, cap, 0.0, Q[k])   # muda: capacidade do tipo k
        end

        function arco!(i, j, e)
            a = add_arc!(G, i, j)
            add_arc_var_mapping!(G, a, x[k, e])          # muda: variável do tipo k
            set_arc_consumption!(G, a, cap, (d(i) + d(j)) / 2)   # igual: demanda não depende do tipo
        end
        for (i, j) in E                                  # muda: todas as arestas, em todos os grafos
            arco!(i, j, (i, j))
            arco!(j, i, (i, j))
        end
        add_graph!(hfvrp, G)
        push!(graphs, G)
    end

    # Packing sets: igual (cópias de cada cliente em todos os grafos)
    set_vertex_packing_sets!(hfvrp, [[(G, i) for G in graphs] for i in V⁺])
    for G in graphs
        define_elementarity_sets_distance_matrix!(hfvrp, G,
            [[float(ℓ(i, j)) for j in V⁺] for i in V⁺])  # muda: distância física ℓ
    end

    set_branching_priority!(hfvrp, "x", 1)
    return (hfvrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_hfvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for k in K, e in E
        get_value(optimizer, x[k, e]) > 0.5 && println("x[tipo $k, $e] = ", round(get_value(optimizer, x[k, e])))
    end
end