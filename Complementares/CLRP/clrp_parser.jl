# ============================================================
#  Parser do Capacitated Location-Routing Problem (formato de Prodhon)
# ============================================================
# Formato (números separados por espaço/tab/linha):
#   nº de clientes n; nº de depósitos t;
#   coordenadas dos t depósitos; coordenadas dos n clientes;
#   capacidade do veículo Q; capacidades dos depósitos W;
#   demandas dos clientes; custos de abertura dos depósitos; custo fixo por rota F;
#   código: 0 = custos inteiros, ceil(100 · distância euclidiana); 1 = custos reais (distância).
#   ceil, e não o "truncado" do arquivo de formato: é a convenção das BKS (conferido na coord20-5-1).
# Prodhon (Prins et al., 2006): código 0, F = 1000.  Barreto (2007): código 1, F = 0.
# Vértices: clientes 1..n, depósitos n+1..n+t (como no MDVRP).
#
# Uso:
#   include("clrp_parser.jl")
#   inst = read_clrp(joinpath(@__DIR__, "toy_clrp.dat"))
#   inst = read_clrp(joinpath(@__DIR__, "Instancias", "Prodhon", "coord20-5-1.dat"))
#   inst.n, inst.t, inst.Q, inst.W[k], inst.f[k], inst.F, inst.d[i], inst.C[i, j]

function read_clrp(path::AbstractString)
    v = parse.(Float64, split(read(path, String)))
    n, t = Int(v[1]), Int(v[2])
    length(v) == 5 + 4t + 3n || error("$path: esperava $(5 + 4t + 3n) números, li $(length(v))")
    k = 2
    xy_dep = [(v[k+2i-1], v[k+2i]) for i in 1:t];  k += 2t
    xy_cli = [(v[k+2i-1], v[k+2i]) for i in 1:n];  k += 2n
    Q = Int(v[k+1]);                               k += 1
    W = Int.(v[k+1:k+t]);                          k += t
    d = vcat(Int.(v[k+1:k+n]), zeros(Int, t));     k += n      # d = 0 nos depósitos
    f = v[k+1:k+t];                                k += t
    F, inteiro = v[k+1], v[k+2] == 0
    pts = vcat(xy_cli, xy_dep)
    dist(a, b) = sqrt((a[1] - b[1])^2 + (a[2] - b[2])^2)
    C = [inteiro ? ceil(100 * dist(a, b)) : dist(a, b) for a in pts, b in pts]
    return (name = splitext(basename(path))[1], n = n, t = t, Q = Q, W = W, d = d,
            f = f, F = F, C = C, inteiro = inteiro, xy = pts)
end

# ---------- Auto-teste: julia clrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_clrp(joinpath(@__DIR__, "toy_clrp.dat"))
    @assert (toy.n, toy.t, toy.Q, toy.W, toy.F, sum(toy.d)) == (8, 3, 20, [25, 30, 35], 1000, 58)
    @assert toy.C[1, 9] == ceil(100 * sqrt(12^2 + 3^2))      # cliente 1 (19,15) ao depósito 1 (7,18)

    p = read_clrp(joinpath(@__DIR__, "Instancias", "Prodhon", "coord20-5-1.dat"))
    @assert (p.n, p.t, p.Q, p.F, p.inteiro) == (20, 5, 70, 1000, true) && p.f[1] == 10841

    files = [(set, f) for set in ["Prodhon", "Barreto"] for f in readdir(joinpath(@__DIR__, "Instancias", set))]
    for (set, f) in files
        inst = read_clrp(joinpath(@__DIR__, "Instancias", set, f))
        @assert all(inst.d .<= inst.Q) f                            # todo cliente cabe num veículo
        @assert sum(inst.d) <= sum(inst.W) f                        # os depósitos dão conta da demanda
        @assert inst.inteiro == (set == "Prodhon") f
    end
    println("OK: toy + $(length(files)) instâncias CLRP lidas (Prodhon e Barreto)")
end
