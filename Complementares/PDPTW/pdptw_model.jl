using VrpSolver, JuMP
include(joinpath(@__DIR__, "pdptw_parser.jl"))  # muda: parser do PDPTW
inst = read_pdptw(joinpath(@__DIR__, "Instancias", "lc101.txt"); r = 20)    # benchmark: read_pdptw(joinpath(@__DIR__, "toy_pdptw.txt")) 

r = inst.r                                      # NOVO: nº de requisições
n = 2r                                          # muda: n = coletas + entregas
Q = inst.Q                                      # muda: volta a ser um número (frota homogênea)
K = inst.K                                      # muda: K = tamanho da frota (sai o conjunto de tipos, f, α, u)

c(i, j) = inst.C[i + 1, j + 1]                  # muda: custo único
t(i, j) = inst.T[i + 1, j + 1]                  # NOVO: tempo do arco i→j = s_i + c_ij (assimétrico)
q̄(i) = inst.q[i + 1]                            # NOVO: demanda ASSINADA (+q na coleta, −q na entrega)
l(i) = inst.l[i + 1]                            # NOVO: janela
u(i) = inst.u[i + 1]

V  = collect(0:n)
Pk = collect(1:r)                               # NOVO: coletas
Dl = collect(r+1:n)                             # NOVO: entregas (entrega de h = h + r)
par(h) = h + r                                  # NOVO: entrega da coleta h

ub = 301.89                                     # toy; lc101 r=10: 155.51

# muda: ARCOS dirigidos (sai E/δ de arestas); corta arcos inúteis
A = [(i, j) for i in V for j in V if i != j &&
        !(i == 0 && j in Dl) &&                 # depósito → entrega: nunca (a coleta vem antes)
        !(i in Pk && j == 0) &&                 # coleta → depósito: nunca (falta entregar)
        !(i in Dl && j == i - r) &&             # entrega h+r → coleta h: nunca
        l(i) + t(i, j) <= u(j)]                 # janela: chegar a tempo é possível
δ⁻ = Dict(j => [a for a in A if a[2] == j] for j in Pk)   # NOVO: arcos que entram nas COLETAS

# ---------- Modelo ----------
function build_model()
    pdp = VrpModel()
    @variable(pdp.formulation, x[a in A] >= 0, Int)                         # muda: por ARCO (sai o tipo k e o z)
    @objective(pdp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A))   # muda: sem custo fixo

    @constraint(pdp.formulation, cob[h in Pk], sum(x[a] for a in δ⁻[h]) == 1)    # muda: cobre só as COLETAS

    # 1. Grafo: volta a ser um só
    G = VrpGraph(pdp, V, 0, 0, (0, K))

    # 3. Recursos
    time = add_resource!(G, main = true)                         # tempo: principal, descartável (permite espera)
    cap  = add_resource!(G, disposable = false)                  # NOVO: carga, secundária (tem consumo negativo)
    req  = [add_resource!(G, binary = true, disposable = false) for h in Pk]   # NOVO: um por requisição
    for i in V
        set_resource_bounds!(G, i, time, l(i), u(i))
        set_resource_bounds!(G, i, cap, 0.0, i == 0 ? 0.0 : Q)   # muda: depósito [0,0] (não descartável exige ponto no source)
    end
    for h in Pk
        set_resource_bounds!(G, 0, req[h], 0.0, 0.0)             # NOVO: depósito [0,0] (nos clientes já é [0,1])
    end

    # 2. Arcos
    for (i, j) in A
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[(i, j)])
        set_arc_consumption!(G, a, time, t(i, j))
        set_arc_consumption!(G, a, cap, j == 0 ? 0.0 : q̄(j))    # +q na coleta, −q na entrega
        j in Pk && set_arc_consumption!(G, a, req[j], 1.0)       # NOVO: entra na coleta h → estado 1
        j in Dl && set_arc_consumption!(G, a, req[j - r], -1.0)  # NOVO: entra na entrega h+r → estado 0
    end
    add_graph!(pdp, G)

    # 4. Packing sets: SÓ as coletas
    set_vertex_packing_sets!(pdp, [[(G, h)] for h in Pk])
    define_elementarity_sets_distance_matrix!(pdp, G,
        [[c(h, g) for g in Pk] for h in Pk])

    set_branching_priority!(pdp, "x", 1)
    return (pdp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_pdptw")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for a in A
        get_value(optimizer, x[a]) > 0.5 && println("x[$a] = ", round(get_value(optimizer, x[a])))
    end
end