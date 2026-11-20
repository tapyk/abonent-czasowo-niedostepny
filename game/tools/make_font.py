"""Generates the game's pixel font: assets/fonts/abonent5.png + abonent5.fnt (BMFont text).

Hand-drawn for this project (no third-party glyphs). Capitals are 5 px tall, lowercase
has a 4 px x-height, and the Polish letters keep their bodies on the baseline: accents
sit above, ogonki (ą, ę, Ą, Ę) hang below like descenders.

Glyph cell: 8 rows.  row 0 = accents over capitals / lowercase acute,
rows 1-5 = capital height (baseline under row 5), rows 2-5 = lowercase x-height,
rows 6-7 = descenders and ogonki.

Run from the game/ folder:  python tools/make_font.py
"""
import os
from PIL import Image

ROWS = 8
BASE = 6          # baseline, px from the top of the cell
LINE = 9          # line height
SIZE = 8          # nominal font size (Art.FONT_SIZE)


def cap(*body, top="", desc=("", "")):
    """Capital / digit / tall glyph: 5 body rows (1-5)."""
    w = max(len(r) for r in body)
    rows = [top] + list(body) + list(desc)
    return [r.ljust(w, ".") for r in rows]


def low(*body, asc="", top="", desc=("", "")):
    """Lowercase: 4 x-height rows (2-5), optional ascender row 1, accent row 0."""
    w = max(len(r) for r in body)
    rows = [top, asc] + list(body) + list(desc)
    return [r.ljust(w, ".") for r in rows]


def rows_at(width, pixels):
    """Free-form glyph: {row: pattern}."""
    return [pixels.get(i, "").ljust(width, ".") for i in range(ROWS)]


G = {}
# --- capitals --------------------------------------------------------------
G["A"] = cap(".##.", "#..#", "####", "#..#", "#..#")
G["B"] = cap("###.", "#..#", "###.", "#..#", "###.")
G["C"] = cap(".###", "#...", "#...", "#...", ".###")
G["D"] = cap("###.", "#..#", "#..#", "#..#", "###.")
G["E"] = cap("####", "#...", "###.", "#...", "####")
G["F"] = cap("####", "#...", "###.", "#...", "#...")
G["G"] = cap(".###", "#...", "#.##", "#..#", ".###")
G["H"] = cap("#..#", "#..#", "####", "#..#", "#..#")
G["I"] = cap("###", ".#.", ".#.", ".#.", "###")
G["J"] = cap("..##", "...#", "...#", "#..#", ".##.")
G["K"] = cap("#..#", "#.#.", "##..", "#.#.", "#..#")
G["L"] = cap("#...", "#...", "#...", "#...", "####")
G["M"] = cap("#...#", "##.##", "#.#.#", "#...#", "#...#")
G["N"] = cap("#..#", "##.#", "#.##", "#..#", "#..#")
G["O"] = cap(".##.", "#..#", "#..#", "#..#", ".##.")
G["P"] = cap("###.", "#..#", "###.", "#...", "#...")
G["Q"] = cap(".##.", "#..#", "#..#", "#.#.", ".#.#")
G["R"] = cap("###.", "#..#", "###.", "#.#.", "#..#")
G["S"] = cap(".###", "#...", ".##.", "...#", "###.")
G["T"] = cap("#####", "..#..", "..#..", "..#..", "..#..")
G["U"] = cap("#..#", "#..#", "#..#", "#..#", ".##.")
G["V"] = cap("#...#", "#...#", ".#.#.", ".#.#.", "..#..")
G["W"] = cap("#...#", "#...#", "#.#.#", "#.#.#", ".#.#.")
G["X"] = cap("#..#", "#..#", ".##.", "#..#", "#..#")
G["Y"] = cap("#...#", ".#.#.", "..#..", "..#..", "..#..")
G["Z"] = cap("####", "...#", ".##.", "#...", "####")
# Polish capitals
G["Ą"] = cap(*G["A"][1:6], desc=("...#", ""))
G["Ć"] = cap(*G["C"][1:6], top="..#.")
G["Ę"] = cap(*G["E"][1:6], desc=("...#", ""))
G["Ł"] = cap(".#..", ".#..", ".##.", "##..", ".###")
G["Ń"] = cap(*G["N"][1:6], top="..#.")
G["Ó"] = cap(*G["O"][1:6], top="..#.")
G["Ś"] = cap(*G["S"][1:6], top="..#.")
G["Ź"] = cap(*G["Z"][1:6], top="..#.")
G["Ż"] = cap(*G["Z"][1:6], top=".#..")

