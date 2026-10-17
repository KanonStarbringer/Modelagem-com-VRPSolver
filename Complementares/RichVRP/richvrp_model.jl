using VrpSolver, JuMP
include(joinpath(@__DIR__, "rich_parser.jl"))   # muda: parser do Rich VRP
inst = read_rich(joinpath(@__DIR__, "toy_rich.rvrp"))     # benchmark: read_rich(joinpath(@__DIR__, "rich_mix15.rvrp"))

n = inst.n
V⁺ = collect(1:n)                               # clientes (sai Cl/St: não há estações)
depots = inst.depots                            # NOVO: depósitos n+1..n+m
K = 1:inst.K                                    # NOVO: tipos de veículo
b, Q, u, f, α = inst.b, inst.Q, inst.u, inst.f, inst.α   # NOVO: base, capacidade, disponibilidade, custo fixo e α por tipo
comp = inst.comp                                # NOVO: tipos compatíveis com cada cliente
ρ = inst.ρ                                      # NOVO: penalidade (−1 = obrigatório)
VM = [i for i in V⁺ if ρ[i] < 0]                # NOVO: obrigatórios
VO = [i for i in V⁺ if ρ[i] >= 0]               # NOVO: opcionais
# saem β, ρ (consumo), ξ, Tmax, plus/out/inn: sem bateria nem desdobramento

ℓ(i, j) = inst.ℓ[i, j]                          # muda: SEM o +1 (vértices 1..n+m, como no MDVRP)
c(k, i, j) = α[k] * ℓ(i, j)                     # NOVO: custo por tipo
t(i, j) = inst.T[i, j]                          # muda: s_i + ℓ_ij (como no VRPTW), assimétrico
d(i) = inst.d[i]                                # NOVO: volta a demanda (d = 0 nos depósitos)
l(i) = inst.l[i]                                # volta: janelas (depósitos inclusive)
uw(i) = inst.u_tw[i]

ub = 197.69                                     # toy; rich_mix15: 622.54

# muda: volta a ARESTAS, por tipo e só compatíveis (como no SDVRP + MDVRP)
Ecc = [(i, j) for i in V⁺ for j in V⁺ if i < j]                     # cliente-cliente
Ek  = Dict(k => vcat([(b[k], i) for i in V⁺ if k in comp[i]],       # base b(k) - cliente (depósito primeiro)
                     [(i, j) for (i, j) in Ecc if k in comp[i] && k in comp[j]]) for k in K)
Vk  = Dict(k => vcat([b[k]], [i for i in V⁺ if k in comp[i]]) for k in K)
δ   = Dict(i => [(k, e) for k in K for e in Ek[k] if i in e] for i in V⁺)   # NOVO: pares (tipo, aresta) que tocam i

# ---------- Modelo ----------
function build_model()
    rich = VrpModel()
    @variable(rich.formulation, x[k in K, e in Ek[k]], Int)                     # como no SDVRP
    @variable(rich.formulation, z[k in K], Int)                                 # como no FSMVRP: veículos do tipo k
    @variable(rich.formulation, ω[i in VO], Bin)                                # muda: 1 se o opcional i NÃO é atendido
    @objective(rich.formulation, Min,
        sum(c(k, e...) * x[k, e] for k in K for e in Ek[k]) +
        sum(f[k] * z[k] for k in K) +
        sum(ρ[i] * ω[i] for i in VO))                                           # muda: sem constante

    @constraint(rich.formulation, obrig[i in VM], sum(x[k, e] for (k, e) in δ[i]) == 2)
    @constraint(rich.formulation, opc[i in VO],   sum(x[k, e] for (k, e) in δ[i]) + 2ω[i] == 2)                                     # NOVO: penalidade dos não atendidos

    G = Dict{Int,VrpGraph}()
    for k in K
        G[k] = VrpGraph(rich, Vk[k], b[k], b[k], (0, u[k]))   # base b(k); só compatíveis; até u[k] veículos

        cap  = add_resource!(G[k], main = true)
        time = add_resource!(G[k], main = true)                # como no VRPTW
        for v in Vk[k]
            set_resource_bounds!(G[k], v, cap, 0.0, Q[k])
            set_resource_bounds!(G[k], v, time, l(v), uw(v))  # janela (depósito inclusive)
        end

        function arco!(i, j, e, vars)
            a = add_arc!(G[k], i, j)
            add_arc_var_mapping!(G[k], a, vars)
            set_arc_consumption!(G[k], a, cap, (d(i) + d(j)) / 2)
            set_arc_consumption!(G[k], a, time, t(i, j))       # assimétrico: cada sentido com o seu tempo
        end
        for e in Ek[k]
            i, j = e
            if i == b[k]
                arco!(i, j, e, [x[k, e], z[k]])                # saída da base: aresta + 1 veículo
                arco!(j, i, e, x[k, e])                        # volta: só a aresta
            else
                arco!(i, j, e, x[k, e])
                arco!(j, i, e, x[k, e])
            end
        end
        add_graph!(rich, G[k])
    end

    # Packing sets: todos os clientes (opcionais inclusive), cópias só nos grafos compatíveis
    set_vertex_packing_sets!(rich, [[(G[k], i) for k in comp[i]] for i in V⁺])
    for k in K
        define_elementarity_sets_distance_matrix!(rich, G[k],
            [[ℓ(i, j) for j in V⁺] for i in V⁺])
    end

    set_branching_priority!(rich, "x", 1)
    return (rich, x, z, ω)
end

# ---------- Resolução ----------
(model, x, z, ω) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_rich")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Frota (z): ", [round(get_value(optimizer, z[k])) for k in K])
    println("Opcionais NÃO atendidos: ", [i for i in VO if get_value(optimizer, ω[i]) > 0.5])
    for k in K, e in Ek[k]
        get_value(optimizer, x[k, e]) > 0.5 && println("x[tipo $k, $e] = ", round(get_value(optimizer, x[k, e])))
    end
end