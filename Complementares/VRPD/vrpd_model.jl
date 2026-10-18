using VrpSolver, JuMP
include(joinpath(@__DIR__, "vrpd_parser.jl"))
inst = read_vrpd(joinpath(@__DIR__, "Instancias", "eil51.tsp"); R = 20, α = 0.2)

n = inst.n
C = inst.C                                         # clientes 1..n
V = collect(0:n)                                   # muda: volta o depósito 0 (source = sink); saem H, h̄, src, snk
R, α = inst.R, inst.α                              # NOVO: alcance do drone e custo por unidade

c(i, j) = inst.c[i + 1, j + 1]                     # muda: volta o +1; distância nint (TSPLIB)
dc(i, j, k) = α * (c(i, k) + c(k, j))              # NOVO: custo da sortie i → k → j

ub = 367.01                                         # muda: volta a ser positivo. toy: 81.6; eil51 (R = 20, α = 0.2): 367.01

A = [(i, j) for i in V for j in V if i != j]       # muda: volta a ARCOS dirigidos (sai E)
S = [(i, j, k) for (i, j) in A for k in C if k != i && k != j && c(i, k) + c(k, j) <= R]   # NOVO: sorties viáveis
δ⁻ = Dict(v => [a for a in A if a[2] == v] for v in C)      # volta (VRPB): arcos que chegam em v
Sv = Dict(v => [s for s in S if s[3] == v] for v in C)      # NOVO: sorties em que o drone atende v

# ---------- Modelo ----------
function build_model()
    vrpd = VrpModel()
    @variable(vrpd.formulation, x[a in A] >= 0, Int)                    # perna (i, j) do caminhão
    @variable(vrpd.formulation, y[s in S] >= 0, Int)                    # NOVO: sortie (i, j, k)
    @objective(vrpd.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A)
                                    + sum(dc(s...) * y[s] for s in S))  # muda: caminhão + drone

    # muda: cobertura (caminhão para em v OU drone atende v). Sai o grau 2g, 2y e U; o fluxo é redundante
    @constraint(vrpd.formulation, cobre[v in C], sum(x[a] for a in δ⁻[v]) + sum(y[s] for s in Sv[v]) == 1)

    # 1. Grafo: um caminhão, source = sink = 0
    G = VrpGraph(vrpd, V, 0, 0, (1, 1))                                 # muda

    # 3. Recurso: nº de clientes atendidos (não restringe; só garante caminhos finitos)
    cli = add_resource!(G, main = true)                                 # muda: sai o tempo
    for v in V
        set_resource_bounds!(G, v, cli, 0.0, Float64(n))
    end

    # 2. Arcos: um direto + um PARALELO por sortie
    P = Dict(v => Tuple{VrpGraph,Int}[] for v in C)                    # NOVO: packing set de cada cliente
    for (i, j) in A
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[(i, j)])
        set_arc_consumption!(G, a, cli, j == 0 ? 0.0 : 1.0)
        j != 0 && push!(P[j], (G, a))                                   # direto (i, v) ∈ P_v
    end
    for (i, j, k) in S
        a = add_arc!(G, i, j)                                           # NOVO: mesmo (i, j), outro arco
        add_arc_var_mapping!(G, a, [x[(i, j)], y[(i, j, k)]])           # NOVO: um arco, DUAS variáveis
        set_arc_consumption!(G, a, cli, j == 0 ? 1.0 : 2.0)             # k pelo drone + j pelo caminhão
        push!(P[k], (G, a))                                             # sortie só em P_k (disjunto)
    end
    add_graph!(vrpd, G)

    # 4. Packing sets em ARCOS
    set_arc_packing_sets!(vrpd, [P[v] for v in C])                      # muda: sai set_vertex_packing_sets!
    define_elementarity_sets_distance_matrix!(vrpd, G, [[c(i, j) for j in C] for i in C])

    set_branching_priority!(vrpd, "x", 1)
    set_branching_priority!(vrpd, "y", 1)                               # muda: sai g
    return (vrpd, x, y)                                                 # muda: sai o callback
end

# ---------- Resolução ----------
(model, x, y) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)                  # muda: volta o CVRP.cfg
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for a in A
        get_value(optimizer, x[a]) > 0.5 && println("x[$a] = ", round(get_value(optimizer, x[a])))
    end
    for (i, j, k) in S                                                  # NOVO
        get_value(optimizer, y[(i, j, k)]) > 0.5 && println("drone: $i → $k → $j")
    end
end