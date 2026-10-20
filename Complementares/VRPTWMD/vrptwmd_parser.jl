# ============================================================
#  Parser do VRPTWMD-2R (Senna, Coelho, Morabito e Munari, EJOR 2024) + geração de padrões
# ============================================================
# Formato (Instances_Paper/README.md do site do Munari):
#   nome; "nº de clusters  nº de clientes"; VEHICLE / NUMBER CAPACITY / K Q
#   CLU NO.  X Y DEMANDA ABERTURA FECHAMENTO SERVIÇO           (linha 0 = depósito; demais = parkings)
#   CUST NO. X Y DEMANDA ABERTURA FECHAMENTO SERVIÇO CLUSTER   (clientes numerados a partir de 0)
# Distância euclidiana truncada + Floyd–Warshall em cada nível: depósito e parkings (veículo) e
# parking + clientes de cada cluster (entregadores). Veículo: tempo = distância. Entregador: tempo =
# vel × distância (1/3 da velocidade do veículo) e sem capacidade. Custos (fv, cv, fd, cd) = (1000, 10, 100, 1).
#
# Padrões: para cada cluster i, as partições dos seus clientes em até ML rotas a pé (listas ordenadas).
# Uma rota a pé que sai do parking em s volta em max(s + δ, ε) e só é viável se s ≤ L (espera permitida).
# Um padrão junta suas rotas: Δ = max δ, E = max ε, L = min L, dist = soma das distâncias a pé.
# P[l] guarda os padrões com até l entregadores que nenhum outro domina (dist, Δ, E menores; L maior).
#
# Uso:
#   include("vrptwmd_parser.jl")
#   inst = read_vrptwmd(joinpath(@__DIR__, "toy_vrptwmd.txt"))
#   inst = read_vrptwmd(joinpath(@__DIR__, "Instancias", "Solomon_10_40", "C101_10_40.txt"))
#   inst.n, inst.K, inst.Q, inst.q[i], inst.a[i+1], inst.b[i+1], inst.d1[i+1, j+1], inst.P[l][k]   (i, j em 0..n)

dist_trunc(p, r) = floor(Int, sqrt((p[1] - r[1])^2 + (p[2] - r[2])^2))

function floyd!(d)
    m = size(d, 1)
    for k in 1:m, i in 1:m, j in 1:m
        d[i, j] = min(d[i, j], d[i, k] + d[k, j])
    end
    return d
end

function particoes(itens, k)                    # partições de itens em até k listas ordenadas
    isempty(itens) && return [Vector{Int}[]]
    out = Vector{Vector{Int}}[]
    for p in particoes(itens[2:end], k)
        for r in eachindex(p), j in 0:length(p[r])
            novo = deepcopy(p)
            insert!(novo[r], j + 1, itens[1])
            push!(out, novo)
        end
        length(p) < k && push!(out, vcat(p, [[itens[1]]]))
    end
    return out
end

