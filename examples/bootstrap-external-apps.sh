#!/usr/bin/env bash
# Bootstrap the sibling examples checkout. Optional arguments validate selected apps.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest="$here/EXTERNAL-APPS.json"
workspace="$(cd "$here/../.." && pwd)"
checkout="$workspace/flare-core-examples"
repo="$(node -p 'require(process.argv[1]).repository' "$manifest")"
paths="$(node -e '
  const manifest = require(process.argv[1]);
  const wanted = process.argv.slice(2);
  const selected = wanted.length ? wanted.map(name => {
    const dir = name.startsWith("flare-core-") ? name : `flare-core-${name}-app`;
    const app = manifest.apps.find(item => item.dir === dir);
    if (!app) throw new Error("Unknown app: " + name);
    return app;
  }) : manifest.apps;
  console.log(selected.map(app => app.path).join("\n"));
' "$manifest" "$@")"

if [ ! -e "$checkout/.git" ]; then
  if [ -n "${BRANCH:-}" ] && git ls-remote --exit-code --heads "$repo" "refs/heads/$BRANCH" >/dev/null; then
    git clone --depth 1 --branch "$BRANCH" "$repo" "$checkout"
  else
    git clone --depth 1 "$repo" "$checkout"
  fi
fi
while IFS= read -r path; do
  test -d "$checkout/$path" || { echo "Missing $checkout/$path" >&2; exit 1; }
done <<< "$paths"
