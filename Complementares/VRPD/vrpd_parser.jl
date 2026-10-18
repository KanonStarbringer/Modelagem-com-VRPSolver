# ============================================================
#  Parser de instâncias do VRP-D da aula (1 caminhão + 1 drone), formato TSPLIB EUC_2D
# ============================================================
# Lê NODE_COORD_SECTION; o 1º nó é o depósito 0 e os demais são os clientes 1..n.
# Custo do caminhão e do drone: distância euclidiana ARREDONDADA (nint, como na TSPLIB).
# Parâmetros do drone: alcance R e custo por unidade α. Vêm das linhas DRONE_RANGE / DRONE_ALPHA
# do arquivo (a toy tem) ou dos keywords R e α, que têm prioridade.
#
# Uso:
#   include("vrpd_parser.jl")
#   inst = read_vrpd(joinpath(@__DIR__, "toy_vrpd.vrp"))                          # R = 20, α = 0.2
#   inst = read_vrpd(joinpath(@__DIR__, "Instancias", "eil51.tsp"); R = 20, α = 0.2)
#   inst.n, inst.C, inst.R, inst.α, inst.c[i+1, j+1]                               (i, j em 0..n)

function read_vrpd(path::AbstractString; R = nothing, α = nothing)
    hdr = Dict{String,String}()
    xy = Tuple{Float64,Float64}[]
    sec = false
    for ln in eachline(path)
        s = strip(ln)
        if startswith(s, "NODE_COORD_SECTION")
            sec = true
        elseif s == "EOF" || occursin(r"^[A-Z_]+_SECTION", s)
            sec = false
        elseif sec && !isempty(s)
            v = split(s); push!(xy, (parse(Float64, v[2]), parse(Float64, v[3])))
        elseif occursin(':', s)
            k, v = strip.(split(s, ':'; limit = 2)); hdr[k] = v
        end
    end
    get(hdr, "EDGE_WEIGHT_TYPE", "EUC_2D") == "EUC_2D" || error("$path: só EUC_2D")
    R = R === nothing ? parse(Float64, hdr["DRONE_RANGE"]) : Float64(R)
    α = α === nothing ? parse(Float64, hdr["DRONE_ALPHA"]) : Float64(α)
    N = length(xy)
    c = [floor(hypot(xy[i][1] - xy[j][1], xy[i][2] - xy[j][2]) + 0.5) for i in 1:N, j in 1:N]
    return (name = splitext(basename(path))[1], n = N - 1, C = collect(1:N-1), R = R, α = α, c = c, xy = xy)
end

# ---------- Auto-teste: julia vrpd_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_vrpd(joinpath(@__DIR__, "toy_vrpd.vrp"))
    @assert (toy.n, toy.R, toy.α) == (7, 20.0, 0.2) && toy.c[1, 5] == 9 && toy.c[2, 6] == 9   # nint(√89), nint(√89)

    dir = isdir(joinpath(@__DIR__, "Instancias")) ? joinpath(@__DIR__, "Instancias") :
          joinpath(@__DIR__, "..", "..", "..", "Artigos", "VRPD", "Instancias")
    files = filter(f -> endswith(f, ".tsp"), readdir(dir))
    dims = Dict("eil51" => 51, "berlin52" => 52, "st70" => 70, "eil76" => 76, "kroA100" => 100)
    for f in files
        inst = read_vrpd(joinpath(dir, f); R = 0, α = 0)
        @assert inst.n + 1 == dims[inst.name] f
    end
    println("OK: toy + $(length(files)) instâncias da TSPLIB lidas")
end
