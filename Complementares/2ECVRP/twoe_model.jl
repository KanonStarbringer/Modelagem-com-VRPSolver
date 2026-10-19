using VrpSolver, JuMP
include(joinpath(@__DIR__, "twoe_parser.jl"))      # muda: parser do 2E-CVRP
inst = read_2ecvrp(joinpath(@__DIR__, "Instancias", "Set5_100-5-1.dat"))   # benchmark: read_2ecvrp(joinpath(@__DIR__, "Instancias", "Set2a_E-n22-k4-s6-17.dat"))

# Base: o clrp_model.jl (um grafo por depósito; carga do depósito mapeada com coeficiente d_j).
# Aqui os "depósitos" do 2º nível são os satélites, e quem os abastece é o 1º nível.
n, t = inst.n, inst.t
c(i, j) = inst.C[i+1, j+1]                      # muda: a matriz inclui o depósito 0
d(i) = inst.d[i]                                # igual: d = 0 nos satélites
# saem W(k), f(k) e F: satélite sem capacidade, sem abertura, sem custo fixo
V⁺ = collect(1:n)
sats = collect(n+1:n+t)                         # muda: satélites no lugar dos depósitos candidatos

# NOVO: 1º nível. Uma rota de caminhão por subconjunto de satélites (máscara r = 1..2^t-1),
# com custo = menor ciclo 0 → satélites de r → 0 (Held-Karp; t ≤ 10 nos benchmarks).
noR(r, s) = (r >> (s - 1)) & 1 == 1             # o s-ésimo satélite está na rota r?
dp = fill(Inf, 2^t - 1, t)
for s in 1:t
    dp[1 << (s - 1), s] = c(0, sats[s])
end
for r in 1:2^t-1, s in 1:t, s2 in 1:t
    noR(r, s) && !noR(r, s2) && (dp[r | 1 << (s2 - 1), s2] = min(dp[r | 1 << (s2 - 1), s2], dp[r, s] + c(sats[s], sats[s2])))
end
c1 = [minimum(dp[r, s] + c(sats[s], 0) for s in 1:t if noR(r, s)) for r in 1:2^t-1]
RS = [(r, s) for r in 1:2^t-1 for s in 1:t if noR(r, s)]   # pares (rota, satélite que ela visita)

ub = 1564.47                                     # toy: 184.3243; Set2a_E-n22-k4-s6-17: 417.08; demais em referencias.csv (BKS + 0.01)

Ecc = [(i, j) for i in V⁺ for j in V⁺ if i < j]     # igual
Edc = [(k, i) for k in sats for i in V⁺]            # igual (satélite-cliente)
E   = vcat(Ecc, Edc)
δ = Dict(i => vcat([e for e in Ecc if i in e], [(k, i) for k in sats]) for i in V⁺)

