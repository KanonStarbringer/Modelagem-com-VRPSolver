using VrpSolver, JuMP
include(joinpath(@__DIR__, "sdvrp_parser.jl"))  # muda: parser do SDVRP
inst = read_sdvrp(joinpath(@__DIR__, "Instancias", "p08"))       # benchmark: read_sdvrp(joinpath(@__DIR__, "toy_sdvrp")) 

n = inst.n
K = 1:inst.K                                    # muda: K volta a ser o conjunto de TIPOS (no VRPB era a frota fixa)
Q = inst.Q                                      # muda: Q[k] por tipo
m = inst.m                                      # NOVO: veículos por tipo (u^k = m)
comp = inst.comp                                # NOVO: comp[i] = tipos que podem visitar i

ℓ(i, j) = inst.ℓ[i + 1, j + 1]                  # muda: distância física
c(k, i, j) = ℓ(i, j)                            # NOVO: custo do tipo k (aqui igual para todos)
d(i) = inst.d[i + 1]                            # igual

V  = collect(0:n)
V⁺ = collect(1:n)
# saem Lh e Bh: não há linehaul/backhaul

ub = 1056.30                                     # toy; p07: 391.31

# muda: volta a ser ARESTAS (sai o A dirigido do VRPB)
E  = [(i, j) for i in V for j in V if i < j]
ok(k, i) = i == 0 || k in comp[i]               # NOVO: vértice i existe no grafo do tipo k?
Ek = Dict(k => [(i, j) for (i, j) in E if ok(k, i) && ok(k, j)] for k in K)   # NOVO: arestas compatíveis com k
Vk = Dict(k => [i for i in V if ok(k, i)] for k in K)                         # NOVO: vértices do grafo k
δ  = Dict(i => [e for e in E if i in e] for i in V)

# ---------- Modelo ----------
function build_model()
    sdvrp = VrpModel()
    @variable(sdvrp.formulation, x[k in K, e in Ek[k]], Int)                     # muda: por tipo, só arestas compatíveis
    @objective(sdvrp.formulation, Min,
        sum(c(k, i, j) * x[k, (i, j)] for k in K for (i, j) in Ek[k]))           # muda: custo por tipo

    @constraint(sdvrp.formulation, grau[i in V⁺],
        sum(x[k, e] for k in comp[i] for e in δ[i] if e in Ek[k]) == 2)          # muda: soma só nos tipos compatíveis

    G = Dict{Int,VrpGraph}()                                                     # NOVO: um grafo por tipo
    for k in K
        G[k] = VrpGraph(sdvrp, Vk[k], 0, 0, (0, m))       # muda: só vértices compatíveis; até m veículos

        cap = add_resource!(G[k], main = true)
        for i in Vk[k]
            set_resource_bounds!(G[k], i, cap, 0.0, Q[k])  # muda: capacidade do tipo k
        end

        for (i, j) in Ek[k]                                # muda: só arestas compatíveis; os dois sentidos → x[k, e]
            for (u, v) in ((i, j), (j, i))
                a = add_arc!(G[k], u, v)
                add_arc_var_mapping!(G[k], a, x[k, (i, j)])
                set_arc_consumption!(G[k], a, cap, (d(i) + d(j)) / 2)
            end
        end
        add_graph!(sdvrp, G[k])
    end

    # Packing sets: as cópias de i só nos grafos compatíveis
    set_vertex_packing_sets!(sdvrp, [[(G[k], i) for k in comp[i]] for i in V⁺])
    for k in K
        define_elementarity_sets_distance_matrix!(sdvrp, G[k],
            [[ℓ(i, j) for j in V⁺] for i in V⁺])
    end

    set_branching_priority!(sdvrp, "x", 1)
    return (sdvrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_sdvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for k in K, e in Ek[k]
        get_value(optimizer, x[k, e]) > 0.5 && println("x[tipo $k, $e] = ", round(get_value(optimizer, x[k, e])))
    end
end