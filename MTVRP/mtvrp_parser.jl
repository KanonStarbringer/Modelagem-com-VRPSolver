# ============================================================
#  Parser de instâncias MTVRP (Taillard, Laporte & Gendreau, 1996)
# ============================================================
# Uma instância MTVRP = arquivo CVRP do CMT (coordenadas, demandas, Q)
#                      + m (nº de veículos) + T (tempo máximo por veículo).
# Os pares (m, T) do benchmark ficam em mtvrp_instances.csv.
# A toy traz m e T no próprio arquivo, nos campos extras VEHICLES e TMAX.
#
# Reaproveita o read_cvrplib do DCVRP (pasta irmã ../DCVRP).
#
# Uso:
#   include("mtvrp_parser.jl")
#   toy  = read_mtvrp("toy_mtvrp.vrp")                       # m, T do arquivo
#   inst = read_mtvrp("CMT1.vrp"; m = 2, T = 275)            # m, T da tabela
#   inst.n, inst.Q, inst.m, inst.T, inst.d[i+1], inst.C[i+1, j+1]
#   tab  = mtvrp_table()                                     # linhas do CSV

include(joinpath(@__DIR__, "..", "DCVRP", "dcvrp_parser.jl"))

function read_mtvrp(path::AbstractString; m = nothing, T = nothing)
    inst = read_cvrplib(path)
    (inst.D == Inf && inst.s == 0) ||
        error("$path: MTVRP usa a versão CVRP do CMT (sem DISTANCE/SERVICE_TIME)")
    lines = readlines(path)
    function field(key)
        for l in lines
            startswith(strip(l), key) && return parse(Float64, split(l, ':')[2])
        end
        error("$path: sem campo $key — passe $(key == "VEHICLES" ? "m" : "T") como argumento")
    end
    m = m === nothing ? Int(field("VEHICLES")) : m
    T = T === nothing ? field("TMAX") : Float64(T)
    return merge(inst, (m = m, T = T))
end

# Tabela do benchmark (Mingozzi, Roberti & Toth, 2013 — tabelas 5.1–5.3 da tese de Roberti)
function mtvrp_table(path = joinpath(@__DIR__, "mtvrp_instances.csv"))
    rows = split.(readlines(path)[2:end], ',')
    return [(base = r[1], n = parse(Int, r[2]), fator = parse(Float64, r[3]),
             m = parse(Int, r[4]), T = parse(Float64, r[5]),
             z = isempty(r[6]) ? NaN : parse(Float64, r[6]), status = r[7], nota = r[8])
            for r in rows if !isempty(r[1])]
end

# ---------- Auto-teste: julia mtvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_mtvrp(joinpath(@__DIR__, "toy_mtvrp.vrp"))
    @assert (toy.n, toy.Q, toy.m, toy.T) == (6, 10.0, 2, 54.0)
    @assert toy.d == [0, 5, 5, 5, 5, 5, 5]

    # T = round(fator · z_RT / m), com z_RT = custo CVRP de Rochat & Taillard (1995)
    zRT = Dict("CMT1" => 524.61, "CMT2" => 835.26, "CMT3" => 826.14,
               "CMT11" => 1042.11, "CMT12" => 819.56)
    dir = joinpath(@__DIR__, "..", "DCVRP", "Instancias", "CMT")
    tab = mtvrp_table()
    for r in tab
        inst = read_mtvrp(joinpath(dir, r.base * ".vrp"); m = r.m, T = r.T)
        @assert inst.n == r.n "$(r.base): n = $(inst.n) ≠ $(r.n)"
        @assert r.T == round(r.fator * zRT[r.base] / r.m) "$(r.base) m=$(r.m): T não bate com a fórmula"
    end
    println("OK: toy + $(length(tab)) instâncias do benchmark ($(count(r -> r.status == "opt", tab)) com ótimo conhecido)")
end
