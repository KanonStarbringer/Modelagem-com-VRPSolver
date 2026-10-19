# ============================================================
#  Parser do Capacitated Arc Routing Problem (formato do CARPData.jl, R. Martinelli)
# ============================================================
# Formato: nº de vértices; nº de arestas; uma linha "de para custo demanda" por aresta
# (vértices de 0 a nv-1, depósito = 0; demanda 0 = aresta não requerida);
# nº de veículos; capacidade; limite inferior e superior conhecidos.
# Grafo NÃO direcionado. Frota livre nos benchmarks (o nº de veículos é só informativo).
# Referências em ../referencias.csv (lb = ub: ótimo provado).
#
# Uso:
#   include("carp_parser.jl")
#   inst = read_carp(joinpath(@__DIR__, "toy_carp.dat"))
#   inst = read_carp(joinpath(@__DIR__, "Instancias", "gdb1.dat"))
#   inst.nv, inst.Q, inst.R[k] = (u, v, c, d), inst.sp[i+1, j+1]     (caminho mínimo de i a j)

function read_carp(path::AbstractString)
    v = parse.(Int, split(read(path, String)))
    nv, ne = v[1], v[2]
    length(v) == 2 + 4ne + 4 || error("$path: esperava $(2 + 4ne + 4) números, li $(length(v))")
    E = [Tuple(v[3+4k:6+4k]) for k in 0:ne-1]             # (u, v, custo, demanda)
    K, Q, lb, ub = v[end-3:end]
    sp = fill(typemax(Int) ÷ 4, nv, nv)                     # Floyd-Warshall, índices 1-based
    for i in 1:nv
        sp[i, i] = 0
    end
    for (a, b, c, _) in E
        sp[a+1, b+1] = min(sp[a+1, b+1], c)
        sp[b+1, a+1] = min(sp[b+1, a+1], c)
    end
    for k in 1:nv, i in 1:nv, j in 1:nv
        sp[i, j] = min(sp[i, j], sp[i, k] + sp[k, j])
    end
    return (name = splitext(basename(path))[1], nv = nv, E = E, R = filter(e -> e[4] > 0, E),
            K = K, Q = Q, lb = lb, ub = ub, sp = sp)
end

# ---------- Auto-teste: julia carp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_carp(joinpath(@__DIR__, "toy_carp.dat"))
    @assert (toy.nv, length(toy.E), length(toy.R), toy.Q, toy.lb) == (6, 9, 6, 6, 52)
    @assert toy.sp[5+1, 0+1] == 9 && toy.sp[1+1, 0+1] == 3          # 5 → 0 direto; 1 → 0 pela aresta (0, 1)

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> endswith(f, ".dat"), readdir(dir))
    for f in files
        inst = read_carp(joinpath(dir, f))
        @assert maximum(inst.sp) < typemax(Int) ÷ 4 f                 # grafo conexo
        @assert all(e[4] <= inst.Q for e in inst.R) f                 # toda aresta cabe num veículo
        @assert inst.lb <= inst.ub f
    end
    println("OK: toy + $(length(files)) instâncias CARP lidas (gdb, val, egl e kshs)")
end
