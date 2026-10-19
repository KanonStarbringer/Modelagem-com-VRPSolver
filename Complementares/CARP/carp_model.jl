using VrpSolver, JuMP
include(joinpath(@__DIR__, "carp_parser.jl"))      # muda: parser do CARP
inst = read_carp(joinpath(@__DIR__, "Instancias", "egl-e1-C.dat"))  # benchmark: read_carp(joinpath(@__DIR__, "Instancias", "gdb1.dat"))

R = inst.R                                          # NOVO: arestas requeridas (u, v, custo, demanda)
nR = length(R)
Q = inst.Q                                          # igual ao CVRP: capacidade do veículo
sp(i, j) = inst.sp[i+1, j+1]                        # NOVO: caminho mínimo no grafo original (deadheading)

# NOVO: vértice do grafo de pricing = ESTADO "acabei de atender a aresta e no sentido o"
#   o = 0: atendida de u para v (termina em v);  o = 1: de v para u (termina em u)
st(e, o) = 2(e - 1) + o + 1                         # ids 1..2nR; o depósito é o 0
ini(e, o) = o == 0 ? R[e][1] : R[e][2]              # nó onde o atendimento começa
fim(e, o) = o == 0 ? R[e][2] : R[e][1]              # nó onde termina
c(e) = R[e][3]
d(e) = R[e][4]

V = vcat([0], [st(e, o) for e in 1:nR for o in 0:1])

# NOVO: cada arco = deadheading (caminho mínimo) de p até q + atendimento de uma aresta a partir de q
origens = vcat([(0, 0)], [(st(e, o), fim(e, o)) for e in 1:nR for o in 0:1])   # (vértice, nó físico onde estou)
Y = unique([(p, q) for (s, p) in origens for q in vcat([ini(f, o) for f in 1:nR for o in 0:1], 0) if p != q])

ub = 5595.01                                          # toy: 52; gdb1: 316.01; demais em referencias.csv (ub + 0.01)

# -------------------- build_model -------------------------------------------------------

function build_model()
    carp = VrpModel()
    @variable(carp.formulation, x[e in 1:nR] >= 0, Int)              # NOVO: atendimento da aresta e
    @variable(carp.formulation, y[a in Y] >= 0, Int)                 # NOVO: deadheading de p a q (caminho mínimo)
    # NOVO: saída do depósito para a aresta e / volta da aresta e ao depósito, custo zero.
    #   Só servem ao RCC: ele exige, em cada arco ligado ao depósito, exatamente uma variável
    #   mapeada apenas em arcos entre o depósito e aquele packing set (x e y são compartilhados).
    @variable(carp.formulation, sai[e in 1:nR] >= 0, Int)
    @variable(carp.formulation, volta[e in 1:nR] >= 0, Int)
    @objective(carp.formulation, Min, sum(c(e) * x[e] for e in 1:nR) + sum(sp(p, q) * y[(p, q)] for (p, q) in Y))
    @constraint(carp.formulation, atende[e in 1:nR], x[e] == 1)      # cada aresta requerida atendida uma vez

    # 1. Grafo: source = sink = depósito; frota livre (até uma rota por aresta)
    G = VrpGraph(carp, V, 0, 0, (0, nR))

    # 3. Recurso: capacidade (igual ao CVRP)
    cap = add_resource!(G, main = true)
    for v in V
        set_resource_bounds!(G, v, cap, 0.0, Q)
    end

    # 2. Arcos
    info = Dict{Int,Tuple{Int,Int,Int}}()                            # id do arco => (nó de saída, aresta, sentido)
    for (s, p) in origens
        for f in 1:nR, o in 0:1
            s != 0 && (s + 1) ÷ 2 == f && continue                   # não atende de novo a aresta que acabou de atender
            q = ini(f, o)
            a = add_arc!(G, s, st(f, o))                             # deadheading p ~> q, depois atende f
            set_arc_consumption!(G, a, cap, d(f))                    # todo arco de atendimento consome d_f > 0
            vars = p == q ? [x[f]] : [x[f], y[(p, q)]]
            s == 0 && push!(vars, sai[f])
            add_arc_var_mapping!(G, a, vars)
            info[a] = (p, f, o)
        end
        if s != 0
            a = add_arc!(G, s, 0)                                    # volta ao depósito pelo caminho mínimo
            set_arc_consumption!(G, a, cap, 0.0)
            add_arc_var_mapping!(G, a, p != 0 ? [y[(p, 0)], volta[(s + 1) ÷ 2]] : [volta[(s + 1) ÷ 2]])
            info[a] = (p, 0, -1)
        end
    end
    add_graph!(carp, G)

    # 4. Packing sets em VÉRTICES: os dois sentidos da aresta e formam um conjunto
    PS = [[(G, st(e, 0)), (G, st(e, 1))] for e in 1:nR]
    set_vertex_packing_sets!(carp, PS)
    dist = [[float(minimum(sp(a, b) for a in R[e][1:2], b in R[f][1:2])) for f in 1:nR] for e in 1:nR]
    define_elementarity_sets_distance_matrix!(carp, G, dist)

    # NOVO: cortes de capacidade arredondados (RCC) sobre as arestas requeridas
    add_capacity_cut_separator!(carp, [(PS[e], float(d(e))) for e in 1:nR], float(Q))

    enable_packset_ryanfoster_branching!(carp, 1)                    # como no BPP: veículos idênticos
    return (carp, x, y, info)
end

# ---------- Resolução ----------
(model, x, y, info) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", inst.name)
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
# "~>" = deadheading pelo caminho mínimo; "=" = atendimento da aresta
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    atendidas = Int[]
    for p in 1:get_number_of_positive_paths(optimizer)
        (_, arcs) = get_path_arcs(optimizer, p)
        txt, custo, carga = "0", 0, 0
        for arc in arcs
            (pnode, f, o) = info[arc.id]
            if f == 0
                custo += sp(pnode, 0)
                txt *= pnode == 0 ? "" : " ~> 0"
            else
                q = ini(f, o)
                pnode != q && (txt *= " ~> $q")
                txt *= " = $(fim(f, o))"
                custo += sp(pnode, q) + c(f)
                carga += d(f)
                push!(atendidas, f)
            end
        end
        println("rota $p: ", txt, "   custo ", custo, "  carga ", carga, "/", Q)
    end
    println(sort(atendidas) == collect(1:nR) ? "OK: cada aresta requerida atendida uma vez" : "ERRO: arestas repetidas ou faltando")
end
