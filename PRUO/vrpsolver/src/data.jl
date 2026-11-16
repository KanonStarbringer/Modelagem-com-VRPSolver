# Leitura das instâncias exportadas por exportar_instancias.py e grafo expandido (cópias).

struct Copia
    tarefa::Int
    modo::Char      # 'L' = computação a bordo; 'S' = offloading no servidor
    periodo::Int    # período do offloading, a partir de 0 (-1 se a bordo)
    lo::Float64     # janela de início do serviço
    hi::Float64
    dur::Float64    # duração do serviço: sensoriamento + processamento (L) ou + transmissão (S)
    ener::Float64
end

struct DataPRUO
    nome::String
    n::Int
    K::Int
    F::Float64
    H::Float64
    D::Float64
    P::Int
    E::Float64
    cE::Float64
    v::Float64
    C::Vector{Float64}
    gam::Vector{Int}
    no::Matrix{Float64}   # linha i+1 = nó i (0 = depósito): x y a b w tauL epsL tauS epsS
    ref::Float64          # valor do compacto no CBC (NaN se não calculado)
    ref_provado::Bool
end

dist(data::DataPRUO, i::Int, j::Int) = hypot(data.no[i+1, 1] - data.no[j+1, 1], data.no[i+1, 2] - data.no[j+1, 2])
tt(data::DataPRUO, i::Int, j::Int) = dist(data, i, j) / data.v
carga(data::DataPRUO, i::Int) = data.no[i+1, 5]

function readPRUOData(path::String)
    kv, nos, em_nos = Dict{String,Vector{String}}(), Vector{Vector{Float64}}(), false
    for linha in eachline(path)
        s = strip(split(linha, '#')[1])
        isempty(s) && continue
        campos = split(s)
        if campos[1] == "nos"
            em_nos = true
        elseif em_nos
            push!(nos, parse.(Float64, campos[2:end]))
        else
            kv[campos[1]] = String.(campos[2:end])
        end
    end
    fl(k) = parse(Float64, kv[k][1])
    int(k) = parse(Int, kv[k][1])
    return DataPRUO(splitext(basename(path))[1], int("n"), int("K"), fl("F"), fl("H"), fl("D"), int("P"),
        fl("E"), fl("cE"), fl("v"), parse.(Float64, kv["C"]), parse.(Int, kv["gam"]),
        permutedims(hcat(nos...)), fl("ref"), kv["ref"][2] == "1")
end

# Cópias de cada tarefa (§4 da nota): uma a bordo e uma por período com enlace em que a
# janela de início cabe. O vértice c do grafo de pricing é a cópia cop[c].
function copias(data::DataPRUO)
    cop = Copia[]
    for i in 1:data.n
        _, _, a, b, _, tauL, epsL, tauS, epsS = data.no[i+1, :]
        push!(cop, Copia(i, 'L', -1, a, b, tauL, epsL))
        tauS < 0 && continue                           # fora do alcance do servidor
        t0 = tt(data, 0, i)   # chegada mais cedo possível (desigualdade triangular)
        for t in 0:data.P-1
            lo, hi = max(a, t * data.D), min(b, (t + 1) * data.D)
            # só cópias alcançáveis e das quais ainda dá para voltar à base: uma cópia sem arco
            # de entrada deixaria y[c] sem mapeamento, o que o VRPSolver rejeita
            data.gam[t+1] == 1 && max(lo, t0) <= hi && max(lo, t0) + tauS + t0 <= data.H &&
                push!(cop, Copia(i, 'S', t, lo, hi, tauS, epsS))
        end
    end
    return cop
end
