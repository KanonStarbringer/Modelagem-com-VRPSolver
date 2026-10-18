# ============================================================
#  Parser de instâncias OPHS (formato de Divsalar et al., 2013; KU Leuven / Sohrabi et al., 2021)
# ============================================================
# Formato:
#   N H D                 N = nº de clientes + 2; H = nº de hotéis extras; D = nº de trips
#   U                     duração total máxima do tour (Tmax)
#   T_1 ... T_D           duração máxima de cada trip
#   x y w                 hotel inicial, hotel final, H hotéis extras e N-2 clientes (w = lucro; 0 nos hotéis)
#
# Renumeração: hotéis 1..H+2 (1 = hotel inicial, 2 = hotel final "m"), clientes H+3..H+N.
# Distância euclidiana REAL. Sem tempo de serviço.
# O modelo da aula (um grafo, Σλ = D) exige T_1 = ... = T_D: confira `inst.uniforme`.
#
# Uso:
#   include("ophs_parser.jl")
#   inst = read_ophs(joinpath(@__DIR__, "toy_ophs.ophs"))
#   inst = read_ophs(joinpath(@__DIR__, "Instancias", "SET_2-3_TSP", "eil51-H4-T3-S3.ophs"))
#   inst.H, inst.C, inst.ini, inst.fim, inst.D, inst.T, inst.U, inst.w[i], inst.t[i, j]

function read_ophs(path::AbstractString)
    L = [split(l) for l in eachline(path) if !isempty(strip(l))]
    N, Hx, D = parse.(Int, L[1])
    U = parse(Float64, L[2][1])
    Td = parse.(Float64, L[3])
    length(Td) == D || error("$path: esperava $D durações de trip, li $(length(Td))")
    P = [parse.(Float64, l[1:3]) for l in L[4:end] if length(l) >= 3]   # o SET_4 termina com uma linha "-----"
    nH, nC = Hx + 2, N - 2
    length(P) == nH + nC || error("$path: esperava $(nH + nC) pontos, li $(length(P))")
    V = nH + nC
    t = [hypot(P[i][1] - P[j][1], P[i][2] - P[j][2]) for i in 1:V, j in 1:V]
    return (name = splitext(basename(path))[1], H = collect(1:nH), C = collect(nH+1:V), ini = 1, fim = 2,
            D = D, T = maximum(Td), Td = Td, uniforme = maximum(Td) - minimum(Td) < 1e-9, U = U,
            w = [p[3] for p in P], t = t, xy = [(p[1], p[2]) for p in P])
end

# ---------- Auto-teste: julia ophs_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_ophs(joinpath(@__DIR__, "toy_ophs.ophs"))
    @assert (toy.H, toy.C, toy.D, toy.T, toy.U, toy.uniforme) == (1:4, 5:11, 3, 25.0, 60.0, true)
    @assert toy.w == [0, 0, 0, 0, 10, 15, 20, 10, 15, 30, 30] && toy.t[1, 2] == 30 && toy.t[3, 4] == 22

    dir = isdir(joinpath(@__DIR__, "Instancias")) ? joinpath(@__DIR__, "Instancias") :
          joinpath(@__DIR__, "..", "..", "..", "Artigos", "OPHS", "Instancias")
    files = [joinpath(dir, sub, f) for sub in readdir(dir) for f in readdir(joinpath(dir, sub))]
    @assert all(f -> read_ophs(f).uniforme, files)
    e = read_ophs(joinpath(dir, "SET_2-3_TSP", "eil51-H4-T3-S3.ophs"))
    @assert (length(e.H), length(e.C), e.D, e.T, e.U, sum(e.w)) == (4, 51, 3, 114.0, 342.0, 2860.0)
    println("OK: toy + $(length(files)) instâncias com T uniforme lidas")
end
