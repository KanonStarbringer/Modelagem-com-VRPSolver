"""Monta a tabela do benchmark PRUO a partir dos logs do VRPSolver.

Lê a linha `statistics:` que o BaPCod imprime ao fim de cada instância
(Optimal, raiz, nós, LB, UB, tempo) e gera:
  tabela_pruo.csv            uma linha por instância
  tabela_pruo_completa.tex   idem, em LaTeX (apêndice)
  tabela_pruo_resumo.tex     médias por n x janela x capacidade
Uso: python tabela.py   (rodar de novo sempre que um log mudar)
"""
import re
import pandas as pd

# log -> configuração usada. Se a mesma instância aparecer em dois logs, vale o último da lista.
LOGS = {
    "saida_bench25.txt": "padrao",
    "saida_bench50.txt": "padrao",
    "saida_bench100.txt": "padrao",
    "saida_bench100_enum100k.txt": "enum100k",
}

STAT = re.compile(r"^statistics: (\S+) & (\d) & \S+ & (\S+) & (\S+) & (\d+) & (\S+) & (\S+) & (\S+) \\\\")
NOME = re.compile(r"bench_(RC|R|C)(E|L)_n(\d+)_c(\d)_s(\d)")


def ler():
    linhas = {}
    for log, cfg in LOGS.items():
        with open(log, encoding="utf-8", errors="replace") as f:
            for l in f:
                m = STAT.match(l)
                if not m:
                    continue
                nome, opt, raiz, traiz, nos, lb, ub, t = m.groups()
                d, j, n, c, s = NOME.search(nome).groups()
                linhas[nome] = dict(instancia=nome, n=int(n), dist=d, janela=j, cap=int(c), seed=int(s),
                                    cfg=cfg, otimo=opt == "1", ub=float("nan" if ub == "--" else ub), lb=float(lb), lb_raiz=float(raiz),
                                    nos=int(nos), t_raiz=float(traiz), tempo=float(t))
    df = pd.DataFrame(linhas.values())
    df["gap"] = 100 * (df.ub - df.lb) / df.ub
    df["gap_raiz"] = 100 * (df.ub - df.lb_raiz) / df.ub
    ordem = {"R": 0, "C": 1, "RC": 2}
    return df.sort_values(["n", "dist", "janela", "cap", "seed"], key=lambda s: s.map(ordem) if s.name == "dist" else s)


def resumo(df):
    g = df.groupby(["n", "janela", "cap"])
    r = pd.DataFrame({
        "inst": g.size(),
        "opt": g.otimo.sum(),
        "tempo": g.tempo.mean(),
        "gap_aberto": g.apply(lambda x: x.loc[~x.otimo, "gap"].mean(), include_groups=False),
        "gap_raiz": g.gap_raiz.mean(),
        "nos": g.nos.mean(),
    }).reset_index()
    return r


def f(x, d=2):
    return "--" if pd.isna(x) else f"{x:.{d}f}"


def tex_completa(df):
    out = [r"\begin{tabular}{lrrrrrrrl}", r"\toprule",
           r"Instance & UB & LB & Gap (\%) & Root gap (\%) & Nodes & Time (s) & Opt. & Cfg. \\", r"\midrule"]
    for n, bloco in df.groupby("n"):
        for _, x in bloco.iterrows():
            nome = x.instancia.removeprefix("bench_").replace("_", r"\_")
            out.append(f"{nome} & {f(x.ub)} & {f(x.lb)} & {f(x.gap)} & {f(x.gap_raiz)} & {x.nos} & "
                       f"{f(x.tempo, 1)} & {'yes' if x.otimo else 'no'} & {x.cfg} \\\\")
        out.append(r"\midrule")
    out[-1] = r"\bottomrule"
    out.append(r"\end{tabular}")
    return "\n".join(out)


def tex_resumo(r):
    out = [r"\begin{tabular}{rcrrrrrr}", r"\toprule",
           r"$n$ & Window & Cap. & Opt./Inst. & Time (s) & Gap open (\%) & Root gap (\%) & Nodes \\", r"\midrule"]
    for _, x in r.iterrows():
        out.append(f"{x.n} & {x.janela} & {x.cap} & {int(x.opt)}/{x.inst} & {f(x.tempo, 1)} & "
                   f"{f(x.gap_aberto)} & {f(x.gap_raiz)} & {f(x.nos, 0)} \\\\")
    out += [r"\bottomrule", r"\end{tabular}"]
    return "\n".join(out)


if __name__ == "__main__":
    df = ler()
    r = resumo(df)
    # checagem: ótimo implica gap ~0, e LB nunca passa do UB
    assert (df.loc[df.otimo, "gap"].abs() < 1e-3).all(), df.loc[df.otimo & (df.gap.abs() >= 1e-3)]
    assert ((df.lb <= df.ub + 1e-6) | df.ub.isna()).all()
    df.to_csv("tabela_pruo.csv", index=False)
    open("tabela_pruo_completa.tex", "w", encoding="utf-8").write(tex_completa(df))
    open("tabela_pruo_resumo.tex", "w", encoding="utf-8").write(tex_resumo(r))
    print(f"{len(df)} instâncias, {df.otimo.sum()} ótimas\n")
    print(r.to_string(index=False, float_format=lambda v: f"{v:.2f}"))
    print("\nEm aberto:")
    print(df.loc[~df.otimo, ["instancia", "cfg", "ub", "lb", "gap", "gap_raiz"]].to_string(index=False, float_format=lambda v: f"{v:.2f}"))
