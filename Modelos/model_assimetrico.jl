# ============================================================
#  CVRP assimétrico no VRPSolver — exemplo com 4 clientes
# ------------------------------------------------------------
#  Diferenças em relação ao modelo simétrico:
#    * arcos DIRECIONADOS: uma variável x_ij por arco (i,j)
#    * mapeamento M(x_ij) = {(i,j)}  (um único arco)
#    * restrição de GRAU DE ENTRADA = 1 em cada cliente
#    * consumo de capacidade q_(i,j) = d_j (demanda do destino)
# ============================================================
# Instalação (uma vez, se necessário):
#   using Pkg
#   Pkg.add(url="https://github.com/tbulhoes/VrpSolver.jl", rev="main")
#   Pkg.add("JuMP"); Pkg.instantiate()
using VrpSolver, JuMP

ub = 24.1                      # cutoff (ótimo conhecido = 24)

# ---------- Dados (depósito 0, clientes 1..4) ----------
n  = 4
V  = collect(0:n)              # vértices: 0 (depósito) e 1..n (clientes)
V⁺ = collect(1:n)              # clientes
Q  = 10                        # capacidade do veículo

# Demandas d[i]  (d[0] = 0)
d = Dict(0 => 0, 1 => 5, 2 => 4, 3 => 3, 4 => 6)

# Matriz de custos c(i,j); linha/coluna i corresponde ao vértice i
C = Float64[ 0  4  5  5  4 ;
             4  0  3  6  7 ;
             5  3  0  4  8 ;
             5  6  4  0  3 ;
             4  7  8  3  0 ]
c(i, j) = C[i + 1, j + 1]

# Arcos DIRECIONADOS do grafo de entrada
A = [(i, j) for i in V for j in V if i != j]

# δ⁻[i] = arcos que ENTRAM no cliente i
δ⁻ = Dict(i => [(j, i) for j in V if j != i] for i in V⁺)

L = ceil(Int, sum(d[i] for i in V⁺) / Q)   # nº mínimo de veículos
U = n                                       # nº máximo de veículos

# ---------- Modelo ----------
function build_model()
    cvrp = VrpModel()
    @variable(cvrp.formulation, x[a in A], Int)
    @objective(cvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in A))
    @constraint(cvrp.formulation, indeg[i in V⁺], sum(x[a] for a in δ⁻[i]) == 1.0)

    v_source = v_sink = 0
    G = VrpGraph(cvrp, V, v_source, v_sink, (L, U))
    cap = add_resource!(G, main = true)             # único recurso: capacidade
    for i in V
        set_resource_bounds!(G, i, cap, 0.0, Q)     # [0, Q] em cada vértice
    end

    # Um arco por arco direcionado; consumo = d_j; mapeamento M(x_ij) = {(i,j)}
    for (i, j) in A
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[(i, j)])
        set_arc_consumption!(G, a, cap, float(d[j]))
    end
    add_graph!(cvrp, G)

    # Packing sets em vértices: cada cliente é um packing set
    set_vertex_packing_sets!(cvrp, [[(G, i)] for i in V⁺])

    # Matriz de distâncias entre elementarity sets (precisa ser Float64)
    define_elementarity_sets_distance_matrix!(cvrp, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    # Branching nos arcos
    set_branching_priority!(cvrp, "x", 1)

    return (cvrp, x)
end

# ---------- Resolução ----------
(model, x) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp_assim")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Solução ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for a in A
        if get_value(optimizer, x[a]) > 0.5
            println("x[$a] = ", round(get_value(optimizer, x[a])))
        end
    end
end
