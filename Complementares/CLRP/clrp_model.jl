using VrpSolver, JuMP
include(joinpath(@__DIR__, "clrp_parser.jl"))     # muda: parser do CLRP (formato de Prodhon)
inst = read_clrp(joinpath(@__DIR__, "Instancias", "Barreto", "coordGaspelle.dat"))   # benchmark: read_clrp(joinpath(@__DIR__, "Instancias", "Prodhon", "coord20-5-1.dat"))

# Base: o mdvrp_model.jl (um grafo por depósito, clientes compartilhados)
n, Q = inst.n, inst.Q
c(i, j) = inst.C[i, j]                          # igual ao MDVRP: clientes 1..n, depósitos n+1..n+t
d(i) = inst.d[i]                                # igual: d = 0 nos depósitos
W(k) = inst.W[k-n]                              # NOVO: capacidade do depósito k
f(k) = inst.f[k-n]                              # NOVO: custo de abertura do depósito k
F = inst.F                                      # NOVO: custo fixo por rota (veículo)

V⁺ = collect(1:n)                               # clientes
depots = collect(n+1:n+inst.t)                  # depósitos CANDIDATOS

ub = 425.0                                   # toy: 21386.01; Prodhon coord20-5-1: 54793.01; demais em referencias.csv

Ecc = [(i, j) for i in V⁺ for j in V⁺ if i < j]     # igual: cliente-cliente
Edc = [(k, i) for k in depots for i in V⁺]          # igual: depósito-cliente
E   = vcat(Ecc, Edc)

δ = Dict(i => vcat([e for e in Ecc if i in e], [(k, i) for k in depots]) for i in V⁺)   # igual

# ---------- Modelo ----------
function build_model()
    clrp = VrpModel()
    @variable(clrp.formulation, x[e in E] >= 0, Int)
    @variable(clrp.formulation, 0 <= y[k in depots] <= 1, Int)  # NOVO: depósito k aberto (fora dos grafos)
    @variable(clrp.formulation, u[k in depots] >= 0)            # NOVO: carga total atendida a partir de k
    # muda: + abertura dos depósitos; cada rota usa 2 arestas do depósito, então F/2 em cada uma
    @objective(clrp.formulation, Min, sum(f(k) * y[k] for k in depots)
                                      + sum(c(i, j) * x[(i, j)] for (i, j) in Ecc)
                                      + sum((c(k, i) + F / 2) * x[(k, i)] for (k, i) in Edc))

    @constraint(clrp.formulation, grau[i in V⁺], sum(x[e] for e in δ[i]) == 2)        # igual
    @constraint(clrp.formulation, capdep[k in depots], u[k] <= W(k) * y[k])           # NOVO: capacidade do depósito
    @constraint(clrp.formulation, liga[(k, i) in Edc], x[(k, i)] <= 2 * y[k])         # NOVO: só sai de depósito aberto

    graphs = VrpGraph[]
    for k in depots
        Vk = vcat([k], V⁺)
        G = VrpGraph(clrp, Vk, k, k, (0, n))             # muda: frota livre (o custo F limita)

        cap = add_resource!(G, main = true)              # igual
        for i in Vk
            set_resource_bounds!(G, i, cap, 0.0, Q)
        end

        function arco!(i, j, e)
            a = add_arc!(G, i, j)
            # NOVO: ao ENTRAR no cliente j, soma d_j em u[k]; é assim que o mestre "vê" a carga do depósito
            add_arc_var_mapping!(G, a, j == k ? [(x[e], 1.0)] : [(x[e], 1.0), (u[k], float(d(j)))])
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
        add_graph!(clrp, G)
        push!(graphs, G)
    end

    PS = [[(G, i) for G in graphs] for i in V⁺]          # igual
    set_vertex_packing_sets!(clrp, PS)
    for G in graphs
        define_elementarity_sets_distance_matrix!(clrp, G, [[float(c(i, j)) for j in V⁺] for i in V⁺])
    end
    add_capacity_cut_separator!(clrp, [(PS[i], float(d(i))) for i in V⁺], float(Q))   # NOVO: RCC

    set_branching_priority!(clrp, "y", 2)                # NOVO: primeiro decide os depósitos
    set_branching_priority!(clrp, "x", 1)
    return (clrp, x, y, graphs)
end

# ---------- Resolução ----------
(model, x, y, graphs) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
# NOVO: rotas lidas dos caminhos; no grafo de k, o vértice interno i+1 é o cliente i
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    abertos = [k for k in depots if get_value(optimizer, y[k]) > 0.5]
    carga = Dict(k => 0 for k in depots)
    atendidos = Int[]
    for p in 1:get_number_of_positive_paths(optimizer)
        (G, arcs) = get_path_arcs(optimizer, p)
        k = depots[findfirst(g -> g === G, graphs)]
        rota = [k; [a.head in 2:n+1 ? a.head - 1 : k for a in arcs]]   # a volta ao depósito cai num sink interno
        clientes = rota[2:end-1]
        carga[k] += sum(d.(clientes))
        append!(atendidos, clientes)
        custo = sum(c(rota[s], rota[s+1]) for s in 1:length(rota)-1)
        println("depósito $k: ", join(rota, " - "), "   custo $custo + F  carga $(sum(d.(clientes)))/$Q")
    end
    for k in abertos
        println("depósito $k aberto: abertura $(f(k))  carga $(carga[k])/$(W(k))")
    end
    ok = sort(atendidos) == V⁺ && all(carga[k] <= W(k) for k in depots) && all(carga[k] == 0 for k in depots if !(k in abertos))
    println(ok ? "OK: cada cliente atendido uma vez, só por depósitos abertos e dentro da capacidade" : "ERRO na solução")
end
