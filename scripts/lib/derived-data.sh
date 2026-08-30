# Resolves this checkout's derived-data app bundle.
#
# Sourced, not executed. Exists because several derived-data directories can
# carry the same project name — a worktree build leaves one behind and it never
# expires — and picking by newest mtime silently returns another checkout's
# bundle. Selection is by the recorded WorkspacePath instead, so the answer is
# tied to this repository rather than to build order.
#
#   fitness_app_bundle <configuration> [scheme]
#     prints the .app path, or nothing and returns 1.

fitness_app_bundle() {
  local configuration="$1"
  local scheme="${2:-FitnessApp}"
  local derived_root="${FITNESS_DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"
  local repo_root
  repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

  local candidate workspace bundle
  for candidate in "$derived_root/$scheme"-*; do
    [ -f "$candidate/info.plist" ] || continue
    workspace="$(plutil -extract WorkspacePath raw "$candidate/info.plist" 2>/dev/null)" || continue
    case "$workspace" in
      "$repo_root"/*) ;;
      *) continue ;;
    esac
    bundle="$candidate/Build/Products/$configuration/$scheme.app"
    if [ -d "$bundle" ]; then
      printf '%s\n' "$bundle"
      return 0
    fi
  done
  return 1
}
