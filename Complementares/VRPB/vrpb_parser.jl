# ============================================================
#  Parser de instâncias VRPB (formatos usados em Queiroga et al., 2020)
# ============================================================
# Dois formatos:
#   .vrpb  TSPLIB estendido (Toth & Vigo e X): BACKHAUL_SECTION lista os backhauls; VEHICLES = frota fixa
#          (ausente nas X = frota livre). Custo EUC_2D arredondado, ⌊dist + 0.5⌋ (ótimos inteiros, ex.: EIL22_50 = 371).
#   .xml   VRP-REP (Goetschalckx & Jacobs-Blecha, GJB): type 0/1/2 = depósito/linehaul/backhaul; frota fixa.
#          Custo euclidiano REAL (ex.: GA1 = 229885.65).
#          ATENÇÃO: o XML marca o último linehaul como backhaul (GA1 vem 19/6; o artigo usa 20/5).
#          O parser move o primeiro backhaul para os linehauls, como no Experimento VRPB.
#
# Vértices renumerados: 0 = depósito, 1..nL = linehauls (L), nL+1..nL+nB = backhauls (B).
#
# Uso:
#   include("vrpb_parser.jl")
#   inst = read_vrpb("toy_vrpb.vrpb")
#   inst.L, inst.B, inst.Q, inst.K (nothing = frota livre), inst.d[i+1], inst.C[i+1, j+1]

function read_vrpb(path::AbstractString)
    txt = read(path, String)
    if endswith(lowercase(path), ".xml")
        nodes = [(parse(Int, m[2]), parse(Int, m[1]), parse(Float64, m[3]), parse(Float64, m[4])) for m in
                 eachmatch(r"(?s)<node\s+type=\"(\d+)\"\s+id=\"(\d+)\">\s*<cx>([^<]+)</cx>\s*<cy>([^<]+)</cy>", txt)]
        veh = match(r"(?s)<vehicle_profile\s+number=\"(\d+)\"[^>]*>.*?<capacity>([^<]+)</capacity>", txt)
        K, Q = parse(Int, veh[1]), parse(Float64, veh[2])
        dem = Dict(parse(Int, m[1]) => parse(Float64, m[2]) for m in
                   eachmatch(r"(?s)<request\s+node=\"(\d+)\"[^>]*>\s*<quantity>([^<]+)</quantity>", txt))
        xy = Dict(id => (x, y) for (id, _, x, y) in nodes)
        dep = only([id for (id, t, _, _) in nodes if t == 0])
        Lid = sort([id for (id, t, _, _) in nodes if t == 1])
        Bid = sort([id for (id, t, _, _) in nodes if t == 2])
        maximum(Lid) < minimum(Bid) || error("$path: fronteira L/B não contígua")
        push!(Lid, popfirst!(Bid))                 # correção da fronteira (ver cabeçalho)
        arred = false
    else
        head = Dict(strip(k) => strip(v) for (k, v) in (split(l, ':'; limit = 2) for l in split(txt, '\n') if occursin(':', l)))
        sec(name) = split(strip(match(Regex("$name\\s*\\n(.*?)\\n\\s*(?:[A-Z_]+_SECTION|EOF)", "s"), txt)[1]), '\n')
        xy = Dict(parse(Int, t[1]) => (parse(Float64, t[2]), parse(Float64, t[3])) for t in split.(sec("NODE_COORD_SECTION")))
        dem = Dict(parse(Int, t[1]) => parse(Float64, t[2]) for t in split.(sec("DEMAND_SECTION")))
        dep = only(filter(!=(-1), parse.(Int, sec("DEPOT_SECTION"))))
        Bid = sort(filter(!=(-1), parse.(Int, sec("BACKHAUL_SECTION"))))
        Lid = sort(setdiff(collect(keys(xy)), [dep; Bid]))
        K = haskey(head, "VEHICLES") ? parse(Int, head["VEHICLES"]) : nothing
        Q = parse(Float64, head["CAPACITY"])
        arred = true
    end
    ids = [dep; Lid; Bid]                          # ids[i+1] = id original do vértice i
    nL, nB = length(Lid), length(Bid)
    dist(a, b) = (h = hypot(xy[a][1] - xy[b][1], xy[a][2] - xy[b][2]); arred ? floor(h + 0.5) : h)
    C = [dist(a, b) for a in ids, b in ids]
    return (name = splitext(basename(path))[1], nL = nL, nB = nB, L = collect(1:nL), B = collect(nL+1:nL+nB),
            Q = Q, K = K, d = [get(dem, a, 0.0) for a in ids], C = C, ids = ids)
end

# ---------- Auto-teste: julia vrpb_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_vrpb(joinpath(@__DIR__, "toy_vrpb.vrpb"))
    @assert (toy.nL, toy.nB, toy.Q, toy.K) == (3, 3, 10.0, 3)
    @assert toy.d == [0, 3, 3, 3, 5, 5, 5]
    @assert toy.C[1, 2] == 21 && toy.C[5, 1] == 19            # 0→(-6,20): 20.88 → 21; (-16,-10)→0: 18.87 → 19

    dir = joinpath(@__DIR__, "Instancias")
    tv = filter(f -> endswith(f, ".vrpb"), readdir(joinpath(dir, "Instancias TV convertidas")))
    gjb = filter(f -> endswith(f, ".xml"), readdir(joinpath(dir, "Instancias GJB")))
    for f in tv
        inst = read_vrpb(joinpath(dir, "Instancias TV convertidas", f))
        @assert inst.K !== nothing && sum(inst.d[2:inst.nL+1]) <= inst.K * inst.Q "$f"
    end
    for f in gjb
        inst = read_vrpb(joinpath(dir, "Instancias GJB", f))
        @assert sum(inst.d[2:inst.nL+1]) <= inst.K * inst.Q && sum(inst.d[inst.nL+2:end]) <= inst.K * inst.Q "$f"
    end
    e22 = read_vrpb(joinpath(dir, "Instancias TV convertidas", "EIL22_50.vrpb"))
    @assert (e22.nL, e22.nB, e22.K, e22.Q) == (11, 10, 3, 6000.0)
    ga1 = read_vrpb(joinpath(dir, "Instancias GJB", "GA1.xml"))
    @assert (ga1.nL, ga1.nB, ga1.K) == (20, 5, 8)
    println("OK: toy + $(length(tv)) TV + $(length(gjb)) GJB lidas")
end