# ---------- Modelo ----------
function build_model()
    twoe = VrpModel()
    @variable(twoe.formulation, x[e in E] >= 0, Int)
    @variable(twoe.formulation, w[k in sats] >= 0)               # igual ao u[k] do CLRP: carga que sai do satélite k
    @variable(twoe.formulation, z[r in 1:2^t-1] >= 0, Int)       # NOVO: nº de caminhões na rota r (fora dos grafos)
    @variable(twoe.formulation, q[rs in RS] >= 0)                # NOVO: quanto a rota r entrega no satélite s (fracionável)
    @objective(twoe.formulation, Min, sum(c1[r] * z[r] for r in 1:2^t-1) + sum(c(i, j) * x[(i, j)] for (i, j) in E))

    @constraint(twoe.formulation, grau[i in V⁺], sum(x[e] for e in δ[i]) == 2)                    # igual
    @constraint(twoe.formulation, frota1, sum(z[r] for r in 1:2^t-1) <= inst.m1)                  # NOVO: nº de caminhões
    @constraint(twoe.formulation, capcam[r in 1:2^t-1], sum(q[(r, s)] for s in 1:t if noR(r, s)) <= inst.Q1 * z[r])   # NOVO
    @constraint(twoe.formulation, abastece[s in 1:t], sum(q[(r, s)] for r in 1:2^t-1 if noR(r, s)) >= w[sats[s]])     # NOVO
    @constraint(twoe.formulation, frota2, sum(x[e] for e in Edc) <= 2 * inst.m2)                  # NOVO: nº total de city freighters

    graphs = VrpGraph[]
    for k in sats
        Vk = vcat([k], V⁺)
        G = VrpGraph(twoe, Vk, k, k, (0, inst.ms))       # muda: até ms city freighters por satélite

        cap = add_resource!(G, main = true)              # igual, com Q2
        for i in Vk
            set_resource_bounds!(G, i, cap, 0.0, inst.Q2)
        end

        function arco!(i, j, e)                          # igual ao CLRP: entrar em j soma d_j em w[k]
            a = add_arc!(G, i, j)
            add_arc_var_mapping!(G, a, j == k ? [(x[e], 1.0)] : [(x[e], 1.0), (w[k], float(d(j)))])
            set_arc_consumption!(G, a, cap, (d(i) + d(j)) / 2)
        end
        for (i, j) in Ecc
            arco!(i, j, (i, j))
            arco!(j, i, (i, j))
        end
        for i in V⁺
            arco!(k, i, (k, i))
            arco!(i, k, (k, i))
        end
        add_graph!(twoe, G)
        push!(graphs, G)
    end

    PS = [[(G, i) for G in graphs] for i in V⁺]          # igual
    set_vertex_packing_sets!(twoe, PS)
    for G in graphs
        define_elementarity_sets_distance_matrix!(twoe, G, [[c(i, j) for j in V⁺] for i in V⁺])
    end
    add_capacity_cut_separator!(twoe, [(PS[i], float(d(i))) for i in V⁺], float(inst.Q2))   # igual

    set_branching_priority!(twoe, "z", 2)                # muda: primeiro os caminhões (no CLRP era y)
    set_branching_priority!(twoe, "x", 1)
    return (twoe, x, z, q, graphs)
end

# ---------- Resolução ----------
(model, x, z, q, graphs) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for r in 1:2^t-1
        nz = round(Int, get_value(optimizer, z[r]))
        nz > 0 || continue
        entregas = join(["$(sats[s]): $(round(get_value(optimizer, q[(r, s)]), digits = 2))" for s in 1:t if noR(r, s)], ", ")
        println("caminhão ×$nz: 0 - {", join(sats[[s for s in 1:t if noR(r, s)]], ", "), "} - 0   custo ", round(c1[r], digits = 2), "   entrega ", entregas)
    end
    carga = Dict(k => 0 for k in sats)
    atendidos = Int[]
    for p in 1:get_number_of_positive_paths(optimizer)
        (G, arcs) = get_path_arcs(optimizer, p)
        k = sats[findfirst(g -> g === G, graphs)]
        rota = [k; [a.head in 2:n+1 ? a.head - 1 : k for a in arcs]]   # igual ao CLRP: a volta cai num sink interno
        clientes = rota[2:end-1]
        carga[k] += sum(d.(clientes))
        append!(atendidos, clientes)
        custo = sum(c(rota[s], rota[s+1]) for s in 1:length(rota)-1)
        println("satélite $k: ", join(rota, " - "), "   custo ", round(custo, digits = 2), "  carga $(sum(d.(clientes)))/$(inst.Q2)")
    end
    recebido = Dict(sats[s] => sum(get_value(optimizer, q[(r, s)]) for r in 1:2^t-1 if noR(r, s)) for s in 1:t)
    ok = sort(atendidos) == V⁺ && all(recebido[k] >= carga[k] - 1e-6 for k in sats)
    println(ok ? "OK: cada cliente atendido uma vez e cada satélite recebe o que entrega" : "ERRO na solução")
end
