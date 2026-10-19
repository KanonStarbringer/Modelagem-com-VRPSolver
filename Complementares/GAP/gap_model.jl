using VrpSolver, JuMP
include(joinpath(@__DIR__, "gap_parser.jl"))       # muda: parser do GAP
inst = read_gap(joinpath(@__DIR__, "Instancias", "d05200"))  # benchmark: read_gap(joinpath(@__DIR__, "toy_gap.txt")) read_gap(joinpath(@__DIR__, "Instancias", "c05100"))

m = inst.m                                          # NOVO: nº de agentes (um grafo por agente)
n = inst.n                                          # igual: nº de tarefas (itens no BPP)
I = 1:m                                             # NOVO
J = 1:n                                             # igual (T no BPP)
c(i, j) = inst.c[i, j]                              # NOVO: custo da tarefa j no agente i
r(i, j) = inst.r[i, j]                              # muda: consumo depende do agente (w(t) no BPP)
b(i) = inst.b[i]                                    # muda: capacidade de cada agente (Q no BPP)

V = collect(0:n)                                    # igual: v_0..v_n, em cada grafo

ub = 12744.01                                          # toy: 32; demais em referencias_cplex.csv (ótimo + 0.01)

# -------------------- build_model -------------------------------------------------------

function build_model()
    gap = VrpModel()
    @variable(gap.formulation, x[i in I, j in J] >= 0, Int)          # muda: x por (agente, tarefa); sai x[0]
    @objective(gap.formulation, Min, sum(c(i, j) * x[i, j] for i in I, j in J))   # muda: custo (no BPP: nº de bins)
    @constraint(gap.formulation, tarefa[j in J], sum(x[i, j] for i in I) == 1)   # muda: soma sobre os agentes

    P = [Tuple{VrpGraph,Int}[] for j in J]                           # muda: um packing set por tarefa, juntando os grafos
    for i in I
        # 1. Grafo do agente i: igual ao do BPP, mas U = 1 (uma só mochila por agente)
        G = VrpGraph(gap, V, 0, n, (0, 1))                           # muda: (0, 1) no lugar de (0, n)

        # 3. Recurso: capacidade b_i do agente
        cap = add_resource!(G, main = true)
        for v in V
            set_resource_bounds!(G, v, cap, 0.0, b(i))               # muda: b(i) no lugar de Q
        end

        # 2. Arcos: dois paralelos entre v_{j-1} e v_j (igual)
        for j in J
            a⁺ = add_arc!(G, j - 1, j)                               # tarefa j no agente i
            set_arc_consumption!(G, a⁺, cap, r(i, j))
            add_arc_var_mapping!(G, a⁺, x[i, j])                     # muda: só x[i, j] (sai o x[0] do item 1)
            push!(P[j], (G, a⁺))                                     # muda: arco entra no packing set da tarefa j

            a⁻ = add_arc!(G, j - 1, j)                               # tarefa j fora do agente i
            set_arc_consumption!(G, a⁻, cap, 0.0)                    # sem mapeamento
        end
        add_graph!(gap, G)
    end

    # 4. Packing sets em arcos: P_j = {a⁺_{1j}, ..., a⁺_{mj}}, atravessando os m grafos
    set_arc_packing_sets!(gap, P)
    # muda: sai enable_packset_ryanfoster_branching!. Com U = 1, x inteiro já fixa a coluna de cada agente
    set_branching_priority!(gap, "x", 1)                             # NOVO
    return (gap, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    usadas = Int[]
    for i in I                                                       # muda: por agente, não por caminho
        tarefas = [j for j in J if get_value(optimizer, x[i, j]) > 0.5]
        append!(usadas, tarefas)
        carga = sum(r(i, j) for j in tarefas; init = 0)
        println("agente $i: tarefas ", tarefas, "  custo ", sum(c(i, j) for j in tarefas; init = 0),
                "  consumo ", carga, "/", b(i), carga <= b(i) ? "" : "  ← ESTOURO")
    end
    println(sort(usadas) == collect(J) ? "OK: cada tarefa em exatamente um agente" : "ERRO: tarefas repetidas ou faltando")
end
