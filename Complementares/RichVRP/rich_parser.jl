# ============================================================
#  Parser do Rich VRP (formato próprio .rvrp: múltiplos depósitos, frota heterogênea, janelas, clientes opcionais)
# ============================================================
# Formato (linhas com # são comentários):
#   NAME nome
#   DIST real | trunc1          real = euclidiana; trunc1 = ⌊10·dist⌋/10 (convenção de Solomon)
#   CUSTOMERS n / DEPOTS m / TYPES t
#   m linhas:  id x y l u                       depósitos, ids n+1..n+m
#   t linhas:  k depósito Q u f α              tipo k: base b(k), capacidade, disponibilidade, custo fixo, custo/distância
#   n linhas:  id x y d s l u ρ tipos...        ρ = penalidade (−1 = obrigatório); tipos = 𝒦_i (compatíveis)
#
# Vértices como no model_mdvrp.jl: clientes 1..n, depósitos n+1..n+m (sem vértice 0, sem o +1).
# Custo da rota do tipo k: f_k + α_k · ℓ.  Tempo do arco i→j: s_i + ℓ_ij (serviço na saída, como no VRPTW).
#
# Uso:
#   include("rich_parser.jl")
#   inst = read_rich("toy_rich.rvrp")
#   inst.n, inst.depots, inst.K, inst.b[k], inst.Q[k], inst.u[k], inst.f[k], inst.α[k]
#   inst.d[i], inst.s[i], inst.l[i], inst.u_tw[i], inst.ρ[i], inst.comp[i], inst.ℓ[i, j], inst.T[i, j]

function read_rich(path::AbstractString)
    L = [split(l) for l in readlines(path) if !isempty(strip(l)) && !startswith(strip(l), "#")]
    head = Dict(t[1] => t[2] for t in L[1:5])
    n, m, t = parse(Int, head["CUSTOMERS"]), parse(Int, head["DEPOTS"]), parse(Int, head["TYPES"])
    N = n + m
    x = zeros(N); y = zeros(N); d = zeros(N); s = zeros(N); l = zeros(N); u = zeros(N); ρ = fill(-1.0, N)
    comp = [Set{Int}() for _ in 1:N]
    for r in L[6:5+m]
        v = parse(Int, r[1]); n < v <= N || error("$path: depósito $v fora de n+1..n+m")
        x[v], y[v], l[v], u[v] = parse.(Float64, r[2:5])
    end
    T6 = [parse.(Float64, r) for r in L[6+m:5+m+t]]
    [Int(r[1]) for r in T6] == 1:t || error("$path: tipos fora de 1..t")
    for r in L[6+m+t:5+m+t+n]
        v = parse(Int, r[1]); 1 <= v <= n || error("$path: cliente $v fora de 1..n")
        x[v], y[v], d[v], s[v], l[v], u[v], ρ[v] = parse.(Float64, r[2:8])
        comp[v] = Set(parse.(Int, r[9:end]))
        isempty(comp[v]) && error("$path: cliente $v sem tipo compatível")
    end
    dist(a, b) = (h = hypot(x[a] - x[b], y[a] - y[b]); head["DIST"] == "trunc1" ? floor(10h + 1e-9) / 10 : h)
    ℓ = [dist(a, b) for a in 1:N, b in 1:N]
    return (name = head["NAME"], n = n, depots = collect(n+1:N), K = t,
            b = [Int(r[2]) for r in T6], Q = [r[3] for r in T6], u = [Int(r[4]) for r in T6], f = [r[5] for r in T6], α = [r[6] for r in T6],
            d = d, s = s, l = l, u_tw = u, ρ = ρ, comp = comp, ℓ = ℓ, T = [s[a] + ℓ[a, b] for a in 1:N, b in 1:N])
end

# ---------- Auto-teste: julia rich_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_rich(joinpath(@__DIR__, "toy_rich.rvrp"))
    @assert (toy.n, toy.depots, toy.K, toy.b, toy.u, toy.f) == (6, [7, 8], 3, [7, 7, 8], [1, 1, 2], [20.0, 40.0, 25.0])
    @assert toy.ρ[1:6] == [-1, -1, -1, -1, 30, 25] && toy.comp[4] == Set([3])
    @assert toy.ℓ[7, 8] == 30 && toy.T[1, 7] ≈ 2 + hypot(4, 4)
    for f in filter(f -> endswith(f, ".rvrp") && f != "toy_rich.rvrp", readdir(@__DIR__))
        inst = read_rich(joinpath(@__DIR__, f))
        @assert all(k -> inst.b[k] in inst.depots, 1:inst.K) "$f"
    end
    println("OK: toy + instâncias .rvrp da pasta lidas")
end
