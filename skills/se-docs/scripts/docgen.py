"""docgen — reusable python-docx helpers for software-engineering project documents.

Shared engine behind the `se-docs` skill. Deliberately understated: it produces
documents that read like a carefully formatted human submission, not a generated
template. That means a serif body (Times New Roman), plain black numbered
headings, restrained greyscale tables, a monochrome Gantt, justified body text,
and footer page numbers — NO coloured corporate banners, no blue header rows, no
zebra striping by default.

Requires: python-docx  (pip install python-docx)

Public API
----------
new_document(title, subtitle=None, meta=None) -> Document
add_heading(doc, text, level=1)
add_body(doc, text, italic=False, size=None, justify=True)
add_wbs_outline(doc, items)                      # indented numbered WBS tree
add_table(doc, headers, rows, ...)               # grey-header table, thin borders
add_gantt(doc, tasks, num_weeks, ...)            # landscape monochrome Gantt
set_landscape(section) / set_portrait(section)
shade_cell(cell, hex_fill)
save(doc, path)

A "task" for add_gantt is a dict:
    {"id": "1.3.1", "name": "Transcription agent", "owner": "Rakshit",
     "start": 6, "end": 7, "phase": "Core Agents"}
"""
from __future__ import annotations

from docx import Document
from docx.enum.section import WD_ORIENT
from docx.enum.table import WD_ALIGN_VERTICAL
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.oxml.ns import qn
from docx.oxml import OxmlElement
from docx.shared import Pt, RGBColor, Inches

# ---------------------------------------------------------------------------
# Academic monochrome palette. No brand colour — that is the point.
# ---------------------------------------------------------------------------
INK = "000000"
MUTED = "444444"
HEADER_FILL = "DDDDDD"      # light grey table header (black text on it)
RULE = "888888"             # thin rule / border grey
GANTT_BAR = "595959"        # single dark-grey bar fill (monochrome)
GANTT_BAR_ALT = "9A9A9A"    # optional lighter grey to separate alternate phases

BODY_FONT = "Times New Roman"
HEAD_FONT = "Times New Roman"


# ---------------------------------------------------------------------------
# Low-level XML helpers
# ---------------------------------------------------------------------------
def _set_cell_bg(cell, hex_fill: str) -> None:
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_fill)
    tcPr.append(shd)


shade_cell = _set_cell_bg


def _set_col_widths(table, widths_inches) -> None:
    table.autofit = False
    table.allow_autofit = False
    for row in table.rows:
        for idx, w in enumerate(widths_inches):
            if idx < len(row.cells):
                row.cells[idx].width = Inches(w)


def _no_space(paragraph) -> None:
    pf = paragraph.paragraph_format
    pf.space_before = Pt(0)
    pf.space_after = Pt(0)


def _cell_text(cell, text, *, bold=False, size=10, color=INK, align="left",
               italic=False, font=BODY_FONT):
    cell.vertical_alignment = WD_ALIGN_VERTICAL.CENTER
    p = cell.paragraphs[0]
    p.alignment = {
        "left": WD_ALIGN_PARAGRAPH.LEFT,
        "center": WD_ALIGN_PARAGRAPH.CENTER,
        "right": WD_ALIGN_PARAGRAPH.RIGHT,
    }[align]
    _no_space(p)
    # "\n" in a cell becomes a real line break (numbered flows, step lists).
    lines = str(text).split("\n")
    run = p.add_run(lines[0])
    for extra in lines[1:]:
        run.add_break()
        run.add_text(extra)
    run.bold = bold
    run.italic = italic
    run.font.name = font
    run.font.size = Pt(size)
    run.font.color.rgb = RGBColor.from_string(color)


def _thin_borders(table, color=RULE, sz="4") -> None:
    tbl = table._tbl
    tblPr = tbl.tblPr
    borders = OxmlElement("w:tblBorders")
    for edge in ("top", "left", "bottom", "right", "insideH", "insideV"):
        el = OxmlElement(f"w:{edge}")
        el.set(qn("w:val"), "single")
        el.set(qn("w:sz"), sz)
        el.set(qn("w:space"), "0")
        el.set(qn("w:color"), color)
        borders.append(el)
    tblPr.append(borders)


