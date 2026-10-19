# ============================================================
#  Parser de instâncias do Cutting Stock (formato CSP da BPPLIB)
# ============================================================
# Formato: m (nº de TIPOS de item), Q (largura do rolo) e m linhas "w_t d_t" (largura e demanda do tipo t).
# São as mesmas instâncias do BPP, agregadas: itens de mesmo peso viram um tipo com demanda d_t.
# Ótimos em ../otimos.csv (BPPLIB: Delorme, Iori & Martello, 2018), iguais aos do BPP.
#
# Uso:
#   include("csp_parser.jl")
#   inst = read_csp(joinpath(@__DIR__, "toy_csp.txt"))
#   inst = read_csp(joinpath(@__DIR__, "Instancias", "Falkenauer_U", "Falkenauer_u120_00.txt"))
#   inst.m, inst.n, inst.Q, inst.w[t], inst.d[t]                    (t em 1..m; n = Σ d_t)

function read_csp(path::AbstractString)
    v = parse.(Int, split(read(path, String)))
    m, Q = v[1], v[2]
    length(v) == 2 + 2m || error("$path: esperava $m tipos, li $((length(v) - 2) ÷ 2)")
    w, d = v[3:2:end], v[4:2:end]
    allunique(w) || error("$path: larguras repetidas (tipos não agregados)")
    maximum(w) <= Q || error("$path: item maior que o rolo")
    return (name = splitext(basename(path))[1], m = m, n = sum(d), Q = Q, w = w, d = d)
end

# ---------- Auto-teste: julia csp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_csp(joinpath(@__DIR__, "toy_csp.txt"))
    @assert (toy.m, toy.n, toy.Q, toy.w, toy.d) == (4, 10, 10, [7, 5, 4, 3], [2, 3, 2, 3])

    dir = isdir(joinpath(@__DIR__, "Instancias")) ? joinpath(@__DIR__, "Instancias") :
          joinpath(@__DIR__, "..", "..", "..", "Artigos", "CSP", "Instancias")
    csv = isfile(joinpath(@__DIR__, "otimos.csv")) ? joinpath(@__DIR__, "otimos.csv") : joinpath(dir, "..", "otimos.csv")
    rows = [split(l, ',') for l in readlines(csv)[2:end]]
    for r in rows
        inst = read_csp(joinpath(dir, r[1], r[2] * ".txt"))
        @assert (inst.m, inst.n, inst.Q) == parse.(Int, (r[3], r[4], r[5])) r[2]
        @assert cld(sum(inst.w .* inst.d), inst.Q) == parse(Int, r[7]) <= parse(Int, r[6]) r[2]
    end
    println("OK: toy + $(length(rows)) instâncias CSP da BPPLIB lidas (Falkenauer U/T, Schwerin 1/2 e Hard28)")
end
