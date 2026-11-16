# Verificação do modelo sem o BaPCod. Um VrpSolver "de mentira" registra o grafo e o mapeamento
# que build_model monta; as rotas são enumeradas com a semântica de recursos do VRPSolver
# (descartáveis: S = max(l, S + q) <= u) e a formulação completa (mestre com todas as rotas)
# é resolvida no HiGHS. Faz o papel de get_complete_formulation, só que roda sem o BaPCod.
#
# Uso (na pasta vrpsolver): julia teste/valida_modelo.jl
module VrpSolver
using JuMP
export VrpModel, VrpGraph, add_resource!, set_resource_bounds!, add_arc!, set_arc_consumption!, add_graph!,
    set_vertex_packing_sets!, define_elementarity_sets_distance_matrix!,
    add_elem_set_to_vertex_init_ng_neighbourhood!, set_branching_priority!
mutable struct VrpGraph
    source::Int
    sink::Int
    mult::Tuple{Int,Int}
    nres::Int
    lb::Dict{Tuple{Int,Int},Float64}
    ub::Dict{Tuple{Int,Int},Float64}
    arcs::Vector{Tuple{Int,Int,Vector{VariableRef}}}
    cons::Dict{Tuple{Int,Int},Float64}
end
mutable struct VrpModel
    formulation::Model
    graphs::Vector{VrpGraph}
    packing::Vector{Any}
    ng::Dict{Int,Set{Int}}
end
VrpModel() = VrpModel(Model(), VrpGraph[], [], Dict{Int,Set{Int}}())
VrpGraph(m::VrpModel, nodes, s, t, mult) = VrpGraph(s, t, mult, 0, Dict(), Dict(), [], Dict())
add_resource!(G::VrpGraph; main=false, binary=false, disposable=true, step_size=0.0) = (G.nres += 1)
set_resource_bounds!(G::VrpGraph, v, r, lb, ub) = (G.lb[(v, r)] = lb; G.ub[(v, r)] = ub)
add_arc!(G::VrpGraph, u, w, vars) = (push!(G.arcs, (u, w, vars)); length(G.arcs))
set_arc_consumption!(G::VrpGraph, id, r, q) = (G.cons[(id, r)] = q)
add_graph!(m::VrpModel, G) = push!(m.graphs, G)
set_vertex_packing_sets!(m::VrpModel, ps) = (m.packing = ps)
define_elementarity_sets_distance_matrix!(m::VrpModel, G, M) = nothing
add_elem_set_to_vertex_init_ng_neighbourhood!(m::VrpModel, G, v, es) = push!(get!(m.ng, v, Set{Int}()), es)
set_branching_priority!(m::VrpModel, args...) = nothing
end

using .VrpSolver, JuMP, HiGHS
include(joinpath(@__DIR__, "..", "src", "data.jl"))
include(joinpath(@__DIR__, "..", "src", "model.jl"))

# Todas as rotas viáveis do grafo, elementares por tarefa (rota que repete tarefa não entra
# em solução inteira, por causa da partição).
function enumera(G, cop)
    saida = Dict{Int,Vector{Int}}()
    for (id, (u, _, _)) in enumerate(G.arcs)
        push!(get!(saida, u, Int[]), id)
    end
    rotas = Vector{Vector{Int}}()
    function dfs(v, S, vis, caminho)
        for id in get(saida, v, Int[])
            w = G.arcs[id][2]
            S2 = [max(get(G.lb, (w, r), 0.0), S[r] + get(G.cons, (id, r), 0.0)) for r in 1:G.nres]
            all(S2[r] <= get(G.ub, (w, r), Inf) + 1e-9 for r in 1:G.nres) || continue
            if w == G.sink
                push!(rotas, [caminho; id])
            elseif vis >> cop[w].tarefa & 1 == 0
                dfs(w, S2, vis | 1 << cop[w].tarefa, [caminho; id])
            end
        end
    end
    dfs(G.source, zeros(G.nres), 0, Int[])
    return rotas
end

# Formulação completa: cada rota vira uma coluna com os coeficientes das variáveis mapeadas.
function completa(model, cop)
    G, F = model.graphs[1], model.formulation
    obj, linhas = objective_function(F), all_constraints(F; include_variable_in_set_constraints=false)
    cols = Dict{Vector{Float64},Float64}()      # coeficientes nas linhas -> menor custo
    rotas = enumera(G, cop)
    for r in rotas
        cnt = Dict{VariableRef,Float64}()
        for id in r, v in G.arcs[id][3]
            cnt[v] = get(cnt, v, 0.0) + 1.0
        end
        custo = sum(coefficient(obj, v) * k for (v, k) in cnt)
        a = [sum(coefficient(constraint_object(c).func, v) * k for (v, k) in cnt) for c in linhas]
        (!haskey(cols, a) || custo < cols[a]) && (cols[a] = custo)
    end
    ks = collect(keys(cols))
    M = Model(HiGHS.Optimizer)
    set_silent(M)
    @variable(M, λ[1:length(ks)], Bin)
    @objective(M, Min, sum(cols[ks[p]] * λ[p] for p in eachindex(ks)))
    for (i, c) in enumerate(linhas)
        s, e = constraint_object(c).set, sum(ks[p][i] * λ[p] for p in eachindex(ks))
        s isa MOI.EqualTo ? @constraint(M, e == s.value) : @constraint(M, e <= s.upper)
    end
    @constraint(M, G.mult[1] <= sum(λ) <= G.mult[2])
    optimize!(M)
    return (termination_status(M) == OPTIMAL ? objective_value(M) : NaN), length(rotas), length(ks)
end

function main()
    pasta = joinpath(@__DIR__, "..", "instancias")
    arqs = sort(filter(s -> occursin(r"^pruo_n(7|10)_", s), readdir(pasta)))
    ok = 0
    println("instância        cópias arcos ng_max  rotas   ótimo(VRPSolver) sem rec.período  referência  confere")
    for f in arqs
        data = readPRUOData(joinpath(pasta, f))
        z = Float64[]
        info = ()
        for sem in (false, true)
            model, cop, arco = build_model(data, Dict{String,Any}("sem_recurso_periodo" => sem, "ng" => 24))
            @assert length(model.packing) == length(cop)          # um packing set por cópia
            zz, nr, _ = completa(model, cop)
            push!(z, zz)
            sem || (info = (length(cop), length(arco), maximum(length, values(model.ng)), nr))
        end
        bate = data.ref_provado && all(abs.(z .- data.ref) .<= 1e-3)
        ok += bate
        println(rpad(splitext(f)[1], 17), lpad(info[1], 6), lpad(info[2], 6), lpad(info[3], 7), lpad(info[4], 7),
            lpad(round(z[1], digits=2), 18), lpad(round(z[2], digits=2), 16), lpad(round(data.ref, digits=2), 12),
            bate ? "   sim" : "   NÃO")
    end
    println("\nConfere com o ótimo do compacto em $(ok) de $(length(arqs)) instâncias.")
end

main()
