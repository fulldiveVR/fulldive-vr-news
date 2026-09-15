#!/usr/bin/env bash
# Publishes firestore.rules to the `main` database of the Firebase project.
#
#   tools/deploy_firestore_rules.sh
#
# Uses the local gcloud login; set GCLOUD_ACCOUNT to pick a specific account.
# The previous ruleset is kept by Firebase, so a rollback is a single
# releases.patch away — the script prints the id it replaced.
set -euo pipefail

PROJECT="${FIREBASE_PROJECT:-full-dive-co}"
DATABASE="${FIRESTORE_DATABASE:-main}"
RULES_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/firestore.rules"
RELEASE="projects/${PROJECT}/releases/cloud.firestore/${DATABASE}"
API="https://firebaserules.googleapis.com/v1"

token_args=()
[[ -n "${GCLOUD_ACCOUNT:-}" ]] && token_args+=("--account=${GCLOUD_ACCOUNT}")
TOKEN="$(gcloud auth print-access-token "${token_args[@]}")"

auth_curl() {
  curl -sS -H "Authorization: Bearer ${TOKEN}" \
          -H "x-goog-user-project: ${PROJECT}" \
          -H "Content-Type: application/json" "$@"
}

echo "Current release:"
auth_curl "${API}/${RELEASE}" | python3 -c 'import json,sys; print("  " + json.load(sys.stdin).get("rulesetName", "(none)"))'

echo "Uploading ${RULES_FILE}…"
RULESET=$(
  python3 -c '
import json, sys
content = open(sys.argv[1]).read()
print(json.dumps({"source": {"files": [{"name": "firestore.rules", "content": content}]}}))
' "${RULES_FILE}" |
    auth_curl -X POST "${API}/projects/${PROJECT}/rulesets" -d @- |
    python3 -c 'import json,sys; print(json.load(sys.stdin)["name"])'
)
echo "  created ${RULESET}"

echo "Pointing the release at it…"
auth_curl -X PATCH "${API}/${RELEASE}" \
  -d "$(python3 -c '
import json, sys
print(json.dumps({"release": {"name": sys.argv[1], "rulesetName": sys.argv[2]}}))
' "${RELEASE}" "${RULESET}")" |
  python3 -c 'import json,sys; d=json.load(sys.stdin); print("  " + d["name"] + " -> " + d["rulesetName"])'

echo "Done."