function read_vrptwmd(path::AbstractString; ML = 3, vel = 3)
    L = [split(l) for l in eachline(path) if !isempty(strip(l))]
    iv = findfirst(l -> l[1] == "VEHICLE", L)
    ik = findfirst(l -> l[1] == "CLU", L)
    ic = findfirst(l -> l[1] == "CUST", L)
    K, Q = parse.(Int, L[iv+2])
    clu = [parse.(Int, l) for l in L[ik+1:ic-1]]              # nº x y demanda a b serviço
    cus = [parse.(Int, l) for l in L[ic+1:end]]               # nº x y demanda a b serviço cluster
    n = length(clu) - 1
    a = [c[5] for c in clu]
    b = [c[6] for c in clu]
    d1 = floyd!([dist_trunc(p[2:3], r[2:3]) for p in clu, r in clu])
    clientes = [[c for c in cus if c[8] == i] for i in 1:n]
    q = [sum(c[4] for c in cs) for cs in clientes]
    q == [c[4] for c in clu[2:end]] || error("$path: demanda de cluster diferente da soma dos clientes")

    P = [NamedTuple[] for l in 1:ML]
    for i in 1:n
        cs = clientes[i]
        pts = vcat([clu[i+1][2:3]], [c[2:3] for c in cs])     # local: 1 = parking, h+1 = cs[h]
        d2 = floyd!([dist_trunc(p, r) for p in pts, r in pts])
        memo = Dict{Vector{Int},Any}()
        function rota(seq)                                    # (dist, δ, ε, L) ou nothing
            α, β, Lr, dist, prev = 0, typemin(Int) ÷ 2, typemax(Int) ÷ 2, 0, 1
            for h in seq
                c = cs[h-1]
                α += vel * d2[prev, h]; β += vel * d2[prev, h]; dist += d2[prev, h]
                β = max(β, c[5])                              # espera a janela abrir
                β > c[6] && return nothing
                Lr = min(Lr, c[6] - α)                        # sair depois de L atrasa este cliente
                α += c[7]; β += c[7]; prev = h
            end
            return (dist + d2[prev, 1], α + vel * d2[prev, 1], β + vel * d2[prev, 1], Lr)
        end
        cands = NamedTuple[]
        for pt in particoes(collect(2:length(cs)+1), ML)
            rs = [get!(() -> rota(r), memo, r) for r in pt]
            any(isnothing, rs) && continue
            Δ = maximum(r[2] for r in rs)
            E = max(maximum(r[3] for r in rs), a[i+1] + Δ)    # o veículo nunca chega antes de a_i
            Lp = min(minimum(r[4] for r in rs), b[i+1])
            Lp < a[i+1] && continue
            E + d1[i+1, 1] > b[1] && continue                 # não dá para voltar ao depósito
            push!(cands, (i = i, k = length(pt), dist = sum(r[1] for r in rs), Δ = Δ, E = E, L = Lp,
                          rotas = [[cs[h-1][1] for h in r] for r in pt]))
        end
        for l in 1:ML
            fr = NamedTuple[]
            for p in sort([p for p in cands if p.k <= l], by = p -> (p.dist, p.Δ, p.E, -p.L))
                any(f -> f.dist <= p.dist && f.Δ <= p.Δ && f.E <= p.E && f.L >= p.L, fr) || push!(fr, p)
            end
            l == ML && isempty(fr) && error("$path: cluster $i sem padrão viável")   # com l < ML pode faltar
            append!(P[l], fr)
        end
    end
    return (name = splitext(basename(path))[1], n = n, K = K, Q = Q, ML = ML,
            custos = (1000, 10, 100, 1), q = q, a = a, b = b, d1 = d1,
            clientes = [[c[1] for c in cs] for cs in clientes], P = P)
end

# ---------- Auto-teste: julia vrptwmd_parser.jl ----------
if abspath(PROGRAM_FILE) == @__FILE__
    toy = read_vrptwmd(joinpath(@__DIR__, "toy_vrptwmd.txt"))
    @assert (toy.n, toy.K, toy.Q, sum(length.(toy.clientes)), toy.q) == (3, 25, 200, 8, [9, 17, 3])
    @assert toy.d1[0+1, 3+1] == 23                           # trunc(√(17² + 16²)) = trunc(23,3)
    # cluster 3: [7] volta em max(s+22, 108), L = 92; [6] em max(s+40, 101), L = 105; [6,7] perde a janela do 7
    p3(l) = [(p.dist, p.Δ, p.E, p.L) for p in toy.P[l] if p.i == 3]
    @assert p3(1) == [(12, 56, 142, 89)]                      # só [7,6] com 1 entregador
    @assert p3(2) == [(12, 56, 142, 89), (14, 40, 112, 92)]   # + [6] | [7]: E = max(108, 101, 72 + 40)

    c101 = read_vrptwmd(joinpath(@__DIR__, "Instancias", "Solomon_10_40", "C101_10_40.txt"))
    @assert (c101.n, sum(length.(c101.clientes)), c101.K, c101.Q, c101.b[1]) == (10, 40, 25, 200, 1236)

    arqs = [f for dir in readdir(joinpath(@__DIR__, "Instancias"), join = true) for f in readdir(dir, join = true)]
    maxP = zeros(Int, 3)
    for f in arqs
        inst = read_vrptwmd(f)
        @assert all(inst.q .<= inst.Q) f
        maxP .= max.(maxP, length.(inst.P))
    end
    println("OK: toy + $(length(arqs)) instâncias VRPTWMD-2R lidas; maior nº de padrões por l = 1, 2, 3: $maxP")
end
