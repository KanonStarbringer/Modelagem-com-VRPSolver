# ============================================================
#  Parser de instâncias GVRP (formato TSPLIB com clusters)
# ============================================================
# Formato:
#   DIMENSION : N   VEHICLES : m   GVRP_SETS : p+1   CAPACITY : Q   EDGE_WEIGHT_TYPE : EUC_2D
#   NODE_COORD_SECTION    id x y           (id 1 = depósito)
#   GVRP_SET_SECTION      k id id ... -1   (cluster k e seus nós; o cluster do depósito só tem o nó 1)
#   DEMAND_SECTION        k q_k            (demanda do CLUSTER, atendida por qualquer nó dele)
#   DEPOT_SECTION         1 / -1
#
# O id TSPLIB k vira o vértice k-1 (depósito = 0). Os clusters de clientes são renumerados 1..p.
#
# Uso:
#   include("gvrp_parser.jl")
#   inst = read_gvrp("toy_gvrp.gvrp")
#   inst.n, inst.m, inst.Q, inst.p, inst.clusters[g], inst.cl[i+1], inst.d[i+1], inst.C[i+1, j+1]

function read_gvrp(path::AbstractString)
    head = Dict{String,String}()
    coord = Dict{Int,Tuple{Float64,Float64}}()
    sets = Dict{Int,Vector{Int}}()
    dem = Dict{Int,Float64}()
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
        elseif section == "GVRP_SET_SECTION"
            sets[parse(Int, t[1])] = [parse(Int, v) - 1 for v in t[2:end] if v != "-1"]
        elseif section == "DEMAND_SECTION"
            dem[parse(Int, t[1])] = parse(Float64, t[2])
        end
    end

    N = parse(Int, head["DIMENSION"])
    length(coord) == N || error("$path: NODE_COORD_SECTION com $(length(coord)) nós, DIMENSION = $N")
    ks = sort([k for k in keys(sets) if sets[k] != [0]])       # clusters de clientes
    sort(vcat([sets[k] for k in ks]...)) == collect(1:N-1) ||
        error("$path: os clusters não particionam os clientes 1..$(N-1)")

    clusters = [sets[k] for k in ks]                            # clusters[g] = vértices do cluster g
    cl = zeros(Int, N)                                          # cl[i+1] = cluster do vértice i (0 = depósito)
    d = zeros(Float64, N)                                       # d[i+1] = demanda do cluster de i
    for (g, k) in enumerate(ks), v in sets[k]
        cl[v+1] = g
        d[v+1] = dem[k]
    end
    xy = [coord[k] for k in 1:N]
    # ponytail: EUC_2D da TSPLIB (arredonda para o inteiro mais próximo), convenção das instâncias A/B/P
    C = [floor(hypot(a[1] - b[1], a[2] - b[2]) + 0.5) for a in xy, b in xy]   # nint da TSPLIB

    return (name = get(head, "NAME", path), n = N - 1,
            m = parse(Int, head["VEHICLES"]), Q = parse(Float64, head["CAPACITY"]),
            p = length(ks), clusters = clusters, cl = cl, d = d, coord = xy, C = C)
end

# ---------- Auto-teste: julia gvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_gvrp(joinpath(@__DIR__, "toy_gvrp.gvrp"))
    @assert (toy.n, toy.m, toy.Q, toy.p) == (9, 4, 10.0, 4)
    @assert toy.clusters == [[1, 2], [3, 4], [5, 6, 7], [8, 9]]
    @assert toy.cl == [0, 1, 1, 2, 2, 3, 3, 3, 4, 4]
    @assert toy.d == [0, 4, 4, 5, 5, 3, 3, 3, 6, 6]
    @assert toy.C[1, 2] == 10 && toy.C[1, 7] == 17         # depósito → (10,0) e → (-14,10): 17.2 → 17
    println("OK: toy lida ($(toy.p) clusters, $(toy.n) clientes)")
end
