# News seeder

One-off bootstrap that fills the `news` collection in Cloud Firestore so the
app has something to show. A standalone content service will replace it; until
then this script is how stories get in.

It pulls recent English-language VR/XR articles from the public RSS feeds
listed in `feeds.json`, normalises them into the document shape the app reads,
de-duplicates across sources, and commits the newest ones.

No npm install — it runs on Node's built-in `fetch` and `crypto` (Node 18+).

## Running it

```bash
# See what would be written, touching nothing
node tools/news_seeder/seed.js --dry-run

# Write the newest 60 stories
node tools/news_seeder/seed.js

# Other options
node tools/news_seeder/seed.js --limit 100 --collection news_staging
```

| Flag | Default | Meaning |
| --- | --- | --- |
| `--limit` | `60` | How many stories to keep, newest first |
| `--dry-run` | off | Parse and report, write nothing |
| `--project` | `full-dive-co` | Firebase project id |
| `--database` | `main` | Firestore database id |
| `--collection` | `news` | Target collection |

## Credentials

Resolved in this order:

1. `GOOGLE_ACCESS_TOKEN` — a raw OAuth token, handy in CI.
2. `GOOGLE_APPLICATION_CREDENTIALS` — path to a service-account key with the
   *Cloud Datastore User* role. This is what the future service should use.
3. The local `gcloud` login. Set `GCLOUD_ACCOUNT` to pick an account:

   ```bash
   GCLOUD_ACCOUNT=you@fulldive.com node tools/news_seeder/seed.js
   ```

Writes go through the Firestore REST API with these credentials, which means
they bypass security rules — `firestore.rules` keeps the collection read-only
for the app itself.

## Document shape

Written to `news/{sha1(sourceUrl)[0..20]}`, so re-running updates the same
document for a story instead of duplicating it.

| Field | Type | Notes |
| --- | --- | --- |
| `title` | string | Headline |
| `summary` | string | Teaser, ≤ 220 chars, shown as the lead |
| `content` | string | Body text, paragraphs separated by blank lines |
| `imageUrl` | string | Cover image; may be empty |
| `sourceName` | string | e.g. `UploadVR` |
| `sourceUrl` | string | Original article, opened by "Read the full story" |
| `author` | string | May be empty |
| `publishedAt` | timestamp | Sort key for the feed |
| `tags` | string[] | Up to 3 topic chips |
| `language` | string | `en` |
| `createdAt` | timestamp | When the seeder wrote the row |

## Sources

`feeds.json` — Road to VR, UploadVR, MIXED Reality and Skarred Ghost, about
100 stories between them. Add a feed by appending `{ "name", "url" }`; any
RSS 2.0 or Atom feed works, and a feed that fails is skipped with a warning
rather than failing the run.
