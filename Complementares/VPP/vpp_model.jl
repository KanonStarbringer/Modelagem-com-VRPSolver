using VrpSolver, JuMP
include(joinpath(@__DIR__, "vpp_parser.jl"))       # muda: parser do VPP
inst = read_vpp(joinpath(@__DIR__, "Instancias", "CL_09_25_01.TXT"))  # benchmark: read_vpp(joinpath(@__DIR__, "toy_vpp.txt")) read_vpp(joinpath(@__DIR__, "Instancias", "CL_06_25_01.TXT"))

n = inst.n                                          # igual: nº de itens
T = 1:n                                             # igual
Q = inst.Q                                          # muda: DUAS capacidades, Q[1] (peso) e Q[2] (volume)
w(k, t) = inst.w[k][t]                              # muda: w(1, t) = peso, w(2, t) = volume do item t

V = collect(0:n)                                    # igual: v_0..v_n

ub = 7.01                                           # toy: 6; CL_01_25_01: 6.01; CL_02_25_01: 13.01; CL_06_25_01: 10.01; CL_09_25_01: 7.01

# -------------------- build_model -------------------------------------------------------

function build_model()
    vpp = VrpModel()
    @variable(vpp.formulation, x[t in 0:n] >= 0, Int)                # igual: x[0] = nº de bins; Int obrigatório
    @objective(vpp.formulation, Min, x[0])                           # igual
    @constraint(vpp.formulation, item[t in T], x[t] == 1)            # igual

    # 1. Grafo: igual ao BPP
    G = VrpGraph(vpp, V, 0, n, (0, n))

    # 3. Recursos: muda, DOIS principais (peso e volume), cada um com seu limite
    cap = [add_resource!(G, main = true) for k in 1:2]               # muda: no BPP era um só
    for v in V, k in 1:2
        set_resource_bounds!(G, v, cap[k], 0.0, Q[k])
    end

    # 2. Arcos: dois paralelos entre v_{t-1} e v_t (igual)
    P = Vector{Tuple{VrpGraph,Int}}[]
    for t in T
        a⁺ = add_arc!(G, t - 1, t)                                   # item t DENTRO
        for k in 1:2
            set_arc_consumption!(G, a⁺, cap[k], w(k, t))             # muda: consome peso E volume
        end
        add_arc_var_mapping!(G, a⁺, t == 1 ? [x[t], x[0]] : [x[t]])
        push!(P, [(G, a⁺)])

        a⁻ = add_arc!(G, t - 1, t)                                   # item t FORA
        for k in 1:2
            set_arc_consumption!(G, a⁻, cap[k], 0.0)                 # muda: zero nos dois recursos
        end
        t == 1 && add_arc_var_mapping!(G, a⁻, x[0])
    end
    add_graph!(vpp, G)

    # 4. Packing sets em arcos e Ryan-Foster: igual ao BPP
    set_arc_packing_sets!(vpp, P)
    enable_packset_ryanfoster_branching!(vpp, 1)
    return (vpp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Nº de bins: ", get_objective_value(optimizer))
    usados = Int[]
    for p in 1:get_number_of_positive_paths(optimizer)
        itens = [t for t in T if get_value(optimizer, x[t], p) > 0.5]
        append!(usados, itens)
        carga = [sum(w(k, t) for t in itens; init = 0) for k in 1:2]  # muda: confere as duas cargas
        println("bin $p: itens ", itens, "  peso ", carga[1], "/", Q[1], "  volume ", carga[2], "/", Q[2],
                all(carga .<= collect(Q)) ? "" : "  ← ESTOURO")
    end
    println(sort(usados) == collect(T) ? "OK: cada item em exatamente um bin" : "ERRO: itens repetidos ou faltando")
end
