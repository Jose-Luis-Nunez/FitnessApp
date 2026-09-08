#!/usr/bin/env bash
# Content-addressed view of the snapshot baselines, for the recording run.
#
# `git status --porcelain` cannot tell whether a recording changed anything:
# a baseline that was already modified before the run stays " M" however many
# times it is re-recorded, and one recorded back to its HEAD bytes drops out of
# the listing entirely -- so the status-line comparison misreported in both
# directions. Comparing content hashes answers the actual question.
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage:
  snapshot-baselines.sh state          # "<sha> <path>" per baseline, tracked or untracked
  snapshot-baselines.sh changed <before> <after>
                                       # paths whose hash differs, or that appeared/vanished
USAGE
  exit 2
}

state() {
  local root
  root=$(git rev-parse --show-toplevel)
  (
    cd "$root"
    # --cached and --others are disjoint (tracked vs untracked), so no path
    # repeats; macOS uniq has no -z, and none is needed.
    git ls-files -z --cached --others --exclude-standard -- '*__Snapshots__*' |
      sort -z |
      while IFS= read -r -d '' path; do
        if [ -f "$path" ]; then
          printf '%s %s\n' "$(git hash-object -- "$path")" "$path"
        else
          printf '%s %s\n' "deleted" "$path"
        fi
      done
  )
}

changed() {
  local before="$1" after="$2"
  # A path is reported once whether its hash moved or it appeared/vanished.
  { diff <(printf '%s\n' "$before") <(printf '%s\n' "$after") || true; } |
    sed -n 's/^[<>] [^ ]* //p' | sort -u
}

case "${1:-}" in
  state) state ;;
  changed) [ "$#" -eq 3 ] || usage; changed "$2" "$3" ;;
  *) usage ;;
esac
