# ============================================================
#  Parser CVRPLIB para os exercícios complementares (CVRP, OVRP, VRP com custo fixo)
# ============================================================
# Reaproveita o read_cvrplib do DCVRP (pasta irmã ../DCVRP) e acrescenta:
#   arred : true  → custo EUC_2D arredondado (nint da TSPLIB), convenção dos ótimos da CVRPLIB (ex.: A-n32-k5 = 784)
#           false → custo real, convenção dos ótimos do OVRP de Letchford et al. (2007) (ex.: A-n32-k5 aberto = 487.306)
#   K     : nº de veículos do nome da instância (-kK); `nothing` se o nome não tiver
#   opt   : "Optimal value" do COMMENT da CVRPLIB (CVRP fechado, custo arredondado); NaN se não houver
#   f     : custo fixo por veículo (campo FIXED_COST, extensão da toy); 0.0 se ausente
#
# Uso:
#   include("cvrp_parser.jl")
#   inst = read_cvrp("toy_comp.vrp")                  # arredondado
#   inst = read_cvrp("A-n32-k5.vrp"; arred = false)   # real
#   inst.n, inst.Q, inst.K, inst.f, inst.d[i+1], inst.C[i+1, j+1]

include(joinpath(@__DIR__, "..", "DCVRP", "dcvrp_parser.jl"))

function read_cvrp(path::AbstractString; arred = true)
    inst = read_cvrplib(path)
    C = arred ? floor.(inst.C .+ 0.5) : inst.C
    txt = read(path, String)
    mK = match(r"-k(\d+)", basename(path))
    mO = match(r"Optimal value:\s*([\d.]+)", txt)
    mF = match(r"FIXED_COST\s*:\s*([\d.]+)", txt)
    return merge(inst, (C = C,
                        K = mK === nothing ? nothing : parse(Int, mK[1]),
                        opt = mO === nothing ? NaN : parse(Float64, mO[1]),
                        f = mF === nothing ? 0.0 : parse(Float64, mF[1])))
end

# ---------- Auto-teste: julia cvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_cvrp(joinpath(@__DIR__, "toy_comp.vrp"))
    @assert (toy.n, toy.Q, toy.f, toy.K) == (6, 11.0, 20.0, nothing)
    @assert toy.d == [0, 3, 3, 3, 4, 4, 4]
    @assert toy.C[1, 7] == 15 && toy.C[6, 7] == 19          # 0→(-14,6): 15.2 → 15; (-3,22)→(-14,6): 19.4 → 19

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> endswith(f, ".vrp"), readdir(dir))
    for f in files
        inst = read_cvrp(joinpath(dir, f))
        @assert inst.K !== nothing && sum(inst.d) <= inst.K * inst.Q "$f: K × Q não cobre a demanda"
    end
    a32 = read_cvrp(joinpath(dir, "A-n32-k5.vrp"))
    @assert (a32.n, a32.Q, a32.K, a32.opt) == (31, 100.0, 5, 784.0)
    println("OK: toy + $(length(files)) instâncias da CVRPLIB (A, B, E, P) lidas")
end
