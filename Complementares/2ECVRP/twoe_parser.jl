# ============================================================
#  Parser do Two-Echelon CVRP (formato unificado de U. Breunig, conjuntos 2 a 6)
# ============================================================
# Linhas com "!" são comentários. Depois deles, 4 linhas de números (separados por vírgula/espaço):
#   caminhões (1º nível):   nº total m1, capacidade Q1, custo/distância, custo fixo
#   city freighters (2º):   máx. por satélite ms, nº total m2, capacidade Q2, custo/distância, custo fixo
#   lojas:                  x,y do depósito; depois x,y de cada satélite
#   clientes:               x,y,demanda de cada cliente
# Custo/distância = 1 e custo fixo = 0 em todos os conjuntos: custo = distância euclidiana REAL.
# Vértices: clientes 1..n, satélites n+1..n+t (como no MDVRP e no CLRP); o depósito é o 0.
#
# Uso:
#   include("twoe_parser.jl")
#   inst = read_2ecvrp(joinpath(@__DIR__, "toy_2ecvrp.dat"))
#   inst = read_2ecvrp(joinpath(@__DIR__, "Instancias", "Set2a_E-n22-k4-s6-17.dat"))
#   inst.n, inst.t, inst.m1, inst.Q1, inst.ms, inst.m2, inst.Q2, inst.d[i], inst.C[i, j]   (i, j em 0..n+t)

function read_2ecvrp(path::AbstractString)
    lines = [l for l in eachline(path) if !startswith(l, "!") && !isempty(strip(l))]
    nums(l) = parse.(Float64, split(l, r"[,\s]+"; keepempty = false))
    tr, cf, st, cu = nums.(lines[1:4])
    length(st) % 2 == 0 && length(cu) % 3 == 0 || error("$path: linha de lojas ou de clientes incompleta")
    t, n = length(st) ÷ 2 - 1, length(cu) ÷ 3
    xy_cli = [(cu[3i-2], cu[3i-1]) for i in 1:n]
    xy_sat = [(st[2s+1], st[2s+2]) for s in 1:t]
    pts = vcat([(st[1], st[2])], xy_cli, xy_sat)                  # índice 1 = depósito 0
    C = [sqrt((a[1] - b[1])^2 + (a[2] - b[2])^2) for a in pts, b in pts]
    return (name = splitext(basename(path))[1], n = n, t = t,
            m1 = Int(tr[1]), Q1 = Int(tr[2]), ms = Int(cf[1]), m2 = Int(cf[2]), Q2 = Int(cf[3]),
            d = vcat(Int.(cu[3:3:end]), zeros(Int, t)),             # d = 0 nos satélites
            C = C, xy = pts)
end

# ---------- Auto-teste: julia twoe_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_2ecvrp(joinpath(@__DIR__, "toy_2ecvrp.dat"))
    @assert (toy.n, toy.t, toy.m1, toy.Q1, toy.ms, toy.m2, toy.Q2, sum(toy.d)) == (7, 2, 2, 15, 2, 3, 10, 22)
    @assert toy.C[0+1, 8+1] ≈ sqrt(19^2 + 11^2)                     # depósito (0,0) ao satélite 8 (19,11)

    e = read_2ecvrp(joinpath(@__DIR__, "Instancias", "Set2a_E-n22-k4-s6-17.dat"))
    @assert (e.n, e.t, e.m1, e.Q1, e.ms, e.m2, e.Q2) == (21, 2, 3, 15000, 4, 4, 6000)
    @assert e.C[6+1, 22+1] == 0                                     # o satélite 22 fica sobre o cliente 6

    files = filter(f -> endswith(f, ".dat"), readdir(joinpath(@__DIR__, "Instancias")))
    for f in files
        inst = read_2ecvrp(joinpath(@__DIR__, "Instancias", f))
        @assert all(inst.d .<= inst.Q2) f                              # todo cliente cabe num city freighter
        @assert sum(inst.d) <= inst.m1 * inst.Q1 f                     # os caminhões dão conta da demanda
    end
    println("OK: toy + $(length(files)) instâncias 2E-CVRP lidas (conjuntos 2 a 6)")
end