def _para_bottom_border(paragraph, color=RULE, sz="6") -> None:
    pPr = paragraph._p.get_or_add_pPr()
    pbdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), sz)
    bottom.set(qn("w:space"), "3")
    bottom.set(qn("w:color"), color)
    pbdr.append(bottom)
    pPr.append(pbdr)


def _add_page_number_footer(doc) -> None:
    """Centered 'Page X' in the footer of the primary section."""
    footer = doc.sections[0].footer
    p = footer.paragraphs[0]
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = p.add_run()
    run.font.name = BODY_FONT
    run.font.size = Pt(9)
    run.font.color.rgb = RGBColor.from_string(MUTED)
    fld_begin = OxmlElement("w:fldChar"); fld_begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText"); instr.set(qn("xml:space"), "preserve")
    instr.text = "PAGE"
    fld_end = OxmlElement("w:fldChar"); fld_end.set(qn("w:fldCharType"), "end")
    run._r.append(fld_begin); run._r.append(instr); run._r.append(fld_end)


# ---------------------------------------------------------------------------
# Section orientation
# ---------------------------------------------------------------------------
def set_landscape(section) -> None:
    if section.orientation != WD_ORIENT.LANDSCAPE:
        section.orientation = WD_ORIENT.LANDSCAPE
        section.page_width, section.page_height = section.page_height, section.page_width
    section.left_margin = Inches(0.7)
    section.right_margin = Inches(0.7)


def set_portrait(section) -> None:
    if section.orientation != WD_ORIENT.PORTRAIT:
        section.orientation = WD_ORIENT.PORTRAIT
        section.page_width, section.page_height = section.page_height, section.page_width
    section.left_margin = Inches(1.0)
    section.right_margin = Inches(1.0)


# ---------------------------------------------------------------------------
# Document skeleton
# ---------------------------------------------------------------------------
def new_document(title: str, subtitle: str | None = None,
                 meta: dict | None = None, **_ignore) -> Document:
    """Create a Document with a restrained, academic title block.

    Extra kwargs (e.g. a legacy `accent`) are accepted and ignored so old build
    scripts keep working under the monochrome theme.
    """
    doc = Document()

    normal = doc.styles["Normal"]
    normal.font.name = BODY_FONT
    normal.font.size = Pt(11)
    normal.font.color.rgb = RGBColor.from_string(INK)
    normal.paragraph_format.line_spacing_rule = WD_LINE_SPACING.MULTIPLE
    normal.paragraph_format.line_spacing = 1.15

    sec = doc.sections[0]
    sec.top_margin = Inches(1.0)
    sec.bottom_margin = Inches(1.0)
    sec.left_margin = Inches(1.0)
    sec.right_margin = Inches(1.0)

    # Title — centered, plain black, no banner.
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    r = p.add_run(title)
    r.bold = True
    r.font.name = HEAD_FONT
    r.font.size = Pt(22)
    r.font.color.rgb = RGBColor.from_string(INK)

    if subtitle:
        ps = doc.add_paragraph()
        ps.alignment = WD_ALIGN_PARAGRAPH.CENTER
        ps.paragraph_format.space_after = Pt(10)
        rs = ps.add_run(subtitle)
        rs.italic = True
        rs.font.name = HEAD_FONT
        rs.font.size = Pt(12.5)
        rs.font.color.rgb = RGBColor.from_string(MUTED)

    # a single thin grey rule under the title block
    rule = doc.add_paragraph()
    rule.paragraph_format.space_after = Pt(10)
    _para_bottom_border(rule, RULE, "6")

    if meta:
        t = doc.add_table(rows=0, cols=2)
        _thin_borders(t, "BFBFBF")
        for k, v in meta.items():
            row = t.add_row().cells
            _cell_text(row[0], k, bold=True, size=10, color=INK)
            _cell_text(row[1], v, size=10)
        _set_col_widths(t, [1.7, 4.3])
        doc.add_paragraph().paragraph_format.space_after = Pt(2)

    _add_page_number_footer(doc)
    return doc


