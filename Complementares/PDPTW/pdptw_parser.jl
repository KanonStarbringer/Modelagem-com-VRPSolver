# ============================================================
#  Parser de instâncias PDPTW (formato de Li & Lim, 2001; SINTEF)
# ============================================================
# Formato (tabulado):
#   K Q velocidade
#   id x y d l u s p e     d > 0 na coleta, d < 0 na entrega; p = id da coleta (nas entregas), e = id da entrega (nas coletas)
#
# Renumeração como no enunciado: depósito 0, coletas 1..r (na ordem dos ids), entrega da coleta h = h + r.
# Convenção das soluções do SINTEF: distância euclidiana REAL e tempo do arco i→j = s_i + c_ij.
#   As .sol são BKS hierárquicas (1º nº de veículos, 2º distância): para minimizar só a distância, são limites superiores.
# Keyword r: usa só as r primeiras requisições (instância reduzida).
#
# Uso:
#   include("pdptw_parser.jl")
#   inst = read_pdptw("toy_pdptw.txt")
#   inst = read_pdptw(joinpath("Instancias", "lc101.txt"); r = 10)
#   inst.r, inst.K, inst.Q, inst.q[v+1] (assinada), inst.l[v+1], inst.u[v+1], inst.s[v+1], inst.C[v+1, w+1], inst.T[v+1, w+1]

function read_pdptw(path::AbstractString; r = nothing)
    L = [split(l) for l in readlines(path) if !isempty(strip(l))]
    K, Q = parse(Int, L[1][1]), parse(Float64, L[1][2])
    row = Dict(parse(Int, t[1]) => parse.(Float64, t[2:9]) for t in L[2:end])   # x y d l u s p e
    picks = sort([v for (v, t) in row if t[3] > 0])
    all(v -> row[Int(row[v][8])][7] == v, picks) || error("$path: pares coleta/entrega inconsistentes")
    r === nothing || (picks = picks[1:r])
    R = length(picks)
    ids = [0; picks; [Int(row[p][8]) for p in picks]]          # ids[v+1] = id original do vértice v
    get(row, 0, nothing) === nothing && error("$path: sem depósito 0")
    col(k) = [row[i][k] for i in ids]
    x, y = col(1), col(2)
    C = [hypot(x[a] - x[b], y[a] - y[b]) for a in eachindex(ids), b in eachindex(ids)]
    s = col(6)
    return (name = splitext(basename(path))[1], r = R, K = K, Q = Q, q = col(3), l = col(4), u = col(5), s = s,
            C = C, T = [s[a] + C[a, b] for a in eachindex(ids), b in eachindex(ids)], ids = ids)
end

# ---------- Auto-teste: julia pdptw_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_pdptw(joinpath(@__DIR__, "toy_pdptw.txt"))
    @assert (toy.r, toy.K, toy.Q) == (3, 3, 10.0)
    @assert toy.q == [0, 4, 5, 6, -4, -5, -6] && toy.l[5] == 19 && toy.u[2] == 65
    @assert toy.C[2, 5] ≈ hypot(1, 6) && toy.T[2, 5] ≈ 5 + hypot(1, 6)     # coleta 1 (-17,-1) → entrega 1 (-18,-7)

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> endswith(f, ".txt"), readdir(dir))
    for f in files
        inst = read_pdptw(joinpath(dir, f))
        @assert all(h -> inst.q[h+1] == -inst.q[h+inst.r+1] > 0, 1:inst.r) "$f"
    end
    lc = read_pdptw(joinpath(dir, "lc101.txt"))
    @assert (lc.r, lc.K, lc.Q) == (53, 25, 200.0)
    @assert read_pdptw(joinpath(dir, "lc101.txt"); r = 10).r == 10
    println("OK: toy + $(length(files)) instâncias de Li & Lim lidas")
end