# --- lowercase -------------------------------------------------------------
G["a"] = low(".##", "#.#", "#.#", ".##")
G["b"] = low("##.", "#.#", "#.#", "##.", asc="#..")
G["c"] = low(".##", "#..", "#..", ".##")
G["d"] = low(".##", "#.#", "#.#", ".##", asc="..#")
G["e"] = low(".#.", "###", "#..", ".##")
G["f"] = low("#..", "###", "#..", "#..", asc=".##")
G["g"] = low(".##", "#.#", "#.#", ".##", desc=("..#", "##."))
G["h"] = low("##.", "#.#", "#.#", "#.#", asc="#..")
G["i"] = low(".", "#", "#", "#", asc="#")
G["j"] = low("..", ".#", ".#", ".#", asc=".#", desc=(".#", "#."))
G["k"] = low("#.#", "##.", "#.#", "#.#", asc="#..")
G["l"] = low("#", "#", "#", "#", asc="#")
G["m"] = low("####.", "#.#.#", "#.#.#", "#.#.#")
G["n"] = low("##.", "#.#", "#.#", "#.#")
G["o"] = low(".#.", "#.#", "#.#", ".#.")
G["p"] = low("##.", "#.#", "#.#", "##.", desc=("#..", "#.."))
G["q"] = low(".##", "#.#", "#.#", ".##", desc=("..#", "..#"))
G["r"] = low("#.#", "##.", "#..", "#..")
G["s"] = low(".##", "#..", "..#", "##.")
G["t"] = low("###", ".#.", ".#.", "..#", asc=".#.")
G["u"] = low("#.#", "#.#", "#.#", ".##")
G["v"] = low("#.#", "#.#", "#.#", ".#.")
G["w"] = low("#...#", "#...#", "#.#.#", ".#.#.")
G["x"] = low("#.#", ".#.", ".#.", "#.#")
G["y"] = low("#.#", "#.#", "#.#", ".##", desc=("..#", "##."))
G["z"] = low("###", "..#", "#..", "###")
# Polish lowercase: bodies stay on the baseline
G["ą"] = low(*G["a"][2:6], desc=("..#", ""))
G["ć"] = low(*G["c"][2:6], top="..#")
G["ę"] = low(*G["e"][2:6], desc=("..#", ""))
G["ł"] = low(".#.", ".##", "##.", ".#.", asc=".#.")
G["ń"] = low(*G["n"][2:6], top="..#")
G["ó"] = low(*G["o"][2:6], top="..#")
G["ś"] = low(*G["s"][2:6], top="..#")
G["ź"] = low(*G["z"][2:6], top="..#")
G["ż"] = low(*G["z"][2:6], top=".#.")

# --- digits ------------------------------------------------------------------
G["0"] = cap("###", "#.#", "#.#", "#.#", "###")
G["1"] = cap(".#.", "##.", ".#.", ".#.", "###")
G["2"] = cap("##.", "..#", ".#.", "#..", "###")
G["3"] = cap("##.", "..#", ".#.", "..#", "##.")
G["4"] = cap("#.#", "#.#", "###", "..#", "..#")
G["5"] = cap("###", "#..", "##.", "..#", "##.")
G["6"] = cap(".##", "#..", "###", "#.#", "###")
G["7"] = cap("###", "..#", ".#.", ".#.", ".#.")
G["8"] = cap("###", "#.#", "###", "#.#", "###")
G["9"] = cap("###", "#.#", "###", "..#", "##.")