def add_heading(doc, text: str, level: int = 1, **_ignore):
    p = doc.add_paragraph()
    pf = p.paragraph_format
    pf.space_before = Pt(14 if level == 1 else 9)
    pf.space_after = Pt(4)
    pf.keep_with_next = True
    r = p.add_run(text)
    r.bold = True
    r.font.name = HEAD_FONT
    r.font.size = Pt(14 if level == 1 else 12 if level == 2 else 11)
    r.font.color.rgb = RGBColor.from_string(INK)
    if level == 1:
        _para_bottom_border(p, RULE, "4")
    return p


def add_body(doc, text: str, italic: bool = False, size: int | None = None,
             justify: bool = True):
    p = doc.add_paragraph()
    p.paragraph_format.space_after = Pt(6)
    if justify:
        p.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
    r = p.add_run(text)
    r.italic = italic
    r.font.name = BODY_FONT
    if size:
        r.font.size = Pt(size)
    return p


# ---------------------------------------------------------------------------
# WBS hierarchical outline
# ---------------------------------------------------------------------------
def add_wbs_outline(doc, items, **_ignore) -> None:
    """items: list of (wbs_id, label). Depth is inferred from dots in wbs_id."""
    for wbs_id, label in items:
        depth = wbs_id.count(".")
        p = doc.add_paragraph()
        pf = p.paragraph_format
        pf.left_indent = Inches(0.32 * depth)
        pf.space_after = Pt(2)
        pf.space_before = Pt(3 if depth == 0 else 0)
        rid = p.add_run(f"{wbs_id} ")   # em-space after the number
        rid.bold = True
        rid.font.name = BODY_FONT
        rid.font.color.rgb = RGBColor.from_string(INK)
        rid.font.size = Pt(12 if depth == 0 else 11 if depth == 1 else 10.5)
        rl = p.add_run(label)
        rl.bold = depth <= 1
        rl.font.name = BODY_FONT
        rl.font.size = Pt(12 if depth == 0 else 11 if depth == 1 else 10.5)


# ---------------------------------------------------------------------------
# Generic table — grey header, black text, thin borders, no zebra by default
# ---------------------------------------------------------------------------
def _repeat_header(table) -> None:
    """Mark row 0 as a header row so it repeats across page breaks."""
    trPr = table.rows[0]._tr.get_or_add_trPr()
    el = OxmlElement("w:tblHeader")
    el.set(qn("w:val"), "true")
    trPr.append(el)


def add_table(doc, headers, rows, *, col_widths=None, header_fill=HEADER_FILL,
              zebra=False, font_size=10, align=None,
              row_depths=None, indent_col=1, bold_depths=(0,)):
    """align: optional list of 'left'|'center'|'right' per column.

    `row_depths` turns the table into an indented tree: give one depth int per
    row and column `indent_col` is indented 0.14in per level; rows whose depth is
    in `bold_depths` are bolded (use for WBS phase rows).
    """
    t = doc.add_table(rows=1, cols=len(headers))
    _thin_borders(t)
    align = align or ["left"] * len(headers)

    hdr = t.rows[0].cells
    for i, h in enumerate(headers):
        _set_cell_bg(hdr[i], header_fill)
        _cell_text(hdr[i], h, bold=True, size=font_size, color=INK,
                   align=align[i])
    _repeat_header(t)

    for ridx, row in enumerate(rows):
        cells = t.add_row().cells
        depth = row_depths[ridx] if row_depths else None
        bold = depth in bold_depths if depth is not None else False
        for i, val in enumerate(row):
            if zebra and ridx % 2 == 1:
                _set_cell_bg(cells[i], "F3F3F3")
            _cell_text(cells[i], val, size=font_size, align=align[i],
                       bold=bold)
            if depth and i == indent_col:
                cells[i].paragraphs[0].paragraph_format.left_indent = Inches(0.14 * depth)

    if col_widths:
        _set_col_widths(t, col_widths)
    return t


