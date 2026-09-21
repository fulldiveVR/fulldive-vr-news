# Google Play release plan

This is an **update to an app that already exists on Play** under
`in.fulldive.shell`, not a new listing. That changes the shape of the work: the
listing, the reviews and the installed base all carry over, and the same users
who installed a VR launcher will receive a news reader. Most of the plan below
is about making that transition clean.

Everything in `metadata/` follows the layout
[fastlane supply](https://docs.fastlane.tools/actions/supply/) expects, so it
can be uploaded by hand today and automated later without moving files.

---

## 1. Check these before anything else

These are the things that can stop the release, and none of them can be
answered from the repository — they need the Play Console.

| Check | Why it matters |
| --- | --- |
| **Play App Signing** — is `in.fulldive.shell` enrolled? | If it is, `keys/keys.jks` is the *upload* key and Google holds the app signing key. Confirm the upload certificate's SHA-1 matches `d25c7e06…55d0`, or the upload is rejected. |
| ~~**Live `versionCode`**~~ — resolved | The public listing shows version **6.10.2.1.1**, which is the Unity formula's cardboard/arm64 build, i.e. `versionCode` **6100211**. Ours is `7000000`, so it clears production, not just the source tree. |
| **Who owns the listing** | The developer account needs release permissions for this package. |
| **Existing listing content** | The current screenshots, description and feature graphic describe a VR launcher. All of it gets replaced. |
| **App category** | The listing carries **Entertainment** from the launcher. Change it to **App** + **News & Magazines** — that is the app's main function, and it has to agree with the IARC answer "primarily a news product: Yes". Expect Play to then ask for a news-app declaration. |
| **Content rating questionnaire** | Must be re-answered: a news reader with user-visible third-party content is a different questionnaire from a VR launcher. |

## 2. What ships

| Artefact | How to produce it |
| --- | --- |
| `fulldive-vr-news-v7.0.0.aab` | `tools/build_release.sh aab` — signed with `keys/keys.jks` |
| Listing text | `metadata/en-US/*.txt` |
| Icon, feature graphic, screenshots | `python3 tools/store_assets.py` |

The artwork is generated, not hand-drawn: `tools/store_assets.py` reads the
device captures in `screenshots/raw/` and composes them. Retake the captures
and re-run it and the whole listing regenerates. To retake them, put the
emulator in demo mode so the status bar is clean:

```bash
export ANDROID_SERIAL=emulator-5554
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 0930
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4 -e fully true
adb shell am broadcast -a com.android.systemui.demo -e command network -e mobile hide
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
# … capture, then:
adb shell am broadcast -a com.android.systemui.demo -e command exit
```

### Asset specs, and what we produced

| Asset | Play requires | Ours |
| --- | --- | --- |
| App icon | 512×512 PNG, 32-bit | ✅ `images/icon.png` — launcher artwork on brand navy |
| Feature graphic | 1024×500 PNG/JPEG, no alpha | ✅ `images/featureGraphic.png` |
| Phone screenshots | 2–8, 16:9–9:16, min 320px side | ✅ 4 × 1080×1920 in `images/phoneScreenshots/` |
| 7" tablet | optional | ➖ not supplied — the app is phone-first |
| 10" tablet | optional | ➖ not supplied |
| Promo video | optional | ➖ none yet |

The 512×512 icon is upscaled from the 192×192 launcher artwork, which is the
largest copy that exists in `fulldive-unity-plugins`. It is fine at the sizes
Play actually renders, but if anyone still has the vector original, re-export
from that instead.

## 3. Store listing fields

| Field | Value |
| --- | --- |
| App name | `metadata/en-US/title.txt` — Fulldive VR News (16/30) |
| Short description | `short_description.txt` (73/80) |
| Full description | `full_description.txt` (1485/4000) |
| What's new | `changelogs/7000000.txt` (423/500) |
| Category | News & Magazines |
| Tags | VR, news, technology |
| Contact email / website / privacy policy | **still needed — see §6** |

## 4. Data safety

**Does your app collect or share any of the required user data types? — No.**

That answer is checked against the shipped artefact, not just the dependency
list. In `fulldive-vr-news-v7.0.0.apk`:

| Probe | Result |
| --- | --- |
| Permissions | `INTERNET`, `ACCESS_NETWORK_STATE` only |
| Registered components | `FirebaseInitProvider`, `ComponentDiscoveryService`, `androidx.startup`, `profileinstaller` |
| `firebase/firestore` | present (the feed) |
| `firebase/installations`, `firebase/analytics`, `gms/measurement` | **absent** |
| `crashlytics`, `firebase/messaging`, `firebase/auth`, `firebase/iid` | **absent** |
| `AdvertisingIdClient`, `gms/ads` | **absent** |

Reproduce it with:

```bash
unzip -qo build/outputs/fulldive-vr-news-v7.0.0.apk -d /tmp/apk
strings /tmp/apk/classes.dex | grep -c "firebase/analytics"   # expect 0
```

So there is no analytics, no crash reporting, no advertising ID, no ads SDK
and no account system. Nothing identifying leaves the device: Firestore reads
are anonymous, and `cached_network_image` caches to local storage, which is
not collection.

With **No** selected, steps 3 (Data types) and 4 (Data usage and handling) are
skipped — the encryption-in-transit and deletion-request questions only appear
under **Yes**. Leave both **Additional badges** off: the independent security
review needs a MASA audit we have not done, and UPI is for Indian payment apps.

### The one judgement call

The in-app browser (`webview_flutter`) loads publisher pages, and those pages
run their own analytics and set their own cookies. This is the same situation
as any app with an in-app browser, and it is the site's collection under the
site's own policy, not ours — user-initiated navigation to third-party content
is outside what the form asks you to declare. It stays that way only as long as
we do not read anything back out of the WebView; injecting JavaScript to
extract page data, or adding a cookie/analytics bridge, would change the
answer. If in doubt, **View required data types** on that page lists exactly
what Play is asking about.

Re-check this whole section if anyone ever adds Firebase Analytics,
Crashlytics, push notifications or an account system — each one flips the
answer to Yes.

## 4b. The rest of App content

Data safety is one entry in **App content**. Expect these too:

| Section | Answer |
| --- | --- |
| Privacy policy | **A URL is required even when nothing is collected — still outstanding, see §6** |
| Ads | No ads |
| App access | No login required; all content is available without credentials |
| Content rating | Re-run the questionnaire — see below |
| Target audience | 13-15, 16-17, 18+ — see below |
| News apps | Appears once the category is News & Magazines — see below |
| Advertising ID | Not used (nothing in the APK references it) |
| Government / financial / health features | None |

### Content rating

**Step 1 — Category: All Other App Types.** Its description lists news apps
explicitly. Not *Game* (the app is about games, it is not one) and not *Social
or Communication* (no messaging, no exchange between users).

**Step 2 — Questionnaire (All Other App Types).** The questions ask what the
app *can* contain, and since **Online Content** is Yes, that covers the feed —
not just the APK.

| Question | Answer | Why |
| --- | --- | --- |
| Ratings-relevant content downloaded as part of the app package | No | The APK ships only the logo and wordmark |
| Natively allows users to interact or exchange content | No | No accounts, comments or sharing |
| Features content that isn't part of the initial download | **Yes** | The whole feed; the same case as news articles in the NYT app |
| Can contain violent material | **Yes** | See below |
| Can contain sexual material or nudity | No | The four feeds are mainstream tech press |
| Can contain potentially offensive language | Borderline — see below | |
| Can contain references to drugs | No | Not a subject these outlets cover |
| *Focuses on* promoting age-restricted products | No | "Focuses on" is the bar, and we do not |
| Shares precise location with other users | No | No location permission or API |
| Allows purchase of digital goods | No | No billing, no IAP |
| Cash rewards, gift cards, play-to-earn, crypto, NFTs | No | None of it |
| **Is the app a web browser or search engine** | **No** | It is a news reader with an in-app viewer — no address bar, no search, no tabs, no user-entered URLs. Having a WebView does not make an app a browser, any more than it does for Reddit or X |
| Is the app primarily a news or educational product | **Yes** | That is exactly what it is |

**Violence is Yes, and it is not a close call.** Of the 60 seeded stories, 10
carry weapon or combat terms in the headline or teaser alone — including
"Gunman Contracts: Stand Alone Early Access Review – Such Beautiful Violence" —
and cover art regularly shows armed characters (Half-Life: Alyx key art is in
the current feed). Answering Yes opens three follow-ups:

| Follow-up | Answer | Why |
| --- | --- | --- |
| Is accessing this material the primary purpose of the app? | **No** | The purpose is VR/XR industry news — hardware, releases, business. Combat imagery arrives as a side effect of covering games. This is the question that separates a news app from one where violence *is* the product, so it carries the most weight |
| Can this violent material be visually depicted? | **Yes** | Publisher cover art shows armed characters — the Half-Life: Alyx key art in the feed has Combine soldiers levelling guns at a kneeling figure |
| Can these violent images be gross or gory? | **No** | See below |
| Are these depictions strictly limited to slapstick or bloodless, unrealistic, cartoony ones? | **No** | "Strictly limited" is the bar. Primal Rumble is cartoony and Rogue Planet stylised, but Gunman Contracts (realistic pistols firing in a subway car) and Breachers: Outbreak (tactical soldiers, muzzle flashes) are realistic shooter art — bloodless, but neither unrealistic nor cartoony |
| Can this violent material be referred to through text or spoken about? | **Yes** | Article text reviews shooters and combat games. No audio in the app, but the question covers either |

**"Gross or gory" is No, and it was checked rather than assumed.** The cover
images of the five most violence-adjacent stories in the feed — Gunman
Contracts, Discovery: Rogue Planet, Primal Rumble, Breachers: Outbreak, In
Death: Unchained — show firing pistols and an explosion, a stylised dragon, a
cartoon dinosaur, soldiers with muzzle flashes, and a snowy cathedral with a
bow. Weapons and combat throughout; no blood, wounds or dismemberment
anywhere. That is structural, not luck: what RSS carries is promotional key
art, which publishers keep non-gory because it has to run on public
storefronts. In the article text, "blood" and "gore" terms appear once or twice
across 265,000 characters, figuratively.

This one matters — "gross or gory" is among the strongest rating drivers and
pushes towards Mature 17+ / PEGI 16-18. Revisit it if the source list ever
grows to outlets that put graphic screenshots in their feeds.

Check it against live data before answering:

```bash
# titles and teasers carrying violence terms
curl -s -X POST "https://firestore.googleapis.com/v1/projects/full-dive-co/databases/main/documents:runQuery" \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" -H "Content-Type: application/json" \
  -d '{"structuredQuery":{"from":[{"collectionId":"news"}],"limit":60}}'
```

**Language is the genuinely borderline one.** Across 265,000 characters of
article text the seeder pulled in, there is one "shit", one "hell" and one
"bloody" — mild, but present, and we republish publisher text verbatim with no
editorial filter. "Can the app contain potentially offensive language" has a
low bar and we do not control the wording, so **Yes** is the defensible answer;
**No** is arguable only because the volume is so low.

### News and magazine apps declaration

Switching the category to News & Magazines adds this declaration, in three
steps: Entity details, Content, Credentials. Its stated purpose is
transparency about who is behind the app.

- **Entity details — "on behalf of your developer account's legal entity,
  Browser by Fulldive Co.?" → Yes.** Fulldive publishes its own app; there is
  no separate news organisation behind it. *No* is for publishing on behalf of
  someone else's newsroom.
- **Content — category: Commercial / private**, and **"Is your app a news or
  magazine aggregator?" → Yes.** Fulldive Co. is a private company, not a
  non-profit or a public broadcaster; and the app carries no original
  reporting — every story belongs to the publication that wrote it and links
  back to the source.
- **Credentials** — press accreditation or media registration. Declaring the
  app an aggregator should keep this light: those are asked of applicants who
  claim their own newsroom. Having none is fine.

Declaring ourselves an aggregator here sits awkwardly against storing the full
article body (§6). Behaving like one — headline, excerpt, link — would make the
declaration and the product agree.

### Target audience

Target age **13-15, 16-17, 18 and over**.

Once the content rating is redone, Play greys out the under-9 groups and notes
the ESRB rating is now "10+ or higher" — useful confirmation that the honest
questionnaire moved the rating off Everyone. **9-12 becomes selectable at that
point; leave it unchecked.** Any group below 13 pulls the app under the Google
Play Families policy, which restricts exactly the thing we deliberately kept —
open navigation to arbitrary web pages in the WebView. Ticking it would put the
Families commitment at odds with what we declared in the rating questionnaire.

Play then warns that the app "could unintentionally appeal to children" and
shows a **Not designed for children** label. That is informational, not a
blocker, and the label is fine to ship with. It is worth knowing what triggers
it though: Play reads the store listing, and our first two screenshots lead
with a cartoon dinosaur (the Primal Rumble story that happened to be top of the
feed when the captures were taken). Leading with a hardware story would both
soften that signal and look more like what the app is for — retake
`screenshots/raw/01_feed.png` and `02_reader.png` on a different lead story and
re-run `tools/store_assets.py`.

## 5. Release steps

1. `tools/build_release.sh aab`
2. Verify the signature matches the legacy certificate:
   `apksigner verify --print-certs build/outputs/fulldive-vr-news-v7.0.0.apk`
3. Play Console → **Testing → Internal testing** → upload the `.aab`, add
   testers, install over a copy of the old app and confirm it updates in place
   rather than installing alongside.
4. Push the store listing with `tools/play_listing.py push --for-review
   --lang en-US` rather than editing it in the Console. See 5b for why. It
   sends name, descriptions, icon, feature graphic and screenshots in one
   commit, which also satisfies Play's rule that an icon, a feature graphic and
   at least two phone screenshots must all be present at every save.
5. Re-run the content rating questionnaire and the Data safety form.
6. Set the category to News & Magazines.
7. **Production → staged rollout, starting small.** This update changes what
   the app *is* for everyone who already has it, so watch the reviews and the
   uninstall rate for a day before widening.

## 5b. When the Console says "Your changes couldn't be saved"

That banner is generic; the real reason is in the failed request. Open DevTools
→ Network, retry the save, and read the **Response** of the red request. It
comes back as protobuf-ish JSON:

```json
{"1":9,"2":"Precondition check failed.","3":[{"1":"…StoreListingError","2":"CgoItgESBWVuLVVT"}]}
```

`"1":9` is gRPC `FAILED_PRECONDITION`. Decode the base64 detail to find which
listing it is about:

```bash
python3 -c 'import base64; print(base64.b64decode("CgoItgESBWVuLVVT").hex(" "))'
# 0a 0a 08 b6 01 12 05 65 6e 2d 55 53  ->  { code: 182, locale: "en-US" }
```

That code is **not** about a missing icon or screenshot — ours were all in
place, in the draft and in storage. It was a stale field the Console form can
no longer write: the en-US listing carried a promo video stored as
`https://youtu.be/k9QPMD3zvg8`. Play now accepts only the
`https://www.youtube.com/watch?v=...` form, so every save failed a precondition
on a value the form never resubmits — which is why the error was byte-identical
whatever we changed, and why it named `en-US`, the only locale with a video.

**The fix goes through the public API, not the Console.** `tools/play_listing.py`
talks to androidpublisher v3, which can write fields the Console form cannot and
returns readable errors instead of numeric codes:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=../creds.txt   # google-play-uploader@full-dive-co
tools/play_listing.py read                 # dump what Play has stored, per locale
tools/play_listing.py validate --lang en-US # apply store/metadata, validate, discard
tools/play_listing.py push --for-review --lang en-US
```

Two things to know before using it:

- **There is no draft.** `changesNotSentForReview=true` is rejected for this app
  ("Changes are sent for review automatically"), so `push` submits for review.
  Use `validate` for dry runs.
- **`video.txt` controls the promo video.** `store/metadata/en-US/` has no such
  file, so each push clears the field. Add one to set a video back.

The old VR-era listing is preserved in `play-stored-listing.json` — it is what
`read` dumped before the replacement, including the APK links and the
crypto-earning claims.

## 5c. Leftover monetization products

The Console still carries two products from the Unity app:

- subscription **`subscription.player`**
- in-app product **`support_fulldive_team`**

The new build cannot sell either. The release APK contains no billing code at
all — zero references to `BillingClient`, `com.android.vending.billing`,
`ProductDetails` or `SkuDetails` — and no `com.android.vending.BILLING`
permission:

```bash
strings /tmp/apk/classes.dex | grep -ci billingclient   # 0
```

They are also at odds with what we declared: the IARC questionnaire answers
"allows users to purchase digital goods" with **No**. Deactivate them rather
than carrying them forward — Play only demands per-locale translations for
*active* products, so deactivating clears that requirement too.

**Check for active subscribers first.** Deactivating a subscription stops new
purchases and does not itself cancel existing ones, but if anyone is still
subscribed to `subscription.player` that is a commercial decision, not
housekeeping. The one-off `support_fulldive_team` is safe to retire.

## 6. Open decisions — needed before production

**Full article text.** The seeder stores each story's complete body
(`content:encoded` from the publisher's RSS) and the reader renders all of it.
Aggregators normally show a headline, a short excerpt and a link, and keep the
full text on the publisher's page. Publishing the complete text of other
people's articles is a copyright exposure, and it is the kind of thing a
publisher complains about rather than Play catching it at review.

The app already has the safer path built: the in-app browser opens the
publisher's own page. Switching to excerpt-only is a small change — cap
`content` in the seeder and make the reader's "Read the full story" the primary
action. Worth deciding before a public rollout.

**Naming publications in the listing.** The description and screenshots name
Road to VR, UploadVR, MIXED and Skarred Ghost. That is ordinary for an
aggregator, but it does use their names to market the app, and it commits us to
keeping those feeds. Drop the names if that is not wanted.

~~**Privacy policy URL**~~ — resolved. This section used to record
`browser.fulldive.com` as having no DNS record, which made every listing save
fail with `FAILED_PRECONDITION` / StoreListingError 182 on en-US. Both hosts
now resolve and answer 200, and the policy is live at
`https://fulldive.com/privacy-policy/`. **Keep the trailing slash** — without
it the site answers 308, and Play follows redirects rather than accepting
them. See §7.2 for the full set of URLs.

**Content freshness.** The feed is filled by a manual script run. Until the
content service exists, the app ships with a snapshot that ages, which is a bad
first impression for a news app — the top story's timestamp is the first thing
a user sees. Either run the seeder right before release, or hold the rollout
until the service is live.

---

## 7. The News and Magazines rejection (enforced 21 Sep 2026)

Play removed the previous version under the **News and Magazines policy**. The
single finding was contact information:

> Doesn't contain a dedicated website and in-app page that's easy to find and
> clearly shows relevant contact information.

The other four bullets in the notice ("content less than three months old",
"original sources for all articles") were measured against the live feed and
already pass — see *Checked, not assumed* below. Only contact details need
work: in the app, and in the three Console fields that point at the website.

### 7.1 In the app — done in `7.0.3` (versionCode `7000003`)

`lib/src/screens/contact_screen.dart` is a full-screen **Contact us** page:
support email, the contact, privacy and terms pages, publisher name and the
app version,
plus a paragraph saying the app is an aggregator and how a publisher asks for
their feed to be dropped. Reachable two ways, because "easy to find" is the
part that was failed:

- the feed's overflow menu (⋮), where the item is spelled out in words
- a **Contact us** link at the end of the feed

The publisher is named **Fulldive Corp.**, matching the privacy policy and the
terms of use. The Play account displays "Browser by Fulldive Co."; that stays
the answer to the declaration's *Entity details* question, which asks about the
developer account rather than about the company.

The address is rendered as selectable plain text with a copy button, not only
as a tappable link — a review device often has no mail client, and a `mailto:`
that opens nothing reads as "no contact information". `FulldiveContact` holds
the values; `test/contact_details_test.dart` keeps the version in step with
`pubspec.yaml` and asserts the page really renders the address.

### 7.2 On the website — the pages exist, at these URLs

The canonical pages, confirmed live on 21 Sep 2026:

| Page | URL |
| --- | --- |
| Contact us | `https://fulldive.com/pages/contact-us/` |
| Privacy policy | `https://fulldive.com/privacy-policy/` |
| Terms of use | `https://fulldive.com/terms-of-use/` |

**The trailing slash is not optional.** Without it fulldive.com answers `308`,
and the site serves its homepage — with HTTP 200 — for every path it does not
recognise, including `/contact`, `/contact-us`, `/support` and `/about`. So a
guessed or shortened URL does not fail loudly; it quietly returns a page with
no contact section on it, which is very likely how the review reached
"doesn't contain a dedicated website … page". Use the three URLs above
verbatim, everywhere.

One thing worth fixing on the contact page: the address is wrapped in
Cloudflare's Email Address Obfuscation, so the HTML says

```html
<span class="__cf_email__" data-cfemail="1261…">[email&#160;protected]</span>
```

and only JavaScript turns it back into `support@fulldive.com`. A human
reviewer with a browser sees the address; anything fetching the page without
running scripts does not. The plain address appears in the page's JSON-LD
(`"email":"support@fulldive.com"`) and nowhere else in the markup. Turning
obfuscation off for the page (Cloudflare → Scrape Shield), or repeating the
address as ordinary text next to the link, removes the doubt for the cost of
a little more spam.

### 7.3 In the Play Console — manual, cannot be done through the API

`androidpublisher` v3 writes title, descriptions and graphics only; contact
details are not in the `Listing` resource, so `tools/play_listing.py` cannot
set them.

| Where | What to set |
| --- | --- |
| Store listing → **Store listing contact details** | Email `support@fulldive.com`; Website `https://fulldive.com/pages/contact-us/`; phone optional |
| App content → **Privacy policy** | `https://fulldive.com/privacy-policy/` |
| App content → **News and magazine apps** declaration | Contact information URL → `https://fulldive.com/pages/contact-us/` (the notice asks specifically for this to be updated) |

Social accounts do not count as contact information, so the Discord link on
the contact page satisfies nothing here — the email does.

### 7.4 Checked, not assumed

Measured against the live `news` collection after re-seeding on 21 Sep 2026,
109 documents:

| Notice bullet | State |
| --- | --- |
| Content less than three months old | ✅ oldest 2 Sep 2026, newest 21 Sep 2026 — the whole collection is under three weeks old |
| Original source (author or publisher) for every article | ✅ 0 of 109 missing `author`, `sourceName` or `sourceUrl` |

The seeder writes `news/{sha1(sourceUrl)}`, so a re-run updates the stories it
already knows and adds the new ones — it never prunes. That is why the count
went 60 → 109 rather than staying at `--limit`. Harmless for the feed, which
is sorted newest-first and paginated, but the collection will keep growing; if
it ever needs trimming, delete by `publishedAt` rather than lowering the
limit.

Reproduce without credentials — the `news` collection is world-readable:

```bash
KEY=$(python3 -c "import json;print(json.load(open('android/app/google-services.json'))['client'][0]['api_key'][0]['current_key'])")
curl -sS -X POST "https://firestore.googleapis.com/v1/projects/full-dive-co/databases/main/documents:runQuery?key=$KEY" \
  -H "Content-Type: application/json" \
  -d '{"structuredQuery":{"from":[{"collectionId":"news"}],"select":{"fields":[{"fieldPath":"publishedAt"},{"fieldPath":"author"}]}}}'
```

Freshness is only true today because the seeder was run recently. Run it again
right before resubmitting: an appeal reviewer opening a feed whose top story is
months old re-reads the same policy differently.

### 7.5 Order of work

1. Set the three Console fields to the exact URLs in 7.2 — with trailing
   slashes. This is the likeliest cause of the finding: whatever the Console
   and the declaration form pointed at before, it resolved to the homepage.
2. Optional but cheap: un-obfuscate the address on the contact page (7.2).
3. `tools/news_seeder` — refresh the feed.
4. `tools/build_release.sh aab` → upload `7000003` → resubmit.
5. Only then **Submit an appeal** on the policy notice, describing 7.1–7.3.
   Appealing before the fixes are live spends the 5–8 day wait on a review
   that will find the same thing.