# --- punctuation -------------------------------------------------------------
G["."] = rows_at(1, {5: "#"})
G[","] = rows_at(1, {5: "#", 6: "#"})
G[":"] = rows_at(1, {3: "#", 5: "#"})
G[";"] = rows_at(1, {3: "#", 5: "#", 6: "#"})
G["!"] = rows_at(1, {1: "#", 2: "#", 3: "#", 5: "#"})
G["?"] = cap("##.", "..#", ".#.", "...", ".#.")
G["-"] = rows_at(3, {3: "###"})
G["–"] = rows_at(4, {3: "####"})
G["—"] = rows_at(5, {3: "#####"})
G["_"] = rows_at(4, {6: "####"})
G["+"] = rows_at(3, {2: ".#.", 3: "###", 4: ".#."})
G["="] = rows_at(3, {2: "###", 4: "###"})
G["*"] = rows_at(3, {2: "#.#", 3: ".#.", 4: "#.#"})
G["/"] = cap("..#", "..#", ".#.", "#..", "#..")
G["\\"] = cap("#..", "#..", ".#.", "..#", "..#")
G["|"] = rows_at(1, {i: "#" for i in range(1, 7)})
G["("] = cap(".#", "#.", "#.", "#.", ".#")
G[")"] = cap("#.", ".#", ".#", ".#", "#.")
G["["] = cap("##", "#.", "#.", "#.", "##")
G["]"] = cap("##", ".#", ".#", ".#", "##")
G["{"] = cap(".##", ".#.", "#..", ".#.", ".##")
G["}"] = cap("##.", ".#.", "..#", ".#.", "##.")
G["<"] = rows_at(3, {2: "..#", 3: ".#.", 4: "#..", 5: ".#.", 6: "..#"})
G[">"] = rows_at(3, {2: "#..", 3: ".#.", 4: "..#", 5: ".#.", 6: "#.."})
G["\""] = rows_at(3, {1: "#.#", 2: "#.#"})
G["'"] = rows_at(1, {1: "#", 2: "#"})
G["`"] = rows_at(2, {1: "#.", 2: ".#"})
G["^"] = rows_at(3, {1: ".#.", 2: "#.#"})
G["~"] = rows_at(4, {2: ".#.#", 3: "#.#."})
G["%"] = cap("#.#", "..#", ".#.", "#..", "#.#")
G["#"] = cap(".#.#.", "#####", ".#.#.", "#####", ".#.#.")
G["&"] = cap(".#..", "#.#.", ".#..", "#.#.", ".#.#")
G["@"] = cap(".###.", "#...#", "#.###", "#.##.", ".#...")
G["$"] = rows_at(3, {1: ".##", 2: "##.", 3: ".#.", 4: ".##", 5: "##.", 6: ".#."})
G["…"] = rows_at(5, {5: "#.#.#"})
G["„"] = rows_at(3, {5: "#.#", 6: "#.#"})
G["”"] = rows_at(3, {1: "#.#", 2: "#.#"})
G["“"] = rows_at(3, {1: "#.#", 2: "#.#"})
G["°"] = rows_at(3, {1: ".#.", 2: "#.#", 3: ".#."})
G["▲"] = rows_at(5, {3: "..#..", 4: ".###.", 5: "#####"})
G["?"] = G["?"]
SPACE_ADVANCE = 3


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    out = os.path.join(here, "..", "assets", "fonts")
    chars = sorted(G, key=ord)
    for ch in chars:
        g = G[ch]
        assert len(g) == ROWS, (ch, len(g))
        assert len({len(r) for r in g}) == 1, (ch, g)
    cols = 16
    cell_w = max(len(G[c][0]) for c in chars) + 1
    cell_h = ROWS + 1
    count = len(chars)
    sheet_w = cols * cell_w
    sheet_h = ((count + cols - 1) // cols) * cell_h
    img = Image.new("RGBA", (sheet_w, sheet_h), (0, 0, 0, 0))
    lines = [
        'info face="Abonent5" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=1,1' % SIZE,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0" % (LINE, BASE, sheet_w, sheet_h),
        'page id=0 file="abonent5.png"',
        "chars count=%d" % (count + 1),
        "char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15" % SPACE_ADVANCE,
    ]
    for i, ch in enumerate(chars):
        g = G[ch]
        w = len(g[0])
        x0 = (i % cols) * cell_w
        y0 = (i // cols) * cell_h
        for y, row in enumerate(g):
            for x, px in enumerate(row):
                if px == "#":
                    img.putpixel((x0 + x, y0 + y), (255, 255, 255, 255))
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
                     % (ord(ch), x0, y0, w, ROWS, w + 1))
    img.save(os.path.join(out, "abonent5.png"))
    with open(os.path.join(out, "abonent5.fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("glyphs:", count + 1)


if __name__ == "__main__":
    main()
