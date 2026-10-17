using VrpSolver, JuMP
include(joinpath(@__DIR__, "mdvrp_parser.jl"))  # muda: parser do MDVRP
inst = read_mdvrp(joinpath(@__DIR__, "Instancias", "p02"))   # benchmark: read_mdvrp(joinpath(@__DIR__, "toy_mdvrp"))

n, Q, m = inst.n, inst.Q, inst.m                # NOVO: m = veículos por depósito
c(i, j) = inst.C[i, j]                          # muda: SEM o +1 (vértices 1..n+t, não há 0)
d(i) = inst.d[i]                                # muda: SEM o +1; d = 0 nos depósitos
# saem t(i, j), l(i), u(i): não há tempo nem janelas

V⁺ = collect(1:n)                               # clientes
depots = inst.depots                            # NOVO: [n+1, ..., n+t]; substitui o V = 0:n

# saem L e U globais: o limite agora é por grafo, (0, m)
ub = 473.54                                     # toy; p01: 576.88

Ecc = [(i, j) for i in V⁺ for j in V⁺ if i < j]     # NOVO: cliente-cliente
Edc = [(k, i) for k in depots for i in V⁺]          # NOVO: depósito-cliente
E   = vcat(Ecc, Edc)                                # muda: sem arestas depósito-depósito

δ = Dict(i => vcat([e for e in Ecc if i in e], [(k, i) for k in depots]) for i in V⁺)   # muda: só para clientes

# ---------- Modelo ----------
function build_model()
    mdvrp = VrpModel()
    @variable(mdvrp.formulation, x[e in E], Int)
    @objective(mdvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))   # igual

    @constraint(mdvrp.formulation, grau[i in V⁺], sum(x[e] for e in δ[i]) == 2)     # igual

    graphs = VrpGraph[]                                  # NOVO: um grafo por depósito
    for k in depots
        Vk = vcat([k], V⁺)                               # NOVO: depósito k + clientes
        G = VrpGraph(mdvrp, Vk, k, k, (0, m))            # muda: source = sink = k; até m veículos

        # Recurso: só a capacidade (sai o tempo)
        cap = add_resource!(G, main = true)
        for i in Vk
            set_resource_bounds!(G, i, cap, 0.0, Q)
        end

        function arco!(i, j, e)
            a = add_arc!(G, i, j)
            add_arc_var_mapping!(G, a, x[e])
            set_arc_consumption!(G, a, cap, (d(i) + d(j)) / 2)
        end
        for (i, j) in Ecc                                # cliente-cliente: em TODOS os grafos
            arco!(i, j, (i, j))
            arco!(j, i, (i, j))
        end
        for i in V⁺                                      # depósito-cliente: SÓ no grafo de k
            arco!(k, i, (k, i))
            arco!(i, k, (k, i))
        end
        add_graph!(mdvrp, G)
        push!(graphs, G)
    end

    # Packing sets: as cópias de cada cliente em todos os grafos
    set_vertex_packing_sets!(mdvrp, [[(G, i) for G in graphs] for i in V⁺])
    for G in graphs
        define_elementarity_sets_distance_matrix!(mdvrp, G,
            [[float(c(i, j)) for j in V⁺] for i in V⁺])
    end

    set_branching_priority!(mdvrp, "x", 1)
    return (mdvrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_mdvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end