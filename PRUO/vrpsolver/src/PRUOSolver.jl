__precompile__(false)
module PRUOSolver
using VrpSolver, JuMP, ArgParse

include("data.jl")
include("model.jl")
include("solution.jl")

function parse_commandline(args_array::Array{String,1}, appfolder::String)
    s = ArgParseSettings(usage="##### PRUO no VRPSolver #####\n\n" *
                               "  No modo interativo, chame main([\"arg1\", ..., \"argn\"])", exit_after_help=false)
    @add_arg_table s begin
        "instance"
        help = "Arquivo da instância (gerado por exportar_instancias.py)"
        "--update"
        help = "Atualiza o pacote VrpSolver"
        action = :store_true
        "--cfg", "-c"
        help = "Arquivo de parâmetros do VRPSolver"
        default = "$appfolder/../config/PRUO.cfg"
        "--ub", "-u"
        help = "Limitante superior (primal bound)"
        arg_type = Float64
        default = 10000000.0
        "--ng"
        help = "Tamanho da vizinhança ng inicial, em cópias (deve ser <= RCSPmaxNGneighbourhoodSize)"
        arg_type = Int
        default = 24
        "--sem_recurso_periodo"
        help = "Não impõe a capacidade por período rota a rota (o LP fica mais fraco; o ótimo não muda)"
        action = :store_true
        "--batch", "-b"
        help = "Arquivo de lote: uma execução (argumentos) por linha"
    end
    return parse_args(args_array, s)
end

function run_pruo(app::Dict{String,Any})
    println("Application parameters:")
    for (arg, val) in app
        println("  $arg  =>  $(repr(val))")
    end
    flush(stdout)

    data = readPRUOData(app["instance"])
    t0 = time()
    (model, cop, arco, x, y) = build_model(data, app)
    println("Instância $(data.nome): $(data.n) tarefas, $(length(cop)) cópias, $(length(arco)) arcos no grafo de pricing")
    optimizer = VrpOptimizer(model, app["cfg"], data.nome)
    set_cutoff!(optimizer, app["ub"])
    (status, solution_found) = optimize!(optimizer)
    tempo = round(time() - t0, digits=1)

    println("########################################################")
    custo, conf = NaN, "-"
    if solution_found
        custo = get_objective_value(optimizer)
        recalc = print_routes(data, cop, rotas(cop, x, y, optimizer))
        println("Custo $(custo) (recalculado pelas rotas: $(round(recalc, digits=4)))")
        if !isnan(data.ref)
            dif = custo - data.ref
            conf = data.ref_provado ? (abs(dif) <= 1e-3 ? "OK" : "DIVERGE") :
                   (dif < -1e-3 ? "melhor que o CBC" : abs(dif) <= 1e-3 ? "igual ao CBC" : "pior que o CBC")
        end
    else
        println(status == :Optimal ? "Problema inviável" : "Solução não encontrada")
    end
    println("Referência (compacto no CBC): $(data.ref)$(data.ref_provado ? " (ótimo provado)" : "") -> $(conf)")
    println("RESULTADO;$(data.nome);$(data.n);$(custo);$(data.ref);$(conf);$(status);$(tempo)")
    println("########################################################")
end

function main(args)
    appfolder = dirname(@__FILE__)
    app = parse_commandline(args, appfolder)
    isnothing(app) && return
    if app["batch"] != nothing
        for line in readlines(app["batch"])
            if isempty(strip(line)) || strip(line)[1] == '#'
                continue
            end
            args_array = [String(s) for s in split(line)]
            app_line = parse_commandline(args_array, appfolder)
            run_pruo(app_line)
        end
    else
        run_pruo(app)
    end
end

export main

end
