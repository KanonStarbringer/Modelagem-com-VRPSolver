using VrpSolver, JuMP
include("top_parser.jl")

inst = read_top(joinpath(@__DIR__, "Instancias", "Set1", "p1.2.p.txt"))

n, m, T = inst.n, inst.m, inst.T                # sai Q (não há capacidade); m e T vêm do arquivo
c(i, j) = inst.C[i + 1, j + 1]                  # tempo de viagem (igual)
p(i)    = inst.p[i + 1]                         # lucro: substitui a demanda d(i)

V  = collect(0:n+1)                             # 0 = início, n+1 = fim (vértices diferentes)
V⁺ = collect(1:n)                               # igual

L  = 0                                          # visita opcional: pode não sair nenhum veículo
U  = m                                          # igual
ub = -249.99                                     # cutoff da toy (ótimo = 70, objetivo negado)

E = [(i, j) for i in V for j in V if i < j && (i, j) != (0, n + 1)]   # sem a aresta início–fim
δ = Dict(i => [e for e in E if i in e] for i in V)                    # igual

aresta(i, j) = (min(i, j), max(i, j))           # continua útil: os arcos i→j e j→i usam a mesma aresta

# ---------- Modelo ----------
function build_model()
    top = VrpModel()
    @variable(top.formulation, x[e in E], Int)
    @variable(top.formulation, y[i in V⁺], Bin)                       # NOVO: i foi visitado?
    @objective(top.formulation, Min, -sum(p(i) * y[i] for i in V⁺))  # max lucro = min −lucro
    @constraint(top.formulation, deg[i in V⁺], sum(x[e] for e in δ[i]) == 2 * y[i])   # era == 2

    # 1. Grafo: início 0 ≠ fim n+1
    G = VrpGraph(top, V, 0, n + 1, (L, U))

    # 3. Recursos: só o tempo
    tim = add_resource!(G, main = true)
    for i in V
        set_resource_bounds!(G, i, tim, 0.0, T)
    end

    # 2. Arcos: sai do início, anda entre clientes, entra no fim
    function arco!(i, j)
        a = add_arc!(G, i, j)
        add_arc_var_mapping!(G, a, x[aresta(i, j)])
        set_arc_consumption!(G, a, tim, c(i, j))
    end
    for j in V⁺
        arco!(0, j)                                  # início → j
        arco!(j, n + 1)                              # j → fim
        for i in V⁺
            i != j && arco!(i, j)                    # i → j  (i→j e j→i usam a mesma aresta)
        end
    end
    add_graph!(top, G)

    # 4. Packing sets: um por cliente (como no CVRP)
    set_vertex_packing_sets!(top, [[(G, i)] for i in V⁺])
    define_elementarity_sets_distance_matrix!(top, G,
        [[float(c(i, j)) for j in V⁺] for i in V⁺])

    set_branching_priority!(top, "y", 2)             # NOVO: decide primeiro quem é visitado
    set_branching_priority!(top, "x", 1)
    return (top, x, y)
end

# ---------- Resolução ----------
(model, x, y) = build_model()

optimizer = VrpOptimizer(model, "CVRP.cfg", "exemplo_cvrp")
set_cutoff!(optimizer, ub)
(status, solution_found) = optimize!(optimizer)

# ---------- Solução ----------
if solution_found
    println("Lucro ótimo: ", -get_objective_value(optimizer))
    println("Visitados: ", [i for i in V⁺ if get_value(optimizer, y[i]) > 0.5])
    for e in E
        get_value(optimizer, x[e]) > 0.5 && println("x[$e] = ", round(get_value(optimizer, x[e])))
    end
end