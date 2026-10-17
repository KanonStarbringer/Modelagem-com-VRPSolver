using VrpSolver, JuMP
include(joinpath(@__DIR__, "vrpb_parser.jl"))   # muda: parser do VRPB
inst = read_vrpb(joinpath(@__DIR__, "Instancias", "Instancias GJB", "GJ4.xml"))    # benchmark: read_vrpb(joinpath(@__DIR__, "toy_vrpb.vrpb")) 

n = inst.nL + inst.nB
Q = inst.Q                                      # muda: volta a ser um número (frota homogênea)
K = inst.K                                      # muda: K agora é o nº FIXO de veículos (não mais tipos)

c(i, j) = inst.C[i + 1, j + 1]                  # muda: custo único (sai α e ℓ)
d(i) = inst.d[i + 1]                            # igual: entrega nos L, coleta nos B

V   = collect(0:n)
V⁺  = collect(1:n)
Lh  = inst.L                                    # NOVO: linehauls 1..nL
Bh  = inst.B                                    # NOVO: backhauls nL+1..n

ub = 296533.17                                    # toy; EIL22_50: 371.01

# NOVO: ARCOS dirigidos (sai E/δ de arestas): sem B→L e sem 0→B
A = vcat([(0, j) for j in Lh],
         [(i, j) for i in Lh for j in Lh if i != j],
         [(i, j) for i in Lh for j in Bh],
         [(i, j) for i in Bh for j in Bh if i != j],
         [(i, 0) for i in V⁺])
δ⁻ = Dict(j => [a for a in A if a[2] == j] for j in V⁺)   # NOVO: arcos que ENTRAM em j

# ---------- Modelo ----------
function build_model()
    vrpb = VrpModel()
    @variable(vrpb.formulation, x[a in A] >= 0, Int)                    # muda: uma variável por ARCO (sai o índice k)
    @objective(vrpb.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A))   # muda: custo único

    @constraint(vrpb.formulation, grau[j in V⁺], sum(x[a] for a in δ⁻[j]) == 1)  # muda: grau de ENTRADA == 1

    # 1. Grafo: volta a ser um só
    G = VrpGraph(vrpb, V, 0, 0, (K, K))                 # muda: exatamente K rotas (frota fixa)

    # 3. Recurso: capacidade com "salto" nos backhauls
    cap = add_resource!(G, main = true)
    for i in V
        if i == 0
            set_resource_bounds!(G, i, cap, 0.0, 2Q)    # NOVO: depósito aceita a carga "saltada"
        elseif i in Bh
            set_resource_bounds!(G, i, cap, Q + d(i), 2Q)   # NOVO: B força o salto para Q + p_i
        else
            set_resource_bounds!(G, i, cap, 0.0, Q)     # L: entregas ≤ Q
        end
    end

    # 2. Arcos: cada arco dirigido → sua própria variável
    for (i, j) in A
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[(i, j)])
        set_arc_consumption!(G, a, cap, j == 0 ? 0.0 : d(j))   # muda: consumo d_j (não mais (d_i+d_j)/2)
    end
    add_graph!(vrpb, G)

    # 4. Packing sets: volta o singleton por cliente
    set_vertex_packing_sets!(vrpb, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(vrpb, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(vrpb, "x", 1)
    return (vrpb, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_vrpb_f1")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for a in A
        get_value(optimizer, x[a]) > 0.5 && println("x[$a] = ", round(get_value(optimizer, x[a])))
    end
end