# ============================================================
#  Parser de instâncias E-VRP com recarga completa (G-VRP de Erdoğan & Miller-Hooks, 2012; versão da UNICAMP)
# ============================================================
# Formato (seções separadas por ';'):
#   Vehicle:  Average speed (ξ), Time limit (T), Fuel comsumption rate (ρ), Fuel Capacity (β)
#   Depot: / Customers: / AFSs:   ID;X;Y;Service Time      (nas AFSs, Service Time = tempo de recarga g_s)
#
# Convenção das soluções publicadas (conferida em 107 delas): distância nint, c = ⌊dist + 0.5⌋;
#   energia e_ij = ρ·c_ij; tempo t_ij = c_ij / ξ; serviço contado no vértice de chegada.
# Sem capacidade de carga (Q = ∞, d = 0). Pastas: consec = estações seguidas permitidas (o exercício);
#   non-consec = arcos estação→estação proibidos (G-VRP original).
#
# Uso:
#   include("evrp_parser.jl")
#   inst = read_evrp("toy_evrp.vrp")
#   inst.C (clientes), inst.S (estações), inst.β, inst.T, inst.ρ, inst.ξ, inst.s[v+1], inst.c[v+1, w+1]

function read_evrp(path::AbstractString)
    head = Dict{String,Float64}(); rows = Dict{Int,Tuple{Float64,Float64,Float64}}(); kind = Dict{Int,String}()
    sec = ""
    for line in strip.(readlines(path))
        isempty(line) && continue
        if endswith(line, ":") && !occursin(';', line)
            sec = line[1:end-1]
        elseif sec == "Vehicle"
            k, v = split(line, ":;"); head[k] = parse(Float64, v)
        elseif !startswith(line, "ID")
            t = split(line, ';'); v = parse(Int, t[1])
            rows[v] = (parse(Float64, t[2]), parse(Float64, t[3]), parse(Float64, t[4])); kind[v] = sec
        end
    end
    N = length(rows)
    sort(collect(keys(rows))) == 0:N-1 || error("$path: ids fora de 0..N-1")
    kind[0] == "Depot" || error("$path: depósito deveria ser o id 0")
    c = [floor(hypot(rows[a][1] - rows[b][1], rows[a][2] - rows[b][2]) + 0.5) for a in 0:N-1, b in 0:N-1]
    return (name = splitext(basename(path))[1], N = N,
            C = sort([v for (v, k) in kind if k == "Customers"]), S = sort([v for (v, k) in kind if k == "AFSs"]),
            ξ = head["Average speed"], T = head["Time limit"], ρ = head["Fuel comsumption rate"], β = head["Fuel Capacity"],
            s = [rows[v][3] for v in 0:N-1], c = c)
end

# ---------- Auto-teste: julia evrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_evrp(joinpath(@__DIR__, "toy_evrp.vrp"))
    @assert (toy.C, toy.S, toy.β, toy.T, toy.ξ, toy.ρ) == ([1, 2, 3], [4, 5], 26.0, 80.0, 1.0, 1.0)
    @assert toy.c[1, 5] == 20 && toy.c[4, 5] == 9 && toy.s[5] == 10       # 0→4: 20.4 → 20; 3→4: 9

    dir = joinpath(@__DIR__, "Instancias")
    files = [joinpath(sub, f) for sub in ("consec", "non-consec") for f in readdir(joinpath(dir, sub)) if endswith(f, ".vrp")]
    for f in files
        inst = read_evrp(joinpath(dir, f))
        m = match(r"(\d+)c(\d+)f", f)
        @assert (length(inst.C), length(inst.S)) == (parse(Int, m[1]), parse(Int, m[2])) "$f: nome não bate com o conteúdo"
    end
    p16 = read_evrp(joinpath(dir, "consec", "mlsa_flow_10c5f23.000000B-P-n16-k8.vrp"))
    @assert (length(p16.C), length(p16.S), p16.β, p16.T, p16.ξ) == (10, 5, 23.0, 10.0, 51.0)
    println("OK: toy + $(length(files)) instâncias G-VRP lidas")
end
