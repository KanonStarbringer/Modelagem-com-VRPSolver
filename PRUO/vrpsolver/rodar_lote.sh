#!/bin/bash
# Roda um lote uma instância por processo: se o Linux matar uma (falta de memória),
# o lote segue. Rodar de novo o mesmo comando pula as instâncias que já têm RESULTADO.
# Uso: bash rodar_lote.sh bench_n50.batch saida_bench50.txt
lote=$1; saida=$2
while read -r linha; do
    [ -z "$linha" ] && continue
    nome=$(basename "${linha%% *}" .txt)
    grep -q "RESULTADO;$nome;" "$saida" 2>/dev/null && continue
    julia src/run.jl $linha < /dev/null >> "$saida" 2>&1
    cod=$?
    [ $cod -ne 0 ] && echo "RESULTADO;$nome;-;-;-;-;Erro_$cod;-" >> "$saida"
done < <(tr -d '\r' < "$lote")  # os .batch foram salvos no Windows (CRLF)
