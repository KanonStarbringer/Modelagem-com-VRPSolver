# ============================================================
#  Parser de instâncias SDVRP (formato de Cordeau, type 3; conjunto de Chao, Golden & Wasil, 1999)
# ============================================================
# Formato:
#   3 m n t                  m = veículos POR TIPO; n = clientes; t = tipos de veículo
#   D Q                      t linhas, uma por tipo (D = duração máx., 0 = sem limite; Q = capacidade)
#   i x y s q f a list       linhas 0..n (0 = depósito); a = nº de tipos permitidos; list = códigos dos tipos
#
# Código do tipo: bit string de t posições, da esquerda para a direita. Com t = 3: 4 = 100 → tipo 1,
# 2 = 010 → tipo 2, 1 = 001 → tipo 3. Custo = distância euclidiana real, igual para todos os tipos.
#
# Uso:
#   include("sdvrp_parser.jl")
#   inst = read_sdvrp("toy_sdvrp")
#   inst.n, inst.K (nº de tipos), inst.m, inst.Q[k], inst.comp[i] (tipos que podem visitar i), inst.d[i+1], inst.ℓ[i+1, j+1]

function read_sdvrp(path::AbstractString)
    L = [split(l) for l in readlines(path) if !isempty(strip(l))]
    typ, m, n, t = parse.(Int, L[1])
    typ == 3 || error("$path: type = $typ, esperado 3 (SDVRP)")
    DQ = [parse.(Float64, L[1+k]) for k in 1:t]
    all(r -> r[1] == 0, DQ) || error("$path: há limite de duração (D > 0); o exercício não tem")
    rows = L[t+2:t+2+n]
    [parse(Int, r[1]) for r in rows] == 0:n || error("$path: numeração fora de 0..n")
    xy = [(parse(Float64, r[2]), parse(Float64, r[3])) for r in rows]
    tipo(code) = t - (ndigits(code; base = 2) - 1)            # bit mais à esquerda = tipo 1
    comp = [Set(tipo.(parse.(Int, r[8:7+parse(Int, r[7])]))) for r in rows[2:end]]
    all(!isempty, comp) || error("$path: cliente sem tipo permitido")
    ℓ = [hypot(a[1] - b[1], a[2] - b[2]) for a in xy, b in xy]
    return (name = basename(path), n = n, K = t, m = m, Q = [r[2] for r in DQ],
            d = [parse(Float64, r[5]) for r in rows], comp = comp, ℓ = ℓ)
end

# ---------- Auto-teste: julia sdvrp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_sdvrp(joinpath(@__DIR__, "toy_sdvrp"))
    @assert (toy.n, toy.K, toy.m, toy.Q) == (6, 2, 1, [10.0, 12.0])
    @assert toy.d == [0, 3, 3, 3, 4, 4, 4]
    @assert toy.comp[1] == Set([2]) && toy.comp[4] == Set([1]) && toy.comp[2] == Set([1, 2])
    @assert toy.ℓ[1, 5] == 12

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> occursin(r"^p\d\d$", f), readdir(dir))
    for f in files
        inst = read_sdvrp(joinpath(dir, f))
        @assert sum(inst.d) <= inst.m * sum(inst.Q) "$f: frota não cobre a demanda"
        @assert all(i -> any(k -> inst.d[i+1] <= inst.Q[k], inst.comp[i]), 1:inst.n) "$f: cliente sem tipo compatível que comporte a demanda"
    end
    p07 = read_sdvrp(joinpath(dir, "p07"))
    @assert (p07.n, p07.K, p07.m, p07.Q) == (27, 3, 1, [150.0, 200.0, 250.0])
    @assert p07.comp[1] == Set([1, 2]) && p07.comp[5] == Set([1, 3])    # códigos "4 2" e "4 1"
    println("OK: toy + $(length(files)) instâncias SDVRP lidas")
end
