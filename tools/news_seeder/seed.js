#!/usr/bin/env node
/**
 * One-off bootstrap: pulls recent English-language VR/XR stories from public
 * RSS feeds and writes them into the `news` collection of Cloud Firestore,
 * which is what the Fulldive VR News app reads.
 *
 * A standalone service will take this over later; until then run:
 *
 *   node tools/news_seeder/seed.js            # seed ~60 stories
 *   node tools/news_seeder/seed.js --dry-run  # print what would be written
 *
 * Credentials: GOOGLE_APPLICATION_CREDENTIALS (service-account key) or a
 * local `gcloud auth login` (set GCLOUD_ACCOUNT to pick the account).
 */

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { FirestoreClient, resolveAccessToken } from './firestore.js';
import { extractImageUrl, htmlToText, splitItems, tagAttribute, tagText, tagTextAll } from './rss.js';

const HERE = dirname(fileURLToPath(import.meta.url));

const DEFAULTS = {
  project: 'full-dive-co',
  // The Firebase project has no `(default)` database; the only one is `main`.
  database: 'main',
  collection: 'news',
  limit: 60,
};

const USER_AGENT =
  'FulldiveVRNewsSeeder/1.0 (+https://fulldive.com; one-off content bootstrap)';

/** Topic chips shown in the app, matched against the title and summary. */
const TOPIC_KEYWORDS = [
  ['Quest', /\bquest\s?\d?\b|\bmeta quest\b/i],
  ['Vision Pro', /\bvision pro\b|\bvisionos\b/i],
  ['PSVR2', /\bpsvr\s?2\b|\bplaystation vr\b/i],
  ['SteamVR', /\bsteamvr\b|\bsteam frame\b|\bvalve\b/i],
  ['Apple', /\bapple\b/i],
  ['Meta', /\bmeta\b(?!\s?verse)/i],
  ['Hardware', /\bheadset\b|\bcontroller\b|\bchipset\b|\bdisplay\b|\bhaptic/i],
  ['Games', /\bgame\b|\bgames\b|\bgameplay\b|\bstudio\b|\blaunch(?:es|ed)?\b/i],
  ['AI', /\bai\b|\bartificial intelligence\b|\bneural\b/i],
  ['AR', /\baugmented reality\b|\bsmart glasses\b|\b\bar glasses\b/i],
  ['VR', /\bvirtual reality\b|\bvr\b/i],
  ['XR', /\bxr\b|\bmixed reality\b|\bmr headset\b/i],
];

/** Feed categories that say nothing useful on a chip. */
const GENERIC_CATEGORIES = /^(news|reviews?|featured|general|uncategor\w+|blog|articles?)$/i;

function parseArgs(argv) {
  const options = { ...DEFAULTS, dryRun: false };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => argv[(i += 1)];

    switch (arg) {
      case '--dry-run': options.dryRun = true; break;
      case '--limit': options.limit = Number(next()); break;
      case '--project': options.project = next(); break;
      case '--database': options.database = next(); break;
      case '--collection': options.collection = next(); break;
      case '--help': case '-h': options.help = true; break;
      default:
        throw new Error(`Unknown argument: ${arg}`);
    }
  }

  if (!Number.isInteger(options.limit) || options.limit < 1) {
    throw new Error('--limit expects a positive integer');
  }
  return options;
}

async function fetchFeed(feed) {
  const response = await fetch(feed.url, {
    headers: { 'user-agent': USER_AGENT, accept: 'application/rss+xml, application/xml, text/xml' },
    redirect: 'follow',
    signal: AbortSignal.timeout(30_000),
  });

  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  return response.text();
}

/** Cuts `text` to `max` characters on a word boundary. */
function truncate(text, max) {
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return `${cut.slice(0, lastSpace > max * 0.6 ? lastSpace : max).trimEnd()}…`;
}

/** Drops the "The post … appeared first on …" boilerplate WordPress appends. */
function stripFeedBoilerplate(text) {
  return text
    .replace(/\n?The post .*? appeared first on .*?\.?$/s, '')
    .replace(/\n?This (?:post|article) (?:was )?(?:originally|first) (?:published|appeared).*$/s, '')
    .trim();
}

function buildTags(categories, haystack) {
  const fromFeed = categories
    .map((category) => category.split(/\s*[&,/]\s*/)[0].trim())
    .map((category) => category.replace(/\b[a-z]/g, (letter) => letter.toUpperCase()))
    .filter((category) => category.length > 1 && category.length <= 18)
    .filter((category) => !GENERIC_CATEGORIES.test(category));

  const fromKeywords = TOPIC_KEYWORDS.filter(([, pattern]) => pattern.test(haystack)).map(([tag]) => tag);

  const tags = [];
  for (const tag of [...fromKeywords, ...fromFeed]) {
    if (!tags.some((existing) => existing.toLowerCase() === tag.toLowerCase())) tags.push(tag);
    if (tags.length === 3) break;
  }
  return tags.length > 0 ? tags : ['VR'];
}

