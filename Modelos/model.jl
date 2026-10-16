# ============================================================
#  CVRP simétrico no VRPSolver — exemplo com 4 clientes
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

# Matriz de custos c(i,j), simétrica; linha/coluna i corresponde ao vértice i
C = Float64[ 0  4  5  5  4 ;
             4  0  3  6  7 ;
             5  3  0  4  8 ;
             5  6  4  0  3 ;
             4  7  8  3  0 ]
c(i, j) = C[i + 1, j + 1]

# Arestas do grafo de entrada
E = [(i, j) for i in V for j in V if i < j]

# Dicionário δ[i] = arestas incidentes ao vértice i
δ = Dict(
    0 => [(0, 1), (0, 2), (0, 3), (0, 4)],
    1 => [(0, 1), (1, 2), (1, 3), (1, 4)],
    2 => [(0, 2), (1, 2), (2, 3), (2, 4)],
    3 => [(0, 3), (1, 3), (2, 3), (3, 4)],
    4 => [(0, 4), (1, 4), (2, 4), (3, 4)],
)

L = ceil(Int, sum(d[i] for i in V⁺) / Q)   # nº mínimo de veículos
U = n                                       # nº máximo de veículos

# ---------- Modelo ----------
function build_model()
    cvrp = VrpModel()
    @variable(cvrp.formulation, x[e in E], Int)
    @objective(cvrp.formulation, Min, sum(c(i, j) * x[(i, j)] for (i, j) in E))
    @constraint(cvrp.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2.0)

    v_source = v_sink = 0
    G = VrpGraph(cvrp, V, v_source, v_sink, (L, U))
    cap = add_resource!(G, main = true)             # único recurso: capacidade
    for i in V
        set_resource_bounds!(G, i, cap, 0.0, Q)     # [0, Q] em cada vértice
    end

    # Dois arcos por aresta; consumo (d_i+d_j)/2; mapeamento M(x_e) = {(i,j),(j,i)}
    for (i, j) in E
        for (u, v) in ((i, j), (j, i))
            a = add_arc!(G, u, v)
            add_arc_var_mapping!(G, a, x[(i, j)])
            set_arc_consumption!(G, a, cap, float(d[v]))     # consumo = demanda do destino (d_j)
        end
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

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Solução ----------
if solution_found
    println("Custo ótimo: ", get_objective_value(optimizer))
    for e in E
        if get_value(optimizer, x[e]) > 0.5
            println("x[$e] = ", round(get_value(optimizer, x[e])))
        end
    end
end
