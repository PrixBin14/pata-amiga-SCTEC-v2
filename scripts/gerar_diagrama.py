#!/usr/bin/env python3
"""Gera o diagrama do modelo estrela (docs/img/modelo-estrela.png).
"""
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from matplotlib.path import Path

FIG_W, FIG_H = 13, 9.6
fig, ax = plt.subplots(figsize=(FIG_W, FIG_H))
ax.set_xlim(0, FIG_W)
ax.set_ylim(-0.6, FIG_H - 0.6)
ax.axis("off")

BG_COLOR = "white"
SURFACE_COLOR = "white"        
COLOR_FATO = "#b23a5c"         
COLOR_DIM = "#c97b95"          
COLOR_BRIDGE = "#7a3c50"       
TEXT_WHITE = "white"
TEXT_BODY = "#3a2530"          
TEXT_MUTED = "#a15a76"         

fig.patch.set_facecolor(BG_COLOR)
ax.set_facecolor(BG_COLOR)


def draw_box(cx, cy, w, h, title, lines, color, title_size=11, line_size=9):
    box = FancyBboxPatch(
        (cx - w / 2, cy - h / 2), w, h,
        boxstyle="round,pad=0.02,rounding_size=0.08",
        linewidth=1.8, edgecolor=color, facecolor=SURFACE_COLOR, zorder=2,
    )
    ax.add_patch(box)
    header_h = 0.42
    header = FancyBboxPatch(
        (cx - w / 2, cy + h / 2 - header_h), w, header_h,
        boxstyle="round,pad=0.0,rounding_size=0.08",
        linewidth=0, facecolor=color, zorder=3,
    )
    ax.add_patch(header)
    ax.text(cx, cy + h / 2 - header_h / 2, title, ha="center", va="center",
            fontsize=title_size, fontweight="bold", color=TEXT_WHITE, zorder=4)
    y0 = cy + h / 2 - header_h - 0.16
    for i, line in enumerate(lines):
        ax.text(cx - w / 2 + 0.15, y0 - i * 0.28, line, ha="left", va="center",
                fontsize=line_size, color=TEXT_BODY, zorder=4, family="monospace")


def arrow(p1, p2, color="#c97b95", style="-", lw=1.4, label=None, label_pos=0.5,
          connectionstyle="arc3,rad=0.0", label_color=TEXT_MUTED):
    a = FancyArrowPatch(p1, p2, arrowstyle="-", linewidth=lw, color=color,
                         linestyle=style, connectionstyle=connectionstyle, zorder=1)
    ax.add_patch(a)
    if label:
        mx = p1[0] + (p2[0] - p1[0]) * label_pos
        my = p1[1] + (p2[1] - p1[1]) * label_pos
        ax.text(mx, my, label, ha="center", va="center", fontsize=8,
                color=label_color, style="italic",
                bbox=dict(boxstyle="round,pad=0.15", fc=BG_COLOR, ec="none"), zorder=5)


# ---------------------------------------------------------------- FATO_PEDIDO
FX, FY, FW, FH = 6.5, 4.6, 3.4, 2.7
draw_box(FX, FY, FW, FH, "FATO_PEDIDO", [
    "PK  sk_pedido",
    "    numero_pedido (deg.)",
    "FK  sk_tempo_pedido",
    "FK  sk_tempo_entrega",
    "FK  sk_loja",
    "FK  sk_categoria",
    "    vl_liquido (aditiva)",
    "    qt_itens (aditiva)",
], COLOR_FATO, title_size=13)
ax.text(FX, FY - FH / 2 - 0.28, "grão: 1 linha = 1 pedido  (4.044 linhas)",
        ha="center", va="center", fontsize=10, style="italic", color=COLOR_FATO)

# ---------------------------------------------------------------- DIM_TEMPO x2
draw_box(2.0, 8.0, 2.6, 1.5, "DIM_TEMPO", [
    "PK  sk_tempo (AAAAMMDD)",
    "    data / ano / mes",
    "    dia_semana",
], COLOR_DIM, title_size=10, line_size=8)
ax.text(2.0, 8.98, "papel: DATA DO PEDIDO", ha="center", fontsize=8.5,
        color=COLOR_DIM, fontweight="bold")

