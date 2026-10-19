using VrpSolver, JuMP
include(joinpath(@__DIR__, "vrpb_parser.jl"))   # igual
inst = read_vrpb(joinpath(@__DIR__, "Instancias", "Instancias GJB", "GJ4.xml"))    # benchmark: read_vrpb(joinpath(@__DIR__, "Instancias", "Instancias TV convertidas", "EILB101_66.vrpb"))

n = inst.nL + inst.nB
Q = inst.Q
K = inst.K

c(i, j) = inst.C[i + 1, j + 1]                  # igual
d(i) = inst.d[i + 1]                            # igual

V⁺  = collect(1:n)
Lh  = inst.L
Bh  = inst.B

ub = 296533.17                                     # toy: 170; EIL22_50: 371.01; EILB101_66: 982.01; GJ4: 296533.17

# ids das cópias (cada grafo tem seus próprios vértices)
p(i) = i + n                                    # igual: i' (cópia do linehaul i), só em Gᴸ
o′   = 2n + 1                                   # igual: 0' (sink de Gᴸ, source de Gᴮ)
# NOVO: em Gᴸ, o id de cada backhaul b é a SOMBRA b̂ ("b é o 1º backhaul da rota"); Gᴸ não tem backhauls de verdade

AL = vcat([(0, j) for j in Lh],
          [(i, j) for i in Lh for j in Lh if i != j])          # igual
AB = vcat([(i, j) for i in Lh for j in Bh],
          [(i, j) for i in Bh for j in Bh if i != j],
          [(i, 0) for i in V⁺])                                # igual
A  = vcat(AL, AB)                               # igual
δ⁻ = Dict(j => [a for a in A if a[2] == j] for j in V⁺)   # igual

# NOVO: pares (l, b) do arco de cruzamento; b = 0 é a rota só com linehauls
Z = [(l, b) for l in Lh for b in vcat(Bh, 0)]

# vértices de cada grafo
VL = vcat([0], Lh, p.(Lh), Bh, [o′])            # muda: + sombras b̂ (ids dos backhauls)
VB = vcat([o′], V⁺, [0])                        # igual

# vértice físico de cada packing set, na ordem em que serão criados:
#   Gᴸ: linehauls, Gᴸ: cópias i', Gᴸ: sombras b̂, Gᴮ: conectores (linehauls), Gᴮ: backhauls
ps_fis = vcat(Lh, Lh, Bh, Lh, Bh)               # muda: + Bh das sombras

# ---------- Modelo ----------
function build_model()
    vrpb = VrpModel()
    @variable(vrpb.formulation, x[a in A] >= 0, Int)                    # igual
    @variable(vrpb.formulation, z[e in Z] >= 0, Int)                    # muda: z por ARCO de cruzamento (sai z_i e w_i)
    @objective(vrpb.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A))   # igual (z custa 0)

    @constraint(vrpb.formulation, grau[j in V⁺], sum(x[a] for a in δ⁻[j]) == 1)  # igual
    @constraint(vrpb.formulation, emparelha[e in Z], z[e] == x[e])               # muda: 1º backhaul declarado = real

    # ===== Grafo Gᴸ: 0 → linehauls → l → l' → b̂ → 0'  (ou l → l' → 0' se a rota só tem linehauls) =====
    GL = VrpGraph(vrpb, VL, 0, o′, (K, K))              # igual
    capL = add_resource!(GL, main = true)
    for v in VL
        set_resource_bounds!(GL, v, capL, 0.0, Q)       # igual
    end
    for (i, j) in AL
        a = add_arc!(GL, i, j)
        add_arc_var_mapping!(GL, a, x[(i, j)])
        set_arc_consumption!(GL, a, capL, d(j))         # igual: entregas
    end
    for l in Lh
        a = add_arc!(GL, l, p(l))                       # muda: (l, l') SEM mapeamento
        set_arc_consumption!(GL, a, capL, 0.0)
        for b in Bh
            a = add_arc!(GL, p(l), b)                   # NOVO: (l', b̂) → z_lb (consumo 0: a coleta fica em Gᴮ)
            add_arc_var_mapping!(GL, a, z[(l, b)])
            set_arc_consumption!(GL, a, capL, 0.0)
        end
        a = add_arc!(GL, p(l), o′)                      # muda: (l', 0') → z_l0 (rota só com linehauls)
        add_arc_var_mapping!(GL, a, z[(l, 0)])
        set_arc_consumption!(GL, a, capL, 0.0)
    end
    for b in Bh
        a = add_arc!(GL, b, o′)                         # NOVO: (b̂, 0') auxiliar, sem mapeamento
        set_arc_consumption!(GL, a, capL, 0.0)
    end
    add_graph!(vrpb, GL)

    # ===== Grafo Gᴮ: 0' → l → backhauls → 0 =====
    GB = VrpGraph(vrpb, VB, o′, 0, (K, K))              # igual
    capB = add_resource!(GB, main = true)
    for v in VB
        set_resource_bounds!(GB, v, capB, 0.0, Q)
    end
    for i in Lh
        a = add_arc!(GB, o′, i)                         # muda: (0', i) SEM mapeamento (sai o w_i)
        set_arc_consumption!(GB, a, capB, 0.0)
    end
    for (i, j) in AB
        a = add_arc!(GB, i, j)
        add_arc_var_mapping!(GB, a, x[(i, j)])          # igual: o cruzamento (l, b) só é pago aqui
        set_arc_consumption!(GB, a, capB, j in Bh ? d(j) : 0.0)   # igual: coletas
    end
    add_graph!(vrpb, GB)

    # Packing sets: os da F2 + a sombra b̂ em Gᴸ (ordem = ps_fis)
    set_vertex_packing_sets!(vrpb, vcat(
        [[(GL, i)]    for i in Lh],
        [[(GL, p(i))] for i in Lh],
        [[(GL, b)]    for b in Bh],                     # NOVO: b é o 1º backhaul de no máximo uma rota
        [[(GB, i)]    for i in Lh],
        [[(GB, b)]    for b in Bh]))
    dist = [[float(c(u, v)) for v in ps_fis] for u in ps_fis]
    define_elementarity_sets_distance_matrix!(vrpb, GL, dist)
    define_elementarity_sets_distance_matrix!(vrpb, GB, dist)

    set_branching_priority!(vrpb, "x", 1)
    return (vrpb, x, z)
end

# ---------- Resolução ----------
(model, x, z) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_vrpb_f3")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Impressão ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    println("Cruzamentos (l, 1º backhaul; 0 = só linehauls): ", [e for e in Z if get_value(optimizer, z[e]) > 0.5])
    for a in A
        get_value(optimizer, x[a]) > 0.5 && println("x[$a] = ", round(get_value(optimizer, x[a])))
    end
end
