# Play Console support request

Paste the body below into Play Console → **?** → Help → Need more help? →
Contact support (topic: store listing / app status, channel: email).

Before sending, put your name in the signature and attach:

Everything is in `support-evidence/`:

- `01-listing-save-failure-network-response.png` — the filled-in form, the
  error banner and the raw Network response in one frame
- `02-listing-review-ai-declaration.png` — the review step, AI asset
  declaration set to "Don't label assets"
- `03-listing-review-assets.png` — the complete draft: icon, feature graphic
  and four phone screenshots
- `04-publishing-overview.png` — the pending changes
- `05-error-decoded.txt` — the decoded error detail

---

**Subject:** Complete store listing draft cannot be published — StoreListingError 182 (en-US)

---

Hello,

I have a complete, valid store listing saved as a draft that I cannot publish.
Every attempt fails with the same server-side precondition error. I have
already ruled out the usual causes, listed below, so please do not begin with
cache or browser troubleshooting.

**App:** Fulldive VR — package `in.fulldive.shell`
**App ID:** 4974715307560072894
**Developer ID:** 8560486430906052018
**Developer account:** Browser by Fulldive Co.
**Currently published:** version 6.10.2.1.1 (versionCode 6100211)
**Update being prepared:** versionCode 7000002

**Context.** The app is being rebuilt from a VR launcher into a news reader,
which means replacing the entire store listing: name, description, icon,
feature graphic and screenshots.

## The problem

The new listing is saved as a draft and meets every requirement — name, short
and full description, 512×512 icon, 1024×500 feature graphic and four 1080×1920
phone screenshots are all present. Publishing it fails. The request returns:

```json
{
  "1": 9,
  "2": "Precondition check failed.",
  "3": [
    {
      "1": "type.googleapis.com/play.console.apps.api.storelistings.StoreListingError",
      "2": "CgoItgESBWVuLVVT"
    }
  ]
}
```

Decoding the detail gives `{ code: 182, locale: "en-US" }`; gRPC status 9 is
FAILED_PRECONDITION.

**The error never changes.** It is byte-for-byte identical no matter what I
alter — including a save where the only change was setting the
AI-generated-content declaration to "not AI generated". A precondition that is
invariant to the payload points at the stored listing, not at my input.

## What I have already ruled out

- **Missing assets.** Icon, feature graphic and four phone screenshots were all
  supplied in a single pass.
- **A store listing experiment.** None exists; the page offers to create a
  first one.
- **The privacy policy.** `https://browser.fulldive.com/privacy-policy/`
  resolves and returns HTTP 200. The Publishing overview issues panel is clear.
- **A pending review lock.** Managed publishing is off and the changes sit
  under "Changes not yet submitted for review".
- **Anything account-wide.** Every other section saves normally: Content
  Rating, Data safety, Privacy policy, App category, Health apps and the News
  and magazine apps declaration all persisted. Only the store listing refuses.
- **Legacy in-app products.** `subscription.player` has been deactivated and
  `support_fulldive_team` deleted. The error is unchanged.
- **The AI asset declaration.** It is set to "Don't label assets", which is
  accurate — none of the artwork is AI-generated. The screenshots are captures
  of the running app, the icon is the existing launcher artwork, and the
  feature graphic is composed programmatically from that logo and a text
  typeface. Setting it either way makes no difference to the error.
- **A damaged en-US record.** I changed the default listing language to en-GB,
  removed en-US entirely, then restored en-US and made it default again. The
  error is byte-for-byte identical before and after, so a freshly created en-US
  listing fails exactly as the original one did.

## My one suspicion

The listing text still live in production contains direct links to APK
downloads hosted outside Google Play:

```
static.fdvr.co/apps/android-vr/v4.9.11-fulldiveVr-release.apk
static.fdvr.co/apps/android-vr/v4.9.11-fulldiveDaydream-release.apk
```

alongside claims about earning cryptocurrency by using the app. That text was
published years ago, under policies of the time.

If a current policy check against the stored listing is what fails the
precondition, it would explain why every publish is rejected regardless of what
I submit — and it leaves me unable to fix it, because the fix requires
publishing. The draft already removes all of it.

Please confirm whether this is the cause and clear the condition, or tell me
what else is failing.

## What I am asking for

1. The reason the en-US store listing returns StoreListingError 182, and how to
   clear it so the draft can be published.
2. If the stored listing text is what fails the check, please say so directly —
   I cannot remove it myself, because removing it requires the publish that the
   check blocks.

Thank you,
[name]