draw_box(11.0, 8.0, 2.6, 1.5, "DIM_TEMPO", [
    "PK  sk_tempo (AAAAMMDD)",
    "    data / ano / mes",
    "    dia_semana",
], COLOR_DIM, title_size=10, line_size=8)
ax.text(11.0, 8.98, "papel: DATA DA ENTREGA", ha="center", fontsize=8.5,
        color=COLOR_DIM, fontweight="bold")
ax.text(6.5, 8.55,
        "mesma tabela em dois papéis (role-playing dimension)\n"
        "— dois relacionamentos independentes com a fato —",
        ha="center", fontsize=8.5, style="italic", color=TEXT_MUTED)

# ---------------------------------------------------------------- DIM_LOJA
draw_box(1.7, 3.1, 2.7, 1.7, "DIM_LOJA", [
    "PK  sk_loja",
    "    cod_loja / chave_loja",
    "    porte / faixa_franquia",
    "    populacao_cidade",
], COLOR_DIM, title_size=10, line_size=8)

# ---------------------------------------------------------------- DIM_CATEGORIA
draw_box(11.2, 3.1, 2.7, 1.6, "DIM_CATEGORIA", [
    "PK  sk_categoria",
    "    categoria_origem",
    "    nome_categoria",
    "    grupo_categoria",
], COLOR_DIM, title_size=10, line_size=8)

# ---------------------------------------------------------------- BRIDGE + DIM_PRACA
draw_box(1.7, 0.95, 3.0, 1.15, "BRIDGE_LOJA_PRACA", [
    "PK  cod_loja + sk_praca",
    "    fator_publico (soma=1,00)",
], COLOR_BRIDGE, title_size=9.5, line_size=8)

draw_box(5.6, 0.75, 2.7, 1.5, "DIM_PRACA", [
    "PK  sk_praca",
    "    cod_praca / nome_praca",
    "    domicilios_com_pet",
], COLOR_DIM, title_size=10, line_size=8)

# ---------------------------------------------------------------------- LINES
# tempo pedido -> fato
arrow((2.6, 7.35), (5.3, 5.7), color=COLOR_DIM)
# tempo entrega -> fato
arrow((10.3, 7.35), (7.7, 5.7), color=COLOR_DIM)
# loja -> fato
arrow((2.9, 3.55), (4.9, 4.0), color=COLOR_DIM)
# categoria -> fato
arrow((10.0, 3.6), (8.1, 4.0), color=COLOR_DIM)
# loja -> bridge (indireto, tracejado)
arrow((1.7, 2.25), (1.7, 1.53), color=COLOR_BRIDGE, style=(0, (4, 3)))
# bridge -> praca (indireto, tracejado)
arrow((3.2, 0.95), (4.25, 0.8), color=COLOR_BRIDGE, style=(0, (4, 3)))

ax.text(1.7, 1.9, "cod_loja", ha="center", fontsize=7.5, color=COLOR_BRIDGE,
        style="italic", bbox=dict(boxstyle="round,pad=0.1", fc=BG_COLOR, ec="none"))
ax.text(3.75, 1.05, "sk_praca", ha="center", fontsize=7.5, color=COLOR_BRIDGE,
        style="italic", bbox=dict(boxstyle="round,pad=0.1", fc=BG_COLOR, ec="none"))

ax.text(6.5, -0.4,
        "único caminho indireto do modelo: dim_praca não liga direto à fato — "
        "passa pela bridge (N:N loja×praça, com fator de rateio)",
        ha="center", fontsize=8.5, style="italic", color=COLOR_BRIDGE)

ax.text(6.5, 9.55, "Pata Amiga — Modelo Dimensional (Esquema Estrela)",
        ha="center", fontsize=15, fontweight="bold", color=TEXT_BODY)

plt.tight_layout()
plt.savefig("docs/img/modelo-estrela.png", dpi=170, bbox_inches="tight",
            facecolor=BG_COLOR)
print("ok")
