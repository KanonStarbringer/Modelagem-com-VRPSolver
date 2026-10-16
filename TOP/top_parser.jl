# ============================================================
#  Parser de instâncias TOP (Chao, Golden & Wasil, 1996)
# ============================================================
# Formato (KU Leuven):
#   n N          nº de pontos, contando início e fim
#   m P          nº de veículos (caminhos)
#   tmax T       tempo máximo por caminho
#   x y S        N linhas: coordenadas e lucro; 1ª = início, última = fim
#
# O ponto k (1..N) vira o vértice k-1: início = 0, clientes = 1..n, fim = n+1.
# Início e fim podem ser pontos DIFERENTES (sets 1–6) ou iguais (set 7).
#
# Uso:
#   include("top_parser.jl")
#   inst = read_top("toy_top.txt")
#   inst.n, inst.m, inst.T, inst.p[i+1], inst.C[i+1, j+1]

function read_top(path::AbstractString)
    L = [split(l) for l in eachline(path) if !isempty(strip(l))]
    (L[1][1], L[2][1], L[3][1]) == ("n", "m", "tmax") || error("$path: cabeçalho n/m/tmax não encontrado")
    N = parse(Int, L[1][2])
    length(L) == N + 3 || error("$path: esperado $N pontos, vieram $(length(L) - 3)")
    pts = [parse.(Float64, l[1:3]) for l in L[4:end]]
    xy = [(q[1], q[2]) for q in pts]               # xy[i+1] = vértice i
    p = [q[3] for q in pts]                        # p[i+1];  p[1] = p[N] = 0
    # ponytail: euclidiana sem arredondamento — convenção dos ótimos publicados
    C = [hypot(a[1] - b[1], a[2] - b[2]) for a in xy, b in xy]
    return (name = splitext(basename(path))[1], n = N - 2,
            m = parse(Int, L[2][2]), T = parse(Float64, L[3][2]),
            p = p, coord = xy, C = C)
end

# ---------- Auto-teste: julia top_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_top(joinpath(@__DIR__, "toy_top.txt"))
    @assert (toy.n, toy.m, toy.T) == (7, 2, 14.0)
    @assert toy.p == [0, 10, 10, 10, 30, 10, 10, 10, 0]
    @assert toy.C[1, 9] == 10.0                     # início (0,0) → fim (10,0)

    dir = joinpath(@__DIR__, "Instancias")
    files = [joinpath(dir, s, f) for s in readdir(dir) for f in readdir(joinpath(dir, s))]
    for f in files
        inst = read_top(f)
        @assert inst.p[1] == inst.p[end] == 0 "$f: início/fim com lucro"
        @assert inst.m == parse(Int, split(basename(f), '.')[2]) "$f: m não bate com o nome"
    end
    k = length(files)
    @assert k == 387
    println("OK: toy + $k instâncias de Chao et al. lidas")
end
