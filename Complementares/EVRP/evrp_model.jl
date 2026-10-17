using VrpSolver, JuMP
include(joinpath(@__DIR__, "evrp_parser.jl"))   # muda: parser do E-VRP
inst = read_evrp(joinpath(@__DIR__, "Instancias", "consec", "mlsa_flow_10c5f23.000000B-P-n16-k8.vrp"))     # benchmark: read_evrp(joinpath(@__DIR__, "toy_evrp.vrp")) 

N  = inst.N                                     # nº de vértices físicos (ids 0..N-1)
Cl = inst.C                                     # NOVO: clientes (sai Pk/Dl)
St = inst.S                                     # NOVO: estações físicas
β, ρ, Tmax, ξ = inst.β, inst.ρ, inst.T, inst.ξ  # NOVO: autonomia, consumo, duração máx., velocidade
# saem r, Q, K, q̄, l, u: sem capacidade, sem janelas, frota livre

c(i, j) = inst.c[i + 1, j + 1]                  # igual (agora nint)
e(i, j) = ρ * c(i, j)                           # NOVO: energia do arco físico
t(i, j) = c(i, j) / ξ                           # muda: só viagem (o serviço entra à parte)
s(i) = inst.s[i + 1]                            # NOVO: serviço no cliente / tempo de recarga g_s na estação

# NOVO: desdobramento das estações — s⁻ = id da estação, s⁺ = id novo
plus(s) = s + N                                 # s⁺
out(i) = i in St ? plus(i) : i                  # sai de s pelo s⁺
inn(j) = j                                      # entra em s pelo s⁻ (= próprio id)
VG = vcat(0, Cl, St, plus.(St))                 # vértices do grafo de pricing

ub = 284.01                                     # toy; 10c5f23: 284.01

# muda: arcos FÍSICOS (variáveis x do mestre); sem laço, sem estação→mesma estação
A  = [(i, j) for i in 0:N-1 for j in 0:N-1 if i != j]
δ⁻ = Dict(j => [a for a in A if a[2] == j] for j in Cl)   # cobre só os CLIENTES
L, U = 0, length(Cl)                            # NOVO: frota livre

# ---------- Modelo ----------
function build_model()
    evrp = VrpModel()
    @variable(evrp.formulation, x[a in A] >= 0, Int)                        # igual: inteira (arcos de estação podem repetir)
    @objective(evrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A))   # igual

    @constraint(evrp.formulation, cob[j in Cl], sum(x[a] for a in δ⁻[j]) == 1)    # muda: cobre só os CLIENTES

    # 1. Grafo: vértices desdobrados
    G = VrpGraph(evrp, VG, 0, 0, (L, U))                # muda: VG inclui s⁻ e s⁺

    # 3. Recursos: tempo + bateria (sai a carga e os recursos de requisição)
    time = add_resource!(G, main = true)
    bat  = add_resource!(G)                             # NOVO: energia consumida desde a última recarga (secundário, descartável)
    for v in VG
        set_resource_bounds!(G, v, time, 0.0, Tmax)     # muda: limite único [0, T] (sem janelas)
        set_resource_bounds!(G, v, bat, 0.0, β)         # NOVO: [0, β] — testado em s⁻ ANTES do reset
    end

    # 2a. Arcos de viagem: físico (i, j) → (out(i), inn(j))
    for (i, j) in A
        a = add_arc!(G, out(i), inn(j))
        add_arc_var_mapping!(G, a, x[(i, j)])
        set_arc_consumption!(G, a, time, t(i, j) + (j in Cl ? s(j) : 0.0))   # serviço só ao chegar em cliente
        set_arc_consumption!(G, a, bat, e(i, j))
    end
    # 2b. NOVO: arcos de recarga (s⁻, s⁺) — sem mapeamento
    for s₀ in St
        a = add_arc!(G, s₀, plus(s₀))
        set_arc_consumption!(G, a, time, s(s₀))         # tempo de recarga g_s
        set_arc_consumption!(G, a, bat, -β)             # reset: max{0, E − β} = 0
    end
    add_graph!(evrp, G)

    # 4. Packing sets: SÓ os clientes (estações ficam fora → revisitáveis)
    set_vertex_packing_sets!(evrp, [[(G, j)] for j in Cl])
    define_elementarity_sets_distance_matrix!(evrp, G,
        [[c(i, j) for j in Cl] for i in Cl])

    set_branching_priority!(evrp, "x", 1)
    return (evrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_evrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for a in A
        get_value(optimizer, x[a]) > 0.5 && println("x[$a] = ", round(get_value(optimizer, x[a])))
    end
end