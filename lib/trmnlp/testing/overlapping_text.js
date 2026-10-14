const shown = (el) => el.checkVisibility({ opacityProperty: true, visibilityProperty: true });
const intersect = (a, b) => ({ left: Math.max(a.left, b.left), top: Math.max(a.top, b.top),
                               right: Math.min(a.right, b.right), bottom: Math.min(a.bottom, b.bottom) });
const area = (r) => Math.max(0, r.right - r.left) * Math.max(0, r.bottom - r.top);
const covers = (a, b, share) => area(intersect(a, b)) > Math.min(area(a), area(b)) * share;
const visiblePart = (rect, el) => {
  let part = rect;
  for (let parent = el; parent; parent = parent.parentElement) {
    if (getComputedStyle(parent).overflow !== 'visible') part = intersect(part, parent.getBoundingClientRect());
  }
  return part;
};
const textMeasuringContext = document.createElement('canvas').getContext('2d');
// A text range's box is as tall as its line, so the font's own box sits in the middle of it.
const baselineOf = (rect, metrics) => rect.top + metrics.fontBoundingBoxAscent +
  (rect.height - metrics.fontBoundingBoxAscent - metrics.fontBoundingBoxDescent) / 2;
const inkOf = (rect, text, style, oneLine) => {
  textMeasuringContext.font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
  const metrics = textMeasuringContext.measureText(text);
  const baseline = baselineOf(rect, metrics);
  const left = oneLine ? rect.left - metrics.actualBoundingBoxLeft : rect.left;
  const right = oneLine ? rect.left + metrics.actualBoundingBoxRight : rect.right;
  return { left, right, top: baseline - metrics.actualBoundingBoxAscent,
           bottom: baseline + metrics.actualBoundingBoxDescent };
};
const texts = [];
const range = document.createRange();
const walker = document.createTreeWalker(document.querySelector('.view') || document.body, NodeFilter.SHOW_TEXT);
for (let node = walker.nextNode(); node; node = walker.nextNode()) {
  const owner = node.parentElement;
  if (!node.data.trim() || owner instanceof SVGElement || owner.closest('script, style, svg') || !shown(owner)) continue;
  range.selectNodeContents(node);
  const style = getComputedStyle(owner);
  const lines = [...range.getClientRects()];
  lines.map((rect) => visiblePart(inkOf(rect, node.data.trim(), style, lines.length === 1), owner))
    .filter((rect) => area(rect) > 4)
    .forEach((rect) => texts.push({ node, owner, rect, text: node.data.trim().slice(0, 40) }));
}
const SHARED_INK_PIXELS = 4;
const glyphCache = new Map();
const glyphsOf = (node) => {
  if (glyphCache.has(node)) return glyphCache.get(node);
  const style = getComputedStyle(node.parentElement);
  const font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
  const glyphs = [];
  for (let start = 0; start < node.data.length;) {
    const end = start + String.fromCodePoint(node.data.codePointAt(start)).length;
    const glyph = node.data.slice(start, end);
    if (glyph.trim()) {
      range.setStart(node, start);
      range.setEnd(node, end);
      [...range.getClientRects()].forEach((rect) => {
        textMeasuringContext.font = font;
        const metrics = textMeasuringContext.measureText(glyph);
        const box = visiblePart(inkOf(rect, glyph, style, false), node.parentElement);
        if (area(box) > 1) glyphs.push({ glyph, font, box, x: rect.left, baseline: baselineOf(rect, metrics) });
      });
    }
    start = end;
  }
  glyphCache.set(node, glyphs);
  return glyphs;
};
// Draws each glyph where the page put it and counts the pixels both inked, so a glyph tucked into the
// empty corner of another glyph's box does not count.
const inkPixels = (glyph, region) => {
  const canvas = document.createElement('canvas');
  canvas.width = Math.ceil(region.right - region.left);
  canvas.height = Math.ceil(region.bottom - region.top);
  const context = canvas.getContext('2d');
  context.font = glyph.font;
  context.fillText(glyph.glyph, glyph.x - region.left, glyph.baseline - region.top);
  const alpha = context.getImageData(0, 0, canvas.width, canvas.height).data;
  const inked = new Set();
  for (let i = 3; i < alpha.length; i += 4) if (alpha[i] > 127) inked.add(i);
  return inked;
};
const inkOverlaps = (one, other) => {
  const shared = intersect(one.box, other.box);
  if (area(shared) < 1) return false;
  const otherInk = inkPixels(other, shared);
  return [...inkPixels(one, shared)].filter((pixel) => otherInk.has(pixel)).length >= SHARED_INK_PIXELS;
};
const inkTouches = (a, b) => glyphsOf(a.node).some((glyph) => glyphsOf(b.node).some((other) => inkOverlaps(glyph, other)));
const related = (a, b) => a === b || a.contains(b) || b.contains(a);
const found = [];
texts.forEach((a, i) => texts.slice(i + 1).forEach((b) => {
  if (!related(a.owner, b.owner) && covers(a.rect, b.rect, 0) && inkTouches(a, b)) found.push(`"${a.text}" and "${b.text}"`);
}));
const titleBar = document.querySelector('.view .title_bar');
if (titleBar) {
  const bar = titleBar.getBoundingClientRect();
  texts.filter((t) => !titleBar.contains(t.owner) && covers(t.rect, bar, 1 / 3))
    .forEach((t) => found.push(`"${t.text}" and the title bar`));
}
return [...new Set(found)];
