# ============================================================
#  Parser de instâncias m-CTP (formato .ctp de Oliveira, Pessoa & Roboredo)
# ============================================================
# Formato (tokens separados por espaço):
#   NOME
#   |O| |C| |M| p q         |M| conta o depósito; q = maxL + 2·max c(0,i) (o parser recalcula a partir do maxL)
#   i j c_ij                arestas entre os vértices roteáveis 0..|M|+|O|-1
#   k  a_1 ... a_|C|        matriz de cobertura: uma linha por OPCIONAL (a = 1 se cobre o cliente)
#   r_1 ... r_|C|           nº de coberturas exigidas (só no multi-covering; ignorado aqui)
#   NODE_COORD_SECTION ... EOF
#
# Vértices roteáveis: 0 = depósito, 1..nM = obrigatórios (T \ {0}), nM+1..nM+nO = opcionais (V \ T).
# Clientes (W) não entram no grafo: são indexados à parte, k = 1..nC.
# Comprimento máximo da rota (convenção dos autores): q = maxL + 2·max_i c(0,i).
# O sufixo -250 / -500 do nome do arquivo é o maxL. Sem maxL: q = Inf (m-CTP-p).
#
# Uso:
#   include("mctp_parser.jl")
#   inst = read_mctp("toy_mctp.ctp"; maxL = 10)
#   inst.R, inst.mand, inst.opt, inst.nC, inst.p, inst.q, inst.C[i+1, j+1], inst.cover[k]

function read_mctp(path::AbstractString; maxL = Inf)
    t = split(read(path, String))
    nO, nC, M1, p = parse.(Int, t[2:5])
    R = nO + M1                                    # roteáveis: 0..R-1
    C = zeros(Float64, R, R)
    pos = 7                                        # primeiro token da 1ª aresta
    for i in 0:R-1, j in i+1:R-1
        (parse(Int, t[pos]), parse(Int, t[pos+1])) == (i, j) || error("$path: aresta ($i,$j) fora de ordem")
        C[i+1, j+1] = C[j+1, i+1] = parse(Float64, t[pos+2])
        pos += 3
    end
    opt = collect(M1:R-1)
    cover = [Int[] for _ in 1:nC]                  # cover[k] = opcionais que cobrem o cliente k
    for i in opt
        pos += 1                                   # pula o índice da linha
        for k in 1:nC
            t[pos] == "1" && push!(cover[k], i)
            pos += 1
        end
    end
    all(!isempty, cover) || error("$path: há cliente que nenhum opcional cobre")
    q = maxL + 2 * maximum(C[1, 2:R])
    return (name = splitext(basename(path))[1], R = R, nO = nO, nM = M1 - 1, nC = nC, p = p,
            mand = collect(1:M1-1), opt = opt, cover = cover, q = q, C = C)
end

# ---------- Auto-teste: julia mctp_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_mctp(joinpath(@__DIR__, "toy_mctp.ctp"); maxL = 10)
    @assert (toy.R, toy.nO, toy.nM, toy.nC, toy.p, toy.q) == (7, 5, 1, 6, 3, 34.0)
    @assert toy.mand == [1] && toy.opt == [2, 3, 4, 5, 6]
    @assert toy.cover == [[3], [2], [2], [4], [3], [6]]
    @assert toy.C[1, 2] == 10 && toy.C[2, 7] == 8          # 0→1 e 1→6

    dir = joinpath(@__DIR__, "Instancias")
    files = filter(f -> endswith(f, ".ctp"), readdir(dir))
    for f in files
        inst = read_mctp(joinpath(dir, f); maxL = parse(Float64, split(splitext(f)[1], '-')[end]))
        parts = parse.(Int, split(splitext(f)[1], '-')[2:5])   # |T|, |V|, |W|, p
        @assert (inst.nM + 1, inst.R, inst.nC, inst.p) == Tuple(parts) "$f: cabeçalho não bate com o nome"
    end
    println("OK: toy + $(length(files)) instâncias da literatura lidas")
end
