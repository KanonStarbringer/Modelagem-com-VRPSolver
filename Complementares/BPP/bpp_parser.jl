# ============================================================
#  Parser de instâncias do Bin Packing (formato BPP da BPPLIB)
# ============================================================
# Formato: n, Q e os n pesos, um por linha.
# As Falkenauer T60 vinham com uma casa decimal (Q = 100.0): foram convertidas para inteiros
# multiplicando por 10 (Q = 1000), para o recurso de capacidade não sofrer com arredondamento.
# Ótimos em ../otimos.csv (BPPLIB: Delorme, Iori & Martello, 2018).
#
# Uso:
#   include("bpp_parser.jl")
#   inst = read_bpp(joinpath(@__DIR__, "toy_bpp.txt"))
#   inst = read_bpp(joinpath(@__DIR__, "Instancias", "Falkenauer_U120", "u120_00.txt"))
#   inst.n, inst.Q, inst.w[t]                                      (t em 1..n)

function read_bpp(path::AbstractString)
    v = parse.(Float64, split(read(path, String)))
    n = Int(v[1])
    length(v) == n + 2 || error("$path: esperava $n pesos, li $(length(v) - 2)")
    w = v[3:end]
    maximum(w) <= v[2] || error("$path: item maior que o bin")
    return (name = splitext(basename(path))[1], n = n, Q = v[2], w = w)
end

# ---------- Auto-teste: julia bpp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_bpp(joinpath(@__DIR__, "toy_bpp.txt"))
    @assert (toy.n, toy.Q, toy.w) == (5, 8.0, [6, 5, 4, 3, 2])

    dir = isdir(joinpath(@__DIR__, "Instancias")) ? joinpath(@__DIR__, "Instancias") :
          joinpath(@__DIR__, "..", "..", "..", "Artigos", "BPP", "Instancias")
    csv = isfile(joinpath(@__DIR__, "otimos.csv")) ? joinpath(@__DIR__, "otimos.csv") : joinpath(dir, "..", "otimos.csv")
    rows = [split(l, ',') for l in readlines(csv)[2:end]]
    for r in rows
        inst = read_bpp(joinpath(dir, r[1], r[2] * ".txt"))
        @assert (inst.n, inst.Q) == (parse(Int, r[3]), parse(Float64, r[4])) r[2]
        @assert ceil(Int, sum(inst.w) / inst.Q) == parse(Int, r[6]) <= parse(Int, r[5]) r[2]
    end
    println("OK: toy + $(length(rows)) instâncias da BPPLIB lidas (Falkenauer U120/U250/T60 e Hard28)")
end
