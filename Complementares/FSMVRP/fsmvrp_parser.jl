# ============================================================
#  Parser FSMVRP — mesmo formato do HFVRP (Golden et al. 1984 / Taillard 1999)
# ============================================================
# ponytail: reaproveita read_hfvrp da pasta irmã ../HFVRP; aqui só fica o auto-teste das variantes FSM.
# Variantes (sufixo do arquivo): fsmfd = custo fixo f + variável α·ℓ (o exercício); fsmf = só fixo (α = 1);
# fsmd = só variável (f = 0). Em todas, max = n (frota livre).
#
# Uso:
#   include("fsmvrp_parser.jl")
#   inst = read_hfvrp("toy_fsmvrp.txt")
#   inst.K, inst.Q[k], inst.f[k], inst.α[k], inst.u[k] (= n), inst.d[i+1], inst.ℓ[i+1, j+1]

include(joinpath(@__DIR__, "..", "HFVRP", "hfvrp_parser.jl"))

# ---------- Auto-teste: julia fsmvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_hfvrp(joinpath(@__DIR__, "toy_fsmvrp.txt"))
    @assert (toy.n, toy.K, toy.Q, toy.f, toy.α, toy.u) == (6, 2, [7.0, 11.0], [10.0, 35.0], [1.0, 1.1], [6, 6])

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> occursin(r"fsm(fd|f|d)\.txt$", f), readdir(dir))
    for f in files
        inst = read_hfvrp(joinpath(dir, f))
        @assert all(==(inst.n), inst.u) "$f: frota deveria ser livre (max = n)"
        endswith(f, "fsmd.txt") ? @assert(all(==(0), inst.f), f) : @assert(all(>(0), inst.f), f)
        endswith(f, "fsmf.txt") && @assert(all(==(1), inst.α), f)
    end
    c13 = read_hfvrp(joinpath(dir, "c50_13fsmfd.txt"))
    @assert (c13.K, c13.f[1], c13.f[end], c13.α[end]) == (6, 20.0, 400.0, 3.2)
    println("OK: toy + $(length(files)) instâncias FSM (fsmfd, fsmf, fsmd) lidas")
end
