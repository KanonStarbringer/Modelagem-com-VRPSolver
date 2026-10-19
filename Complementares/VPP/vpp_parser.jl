# ============================================================
#  Parser do Vector Packing 2D (formato da biblioteca DEIS/Bologna: Spieksma e Caprara & Toth)
# ============================================================
# Formato do CL_X_N_Z.TXT: n; capacidades W1 W2 do bin; n linhas "índice w1 w2" (peso e volume do item).
# Classe X = 1..10, N = 25/50/100/200 itens (classe 10: 24/51/99/201), Z = 1..10.
# Toda demanda é 1: cada linha é um item.
# Referências em ../referencias_cplex.csv (MIP de atribuição no CPLEX, só para N = 25 e 50).
#
# Uso:
#   include("vpp_parser.jl")
#   inst = read_vpp(joinpath(@__DIR__, "toy_vpp.txt"))
#   inst = read_vpp(joinpath(@__DIR__, "Instancias", "CL_01_25_01.TXT"))
#   inst.n, inst.Q[1], inst.Q[2], inst.w[1][i], inst.w[2][i]        (i em 1..n)

function read_vpp(path::AbstractString)
    v = parse.(Int, split(read(path, String)))
    n = v[1]
    length(v) == 3 + 3n || error("$path: esperava $n itens, li $((length(v) - 3) ÷ 3)")
    v[4:3:end] == 1:n || error("$path: índices dos itens fora de 1..n")
    w = (v[5:3:end], v[6:3:end])
    all(k -> maximum(w[k]) <= v[1+k], 1:2) || error("$path: item maior que o bin")
    return (name = splitext(basename(path))[1], n = n, Q = (v[2], v[3]), w = w)
end

# ---------- Auto-teste: julia vpp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_vpp(joinpath(@__DIR__, "toy_vpp.txt"))
    @assert (toy.n, toy.Q, toy.w[1], toy.w[2]) == (8, (10, 10), [6, 2, 3, 6, 3, 4, 8, 2], [8, 8, 8, 5, 5, 4, 3, 2])

    dir = isdir(joinpath(@__DIR__, "Instancias")) ? joinpath(@__DIR__, "Instancias") :
          joinpath(@__DIR__, "..", "..", "..", "Artigos", "VPP", "Instancias")
    files = filter(f -> startswith(f, "CL_"), readdir(dir))
    for f in files
        inst = read_vpp(joinpath(dir, f))
        m = match(r"CL_(\d+)_(\d+)_(\d+)", f)
        @assert inst.n == parse(Int, m[2]) f
    end
    println("OK: toy + $(length(files)) instâncias 2-VPP lidas")
end
