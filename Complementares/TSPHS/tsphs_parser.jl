# ============================================================
#  Parser de instâncias TSPHS (formato de Barbosa, 2018; repositório mcroboredo/TSPHS_OPHS)
# ============================================================
# Formato:
#   h c L                 nº de hotéis, nº de clientes, duração máxima de cada trip
#   id x y                h linhas de hotéis (o 1º é o hotel de partida/chegada do tour)
#   id x y s              c linhas de clientes (s = tempo de serviço)
#
# Renumeração: hotéis 1..h (hotel 1 = início e fim do tour), clientes h+1..h+c.
# Distância euclidiana TRUNCADA em 1 casa, como no data.jl do professor: floor(sqrt(.), digits = 1).
# Duração de uma trip = viagem + serviço dos clientes visitados ≤ T. O objetivo é só a viagem.
#
# Uso:
#   include("tsphs_parser.jl")
#   inst = read_tsphs(joinpath(@__DIR__, "toy_tsphs.txt"))
#   inst = read_tsphs(joinpath(@__DIR__, "Instancias", "instancias_c50", "h05_c50_l150_09.txt"))
#   inst.H, inst.C, inst.N, inst.T, inst.s[i], inst.t[i, j]       (i, j em 1..N)

function read_tsphs(path::AbstractString)
    tok = split(read(path, String))
    h, c = parse(Int, tok[1]), parse(Int, tok[2])
    T = parse(Float64, tok[3])
    xy = Tuple{Float64,Float64}[]
    s = Float64[]
    k = 4
    for _ in 1:h                                    # id x y
        push!(xy, (parse(Float64, tok[k+1]), parse(Float64, tok[k+2]))); push!(s, 0.0); k += 3
    end
    for _ in 1:c                                    # id x y s
        push!(xy, (parse(Float64, tok[k+1]), parse(Float64, tok[k+2]))); push!(s, parse(Float64, tok[k+3])); k += 4
    end
    k == length(tok) + 1 || error("$path: sobraram $(length(tok) - k + 1) campos")
    N = h + c
    t = [i == j ? 0.0 : floor(hypot(xy[i][1] - xy[j][1], xy[i][2] - xy[j][2]), digits = 1) for i in 1:N, j in 1:N]
    return (name = splitext(basename(path))[1], H = collect(1:h), C = collect(h+1:N), N = N, T = T, s = s, t = t, xy = xy)
end

# ---------- Auto-teste: julia tsphs_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_tsphs(joinpath(@__DIR__, "toy_tsphs.txt"))
    @assert (toy.H, toy.C, toy.T) == (1:3, 4:9, 45.0)
    @assert toy.s == [0, 0, 0, 2, 2, 2, 2, 2, 2] && toy.t[1, 4] == 7.8 && toy.t[2, 6] == 7.2   # floor(√61, 1), floor(√52, 1)

    dir = isdir(joinpath(@__DIR__, "Instancias")) ? joinpath(@__DIR__, "Instancias") :
          joinpath(@__DIR__, "..", "..", "..", "Artigos", "TSPHS", "Instancias")
    files = [joinpath(dir, sub, f) for sub in readdir(dir) for f in readdir(joinpath(dir, sub))]
    for f in files
        inst = read_tsphs(f)
        m = match(r"h(\d+)_c(\d+)_l(\d+)", f)
        @assert (length(inst.H), length(inst.C), inst.T) == (parse(Int, m[1]), parse(Int, m[2]), parse(Float64, m[3])) f
    end
    b = read_tsphs(joinpath(dir, "instancias_c50", "h05_c50_l150_09.txt"))
    @assert sum(b.s) == 500 && b.t == b.t'
    println("OK: toy + $(length(files)) instâncias de Barbosa (2018) lidas")
end
