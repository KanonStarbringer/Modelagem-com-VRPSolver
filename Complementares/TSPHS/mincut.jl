# ============================================================
#  Corte mínimo s–t (Edmonds-Karp) para separar os cortes de conectividade do TSPHS e do OPHS
# ============================================================
# cap[i, j] = cap[j, i] = valor de x_e na solução fracionária (grafo não-direcionado).
# Devolve (valor do fluxo máximo, S), em que S = vértices alcançáveis a partir de s no grafo residual.
# Se o fluxo for menor que o lado direito, δ(S) dá o corte violado.
# ponytail: Edmonds-Karp em matriz densa, O(V·E²); basta para ~100 vértices. Trocar por push-relabel se ficar lento.
#
# Uso:
#   include(joinpath(@__DIR__, "mincut.jl"))        # no OPHS: joinpath(@__DIR__, "..", "TSPHS", "mincut.jl")
#   fl, S = mincut(cap, 1, k)

function mincut(cap::Matrix{Float64}, s::Int, t::Int)
    N = size(cap, 1)
    r = copy(cap)
    fl = 0.0
    while true
        pai = zeros(Int, N); pai[s] = s
        fila = [s]
        while !isempty(fila) && pai[t] == 0
            u = popfirst!(fila)
            for v in 1:N
                if pai[v] == 0 && r[u, v] > 1e-9
                    pai[v] = u; push!(fila, v)
                end
            end
        end
        pai[t] == 0 && return fl, findall(!=(0), pai)
        Δ, v = Inf, t
        while v != s; Δ = min(Δ, r[pai[v], v]); v = pai[v]; end
        v = t
        while v != s; r[pai[v], v] -= Δ; r[v, pai[v]] += Δ; v = pai[v]; end
        fl += Δ
    end
end

# ---------- Auto-teste: julia mincut.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    # dois triângulos {1,2,3} e {4,5,6} ligados só pela aresta 3–4 com valor 0.5
    cap = zeros(6, 6)
    for (i, j, v) in [(1, 2, 1.0), (2, 3, 1.0), (1, 3, 1.0), (4, 5, 1.0), (5, 6, 1.0), (4, 6, 1.0), (3, 4, 0.5)]
        cap[i, j] = cap[j, i] = v
    end
    fl, S = mincut(cap, 1, 6)
    @assert fl ≈ 0.5 && S == [1, 2, 3]
    @assert mincut(cap, 1, 2)[1] ≈ 2.0                    # 1–2 direto + 1–3–2
    println("OK: mincut")
end
