# ============================================================
#  Parser de instâncias MCVRP (formato "MCVRP Set 1..5")
# ============================================================
# Formato (tokens separados por espaço/quebra de linha):
#   N                    nº total de nós no arquivo (= 1 + P*n)
#   P                    nº de produtos / compartimentos
#   Q_1 ... Q_P          capacidade de cada compartimento
#   n_1 ... n_P          nº de clientes por produto (todos iguais a n)
#   N linhas: id x y d   nó 0 = depósito; nó (p-1)*n + i = cliente i, produto p
#
# O arquivo repete cada cliente uma vez por produto (mesmas coordenadas).
# O parser agrega isso em d[i, p] — o formato que o modelo da Lista 1 usa.
#
# Uso:
#   include("mcvrp_parser.jl")
#   inst = read_mcvrp("toy_4-2.txt")
#   inst.n, inst.P, inst.Q, inst.d[i+1, p], inst.C[i+1, j+1]

function read_mcvrp(path::AbstractString)
    tok = split(read(path, String))
    pos = 0
    next() = (pos += 1; parse(Float64, tok[pos]))

    N = Int(next())
    P = Int(next())
    Q = [next() for _ in 1:P]
    m = [Int(next()) for _ in 1:P]
    n = m[1]
    all(==(n), m) || error("$path: nº de clientes difere entre produtos: $m")
    N == 1 + P * n || error("$path: N = $N, esperado 1 + P*n = $(1 + P * n)")

    raw = [(id = Int(next()), x = next(), y = next(), d = next()) for _ in 1:N]
    all(raw[k].id == k - 1 for k in 1:N) || error("$path: ids fora de ordem")

    coord = zeros(n + 1, 2)            # linha i+1 = vértice i (0 = depósito)
    d = zeros(n + 1, P)                # d[i+1, p]; d[1, :] = 0 (depósito)
    coord[1, :] .= (raw[1].x, raw[1].y)
    for p in 1:P, i in 1:n
        r = raw[1 + (p - 1) * n + i]
        if p == 1
            coord[i + 1, :] .= (r.x, r.y)
        elseif (r.x, r.y) != (coord[i + 1, 1], coord[i + 1, 2])
            error("$path: nó $(r.id) não tem as coordenadas do cliente $i")
        end
        d[i + 1, p] = r.d
    end

    # ponytail: euclidiana sem arredondamento; ajuste aqui se o artigo de referência arredondar
    C = [hypot(coord[i, 1] - coord[j, 1], coord[i, 2] - coord[j, 2]) for i in 1:n+1, j in 1:n+1]

    return (name = path, n = n, P = P, Q = Q, coord = coord, d = d, C = C)
end

# ---------- Auto-teste: julia mcvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_mcvrp(joinpath(@__DIR__, "toy_4-2.txt"))
    @assert (toy.n, toy.P, toy.Q) == (4, 2, [10.0, 10.0])
    @assert toy.d == [0 0; 6 2; 3 5; 4 4; 2 6]
    @assert toy.C[1, 2] ≈ hypot(40, 10)          # depósito (50,50) → cliente 1 (10,60)
    @assert toy.C == toy.C'

    root = @__DIR__
    files = [joinpath(r, f) for (r, _, fs) in walkdir(root) for f in fs if endswith(f, ".txt") && occursin("MCVRP Set", r)]
    for f in files
        read_mcvrp(f)
    end
    println("OK: toy + $(length(files)) instâncias lidas")
end
