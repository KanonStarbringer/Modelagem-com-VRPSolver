using VrpSolver, JuMP
include(joinpath(@__DIR__, "vrptwmd_parser.jl"))   # muda: parser do VRPTWMD-2R (gera os padrões)
inst = read_vrptwmd(joinpath(@__DIR__, "Instancias", "Solomon_10_40", "RC101_10_40.txt"))   # benchmark: read_vrptwmd(joinpath(@__DIR__, "Instancias", "Solomon_10_40", "C101_10_40.txt"))

# Base: o vrptw_model.jl (recurso de tempo com janela nos vértices). Aqui o veículo visita parkings,
# e o tempo parado em cada um vem de um padrão (rotas a pé enumeradas no parser): chegando em s,
# o veículo sai em max(s + Δ, E), e o padrão só vale se s ≤ L. Um grafo por nº de entregadores l.
n, ML = inst.n, inst.ML
fv, cv, fd, cd = inst.custos
d1(i, j) = inst.d1[i+1, j+1]                    # veículo: distância = tempo (0 = depósito)
a(i) = inst.a[i+1]                              # igual: janela do vértice (aqui, chegada ao parking)
b(i) = inst.b[i+1]
q(i) = inst.q[i]                                # demanda do cluster = soma dos seus clientes
P = inst.P                                      # NOVO: P[l] = padrões não dominados com até l entregadores

ub = 10022.01                                    # toy: 2918.01; demais em referencias.csv (UB + 0.01)

A = vcat([(0, j) for j in 1:n], [(i, j) for i in 1:n for j in 1:n if i != j], [(i, 0) for i in 1:n])
custo(l, i, j) = (i == 0 ? fv + l * fd : 0) + cv * d1(i, j)   # NOVO: veículo e seus l entregadores pagos na saída

# Vértices de G_l: 0 = depósito; i = chegada ao parking i; n+i = saída do parking i;
# 2n+2k-1 e 2n+2k = início e fim do k-ésimo padrão de P[l]
sai(i) = n + i
ini(k) = 2n + 2k - 1
fim(k) = 2n + 2k

# ---------- Modelo ----------
function build_model()
    md = VrpModel()
    @variable(md.formulation, x[l in 1:ML, e in A] >= 0, Int)                   # arco do veículo com l entregadores
    @variable(md.formulation, y[l in 1:ML, k in 1:length(P[l])] >= 0, Int)      # NOVO: padrão k de P[l]
    @objective(md.formulation, Min,
        sum(custo(l, i, j) * x[l, (i, j)] for l in 1:ML for (i, j) in A) +
        sum(cd * P[l][k].dist * y[l, k] for l in 1:ML for k in 1:length(P[l])))

    @constraint(md.formulation, visita[i in 1:n], sum(x[l, (j, i)] for l in 1:ML for j in 0:n if j != i) == 1)
    @constraint(md.formulation, frota, sum(x[l, (0, j)] for l in 1:ML for j in 1:n) <= inst.K)

    graphs = VrpGraph[]
    for l in 1:ML
        V = collect(0:2n+2length(P[l]))
        G = VrpGraph(md, V, 0, 0, (0, inst.K))

        cap  = add_resource!(G, main = true)
        time = add_resource!(G, main = true)
        for v in V
            set_resource_bounds!(G, v, cap, 0, inst.Q)
            set_resource_bounds!(G, v, time, 0, b(0))
        end
        for i in 1:n
            set_resource_bounds!(G, i, time, a(i), b(i))          # chegada ao parking dentro da janela
        end
        for (k, p) in enumerate(P[l])
            set_resource_bounds!(G, ini(k), time, a(p.i), p.L)    # NOVO: o padrão exige chegada até L
            set_resource_bounds!(G, fim(k), time, p.E, b(0))      # NOVO: espera até E (cliente que abre tarde)
        end

        for (i, j) in A                                           # o veículo anda de saída em chegada
            arc = add_arc!(G, i == 0 ? 0 : sai(i), j, x[l, (i, j)])
            set_arc_consumption!(G, arc, time, d1(i, j))
            set_arc_consumption!(G, arc, cap, j == 0 ? 0 : q(j))
        end
        for (k, p) in enumerate(P[l])                             # NOVO: i → início → fim → saída de i
            add_arc!(G, p.i, ini(k))
            arc = add_arc!(G, ini(k), fim(k), y[l, k])
            set_arc_consumption!(G, arc, time, p.Δ)               # com a janela de fim(k): max(s + Δ, E)
            add_arc!(G, fim(k), sai(p.i))
        end
        add_graph!(md, G)
        push!(graphs, G)
    end

    set_vertex_packing_sets!(md, [[(G, i) for G in graphs] for i in 1:n])   # muda: o parking em todos os G_l
    for G in graphs
        define_elementarity_sets_distance_matrix!(md, G, [[float(d1(i, j)) for j in 1:n] for i in 1:n])
    end
    set_branching_priority!(md, "x", 2)
    set_branching_priority!(md, "y", 1)
    return (md, x, y, graphs)
end

# ---------- Resolução ----------
(model, x, y, graphs) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    visitados, custos_rotas = Int[], Int[]     # vetores: o for não reatribui globais (lição do CSP)
    for pth in 1:get_number_of_positive_paths(optimizer)
        λ = get_value(optimizer, pth)
        (G, arcs) = get_path_arcs(optimizer, pth)
        l = findfirst(g -> g === G, graphs)
        uid(v) = G.vertices[v].user_id
        ks = [(uid(e.tail) - 2n + 1) ÷ 2 for e in arcs if uid(e.tail) > 2n && uid(e.head) == uid(e.tail) + 1]
        println("veículo com $l entregador(es)", λ > 1 ? " ×$λ" : "", ":")
        t, prev, dv, dp = 0, 0, 0, 0
        for k in ks
            p = P[l][k]
            chega = max(t + d1(prev, p.i), a(p.i))
            t = max(chega + p.Δ, p.E)
            println("  parking $(p.i): chega $chega, sai $t   a pé: ",
                    join(["P$(p.i) - " * join(r, " - ") * " - P$(p.i)" for r in p.rotas], " | "))
            dv += d1(prev, p.i); dp += p.dist; prev = p.i
            push!(visitados, p.i)
        end
        dv += d1(prev, 0)
        c = fv + l * fd + cv * dv + cd * dp
        println("  volta ao depósito em $(t + d1(prev, 0))   dist. veículo $dv, a pé $dp, custo $c")
        push!(custos_rotas, λ * c)
    end
    ok = sort(visitados) == collect(1:n) && sum(custos_rotas) == round(Int, get_objective_value(optimizer))
    println(ok ? "OK: cada cluster visitado uma vez e custo conferido ($(sum(custos_rotas)))" : "ERRO na solução")
end
