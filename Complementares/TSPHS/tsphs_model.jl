using VrpSolver, JuMP
include(joinpath(@__DIR__, "tsphs_parser.jl"))  # muda: parser do TSPHS
include(joinpath(@__DIR__, "mincut.jl"))        # NOVO: corte mínimo para o callback de conectividade
inst = read_tsphs(joinpath(@__DIR__, "Instancias", "instancias_c50", "h05_c50_l150_09.txt"))    # benchmark: read_tsphs(joinpath(@__DIR__, "toy_tsphs.txt")) 

H = inst.H                                      # NOVO: hotéis 1..h (1 = início e fim do tour)
C = inst.C                                      # NOVO: clientes h+1..N (saem Lh e Bh)
N = inst.N                                      # muda: vértices 1..N, sem depósito 0
T = inst.T                                      # NOVO: duração máxima de cada trip (sai Q)
K = 9                                           # muda: nº de TRIPS, fixado à mão (toy: 3; h05_c50_l150_09: 9)

t(i, j) = inst.t[i, j]                          # muda: distância truncada em 1 casa, SEM o +1 (sai c)
s(j) = inst.s[j]                                # NOVO: tempo de serviço (sai d)

src, snk = 0, N + length(H) + 1                 # NOVO: source e sink separados (não há depósito)
h̄(h) = N + h                                    # NOVO: cópia de CHEGADA do hotel h
V = vcat(src, collect(1:N), [h̄(h) for h in H], snk)   # NOVO: vértices do grafo ≠ vértices do mestre

ub = 722.21                                      # toy; h05_c50_l150_09: 76.21 

# muda: volta a ARESTAS {i,j}, i < j (sai o A dirigido do VRPB)
E = [(i, j) for i in 1:N for j in i+1:N]        # inclui hotel–hotel (trip vazia, h ≠ h')
δ(v) = [e for e in E if v in e]                 # volta: arestas incidentes (sai δ⁻)

# ---------- Modelo ----------
function build_model()
    tsphs = VrpModel()
    @variable(tsphs.formulation, x[e in E] >= 0, Int)                  # muda: volta a uma variável por ARESTA
    @variable(tsphs.formulation, 0 <= y[h in H] <= K, Int)             # NOVO: nº de usos do hotel h (NÃO mapeada)
    @objective(tsphs.formulation, Min, sum(t(i, j) * x[(i, j)] for (i, j) in E))   # muda: só a viagem (sem s_j)

    @constraint(tsphs.formulation, grauC[j in C], sum(x[e] for e in δ(j)) == 2)       # (1b) muda: grau 2 (arestas)
    @constraint(tsphs.formulation, grauH[h in H], sum(x[e] for e in δ(h)) == 2y[h])   # (1c) NOVO
    @constraint(tsphs.formulation, y[1] >= 1)                                          # (1d) NOVO

    # 1. Grafo: source ≠ sink, exatamente K caminhos (= K trips)
    G = VrpGraph(tsphs, V, src, snk, (K, K))           # muda: src/snk separados

    # 3. Recurso: tempo da trip (sai a capacidade com "salto")
    tempo = add_resource!(G, main = true)
    for v in V
        set_resource_bounds!(G, v, tempo, 0.0, T)      # muda: [0, T] em todos
    end

    # 2. Arcos
    for h in H                                          # NOVO: source → v_h e v̄_h → sink, sem mapeamento
        a = add_arc!(G, src, h);   set_arc_consumption!(G, a, tempo, 0.0)
        a = add_arc!(G, h̄(h), snk); set_arc_consumption!(G, a, tempo, 0.0)
    end
    for (i, j) in E                                     # muda: cada aresta → DOIS arcos com a mesma x
        if j in H                                       # i, j hotéis: trip vazia i → j̄ e j → ī
            a = add_arc!(G, i, h̄(j)); add_arc_var_mapping!(G, a, x[(i, j)]); set_arc_consumption!(G, a, tempo, t(i, j))
            a = add_arc!(G, j, h̄(i)); add_arc_var_mapping!(G, a, x[(i, j)]); set_arc_consumption!(G, a, tempo, t(j, i))
        elseif i in H                                   # hotel i, cliente j: i → j e j → ī
            a = add_arc!(G, i, j);    add_arc_var_mapping!(G, a, x[(i, j)]); set_arc_consumption!(G, a, tempo, t(i, j) + s(j))
            a = add_arc!(G, j, h̄(i)); add_arc_var_mapping!(G, a, x[(i, j)]); set_arc_consumption!(G, a, tempo, t(j, i))
        else                                            # dois clientes: i → j e j → i
            a = add_arc!(G, i, j); add_arc_var_mapping!(G, a, x[(i, j)]); set_arc_consumption!(G, a, tempo, t(i, j) + s(j))
            a = add_arc!(G, j, i); add_arc_var_mapping!(G, a, x[(i, j)]); set_arc_consumption!(G, a, tempo, t(j, i) + s(i))
        end
    end
    add_graph!(tsphs, G)

    # 4. Packing sets: SÓ os clientes (hotéis são revisitáveis)
    set_vertex_packing_sets!(tsphs, [[(G, j)] for j in C])                # muda: C, não V⁺
    define_elementarity_sets_distance_matrix!(tsphs, G, [[t(i, j) for j in C] for i in C])

    set_branching_priority!(tsphs, "x", 1)
    set_branching_priority!(tsphs, "y", 1)                                # NOVO

    # 5. NOVO: cortes de conectividade (1g) e (1h), por corte mínimo a partir do hotel 1
    function conectividade()
        cap = zeros(N, N)
        for (i, j) in E
            cap[i, j] = cap[j, i] = get_value(tsphs.optimizer, x[(i, j)])
        end
        vistos = Set{Vector{Int}}()
        for k in vcat(C, H[2:end])
            fl, S = mincut(cap, 1, k)
            δS = [e for e in E if (e[1] in S) != (e[2] in S)]
            if k in C
                fl < 2 - 1e-4 && S ∉ vistos || continue
                add_dynamic_constr!(tsphs.optimizer, [x[e] for e in δS], ones(length(δS)), >=, 2.0, "conect")   # (1g)
            else
                K > 1 && fl < 2get_value(tsphs.optimizer, y[k]) / (K - 1) - 1e-4 || continue
                add_dynamic_constr!(tsphs.optimizer, [[x[e] for e in δS]; y[k]],
                                    [ones(length(δS)); -2 / (K - 1)], >=, 0.0, "conect")                          # (1h)
            end
            push!(vistos, S)
        end
    end
    add_cut_callback!(tsphs, conectividade, "conect")

    return (tsphs, x, y)
end

# ---------- Resolução ----------
(model, x, y) = build_model()

optimizer = VrpOptimizer(model, "TSPHS.cfg", inst.name)                 # muda: TSPHS.cfg
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
    for h in H
        get_value(optimizer, y[h]) > 0.5 && println("y[$h] = ", round(get_value(optimizer, y[h])))
    end
end