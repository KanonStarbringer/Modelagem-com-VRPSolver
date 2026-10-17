# ============================================================
#  Parser de instâncias HFVRP (formato de Golden et al. 1984 / Taillard 1999, como no VRPSolverEasy)
# ============================================================
# Formato (tokens separados por espaço):
#   n
#   0 x y 0                  depósito
#   i x y d                  n linhas de clientes
#   nt                       nº de tipos de veículo
#   Q f α min max            nt linhas: capacidade, custo fixo, custo por unidade de distância, mín./máx. de veículos
#
# Variante "hd" (limited fleet, variable costs) = o exercício: f = 0, custo do tipo k = α_k · distância real.
#   Ex.: c50_13hd = 1517.84 (Taillard 1999; ótimo de Baldacci & Mingozzi 2009).
#
# Uso:
#   include("hfvrp_parser.jl")
#   inst = read_hfvrp("toy_hfvrp.txt")
#   inst.n, inst.K, inst.Q[k], inst.α[k], inst.u[k], inst.f[k], inst.d[i+1], inst.ℓ[i+1, j+1]
#   custo do tipo k: inst.α[k] * inst.ℓ[i+1, j+1]

function read_hfvrp(path::AbstractString)
    t = split(read(path, String))
    n = parse(Int, t[1])
    rows = [parse.(Float64, t[2+4i:5+4i]) for i in 0:n]       # depósito + n clientes
    [Int(r[1]) for r in rows] == 0:n || error("$path: numeração dos vértices fora de 0..n")
    pos = 2 + 4(n + 1)
    nt = parse(Int, t[pos])
    T = [parse.(Float64, t[pos+1+5k:pos+5+5k]) for k in 0:nt-1]
    length(t) == pos + 5nt || error("$path: sobram tokens no fim do arquivo")
    xy = [(r[2], r[3]) for r in rows]
    ℓ = [hypot(a[1] - b[1], a[2] - b[2]) for a in xy, b in xy]   # distância física (real)
    return (name = splitext(basename(path))[1], n = n, K = nt, d = [r[4] for r in rows], ℓ = ℓ,
            Q = [r[1] for r in T], f = [r[2] for r in T], α = [r[3] for r in T], u = [Int(r[5]) for r in T])
end

# ---------- Auto-teste: julia hfvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_hfvrp(joinpath(@__DIR__, "toy_hfvrp.txt"))
    @assert (toy.n, toy.K, toy.Q, toy.α, toy.u) == (6, 2, [7.0, 11.0], [1.0, 1.5], [2, 2])
    @assert toy.d == [0, 3, 3, 3, 4, 4, 4] && toy.f == [0.0, 0.0]
    @assert toy.ℓ[1, 5] == 12 && toy.ℓ[3, 4] == 10

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> endswith(f, "hd.txt"), readdir(dir))
    for f in files
        inst = read_hfvrp(joinpath(dir, f))
        @assert all(==(0), inst.f) "$f: variante hd não deveria ter custo fixo"
        @assert sum(inst.d) <= sum(inst.Q .* inst.u) "$f: frota não cobre a demanda"
    end
    c13 = read_hfvrp(joinpath(dir, "c50_13hd.txt"))
    @assert (c13.n, c13.K, c13.Q[1], c13.α[end], c13.u) == (50, 6, 20.0, 3.2, [4, 2, 4, 4, 2, 1])
    println("OK: toy + $(length(files)) instâncias de Golden/Taillard (hd) lidas")
end
