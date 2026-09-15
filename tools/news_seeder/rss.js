/**
 * Minimal RSS/Atom reading: just enough of the format to pull the fields the
 * news collection needs, without adding a dependency to the bootstrap script.
 */

const ENTITIES = {
  amp: '&',
  lt: '<',
  gt: '>',
  quot: '"',
  apos: "'",
  nbsp: ' ',
  hellip: '…',
  mdash: '—',
  ndash: '–',
  rsquo: '’',
  lsquo: '‘',
  ldquo: '“',
  rdquo: '”',
};

export function decodeEntities(text) {
  return text
    .replace(/&#(\d+);/g, (_, code) => String.fromCodePoint(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCodePoint(parseInt(code, 16)))
    .replace(/&([a-z]+);/gi, (match, name) => ENTITIES[name.toLowerCase()] ?? match);
}

function unwrapCdata(text) {
  const cdata = text.match(/^\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*$/);
  return cdata ? cdata[1] : text;
}

/** Text content of the first `<tag>` inside `xml`, CDATA and entities resolved. */
export function tagText(xml, tag) {
  const escaped = tag.replace(':', '\\:');
  const match = xml.match(new RegExp(`<${escaped}(?:\\s[^>]*)?>([\\s\\S]*?)</${escaped}>`, 'i'));
  if (!match) return '';
  return decodeEntities(unwrapCdata(match[1])).trim();
}

/** Text content of every `<tag>` inside `xml`. */
export function tagTextAll(xml, tag) {
  const escaped = tag.replace(':', '\\:');
  const matches = xml.matchAll(new RegExp(`<${escaped}(?:\\s[^>]*)?>([\\s\\S]*?)</${escaped}>`, 'gi'));
  return [...matches].map((m) => decodeEntities(unwrapCdata(m[1])).trim()).filter(Boolean);
}

/** Value of `attribute` on the first `<tag ...>` inside `xml`. */
export function tagAttribute(xml, tag, attribute) {
  const escaped = tag.replace(':', '\\:');
  const element = xml.match(new RegExp(`<${escaped}\\s[^>]*>`, 'i'));
  if (!element) return '';
  const value = element[0].match(new RegExp(`${attribute}\\s*=\\s*["']([^"']+)["']`, 'i'));
  return value ? decodeEntities(value[1]) : '';
}

/** Strips markup, keeping paragraph breaks so the body stays readable. */
export function htmlToText(html) {
  const text = html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<figure[\s\S]*?<\/figure>/gi, '')
    .replace(/<(?:br|hr)\s*\/?>/gi, '\n')
    .replace(/<\/(?:p|div|li|h[1-6]|blockquote)>/gi, '\n\n')
    .replace(/<li[^>]*>/gi, '• ')
    .replace(/<[^>]+>/g, '');

  return decodeEntities(text)
    .replace(/[ \t ]+/g, ' ')
    .split('\n')
    .map((line) => line.trim())
    .join('\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

/** Splits a document into its `<item>` (RSS) or `<entry>` (Atom) blocks. */
export function splitItems(xml) {
  const rss = [...xml.matchAll(/<item(?:\s[^>]*)?>([\s\S]*?)<\/item>/gi)];
  if (rss.length > 0) return rss.map((m) => m[1]);
  return [...xml.matchAll(/<entry(?:\s[^>]*)?>([\s\S]*?)<\/entry>/gi)].map((m) => m[1]);
}

/** First usable image: an explicit media element, else the first inline `<img>`. */
export function extractImageUrl(itemXml, html) {
  const candidates = [
    tagAttribute(itemXml, 'media:content', 'url'),
    tagAttribute(itemXml, 'media:thumbnail', 'url'),
    tagAttribute(itemXml, 'enclosure', 'url'),
    (html.match(/<img[^>]+src\s*=\s*["']([^"']+)["']/i) ?? [])[1] ?? '',
  ];

  for (const candidate of candidates) {
    const url = decodeEntities(candidate ?? '').trim();
    if (url.startsWith('http')) return url;
  }
  return '';
}
