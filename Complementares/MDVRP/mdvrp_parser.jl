# ============================================================
#  Parser de instâncias MDVRP (formato de Cordeau, Gendreau & Laporte, 1997)
# ============================================================
# Formato:
#   type m n t               type = 2 (MDVRP); m = veículos POR depósito; n = clientes; t = depósitos
#   D Q                      t linhas, uma por depósito (D = duração máx. da rota, 0 = sem limite)
#   i x y d q f a list       n linhas de clientes (d = serviço, q = demanda)
#   i x y 0 0 0 0            t linhas de depósitos, numerados n+1..n+t
#
# Vértices como no model_mdvrp.jl do professor: clientes 1..n, depósitos n+1..n+t (não há vértice 0).
# Custo = distância euclidiana real (convenção dos valores publicados, ex.: p01 = 576.87).
#
# Uso:
#   include("mdvrp_parser.jl")
#   inst = read_mdvrp("toy_mdvrp")
#   inst.n, inst.m, inst.Q, inst.D, inst.depots, inst.d[i], inst.C[i, j]

function read_mdvrp(path::AbstractString)
    L = [split(l) for l in readlines(path) if !isempty(strip(l))]
    typ, m, n, t = parse.(Int, L[1])
    typ == 2 || error("$path: type = $typ, esperado 2 (MDVRP)")
    DQ = [parse.(Float64, L[1+k][1:2]) for k in 1:t]
    allequal(DQ) || error("$path: depósitos com D/Q diferentes")
    D, Q = DQ[1]
    rows = [parse.(Float64, l[1:5]) for l in L[t+2:t+1+n+t]]
    [Int(r[1]) for r in rows] == 1:n+t || error("$path: numeração dos vértices fora de 1..n+t")
    xy = [(r[2], r[3]) for r in rows]
    d = [r[5] for r in rows]                       # d[k] = 0 nos depósitos
    C = [hypot(a[1] - b[1], a[2] - b[2]) for a in xy, b in xy]
    return (name = basename(path), n = n, m = m, Q = Q, D = D == 0 ? Inf : D,
            s = [r[4] for r in rows], depots = collect(n+1:n+t), d = d, coord = xy, C = C)
end

# ---------- Auto-teste: julia mdvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_mdvrp(joinpath(@__DIR__, "toy_mdvrp"))
    @assert (toy.n, toy.m, toy.Q, toy.D, toy.depots) == (6, 1, 11.0, Inf, [7, 8])
    @assert toy.d == [3, 3, 3, 4, 4, 4, 0, 0]
    @assert toy.C[6, 7] ≈ hypot(18, 3) && toy.C[3, 8] ≈ hypot(4, 14)

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> startswith(f, "p"), readdir(dir))
    for f in files
        inst = read_mdvrp(joinpath(dir, f))
        @assert sum(inst.d) <= inst.m * length(inst.depots) * inst.Q "$f: frota não cobre a demanda"
    end
    p01 = read_mdvrp(joinpath(dir, "p01"))
    @assert (p01.n, p01.m, p01.Q, p01.D, p01.depots) == (50, 4, 80.0, Inf, [51, 52, 53, 54])
    println("OK: toy + $(length(files)) instâncias de Cordeau lidas")
end
