# Data-Flow & Architecture Diagrams

The diagram is the heart of a project-review deck. A clear, directional, labeled diagram is what makes a panel believe you understand your own system. Two ways to build it — pick by complexity.

## Decision: SVG-to-image vs native pptxgenjs shapes

| Diagram | Best method |
|---------|-------------|
| ≤ 6 nodes, simple linear or branching flow | **Native pptxgenjs shapes** (editable, crisp) |
| 7+ nodes, layered architecture, curved/crossing connectors, swimlanes | **Render an SVG, convert to PNG, embed as an image** |

For most project reviews the architecture slide is complex → SVG is cleaner and avoids fiddly connector math. The data-flow slide is often a simple chain → native shapes are fine.

---

## Method A — Native shapes (pptxgenjs)

Nodes = rounded rectangles; edges = arrow connectors. Keep it directional.

```javascript
// Node helper — colored rounded box with a label
function node(slide, x, y, w, label, fill, line) {
  slide.addShape("roundRect", { x, y, w, h: 0.7, rectRadius: 0.08,
    fill: { color: fill }, line: { color: line, width: 1 } });
  slide.addText(label, { x, y, w, h: 0.7, align: "center", valign: "middle",
    fontSize: 12, bold: true, color: "FFFFFF", fontFace: "Calibri" });
}

// Arrow between two boxes (horizontal)
function arrow(slide, x1, x2, y, color) {
  slide.addShape("line", { x: x1, y: y + 0.35, w: x2 - x1, h: 0,
    line: { color, width: 2, endArrowType: "triangle" } });
}

// Example: Client → API → Service → DB
const Y = 2.6;
node(slide, 0.6, Y, 1.8, "React Client", "1C7293", "0E3A4A");
arrow(slide, 2.4, 3.0, Y, "555555");
node(slide, 3.0, Y, 1.8, "FastAPI", "065A82", "0E3A4A");
arrow(slide, 4.8, 5.4, Y, "555555");
node(slide, 5.4, Y, 1.8, "Inference", "028090", "0E3A4A");
arrow(slide, 7.2, 7.8, Y, "555555");
node(slide, 7.8, Y, 1.8, "PostgreSQL", "21295C", "0E3A4A");
```

Rules:
- **One direction.** Left→right for a pipeline, top→bottom for a stack. Don't zigzag.
- **Label every arrow** if the relationship isn't obvious (e.g. "JSON", "SQL", "webhook"). Small 9–10pt muted text above the line.
- **Color-code by layer** (client / API / logic / data / external each get a tone from the deck palette), and add a tiny legend.
- **Number the steps** (1→2→3) on the data-flow slide so the presenter can narrate the path.

## Method B — SVG → PNG (complex / layered)

Write an SVG, convert with a headless tool, embed the PNG. This gives full control over layered layouts, swimlanes, and grouping boxes.

```bash
# After writing diagram.svg:
python -c "import cairosvg; cairosvg.svg2png(url='diagram.svg', write_to='diagram.png', output_width=2400)" \
  2>/dev/null || rsvg-convert -w 2400 diagram.svg -o diagram.png \
  || (npm i -g @resvg/resvg-js-cli && resvg --width 2400 diagram.svg diagram.png)
```

Then in pptxgenjs: `slide.addImage({ path: "diagram.png", x: 0.5, y: 1.6, w: 9, h: 4.4 })` (preserve aspect ratio — set only w OR compute h to match).

SVG layout tips:
- Render at high width (2000–2400px) so labels stay sharp when scaled on the slide.
- Use the **deck's palette** for node fills — the diagram must match the slide, not look pasted in.
- Group a layer's nodes inside a faint container rect with a layer label ("Frontend", "Services", "Data") — that's what makes it read as an *architecture*, not a flowchart.
- Keep font ≥ 28px in SVG units so it survives downscaling; never let labels overflow their boxes.

---

## Reading the data flow onto the slide

From `analysis.md` you have a numbered path like:
`1. User submits form → 2. POST /api/scan → 3. ScanService validates → 4. YOLOv8 inference → 5. results written to Postgres → 6. JSON back to client → 7. dashboard renders`

Turn that into:
- **Architecture slide:** the layered box diagram (who talks to whom).
- **Data-flow slide:** the *same components* arranged as a numbered chain with the step labels on the arrows, so the story is "data goes in here, comes out there."

Using consistent node colors across both slides (API is always the same blue, DB always the same navy) ties the deck together and is a cheap, high-impact polish move.

## Common diagram defects to QA for

- Labels overflowing their boxes (the #1 issue) — shorten text or widen the box.
- Arrowheads buried under the next node — leave a gap between arrow end and box.
- Tiny unreadable text after an SVG is downscaled — bump SVG font size and re-export.
- Crossing connectors that look like spaghetti — reorder nodes or route around.
- Diagram color clashing with the slide background — pull fills from the deck palette.
