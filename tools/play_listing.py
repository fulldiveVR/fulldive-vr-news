#!/usr/bin/env python3
"""Read and write the Play store listing through the public Developer API.

The Play Console web UI writes listings through a private RPC
(playconsoleapps-pa) whose failures arrive as opaque numeric codes. This goes
through androidpublisher v3 instead: a different validation path, and errors
that come back as readable text.

Credentials: a service account key with the Google Play Android Developer API
enabled, invited into Play Console under Users and permissions with at least
"Edit store listing". Point GOOGLE_APPLICATION_CREDENTIALS at the key file, or
pass --key.

  ./play_listing.py read                 # dump what Play has stored, per locale
  ./play_listing.py validate             # apply store/metadata, validate, discard
  ./play_listing.py push                 # apply, validate, commit
  ./play_listing.py push --for-review    # commit and submit for review
"""

import argparse
import json
import mimetypes
import os
import pathlib
import sys

import requests
from google.oauth2 import service_account
from google.auth.transport.requests import Request

API = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
PACKAGE = "in.fulldive.shell"

REPO = pathlib.Path(__file__).resolve().parent.parent
METADATA = REPO / "store" / "metadata"

# local directory name -> androidpublisher imageType
IMAGE_TYPES = {
    "icon.png": "icon",
    "featureGraphic.png": "featureGraphic",
    "phoneScreenshots": "phoneScreenshots",
    "sevenInchScreenshots": "sevenInchScreenshots",
    "tenInchScreenshots": "tenInchScreenshots",
    "tvBanner": "tvBanner",
    "tvScreenshots": "tvScreenshots",
    "wearScreenshots": "wearScreenshots",
}


class ApiError(RuntimeError):
    pass


def session(key_path):
    key_path = key_path or os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not key_path:
        sys.exit("No credentials. Set GOOGLE_APPLICATION_CREDENTIALS or pass --key.")
    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=[SCOPE]
    )
    creds.refresh(Request())
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    return s


def call(s, method, url, **kw):
    r = s.request(method, url, **kw)
    if r.status_code >= 400:
        # The whole point of this tool: print what Play actually said.
        try:
            body = json.dumps(r.json(), indent=2, ensure_ascii=False)
        except ValueError:
            body = r.text
        raise ApiError(f"{method} {url}\n  HTTP {r.status_code}\n{body}")
    return r.json() if r.content else {}


def new_edit(s):
    edit = call(s, "POST", f"{API}/applications/{PACKAGE}/edits")
    print(f"edit {edit['id']}  (expires {edit.get('expiryTimeSeconds')})")
    return edit["id"]


def delete_edit(s, edit_id):
    try:
        call(s, "DELETE", f"{API}/applications/{PACKAGE}/edits/{edit_id}")
    except ApiError as e:
        print(f"could not discard edit: {e}", file=sys.stderr)


def cmd_read(s, args):
    edit_id = new_edit(s)
    try:
        listings = call(
            s, "GET", f"{API}/applications/{PACKAGE}/edits/{edit_id}/listings"
        ).get("listings", [])
        out = {"package": PACKAGE, "listings": listings, "images": {}}

        print(f"\n{len(listings)} localized listing(s) stored:\n")
        for l in listings:
            lang = l["language"]
            print(f"  {lang:<8} {l.get('title', '')!r}")
            out["images"][lang] = {}
            for t in ("icon", "featureGraphic", "phoneScreenshots"):
                try:
                    imgs = call(
                        s,
                        "GET",
                        f"{API}/applications/{PACKAGE}/edits/{edit_id}/listings/{lang}/{t}",
                    ).get("images", [])
                except ApiError:
                    imgs = []
                out["images"][lang][t] = imgs

        dest = REPO / "store" / "play-stored-listing.json"
        dest.write_text(json.dumps(out, indent=2, ensure_ascii=False))
        print(f"\nfull dump -> {dest}")
    finally:
        delete_edit(s, edit_id)


def read_text(path):
    return path.read_text(encoding="utf-8").strip() if path.is_file() else None


def apply_locale(s, edit_id, lang, upload_images):
    base = METADATA / lang
    body = {"language": lang}
    for field, name in (
        ("title", "title.txt"),
        ("shortDescription", "short_description.txt"),
        ("fullDescription", "full_description.txt"),
    ):
        v = read_text(base / name)
        if v is not None:
            body[field] = v
    # No video.txt means no promo video. PUT replaces the resource, so an empty
    # string is how a stale stored URL gets cleared.
    body["video"] = read_text(base / "video.txt") or ""
    print(f"\n{lang}: PUT listing video={body['video']!r} "
          f"(title {len(body.get('title',''))}, "
          f"short {len(body.get('shortDescription',''))}, "
          f"full {len(body.get('fullDescription',''))} chars)")
    call(
        s,
        "PUT",
        f"{API}/applications/{PACKAGE}/edits/{edit_id}/listings/{lang}",
        json=body,
    )

    if not upload_images:
        return
    images = base / "images"
    if not images.is_dir():
        return
    for entry, image_type in IMAGE_TYPES.items():
        path = images / entry
        files = []
        if path.is_file():
            files = [path]
        elif path.is_dir():
            files = sorted(p for p in path.iterdir() if p.suffix.lower() in
                           (".png", ".jpg", ".jpeg"))
        if not files:
            continue
        call(
            s,
            "DELETE",
            f"{API}/applications/{PACKAGE}/edits/{edit_id}/listings/{lang}/{image_type}",
        )
        for f in files:
            ctype = mimetypes.guess_type(f.name)[0] or "image/png"
            call(
                s,
                "POST",
                f"{UPLOAD}/applications/{PACKAGE}/edits/{edit_id}/listings/"
                f"{lang}/{image_type}?uploadType=media",
                data=f.read_bytes(),
                headers={"Content-Type": ctype},
            )
            print(f"  {image_type}: {f.name}")


def cmd_apply(s, args, commit):
    langs = args.lang or [p.name for p in METADATA.iterdir() if p.is_dir()]
    edit_id = new_edit(s)
    committed = False
    try:
        for lang in langs:
            apply_locale(s, edit_id, lang, upload_images=not args.no_images)

        for lang in args.drop_lang or []:
            print(f"\n{lang}: DELETE listing")
            call(s, "DELETE",
                 f"{API}/applications/{PACKAGE}/edits/{edit_id}/listings/{lang}")

        print("\nvalidating…")
        call(s, "POST", f"{API}/applications/{PACKAGE}/edits/{edit_id}:validate")
        print("validate: OK")

        if commit:
            q = "" if args.for_review else "?changesNotSentForReview=true"
            call(s, "POST",
                 f"{API}/applications/{PACKAGE}/edits/{edit_id}:commit{q}")
            committed = True
            print("commit: OK"
                  + ("" if args.for_review else "  (not sent for review)"))
    finally:
        if not committed:
            delete_edit(s, edit_id)


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("command", choices=["read", "validate", "push"])
    p.add_argument("--key", help="service account JSON key")
    p.add_argument("--lang", action="append",
                   help="locale to apply (repeatable); default: all in store/metadata")
    p.add_argument("--no-images", action="store_true",
                   help="text only, leave graphics alone")
    p.add_argument("--drop-lang", action="append",
                   help="locale to remove from the listing (repeatable)")
    p.add_argument("--for-review", action="store_true",
                   help="push: submit for review instead of saving as a draft")
    args = p.parse_args()

    s = session(args.key)
    try:
        if args.command == "read":
            cmd_read(s, args)
        else:
            cmd_apply(s, args, commit=args.command == "push")
    except ApiError as e:
        print(f"\nPlay API refused the call:\n{e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
