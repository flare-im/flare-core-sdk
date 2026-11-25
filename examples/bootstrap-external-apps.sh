#!/usr/bin/env bash
# Clone each selected public demo at its published branch.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
workspace="${FLARE_DEMO_DIR:-$(cd "$here/../.." && pwd)}"

entries="$(node -e '
  const { demos } = require(process.argv[1]);
  const wanted = process.argv.slice(2);
  for (const platform of wanted.length ? wanted : Object.keys(demos)) {
    if (!Object.hasOwn(demos, platform)) throw new Error("Unknown demo: " + platform);
    const { repository, branch } = demos[platform];
    console.log([platform, repository, branch].join("\t"));
  }
' "$here/EXTERNAL-APPS.json" "$@")"

mkdir -p "$workspace"
while IFS=$'\t' read -r platform repo branch; do
  checkout="$workspace/flare-core-$platform-demo"
  if [ ! -e "$checkout" ]; then
    git clone --depth 1 --branch "$branch" "$repo" "$checkout"
  fi
  test "$(git -C "$checkout" remote get-url origin)" = "$repo"
  test -f "$checkout/demo.lock.json"
done <<< "$entries"
