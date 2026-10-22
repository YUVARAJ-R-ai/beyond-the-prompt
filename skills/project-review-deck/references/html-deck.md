# Interactive HTML Deck

Produce a **single self-contained `.html` file** — all CSS and JS inline, any libraries/fonts pulled from CDN — so the user can double-click it and present from any laptop with no build step or server. The two things that make this format worth choosing over PPTX are **slide transitions** and an **animated data-flow diagram**; both are required here.

Read `frontend-design` (`/mnt/skills/public/frontend-design/SKILL.md`) first for visual direction. `frontend-patterns` is available if you want structural patterns, but keep the output dependency-light.

## Architecture of the file

Two viable approaches — pick based on the vibe:

| Approach | When | How |
|----------|------|-----|
| **Custom slide engine** (recommended) | Full control over transitions + diagram animation | One `<section class="slide">` per slide, a tiny JS controller for navigation, CSS transitions, inline SVG diagrams animated with JS |
| **reveal.js** (CDN) | User wants a battle-tested deck framework, speaker notes, overview mode | `<link>`/`<script>` reveal.js from cdnjs; put diagrams in `<section>`s; use fragments for step reveals |

Default to the **custom engine** — it keeps the file small, avoids version pinning, and gives precise control over the diagram animation, which reveal.js fragments handle only crudely.

### Custom engine skeleton

```html
<!doctype html><html><head><meta charset="utf-8">
<style>
  :root{ --primary:#1E2761; --secondary:#CADCFC; --accent:#028090; --text:#212121; --bg:#fff;
         --font-head:'Cambria',serif; --font-body:'Calibri',sans-serif; }
  *{box-sizing:border-box} body{margin:0;font-family:var(--font-body);color:var(--text);background:#000;overflow:hidden}
  .deck{position:relative;width:100vw;height:100vh}
  .slide{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;
         padding:6vh 8vw;background:var(--bg);opacity:0;transform:translateX(40px);
         transition:opacity .5s ease,transform .5s ease;pointer-events:none}
  .slide.active{opacity:1;transform:none;pointer-events:auto}
  .slide.prev{transform:translateX(-40px)}
  h1{font-family:var(--font-head);font-size:3.2rem;margin:0 0 .4em}
  .progress{position:fixed;bottom:0;left:0;height:4px;background:var(--accent);transition:width .4s}
</style></head><body>
<div class="deck" id="deck"><!-- sections injected or written inline --></div>
<div class="progress" id="prog"></div>
<script>
  const slides=[...document.querySelectorAll('.slide')]; let i=0;
  function show(n){ slides.forEach((s,k)=>{ s.className='slide'+(k===n?' active':k<n?' prev':''); });
    document.getElementById('prog').style.width=((n+1)/slides.length*100)+'%';
    if(slides[n].dataset.diagram) animateDiagram(slides[n]); }
  function go(d){ i=Math.max(0,Math.min(slides.length-1,i+d)); show(i); }
  addEventListener('keydown',e=>{ if(e.key==='ArrowRight'||e.key===' ')go(1); if(e.key==='ArrowLeft')go(-1); });
  addEventListener('click',e=>{ if(e.clientX>innerWidth*0.5)go(1); else go(-1); });
  show(0);
</script></body></html>
```

## Transitions

- Slide-to-slide: opacity + horizontal translate (above). Keep it ~0.4–0.6s — fast enough to feel responsive, slow enough to read as intentional.
- Navigation: **← →** and spacebar, plus click left/right half of screen (handy on a projector remote). Show a thin progress bar.
- Within-slide reveals (for *Minimal* density or step-by-step points): give elements `.reveal` and stagger their `transition-delay` when the slide becomes `.active`.
- Respect `prefers-reduced-motion`: wrap non-essential motion in `@media (prefers-reduced-motion:no-preference)`.

## Animated data-flow diagram (the centerpiece)

Build the diagram as **inline SVG** so JS can animate individual nodes and the flow between them. Drive it from the numbered path in `analysis.md`. The effect: as the presenter advances, each node activates in turn and the connector "flows" into the next — so the panel watches data move through the system.

