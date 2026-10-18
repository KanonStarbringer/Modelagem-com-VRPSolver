using VrpSolver, JuMP
include(joinpath(@__DIR__, "ophs_parser.jl"))                # muda: parser do OPHS
include(joinpath(@__DIR__, "..", "TSPHS", "mincut.jl"))      # muda: reaproveita o mincut do TSPHS
inst = read_ophs(joinpath(@__DIR__, "Instancias", "SET_2-3_TSP", "eil51-H4-T3-S3.ophs"))        # benchmark: read_ophs(joinpath(@__DIR__, "toy_ophs.ophs")) 
inst.uniforme || error("T diferente por trip: o modelo da aula não vale")   # NOVO

H = inst.H                                      # hotéis 1..h
C = inst.C                                      # clientes h+1..N
N = length(inst.w)                              # muda: o parser não devolve N
ini, fim = inst.ini, inst.fim                   # NOVO: hotel inicial (1) e final (m = 2)
Hm = setdiff(H, [ini, fim])                     # NOVO: hotéis intermediários
T = inst.T                                      # duração máxima de cada trip
U = inst.U                                      # NOVO: duração máxima do tour inteiro
D = inst.D                                      # muda: nº de trips vem da instância (era K, à mão)

t(i, j) = inst.t[i, j]                          # muda: distância REAL (sem truncar)
w(j) = inst.w[j]                                # NOVO: lucro (sai s: não há tempo de serviço)

src, snk = 0, N + length(H) + 1                 # igual
h̄(h) = N + h                                    # igual: cópia de chegada do hotel h
V = vcat(src, collect(1:N), [h̄(h) for h in H], snk)

ub = −2469.99                                     # muda: NEGATIVO (−lucro). toy: 55; eil51-H4-T3-S3: −2469.99 -54.99 

E = [(i, j) for i in 1:N for j in i+1:N]        # igual
δ(v) = [e for e in E if v in e]

# ---------- Modelo ----------
function build_model()
    ophs = VrpModel()
    @variable(ophs.formulation, x[e in E] >= 0, Int)
    @variable(ophs.formulation, 0 <= y[h in H] <= D, Int)
    @variable(ophs.formulation, 0 <= g[j in C] <= 1, Int)                  # NOVO: cliente j visitado (não mapeada)
    @objective(ophs.formulation, Min, -sum(w(j) * g[j] for j in C))         # muda: −lucro (o VRPSolver minimiza)

    @constraint(ophs.formulation, grauC[j in C], sum(x[e] for e in δ(j)) == 2g[j])            # (3b) muda: visita opcional
    @constraint(ophs.formulation, grauH[h in Hm], sum(x[e] for e in δ(h)) == 2y[h])           # (3c) muda: só os intermediários
    @constraint(ophs.formulation, grauIF[h in [ini, fim]], sum(x[e] for e in δ(h)) == 2y[h] - 1)   # (3d) NOVO: grau ímpar
    @constraint(ophs.formulation, y[fim] >= 1)                                                 # (3e) muda: y_m (era y_1)
    @constraint(ophs.formulation, sum(t(i, j) * x[(i, j)] for (i, j) in E) <= U)               # (3f) NOVO: duração total

    G = VrpGraph(ophs, V, src, snk, (D, D))             # muda: D trips
    tempo = add_resource!(G, main = true)
    for v in V
        set_resource_bounds!(G, v, tempo, 0.0, T)
    end

    for h in H                                          # igual
        a = add_arc!(G, src, h);   set_arc_consumption!(G, a, tempo, 0.0)
        a = add_arc!(G, h̄(h), snk); set_arc_consumption!(G, a, tempo, 0.0)
    end
    for (i, j) in E                                     # muda: sem serviço, os 3 casos viram um só
        for (o, d) in ((i, j), (j, i))
            a = add_arc!(G, o, d in H ? h̄(d) : d)       # chegada num hotel vai para a cópia h̄
            add_arc_var_mapping!(G, a, x[(i, j)])
            set_arc_consumption!(G, a, tempo, t(o, d))
        end
    end
    add_graph!(ophs, G)

    set_vertex_packing_sets!(ophs, [[(G, j)] for j in C])
    define_elementarity_sets_distance_matrix!(ophs, G, [[t(i, j) for j in C] for i in C])

    set_branching_priority!(ophs, "x", 1)
    set_branching_priority!(ophs, "y", 1)
    set_branching_priority!(ophs, "g", 1)                                  # NOVO

    # (3h) e (3i): S contém {1, m}
    function conectividade()
        cap = zeros(N, N)
        for (i, j) in E
            cap[i, j] = cap[j, i] = get_value(ophs.optimizer, x[(i, j)])
        end
        cap[ini, fim] = cap[fim, ini] = Inf                                # NOVO: "cola" 1 e m
        vistos = Set{Vector{Int}}()
        for k in vcat(C, Hm)                                               # muda: Hm (era H \ {1})
            fl, S = mincut(cap, ini, k)
            δS = [e for e in E if (e[1] in S) != (e[2] in S)]
            if k in C
                fl < 2get_value(ophs.optimizer, g[k]) - 1e-4 && S ∉ vistos || continue
                add_dynamic_constr!(ophs.optimizer, [[x[e] for e in δS]; g[k]],
                                    [ones(length(δS)); -2.0], >=, 0.0, "conect")                 # (3h) muda: ≥ 2g_j
            else
                D > 1 && fl < 2get_value(ophs.optimizer, y[k]) / (D - 1) - 1e-4 || continue
                add_dynamic_constr!(ophs.optimizer, [[x[e] for e in δS]; y[k]],
                                    [ones(length(δS)); -2 / (D - 1)], >=, 0.0, "conect")         # (3i)
            end
            push!(vistos, S)
        end
    end
    add_cut_callback!(ophs, conectividade, "conect")

    return (ophs, x, y, g)
end

# ---------- Resolução ----------
(model, x, y, g) = build_model()

optimizer = VrpOptimizer(model, "OPHS.cfg", inst.name)                    # muda: OPHS.cfg
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Lucro ótimo: ", -get_objective_value(optimizer))              # muda: troca o sinal
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
    for h in H
        get_value(optimizer, y[h]) > 0.5 && println("y[$h] = ", round(get_value(optimizer, y[h])))
    end
    println("Visitados: ", [j for j in C if get_value(optimizer, g[j]) > 0.5])   # NOVO
end