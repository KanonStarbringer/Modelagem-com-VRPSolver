using VrpSolver, JuMP
include(joinpath(@__DIR__, "fsmvrp_parser.jl"))  # muda: parser do FSMVRP (= read_hfvrp)
inst = read_hfvrp(joinpath(@__DIR__, "Instancias", "c50_14fsmfd.txt"))   # benchmark: read_hfvrp(joinpath(@__DIR__, "toy_fsmvrp.txt")) 

n = inst.n
K = 1:inst.K                                    # igual: conjunto de tipos
Q = inst.Q                                      # igual: Q[k]
u = inst.u                                      # muda: u[k] por tipo (= n: frota livre); sai o m único
f = inst.f                                      # NOVO: custo fixo f[k]
α = inst.α                                      # NOVO: custo por unidade de distância α[k]
# sai comp: todo tipo atende todo cliente

ℓ(i, j) = inst.ℓ[i + 1, j + 1]                  # igual
c(k, i, j) = α[k] * ℓ(i, j)                     # muda: agora depende do tipo de verdade
d(i) = inst.d[i + 1]                            # igual

V  = collect(0:n)
V⁺ = collect(1:n)

ub = 9126.91                                     # toy; c50_14fsmfd: 209.26

E = [(i, j) for i in V for j in V if i < j]     # igual
δ = Dict(i => [e for e in E if i in e] for i in V)
# saem ok, Ek e Vk: sem compatibilidade, todos os grafos usam V e E inteiros

# ---------- Modelo ----------
function build_model()
    fsm = VrpModel()
    @variable(fsm.formulation, x[k in K, e in E], Int)                           # muda: todas as arestas (sem Ek)
    @variable(fsm.formulation, z[k in K], Int)                                   # NOVO: nº de veículos do tipo k
    @objective(fsm.formulation, Min,
        sum(c(k, i, j) * x[k, (i, j)] for k in K for (i, j) in E) +
        sum(f[k] * z[k] for k in K))                                             # NOVO: + Σ f_k z_k

    @constraint(fsm.formulation, grau[i in V⁺],
        sum(x[k, e] for k in K for e in δ[i]) == 2)                              # muda: soma sobre todos os tipos

    G = Dict{Int,VrpGraph}()
    for k in K
        G[k] = VrpGraph(fsm, V, 0, 0, (0, u[k]))           # muda: todos os vértices; até u[k] (= n) veículos

        cap = add_resource!(G[k], main = true)
        for i in V
            set_resource_bounds!(G[k], i, cap, 0.0, Q[k])
        end

        function arco!(i, j, vars)
            a = add_arc!(G[k], i, j)
            add_arc_var_mapping!(G[k], a, vars)
            set_arc_consumption!(G[k], a, cap, (d(i) + d(j)) / 2)
        end
        for (i, j) in E
            if i == 0
                arco!(0, j, [x[k, (0, j)], z[k]])          # NOVO: saída conta a aresta E um veículo do tipo k
                arco!(j, 0, x[k, (0, j)])                  # volta: só a aresta
            else
                arco!(i, j, x[k, (i, j)])
                arco!(j, i, x[k, (i, j)])
            end
        end
        add_graph!(fsm, G[k])
    end

    # Packing sets: cópias de i em todos os grafos (sem compatibilidade)
    set_vertex_packing_sets!(fsm, [[(G[k], i) for k in K] for i in V⁺])
    for k in K
        define_elementarity_sets_distance_matrix!(fsm, G[k],
            [[ℓ(i, j) for j in V⁺] for i in V⁺])
    end

    set_branching_priority!(fsm, "x", 1)
    return (fsm, x, z)
end

# ---------- Resolução ----------
(model, x, z) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_fsmvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Frota (z): ", [round(get_value(optimizer, z[k])) for k in K])
    for k in K, e in E
        get_value(optimizer, x[k, e]) > 0.5 && println("x[tipo $k, $e] = ", round(get_value(optimizer, x[k, e])))
    end
end