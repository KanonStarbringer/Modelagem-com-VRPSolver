# ============================================================
#  Parser de instâncias CVRPLIB/TSPLIB (CVRP e DCVRP — set CMT)
# ============================================================
# Formato:
#   NAME : ...  DIMENSION : N  CAPACITY : Q
#   DISTANCE : D          (opcional — limite por rota; ausente = sem limite)
#   SERVICE_TIME : s      (opcional — tempo de serviço em cada cliente)
#   NODE_COORD_SECTION    id x y      (id 1 = depósito)
#   DEMAND_SECTION        id d
#   DEPOT_SECTION         1 / -1
#
# O id TSPLIB k vira o vértice k-1, então o depósito é o vértice 0, como no exemplo do professor.
#
# Uso:
#   include("dcvrp_parser.jl")
#   inst = read_cvrplib("toy_dcvrp.vrp")
#   inst.n, inst.Q, inst.D, inst.s, inst.d[i+1], inst.C[i+1, j+1]

function read_cvrplib(path::AbstractString)
    head = Dict{String,String}()
    coord = Dict{Int,Tuple{Float64,Float64}}()
    dem = Dict{Int,Float64}()
    depots = Int[]
    section = ""
    for line in eachline(path)
        t = split(strip(line))
        isempty(t) && continue
        if occursin(':', line) && !occursin("SECTION", line)
            k, v = strip.(split(line, ':'; limit = 2))
            head[k] = v
        elseif endswith(t[1], "SECTION") || t[1] == "EOF"
            section = t[1]
        elseif section == "NODE_COORD_SECTION"
            coord[parse(Int, t[1])] = (parse(Float64, t[2]), parse(Float64, t[3]))
        elseif section == "DEMAND_SECTION"
            dem[parse(Int, t[1])] = parse(Float64, t[2])
        elseif section == "DEPOT_SECTION"
            parse(Int, t[1]) == -1 || push!(depots, parse(Int, t[1]))
        end
    end

    N = parse(Int, head["DIMENSION"])
    get(head, "EDGE_WEIGHT_TYPE", "EUC_2D") == "EUC_2D" || error("$path: só EUC_2D é suportado")
    depots == [1] || error("$path: esperado depósito único no nó 1, veio $depots")
    length(coord) == N == length(dem) || error("$path: seções com tamanho diferente de DIMENSION = $N")

    n = N - 1
    xy = [coord[k] for k in 1:N]                  # xy[i+1] = vértice i
    d = [dem[k] for k in 1:N]                     # d[i+1];  d[1] = 0 (depósito)
    # ponytail: euclidiana sem arredondamento — é a convenção dos ótimos publicados do CMT (ex.: 555.43)
    C = [hypot(xy[i][1] - xy[j][1], xy[i][2] - xy[j][2]) for i in 1:N, j in 1:N]

    return (name = get(head, "NAME", path), n = n,
            Q = parse(Float64, head["CAPACITY"]),
            D = haskey(head, "DISTANCE") ? parse(Float64, head["DISTANCE"]) : Inf,
            s = haskey(head, "SERVICE_TIME") ? parse(Float64, head["SERVICE_TIME"]) : 0.0,
            d = d, coord = xy, C = C)
end

# ---------- Auto-teste: julia dcvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_cvrplib(joinpath(@__DIR__, "toy_dcvrp.vrp"))
    @assert (toy.n, toy.Q, toy.D, toy.s) == (4, 10.0, 80.0, 5.0)
    @assert toy.d == [0, 2, 2, 2, 2]
    @assert toy.C[3, 5] ≈ hypot(20, 20)            # cliente 2 (20,0) → cliente 4 (0,20)

    dir = joinpath(@__DIR__, "Instancias", "CMT")
    cmt = Dict(f => read_cvrplib(joinpath(dir, f)) for f in readdir(dir) if endswith(f, ".vrp"))
    @assert cmt["CMT1.vrp"].D == Inf && cmt["CMT1.vrp"].s == 0
    @assert (cmt["CMT6.vrp"].n, cmt["CMT6.vrp"].Q, cmt["CMT6.vrp"].D, cmt["CMT6.vrp"].s) == (50, 160.0, 200.0, 10.0)
    @assert cmt["CMT6.vrp"].C == cmt["CMT1.vrp"].C   # CMT6 = CMT1 + limite de rota
    println("OK: toy + $(length(cmt)) instâncias CMT lidas")
end
