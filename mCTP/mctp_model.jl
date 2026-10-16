using VrpSolver, JuMP
include("mctp_parser.jl")

inst = read_mctp(joinpath(@__DIR__, "Instancias", "A1-1-25-75-4-250.ctp"); maxL = 250)

R, p, q = inst.R, inst.p, inst.q                # sai Q; entram p (vértices/rota) e q (comprimento/rota)
c(i, j) = inst.C[i + 1, j + 1]                  # igual (custo = comprimento)
M_ = inst.mand                                  # NOVO: obrigatórios (T \ {0})
O_ = inst.opt                                   # NOVO: opcionais (V \ T)
cover = inst.cover                              # NOVO: cover[k] = opcionais que cobrem o cliente k
K  = 1:inst.nC                                  # NOVO: clientes de W (não são vértices do grafo!)

V  = collect(0:R-1)                             # só vértices roteáveis
V⁺ = collect(1:R-1)

L  = 0                                          # frota livre
U  = R - 1
ub = 12182.01                                      # toy com maxL = 10 (ótimo 84); com maxL = 1000: 71.01

E = [(i, j) for i in V for j in V if i < j]     # todas as arestas (sem clusters)
δ = Dict(i => [e for e in E if i in e] for i in V)
corte(S) = [e for e in E if (e[1] in S) != (e[2] in S)]   # NOVO: arestas que cruzam a fronteira de S

aresta(i, j) = (min(i, j), max(i, j))

# ---------- Modelo ----------
function build_model()
    mctp = VrpModel()
    @variable(mctp.formulation, x[e in E], Int)
    @objective(mctp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))      # igual

    @constraint(mctp.formulation, obrig[i in M_], sum(x[e] for e in δ[i]) == 2)    # T: visita obrigatória
    @constraint(mctp.formulation, opc[i in O_],   sum(x[e] for e in δ[i]) <= 2)    # V\T: visita opcional
    @constraint(mctp.formulation, cob[k in K],
        sum(x[e] for e in corte(cover[k])) >= 2)                                   # W: cobertura

    # 1. Grafo: igual (source = sink = 0)
    G = VrpGraph(mctp, V, 0, 0, (L, U))

    # 3. Recursos: dois, no lugar da capacidade
    nv  = add_resource!(G, main = true)              # nº de vértices na rota
    len = add_resource!(G, main = true)              # comprimento da rota
    for i in V
        set_resource_bounds!(G, i, nv,  0.0, float(p))
        set_resource_bounds!(G, i, len, 0.0, q)
    end

    # 2. Arcos: os dois sentidos de cada aresta
    function arco!(i, j)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[aresta(i, j)])
        set_arc_consumption!(G, a, nv, (i == 0 || j == 0) ? 0.5 : 1.0)   # 0.5 + ... + 0.5 = nº de vértices
        set_arc_consumption!(G, a, len, c(i, j))
    end
    for (i, j) in E
        arco!(i, j)
        arco!(j, i)
    end
    add_graph!(mctp, G)

    # 4. Packing sets: voltam a ser singletons (obrigatórios e
    set_vertex_packing_sets!(mctp, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(mctp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(mctp, "x", 1)
    return (mctp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Visitados: ", [i for i in V⁺ if sum(get_value(optimizer, x[e]) for e in δ[i]) > 0.5])
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end