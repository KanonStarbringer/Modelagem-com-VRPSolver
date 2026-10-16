# ============================================================
#  Parser de instâncias do PTP capacitado (CPTP — Archetti et al., 2009/2013)
# ============================================================
# Formato (.cri):
#   NAME ...   MAXVEHICLES m   MAXCAPACITY Q   MAXTIME T   DEPOT x y   CUSTOMERS n
#   CUSTOMERDATA
#   x y d s p          n linhas: coordenadas, demanda, tempo de serviço, lucro
#
# O depósito é o vértice 0 e o k-ésimo cliente é o vértice k.
# MAXTIME e o tempo de serviço s são do CTOP; o CPTP ignora os dois.
#
# Uso:
#   include("ptp_parser.jl")
#   inst = read_ptp("toy_ptp.cri")
#   inst.n, inst.m, inst.Q, inst.d[i+1], inst.p[i+1], inst.C[i+1, j+1]

function read_ptp(path::AbstractString)
    L = [split(l) for l in eachline(path) if !isempty(strip(l))]
    k = findfirst(l -> l[1] == "CUSTOMERDATA", L)
    k === nothing && error("$path: sem CUSTOMERDATA")
    h = Dict(l[1] => l[2:end] for l in L[1:k-1])
    n = parse(Int, h["CUSTOMERS"][1])
    rows = [parse.(Float64, l) for l in L[k+1:end]]
    length(rows) == n || error("$path: esperado $n clientes, vieram $(length(rows))")
    xy = [(parse(Float64, h["DEPOT"][1]), parse(Float64, h["DEPOT"][2])); [(r[1], r[2]) for r in rows]]
    # ponytail: euclidiana sem arredondamento, como no CMT de onde as instâncias vêm
    C = [hypot(a[1] - b[1], a[2] - b[2]) for a in xy, b in xy]
    return (name = splitext(basename(path))[1], n = n,
            m = parse(Int, h["MAXVEHICLES"][1]), Q = parse(Float64, h["MAXCAPACITY"][1]),
            d = [0.0; [r[3] for r in rows]], p = [0.0; [r[5] for r in rows]],
            coord = xy, C = C)
end

# ---------- Auto-teste: julia ptp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_ptp(joinpath(@__DIR__, "toy_ptp.cri"))
    @assert (toy.n, toy.m, toy.Q) == (6, 6, 10.0)
    @assert toy.d == [0, 6, 6, 4, 9, 3, 9] && toy.p == [0, 30, 30, 25, 10, 8, 10]
    @assert toy.C[1, 2] == 10.0                     # depósito (0,0) → cliente 1 (10,0)

    dir = joinpath(@__DIR__, "Instancias")
    insts = [read_ptp(joinpath(dir, f)) for f in readdir(dir) if endswith(f, ".cri")]
    @assert length(insts) == 10
    p06 = read_ptp(joinpath(dir, "p06.cri"))        # = CMT1 + lucros
    @assert (p06.n, p06.m, p06.Q, sum(p06.d), sum(p06.p)) == (50, 10, 160.0, 777.0, 761.0)
    println("OK: toy + $(length(insts)) instâncias de Archetti et al. lidas")
end
