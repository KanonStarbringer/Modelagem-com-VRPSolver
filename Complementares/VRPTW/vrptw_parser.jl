# ============================================================
#  Parser de instâncias VRPTW (formato de Solomon, 1987)
# ============================================================
# Formato:
#   NOME
#   VEHICLE / NUMBER CAPACITY / K Q
#   CUSTOMER / cabeçalho
#   i  x  y  d  l  u  s        (i = 0 é o depósito; l..u = janela; s = tempo de serviço)
#
# Convenção da literatura exata (e das soluções .sol da CVRPLIB): distância euclidiana
# TRUNCADA em uma casa decimal, c_ij = ⌊10·dist⌋/10, e tempo do arco t_ij = s_i + c_ij.
#   Ex.: C101 = 827.3, R101 = 1637.7 (100 clientes).
# Instâncias de 25 e 50 clientes = os n primeiros clientes do arquivo de 100 (keyword n).
#
# Uso:
#   include("vrptw_parser.jl")
#   inst = read_vrptw("toy_vrptw.txt")
#   inst = read_vrptw(joinpath("Instancias", "R101.txt"); n = 25)
#   inst.n, inst.K, inst.Q, inst.d[i+1], inst.l[i+1], inst.u[i+1], inst.s[i+1], inst.C[i+1, j+1], inst.T[i+1, j+1]

function read_vrptw(path::AbstractString; n = nothing)
    L = split.(strip.(readlines(path)))
    K, Q = parse.(Int, L[5])
    rows = [parse.(Float64, t) for t in L[10:end] if length(t) == 7]
    n === nothing || (rows = rows[1:n+1])
    rows[1][1] == 0 || error("$path: o depósito deveria ser o cliente 0")
    col(k) = [r[k] for r in rows]
    x, y, d, l, u, s = col(2), col(3), col(4), col(5), col(6), col(7)
    N = length(rows)
    C = [floor(10 * hypot(x[i] - x[j], y[i] - y[j]) + 1e-9) / 10 for i in 1:N, j in 1:N]
    T = [s[i] + C[i, j] for i in 1:N, j in 1:N]       # tempo do arco i→j inclui o serviço em i
    sol = splitext(path)[1] * ".sol"
    opt = n === nothing && isfile(sol) ? parse(Float64, match(r"Cost\s+([\d.]+)", read(sol, String))[1]) : NaN
    return (name = splitext(basename(path))[1], n = N - 1, K = K, Q = float(Q),
            d = d, l = l, u = u, s = s, C = C, T = T, opt = opt)
end

# ---------- Auto-teste: julia vrptw_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_vrptw(joinpath(@__DIR__, "toy_vrptw.txt"))
    @assert (toy.n, toy.K, toy.Q) == (6, 6, 11.0)
    @assert toy.d == [0, 3, 3, 3, 4, 4, 4] && toy.l[5] == 60 && toy.u[2] == 15
    @assert toy.C[1, 6] == 22.2 && toy.C[4, 5] == 32.3       # 0→(-3,22): 22.20; (30,0)→(0,12): 32.31
    @assert toy.T[2, 3] == 15.0                              # serviço 5 em 1 + 10 de viagem

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> endswith(f, ".txt"), readdir(dir))
    for f in files
        inst = read_vrptw(joinpath(dir, f))
        @assert inst.n == 100 && !isnan(inst.opt) "$f"
    end
    r25 = read_vrptw(joinpath(dir, "R101.txt"); n = 25)
    @assert r25.n == 25 && isnan(r25.opt)
    @assert read_vrptw(joinpath(dir, "C101.txt")).opt == 827.3
    println("OK: toy + $(length(files)) instâncias de Solomon lidas")
end
