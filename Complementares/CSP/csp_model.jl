using VrpSolver, JuMP
include(joinpath(@__DIR__, "csp_parser.jl"))       # muda: parser do CSP
inst = read_csp(joinpath(@__DIR__, "Instancias", "Hard28", "Hard28_BPP14.txt"))  # benchmark: read_csp(joinpath(@__DIR__, "toy_csp.txt")) 

m = inst.m                                          # NOVO: nº de TIPOS de item
n = inst.n                                          # nº total de peças (Σ d_t): só limita U
T = 1:m                                             # muda: tipos, não itens
Q = inst.Q                                          # igual: largura do rolo
w(t) = inst.w[t]                                    # igual: largura do tipo t
d(t) = inst.d[t]                                    # NOVO: demanda do tipo t

V = collect(0:Q)                                    # muda: um vértice por CARGA acumulada 0..Q (no BPP: um por item)

# NOVO: arcos de item (l, l + w_t), um para cada posição l onde a peça t ainda cabe
Y = [(l, t) for t in T for l in 0:(Q - w(t))]

ub = 62.01                                            # toy: 5 5.01; u120_00: 48.01; u1000_00: 399.01; t60_00: 20.01

# -------------------- build_model -------------------------------------------------------

function build_model()
    csp = VrpModel()
    @variable(csp.formulation, y[e in Y] >= 0, Int)                  # muda: y por ARCO (sai x[0..n]); Int obrigatório, como no BPP
    @objective(csp.formulation, Min, sum(y[(0, t)] for t in T))      # muda: nº de rolos = arcos de item que saem de 0 (sai x[0])
    @constraint(csp.formulation, demanda[t in T],
                sum(y[(l, s)] for (l, s) in Y if s == t) >= d(t))    # muda: ≥ d_t (no BPP: x[t] == 1)

    # 1. Grafo: source 0, sink Q (no BPP: source v_0, sink v_n), de 0 a n rolos
    G = VrpGraph(csp, V, 0, Q, (0, n))                               # muda: sink = Q

    # 3. Recurso: capacidade do rolo (igual)
    cap = add_resource!(G, main = true)
    for v in V
        set_resource_bounds!(G, v, cap, 0.0, Q)
    end

    # 2. Arcos
    for (l, t) in Y
        a = add_arc!(G, l, l + w(t))                                 # muda: corta uma peça t na posição l
        set_arc_consumption!(G, a, cap, w(t))
        add_arc_var_mapping!(G, a, y[(l, t)])                        # muda: cada arco tem sua própria variável
    end
    for l in 1:(Q - 1)
        a = add_arc!(G, l, Q)                                        # NOVO: fecha o rolo; o resto é perda
        set_arc_consumption!(G, a, cap, 0.0)                         #       sem mapeamento (sem eles: 6 na toy)
    end                                                              # sem (0, Q): seria o rolo vazio
    add_graph!(csp, G)

    # 4. Sai set_arc_packing_sets!: o tipo t aparece d_t vezes, então {arcos de t} NÃO é packing set
    # Sai enable_packset_ryanfoster_branching!: sem packing sets não há Ryan-Foster.
    #     Não faz falta: y inteiro = fluxo inteiro no DAG, que se decompõe em padrões viáveis
    set_branching_priority!(csp, "y", 1)                             # NOVO: branching nas variáveis de arco
    return (csp, y)
end

# ---------- Resolução ----------
(model, y) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
# muda: get_value(optimizer, y) e get_objective_value IGNORAM a multiplicidade do caminho (λ):
# somam cada caminho uma vez só (VrpSolver.jl, _get_value). No BPP os packing sets forçam λ = 1;
# no CSP o mesmo padrão pode sair com λ = 2, 3, ... Por isso tudo é lido por caminho × multiplicidade.
if solution_found
    feitos = zeros(Int, m)
    for p in 1:get_number_of_positive_paths(optimizer)
        λ = get_value(optimizer, p)                                  # nº de rolos com este padrão
        pecas = [t for (l, t) in Y if get_value(optimizer, y[(l, t)], p) > 0.5]
        for t in pecas
            feitos[t] += λ
        end
        println("padrão $p (×$λ): tipos ", pecas, "  larguras ", w.(pecas), "  carga ", sum(w.(pecas)), "/", Q)
    end
    println("Nº de rolos: ", sum(get_value(optimizer, p) for p in 1:get_number_of_positive_paths(optimizer)))
    println("produzido ", feitos, "  demanda ", inst.d)
    println(all(feitos .>= inst.d) ? "OK: todas as demandas atendidas" : "ERRO: demanda não atendida")
end
