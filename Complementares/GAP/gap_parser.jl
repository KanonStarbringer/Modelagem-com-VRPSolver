# ============================================================
#  Parser do Generalized Assignment Problem (formato OR-Library / Yagiura)
# ============================================================
# Formato (um problema por arquivo): m (nº de agentes) n (nº de tarefas);
#   m linhas de n custos c_ij; m linhas de n consumos r_ij; m capacidades b_i.
# Instâncias de Yagiura (tipos C, D e E), todas de MINIMIZAÇÃO. Nome: tipo + m (2 dígitos) + n,
# por exemplo d10200 = tipo D, 10 agentes, 200 tarefas.
# Referências em ../referencias_cplex.csv (MIP de atribuição no CPLEX).
#
# Uso:
#   include("gap_parser.jl")
#   inst = read_gap(joinpath(@__DIR__, "toy_gap.txt"))
#   inst = read_gap(joinpath(@__DIR__, "Instancias", "d05100"))
#   inst.m, inst.n, inst.c[i, j], inst.r[i, j], inst.b[i]        (i em 1..m, j em 1..n)

function read_gap(path::AbstractString)
    v = parse.(Int, split(read(path, String)))
    m, n = v[1], v[2]
    length(v) == 2 + 2m * n + m || error("$path: esperava $(2 + 2m * n + m) números, li $(length(v))")
    c = permutedims(reshape(v[3:2+m*n], n, m))              # linha i = agente i
    r = permutedims(reshape(v[3+m*n:2+2m*n], n, m))
    b = v[3+2m*n:end]
    return (name = splitext(basename(path))[1], m = m, n = n, c = c, r = r, b = b)
end

# ---------- Auto-teste: julia gap_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_gap(joinpath(@__DIR__, "toy_gap.txt"))
    @assert (toy.m, toy.n, toy.b) == (3, 8, [6, 6, 6])
    @assert toy.c[1, :] == [2, 4, 3, 5, 4, 8, 1, 1] && toy.r[3, :] == [3, 2, 2, 4, 3, 6, 4, 2]

    dir = joinpath(@__DIR__, "Instancias")
    files = readdir(dir)
    for f in files
        inst = read_gap(joinpath(dir, f))
        @assert (inst.m, inst.n) == (parse(Int, f[2:3]), parse(Int, f[4:end])) f
        @assert all(any(inst.r[:, j] .<= inst.b) for j in 1:inst.n) f     # toda tarefa cabe em algum agente
    end
    println("OK: toy + $(length(files)) instâncias GAP (tipos C, D e E) lidas")
end