def add_kv_table(doc, rows, *, label_w=1.75, value_w=4.45, font_size=9.5,
                 label_fill=None):
    """Two-column label/value table — use-case specifications, templates, forms."""
    t = doc.add_table(rows=0, cols=2)
    _thin_borders(t)
    for label, value in rows:
        cells = t.add_row().cells
        if label_fill:
            _set_cell_bg(cells[0], label_fill)
        _cell_text(cells[0], label, bold=True, size=font_size)
        _cell_text(cells[1], value, size=font_size)
    _set_col_widths(t, [label_w, value_w])
    return t


def add_image(doc, path, *, width_in=5.9, caption=None):
    """Insert a centered picture, with an optional italic caption beneath it."""
    doc.add_picture(path, width=Inches(width_in))
    pic_par = doc.paragraphs[-1]
    pic_par.alignment = WD_ALIGN_PARAGRAPH.CENTER
    pic_par.paragraph_format.space_before = Pt(4)
    pic_par.paragraph_format.space_after = Pt(2)
    if caption:
        cap = doc.add_paragraph()
        cap.alignment = WD_ALIGN_PARAGRAPH.CENTER
        cap.paragraph_format.space_after = Pt(10)
        r = cap.add_run(caption)
        r.italic = True
        r.font.name = BODY_FONT
        r.font.size = Pt(9)
        r.font.color.rgb = RGBColor.from_string(MUTED)
    return pic_par


# ---------------------------------------------------------------------------
# Gantt chart — native Word table, monochrome bars
# ---------------------------------------------------------------------------
def add_gantt(doc, tasks, num_weeks, *, id_w=0.5, name_w=2.7, owner_w=0.9,
              week_w=0.36, header_fill=HEADER_FILL, week_label="W",
              two_tone=True):
    """Render a table-based Gantt with monochrome bars.

    Bars span start..end weeks. By default alternating phases get two shades of
    grey (two_tone=True) purely to aid reading; set two_tone=False for a single
    grey. No colour, no legend chips — a filled cell simply means 'active'.
    """
    # order phases as first seen -> alternate the two greys
    order: list[str] = []
    for tk in tasks:
        ph = tk.get("phase", "")
        if ph not in order:
            order.append(ph)
    phase_shade = {
        ph: (GANTT_BAR if (i % 2 == 0 or not two_tone) else GANTT_BAR_ALT)
        for i, ph in enumerate(order)
    }

    cols = 3 + num_weeks
    t = doc.add_table(rows=1, cols=cols)
    _thin_borders(t, "BFBFBF")

    hdr = t.rows[0].cells
    _set_cell_bg(hdr[0], header_fill)
    _cell_text(hdr[0], "ID", bold=True, size=8, align="center")
    _set_cell_bg(hdr[1], header_fill)
    _cell_text(hdr[1], "Work Package", bold=True, size=8)
    _set_cell_bg(hdr[2], header_fill)
    _cell_text(hdr[2], "Owner", bold=True, size=8, align="center")
    for w in range(1, num_weeks + 1):
        c = hdr[3 + w - 1]
        _set_cell_bg(c, header_fill)
        _cell_text(c, f"{week_label}{w}", bold=True, size=7, align="center")

    for tk in tasks:
        cells = t.add_row().cells
        _cell_text(cells[0], tk["id"], size=8, align="center")
        _cell_text(cells[1], tk["name"], size=8)
        _cell_text(cells[2], tk.get("owner", ""), size=8, align="center")
        shade = phase_shade[tk.get("phase", "")]
        for w in range(1, num_weeks + 1):
            c = cells[3 + w - 1]
            if tk["start"] <= w <= tk["end"]:
                _set_cell_bg(c, shade)

    widths = [id_w, name_w, owner_w] + [week_w] * num_weeks
    _set_col_widths(t, widths)
    return t


def save(doc, path: str) -> None:
    doc.save(path)
