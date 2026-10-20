# Roda o vrptwmd_model.jl nas instâncias de referencias.csv e compara com o Senna et al. (2024).
# O modelo não é editado: em cada instância, o texto dele é avaliado num módulo novo, com as linhas
# `inst = ...` e `ub = ...` trocadas (ub = UB publicado + 0.01) e o CVRP.cfg com limite de tempo.
#
# Uso (na pasta VRPTWMD/):  julia vrptwmd_batch.jl [filtro] [limite_s]
#   julia vrptwmd_batch.jl 10_40          # só as 29 do tamanho 10_40
#   julia vrptwmd_batch.jl "" 3600        # todas as 145, até 1 h cada (padrão)
# Saída: resultados.csv, uma linha gravada ao fim de cada instância (as já presentes são puladas),
#        logs/<instância>.log (saída completa do modelo e do BaPCod) e logs/<instância>.dot (árvore B&B).
# No terminal fica só uma linha de resumo por instância.

filtro = get(ARGS, 1, "")
limite = parse(Int, get(ARGS, 2, "3600"))
dir = @__DIR__
modelo = read(joinpath(dir, "vrptwmd_model.jl"), String)
cfg = joinpath(dir, "batch.cfg")
write(cfg, read(joinpath(dir, "CVRP.cfg"), String) * "\nGlobalTimeLimit = $limite\n")

saida = joinpath(dir, "resultados.csv")
isfile(saida) || write(saida, "instancia,tamanho,ref_LB,ref_UB,ref_otimo,raiz,LB,UB,otimo,nos,tempo_s,comparacao\n")
feitas = Set(first.(split.(readlines(saida)[2:end], ",")))
logs = mkpath(joinpath(dir, "logs"))

for linha in readlines(joinpath(dir, "referencias.csv"))[2:end]
    nome, tam, rlb, rub, rot = split(linha, ",")[1:5]
    (occursin(filtro, nome) && !(nome in feitas)) || continue
    arq = joinpath(dir, "Instancias", "Solomon_$tam", "$nome.txt")
    log, dot = joinpath(logs, "$nome.log"), joinpath(logs, "$nome.dot")
    src = replace(modelo, r"^inst = .*$"m => "inst = read_vrptwmd(raw\"$arq\")",
                          r"^ub = .*$"m => "ub = $(parse(Float64, rub) + 0.01)",
                          "\"CVRP.cfg\"" => "raw\"$cfg\", baptreedot = raw\"$dot\"")
    m = Module()
    Core.eval(m, :(include(f) = Base.include($m, f)))     # módulo vazio não traz include
    ok = open(log, "w") do io                              # saída do Julia e do BaPCod (C) no log da instância
        redirect_stdio(stdout = io, stderr = io) do
            try
                Base.include_string(m, src, joinpath(dir, "vrptwmd_model.jl"))
                true
            catch e
                showerror(stdout, e, catch_backtrace())
                false
            finally
                Libc.flush_cstdio()
            end
        end
    end
    if !ok
        open(io -> println(io, join([nome, tam, rlb, rub, rot, "", "", "", "", "", "", "erro (ver log)"], ",")), saida, "a")
        println("$nome: ERRO, ver $log")
        continue
    end
    opt, achou, st = (Base.invokelatest(getglobal, m, v) for v in (:optimizer, :solution_found, :status))   # Julia 1.12: global novo exige world age novo
    s = opt.stats
    otimo = st == :Optimal
    # cutoff = UB publicado + 0.01: terminar ótimo sem solução nova prova que o UB publicado é ótimo
    ub = achou ? s[:bcRecBestInc] : (otimo ? parse(Float64, rub) : NaN)
    lb = otimo ? ub : s[:bcRecBestDb]
    cmp = isnan(ub) ? "nada abaixo do UB publicado (sem prova)" :
          ub < parse(Float64, rub) - 0.5 ? "melhorou o UB" :
          otimo && rot == "0" ? "provou o ótimo" :
          otimo ? "igual (ótimo)" : "igual ao UB (sem prova)"
    tempo = round(s[:bcTimeMain] / 100, digits = 2)
    open(saida, "a") do io
        println(io, join([nome, tam, rlb, rub, rot, round(s[:bcRecRootDb], digits = 2), round(lb, digits = 2),
                          round(ub, digits = 2), Int(otimo), s[:bcCountNodeProc], tempo, cmp], ","))
    end
    println("$nome: $cmp  (LB $(round(lb, digits = 2)), UB $(round(ub, digits = 2)), $tempo s)")
    flush(stdout)                                          # com nohup a saída vai a arquivo e ficaria em buffer
end
println("Fim: resultados em $saida")
