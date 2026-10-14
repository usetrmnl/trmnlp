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
// A glyph can reach past its line box, above it or below it, by up to about half its font size.
const widen = (rect, by) => ({ left: rect.left - by, top: rect.top - by, right: rect.right + by, bottom: rect.bottom + by });
const texts = [];
const range = document.createRange();
const walker = document.createTreeWalker(document.querySelector('.view') || document.body, NodeFilter.SHOW_TEXT);
for (let node = walker.nextNode(); node; node = walker.nextNode()) {
  const owner = node.parentElement;
  if (!node.data.trim() || owner instanceof SVGElement || owner.closest('script, style, svg') || !shown(owner)) continue;
  range.selectNodeContents(node);
  const fontSize = parseFloat(getComputedStyle(owner).fontSize) || 16;
  [...range.getClientRects()].map((line) => ({ line: visiblePart(line, owner), rect: visiblePart(widen(line, fontSize / 2), owner) }))
    .filter(({ line }) => area(line) > 4)
    .forEach(({ line, rect }) => texts.push({ owner, line, rect, text: node.data.trim().slice(0, 40) }));
}
const related = (a, b) => a === b || a.contains(b) || b.contains(a);
const pairs = [];
const neighbors = new Map(texts.map((t) => [t.owner, new Set()]));
texts.forEach((a, i) => texts.slice(i + 1).forEach((b) => {
  if (a.owner === b.owner || !covers(a.rect, b.rect, 0)) return;
  neighbors.get(a.owner).add(b.owner);
  neighbors.get(b.owner).add(a.owner);
  if (!related(a.owner, b.owner)) pairs.push([a, b]);
}));
// Texts whose widened boxes do not meet share a group, and each group one screenshot.
const groups = new Map();
pairs.flat().map((t) => t.owner).forEach((owner) => {
  if (groups.has(owner)) return;
  const taken = new Set([...neighbors.get(owner)].map((other) => groups.get(other)));
  let group = 0;
  while (taken.has(group)) group += 1;
  groups.set(owner, group);
});
groups.forEach((group, owner) => owner.setAttribute('data-trmnlp-text', group));
const candidates = pairs.map(([a, b]) => {
  const region = intersect(a.rect, b.rect);
  return { texts: [groups.get(a.owner), groups.get(b.owner)], names: `"${a.text}" and "${b.text}"`,
           region: { left: region.left, top: region.top, width: region.right - region.left,
                     height: region.bottom - region.top } };
});
const underTitleBar = [];
const titleBar = document.querySelector('.view .title_bar');
if (titleBar) {
  const bar = titleBar.getBoundingClientRect();
  texts.filter((t) => !titleBar.contains(t.owner) && covers(t.line, bar, 1 / 3))
    .forEach((t) => underTitleBar.push(`"${t.text}" and the title bar`));
}
return { candidates, under_title_bar: [...new Set(underTitleBar)] };