```html
<svg viewBox="0 0 1000 200" class="flow">
  <!-- nodes -->
  <g class="node" data-step="0"><rect x="20"  y="70" width="150" height="60" rx="10"/><text x="95"  y="105">React Client</text></g>
  <g class="node" data-step="1"><rect x="240" y="70" width="150" height="60" rx="10"/><text x="315" y="105">FastAPI</text></g>
  <g class="node" data-step="2"><rect x="460" y="70" width="150" height="60" rx="10"/><text x="535" y="105">Inference</text></g>
  <g class="node" data-step="3"><rect x="680" y="70" width="150" height="60" rx="10"/><text x="755" y="105">PostgreSQL</text></g>
  <!-- connectors: dashed paths that "draw" via stroke-dashoffset -->
  <path class="link" data-step="1" d="M170 100 H240" marker-end="url(#arrow)"/>
  <path class="link" data-step="2" d="M390 100 H460" marker-end="url(#arrow)"/>
  <path class="link" data-step="3" d="M610 100 H680" marker-end="url(#arrow)"/>
  <defs><marker id="arrow" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto">
    <path d="M0,0 L8,3 L0,6 Z" fill="currentColor"/></marker></defs>
</svg>
```

```css
.node rect{fill:var(--secondary);stroke:var(--primary);stroke-width:2;transition:fill .4s,transform .4s}
.node text{text-anchor:middle;font:600 15px var(--font-body);fill:var(--text)}
.node.on rect{fill:var(--accent);transform:scale(1.04);transform-origin:center}
.node.on text{fill:#fff}
.link{fill:none;stroke:var(--primary);stroke-width:3;color:var(--primary);
      stroke-dasharray:120;stroke-dashoffset:120;transition:stroke-dashoffset .5s ease}
.link.on{stroke-dashoffset:0;stroke:var(--accent);color:var(--accent)}
```

```js
// Step through the flow automatically when the slide opens, or on key/click within it.
function animateDiagram(slide){
  const nodes=[...slide.querySelectorAll('.node')], links=[...slide.querySelectorAll('.link')];
  nodes.forEach(n=>n.classList.remove('on')); links.forEach(l=>l.classList.remove('on'));
  let step=0; const total=nodes.length;
  const tick=()=>{ if(step<total){ nodes[step].classList.add('on');
      const link=links.find(l=>+l.dataset.step===step); if(link) link.classList.add('on');
      step++; setTimeout(tick, 700); } };
  tick();
}
```

For a **layered architecture** diagram (not a linear chain), the same idea applies: group nodes into layer containers (`<g class="layer">`) and reveal layers top-to-bottom, then animate the cross-layer connectors. Keep the deck palette so the diagram matches the slides.

Optional libs if the diagram is complex: **D3** (force/linkage layouts) or **anime.js** for richer sequencing — both CDN, both optional. Don't reach for them unless the custom SVG can't express the layout.

## Vibe → CSS mapping

Take the chosen preset from `references/vibes.md` and set the `:root` custom properties: `--primary --secondary --accent --text --bg --font-head --font-body`. For fonts, prefer the safe families (they exist on most machines); if a preset serif isn't web-safe, load a near-equivalent from Google Fonts via a `<link>` (e.g. headers serif → "Source Serif 4"; keep body to a clean sans). Dark vibes → set `--bg` dark and `--text` light, and verify contrast.

## QA (required)

Render headless and eyeball a few slides plus the diagram mid-animation:

```bash
# Screenshot slides 1, the architecture slide, and the data-flow slide
npx --yes playwright@latest install chromium >/dev/null 2>&1
node -e '
const {chromium}=require("playwright");
(async()=>{const b=await chromium.launch();const p=await b.newPage();
await p.setViewportSize({width:1280,height:720});
await p.goto("file://'"$PWD"'/deck.html");
for(const k of [0,4,5]){ for(let j=0;j<k;j++){await p.keyboard.press("ArrowRight");}
  await p.waitForTimeout(1500); await p.screenshot({path:`qa-${k}.png`}); 
  // reset for next: reload
  await p.reload(); }
await b.close();})();' 2>/dev/null
ls qa-*.png
```

(If Playwright isn't available, fall back to the pptx skill's LibreOffice path won't help here — instead just open in a headless chromium you have, or visually reason through the SVG coordinates carefully.)

Check: text fits its container at 1280×720 and scales (use `vw`/`clamp()` for headings so it survives a projector), diagram labels are readable, nodes don't overlap connectors, contrast is sufficient on the chosen background, and transitions don't leave a previous slide visible underneath. Fix once, re-shoot the affected slides, stop.

## Deliver

Name it `<project>-review-deck.html`, present it, and tell the user: open in any browser, **← →** or click to navigate, the data-flow diagram animates as they advance. Mention it's one self-contained file they can email or host as-is.
