# Rotas da solução: sequência de cópias de cada caminho positivo, lida pelos valores de x
# (ordem das tarefas) e de y (cópia usada) em cada caminho, com get_value(optimizer, var, p).
function rotas(cop::Vector{Copia}, x, y, optimizer::VrpOptimizer)
    R = Vector{Vector{Int}}()
    for p in 1:get_number_of_positive_paths(optimizer)
        get_value(optimizer, p) > 0.5 || continue
        prox = Dict(e[1] => e[2] for e in axes(x, 1) if get_value(optimizer, x[e], p) > 0.5)
        copia = Dict(cop[c].tarefa => c for c in eachindex(cop) if get_value(optimizer, y[c], p) > 0.5)
        seq, i = Int[], prox[0]
        while i != 0
            push!(seq, copia[i])
            i = prox[i]
        end
        push!(R, seq)
    end
    return R
end

# Imprime cada rota com o modo, o período do offloading e o início do serviço (o mais cedo
# possível), no mesmo formato do protótipo em Python. Devolve o custo recalculado.
function print_routes(data::DataPRUO, cop::Vector{Copia}, R::Vector{Vector{Int}})
    custo = 0.0
    for (k, r) in enumerate(R)
        t, prev, km, partes = 0.0, 0, 0.0, String[]
        for c in r
            i = cop[c].tarefa
            ini = max(t + tt(data, prev, i), cop[c].lo)
            modo = cop[c].modo == 'L' ? "L" : "S@$(cop[c].periodo)"
            push!(partes, "$(i)[$(modo), $(round(ini, digits=1))]")
            km += dist(data, prev, i)
            t, prev = ini + cop[c].dur, i
        end
        km += dist(data, prev, 0)
        custo += data.F + km
        println("Rota #$(k): 0 -> ", join(partes, " -> "), " -> 0   ",
            "(volta em $(round(t + tt(data, prev, 0), digits=1)) min; $(round(km, digits=1)) km)")
    end
    return custo
end