/** RSS/Atom `<item>` -> the document shape the app reads. */
function toArticle(itemXml, feed) {
  const title = tagText(itemXml, 'title');
  const link = tagText(itemXml, 'link') || tagAttribute(itemXml, 'link', 'href');
  if (!title || !link) return null;

  const publishedRaw =
    tagText(itemXml, 'pubDate') || tagText(itemXml, 'published') || tagText(itemXml, 'updated') || tagText(itemXml, 'dc:date');
  const publishedAt = new Date(publishedRaw);
  if (Number.isNaN(publishedAt.getTime())) return null;

  const descriptionHtml = tagText(itemXml, 'description') || tagText(itemXml, 'summary');
  const contentHtml = tagText(itemXml, 'content:encoded') || tagText(itemXml, 'content') || descriptionHtml;

  const content = stripFeedBoilerplate(htmlToText(contentHtml));
  const summarySource = stripFeedBoilerplate(htmlToText(descriptionHtml)) || content;
  if (content.length < 120) return null;

  const categories = tagTextAll(itemXml, 'category');
  const summary = truncate(summarySource.split('\n')[0], 220);

  return {
    id: createHash('sha1').update(link.replace(/[?#].*$/, '')).digest('hex').slice(0, 20),
    data: {
      title,
      summary,
      content,
      imageUrl: extractImageUrl(itemXml, contentHtml || descriptionHtml),
      sourceName: feed.name,
      sourceUrl: link,
      author: tagText(itemXml, 'dc:creator') || tagText(itemXml, 'author').replace(/<[^>]+>/g, '').trim(),
      publishedAt,
      tags: buildTags(categories, `${title} ${summary}`),
      language: 'en',
      createdAt: new Date(),
    },
  };
}

async function collectArticles(feeds) {
  const results = await Promise.allSettled(
    feeds.map(async (feed) => {
      const xml = await fetchFeed(feed);
      const articles = splitItems(xml).map((item) => toArticle(item, feed)).filter(Boolean);
      console.log(`  ${feed.name.padEnd(16)} ${String(articles.length).padStart(3)} stories`);
      return articles;
    }),
  );

  const articles = [];
  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      articles.push(...result.value);
    } else {
      console.warn(`  ${feeds[index].name.padEnd(16)} skipped — ${result.reason.message}`);
    }
  });
  return articles;
}

function dedupe(articles) {
  const byId = new Map();
  const seenTitles = new Set();

  for (const article of articles) {
    const titleKey = article.data.title.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
    if (byId.has(article.id) || seenTitles.has(titleKey)) continue;
    byId.set(article.id, article);
    seenTitles.add(titleKey);
  }
  return [...byId.values()];
}

async function main() {
  const options = parseArgs(process.argv.slice(2));

  if (options.help) {
    console.log(readFileSync(resolve(HERE, 'README.md'), 'utf8'));
    return;
  }

  const feeds = JSON.parse(readFileSync(resolve(HERE, 'feeds.json'), 'utf8'));

  console.log(`Fetching ${feeds.length} VR news feeds…`);
  const collected = await collectArticles(feeds);

  const articles = dedupe(collected)
    .sort((a, b) => b.data.publishedAt - a.data.publishedAt)
    .slice(0, options.limit);

  if (articles.length === 0) {
    console.error('No stories could be parsed — nothing to write.');
    process.exitCode = 1;
    return;
  }

  const withImages = articles.filter((article) => article.data.imageUrl).length;
  console.log(
    `\n${articles.length} stories ready (${withImages} with a cover image), ` +
      `newest ${articles[0].data.publishedAt.toISOString().slice(0, 10)}, ` +
      `oldest ${articles.at(-1).data.publishedAt.toISOString().slice(0, 10)}.`,
  );

  if (options.dryRun) {
    console.log('\n--dry-run, nothing written. Sample:\n');
    for (const article of articles.slice(0, 3)) {
      console.log(`  ${article.data.title}`);
      console.log(`    ${article.data.sourceName} · ${article.data.publishedAt.toISOString()} · [${article.data.tags.join(', ')}]`);
      console.log(`    image:   ${article.data.imageUrl || '(none)'}`);
      console.log(`    summary: ${truncate(article.data.summary, 110)}`);
      console.log(`    body:    ${article.data.content.length} chars\n`);
    }
    return;
  }

  const client = new FirestoreClient({
    projectId: options.project,
    databaseId: options.database,
    accessToken: await resolveAccessToken(),
  });

  const written = await client.commit(options.collection, articles);
  const total = await client.count(options.collection);
  console.log(
    `\nWrote ${written} documents to ${options.project}/${options.database}/${options.collection} ` +
      `(${total} in the collection now).`,
  );
}

main().catch((error) => {
  console.error(`\n${error.message}`);
  process.exitCode = 1;
});
