using VrpSolver, JuMP
include(joinpath(@__DIR__, "bpp_parser.jl"))       # muda: parser do BPP
inst = read_bpp(joinpath(@__DIR__, "Instancias", "Falkenauer_U120", "u120_00.txt"))  # benchmark: read_bpp(joinpath(@__DIR__, "toy_bpp.txt")) 

n = inst.n
T = 1:n                                             # NOVO: itens (saem C e o depósito)
Q = inst.Q                                          # volta: capacidade do bin (saem R e α)
w(t) = inst.w[t]                                    # NOVO: peso do item (saem c e dc)

V = collect(0:n)                                    # muda: v_0..v_n, um vértice por decisão (não por cliente)

ub = 48.01                                           # toy: 3 bins; u120_00: 3.01 
# saem A, S, δ⁻ e Sv: os arcos são criados direto no build_model

# -------------------- build_model -------------------------------------------------------

function build_model()
    bpp = VrpModel()
    @variable(bpp.formulation, x[t in 0:n] >= 0, Int)                     # muda: CONTÍNUAS. x[0] = nº de bins, x[t] = item t
    @objective(bpp.formulation, Min, x[0])                           # muda: nº de bins
    @constraint(bpp.formulation, item[t in T], x[t] == 1)            # muda: cada item empacotado uma vez

    # 1. Grafo: source v_0 ≠ sink v_n, de 0 a n bins
    G = VrpGraph(bpp, V, 0, n, (0, n))                               # muda

    # 3. Recurso: capacidade do bin
    cap = add_resource!(G, main = true)                              # muda: volta a capacidade
    for v in V
        set_resource_bounds!(G, v, cap, 0.0, Q)
    end

    # 2. Arcos: dois PARALELOS entre v_{t-1} e v_t
    P = Vector{Tuple{VrpGraph,Int}}[]
    for t in T
        a⁺ = add_arc!(G, t - 1, t)                                   # item t DENTRO
        set_arc_consumption!(G, a⁺, cap, w(t))
        add_arc_var_mapping!(G, a⁺, t == 1 ? [x[t], x[0]] : [x[t]])  # x[0] conta o bin no item 1
        push!(P, [(G, a⁺)])                                          # packing set {a_t⁺}

        a⁻ = add_arc!(G, t - 1, t)                                   # item t FORA
        set_arc_consumption!(G, a⁻, cap, 0.0)
        t == 1 && add_arc_var_mapping!(G, a⁻, x[0])                  # todo bin passa por a_1⁺ OU a_1⁻
    end
    add_graph!(bpp, G)

    # 4. Packing sets em arcos: só os "item dentro"
    set_arc_packing_sets!(bpp, P)
    # sai define_elementarity_sets_distance_matrix!: grafo acíclico, o ng não tem o que relaxar

    enable_packset_ryanfoster_branching!(bpp, 1)                     # NOVO: único branching correto
    return (bpp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Nº de bins: ", get_objective_value(optimizer))
    for p in 1:get_number_of_positive_paths(optimizer)
        itens = [t for t in T if get_value(optimizer, x[t], p) > 0.5]
        println("bin $p: itens ", itens, "  pesos ", w.(itens), "  carga ", sum(w.(itens)), "/", Q)
    end                                                              # ← fim do for
    usados = [t for p in 1:get_number_of_positive_paths(optimizer) for t in T if get_value(optimizer, x[t], p) > 0.5]
    println(sort(usados) == collect(T) ? "OK: cada item em exatamente um bin" : "ERRO: itens repetidos ou faltando")
end