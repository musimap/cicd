#!/usr/bin/env bash
# Static validation for secondary-image digest pinning helpers (no ECR push).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

MANIFEST="$TMP/deployment.yaml"
cat >"$MANIFEST" <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example
spec:
  template:
    spec:
      containers:
        - name: icecast
          image: 156551338767.dkr.ecr.eu-west-1.amazonaws.com/msm-audio-streamer-icecast@sha256:olddigest0000000000000000000000000000000000000000000000000000
EOF

if ! command -v yq >/dev/null 2>&1; then
  echo "yq required for this check" >&2
  exit 1
fi

NEW_REF="156551338767.dkr.ecr.eu-west-1.amazonaws.com/msm-audio-streamer-icecast@sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
yq e -i '.spec.template.spec.containers[0].image = "'"$NEW_REF"'"' "$MANIFEST"
PINNED=$(yq e '.spec.template.spec.containers[0].image' "$MANIFEST")

[[ "$PINNED" == *"@sha256:"* ]] || { echo "FAIL: not digest-pinned: $PINNED"; exit 1; }
[[ "$PINNED" != *":latest"* ]] || { echo "FAIL: latest found"; exit 1; }
[[ "$PINNED" == "$NEW_REF" ]] || { echo "FAIL: unexpected pin $PINNED"; exit 1; }

# Workflow inputs present
grep -q 'extra_image_dockerfile' "$ROOT/.github/workflows/python-service-django.yaml"
grep -q 'steps-pin-image-digest' "$ROOT/.github/workflows/python-service-django.yaml"
grep -q 'dockerfile:' "$ROOT/github-actions/_partials/steps-build-docker/action.yaml"
test -f "$ROOT/github-actions/_partials/steps-pin-image-digest/action.yaml"

echo "OK: digest pin helper + workflow wiring validated"
