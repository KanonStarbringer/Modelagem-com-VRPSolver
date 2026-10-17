using VrpSolver, JuMP
include(joinpath(@__DIR__, "vrpb_parser.jl"))   # igual
inst = read_vrpb(joinpath(@__DIR__, "Instancias", "Instancias GJB", "GJ4.xml"))    # benchmark: read_vrpb(joinpath(@__DIR__, "toy_vrpb.vrpb")) 

n = inst.nL + inst.nB
Q = inst.Q
K = inst.K

c(i, j) = inst.C[i + 1, j + 1]                  # igual
d(i) = inst.d[i + 1]                            # igual

V⁺  = collect(1:n)
Lh  = inst.L
Bh  = inst.B

ub = 296533.17                                     # toy; EIL22_50: 371.01

# NOVO: ids das cópias (cada grafo tem seus próprios vértices)
p(i) = i + n                                    # i' (cópia primada do linehaul i), só em Gᴸ
o′   = 2n + 1                                   # 0' (sink de Gᴸ, source de Gᴮ)

# muda: os arcos de A se dividem entre os dois grafos
AL = vcat([(0, j) for j in Lh],
          [(i, j) for i in Lh for j in Lh if i != j])          # Gᴸ: depósito → linehauls
AB = vcat([(i, j) for i in Lh for j in Bh],
          [(i, j) for i in Bh for j in Bh if i != j],
          [(i, 0) for i in V⁺])                                # Gᴮ: conector L → backhauls → depósito
A  = vcat(AL, AB)                               # igual ao A da F1 (variáveis x do mestre)
δ⁻ = Dict(j => [a for a in A if a[2] == j] for j in V⁺)   # igual

# NOVO: vértices de cada grafo
VL = vcat([0], Lh, p.(Lh), [o′])
VB = vcat([o′], V⁺, [0])

# NOVO: vértice físico de cada packing set, na ordem em que serão criados:
#       Gᴸ: linehauls, Gᴸ: cópias i', Gᴮ: conectores (linehauls), Gᴮ: backhauls
ps_fis = vcat(Lh, Lh, Lh, Bh)

# ---------- Modelo ----------
function build_model()
    vrpb = VrpModel()
    @variable(vrpb.formulation, x[a in A] >= 0, Int)                    # igual
    @variable(vrpb.formulation, z[i in Lh] >= 0, Int)                   # NOVO: fim do segmento linehaul em i
    @variable(vrpb.formulation, w[i in Lh] >= 0, Int)                   # NOVO: início do segmento backhaul em i
    @objective(vrpb.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A))   # igual (z, w custam 0)

    @constraint(vrpb.formulation, grau[j in V⁺], sum(x[a] for a in δ⁻[j]) == 1)  # igual
    @constraint(vrpb.formulation, emparelha[i in Lh], z[i] == w[i])              # NOVO: une os dois caminhos

    # ===== Grafo Gᴸ: 0 → linehauls → i → i' → 0' =====
    GL = VrpGraph(vrpb, VL, 0, o′, (K, K))              # muda: sink = 0'
    capL = add_resource!(GL, main = true)
    for v in VL
        set_resource_bounds!(GL, v, capL, 0.0, Q)       # muda: só [0, Q] (sai o salto)
    end
    for (i, j) in AL
        a = add_arc!(GL, i, j)
        add_arc_var_mapping!(GL, a, x[(i, j)])
        set_arc_consumption!(GL, a, capL, d(j))         # entregas
    end
    for i in Lh
        a = add_arc!(GL, i, p(i))                       # NOVO: (i, i') → z_i
        add_arc_var_mapping!(GL, a, z[i])
        set_arc_consumption!(GL, a, capL, 0.0)
        a = add_arc!(GL, p(i), o′)                      # NOVO: (i', 0') auxiliar, sem mapeamento
        set_arc_consumption!(GL, a, capL, 0.0)
    end
    add_graph!(vrpb, GL)

    # ===== Grafo Gᴮ: 0' → i → backhauls → 0 =====
    GB = VrpGraph(vrpb, VB, o′, 0, (K, K))              # NOVO: source = 0', sink = 0
    capB = add_resource!(GB, main = true)
    for v in VB
        set_resource_bounds!(GB, v, capB, 0.0, Q)
    end
    for i in Lh
        a = add_arc!(GB, o′, i)                         # NOVO: (0', i) → w_i
        add_arc_var_mapping!(GB, a, w[i])
        set_arc_consumption!(GB, a, capB, 0.0)
    end
    for (i, j) in AB
        a = add_arc!(GB, i, j)
        add_arc_var_mapping!(GB, a, x[(i, j)])
        set_arc_consumption!(GB, a, capB, j in Bh ? d(j) : 0.0)   # coletas (0 ao voltar ao depósito)
    end
    add_graph!(vrpb, GB)

    # Packing sets: um singleton por vértice não depósito, em cada grafo (ordem = ps_fis)
    set_vertex_packing_sets!(vrpb, vcat(
        [[(GL, i)]    for i in Lh],
        [[(GL, p(i))] for i in Lh],
        [[(GB, i)]    for i in Lh],
        [[(GB, b)]    for b in Bh]))
    dist = [[float(c(u, v)) for v in ps_fis] for u in ps_fis]
    define_elementarity_sets_distance_matrix!(vrpb, GL, dist)
    define_elementarity_sets_distance_matrix!(vrpb, GB, dist)

    set_branching_priority!(vrpb, "x", 1)
    return (vrpb, x, z, w)
end

# ---------- Resolução ----------
(model, x, z, w) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_vrpb_f2")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Conectores (z = w): ", [i for i in Lh if get_value(optimizer, z[i]) > 0.5])
    for a in A
        get_value(optimizer, x[a]) > 0.5 && println("x[$a] = ", round(get_value(optimizer, x[a])))
    end
end