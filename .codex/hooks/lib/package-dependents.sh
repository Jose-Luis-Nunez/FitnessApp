#!/bin/bash
# Reverse-dependency helper for test selection.
#
# Test scope was derived from changed paths alone, so a changed `public`
# signature in FitnessTraining selected only FitnessTraining -- while eight
# files in FitnessExercise consumed it. Every gate passed with those call sites
# untested. This closes that gap deterministically instead of relying on the
# reviewer noticing.

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  set -euo pipefail
fi

PACKAGE_DEPENDENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=validation-evidence.sh
source "$PACKAGE_DEPENDENTS_DIR/validation-evidence.sh"

package_manifest_path() {
  printf '%s\n' "${PACKAGE_MANIFEST:-Packages/Package.swift}"
}

# Emits "target<TAB>dependency" for every first-party target dependency.
# `.product(...)` entries are third-party and are ignored on purpose.
package_dependency_edges() {
  local manifest
  manifest=$(package_manifest_path)
  [ -f "$manifest" ] || return 0

  python3 - "$manifest" <<'PY'
import re, sys

try:
    text = open(sys.argv[1]).read()
except OSError:
    raise SystemExit(0)

# Walk each `.target(`/`.testTarget(` block by bracket depth so a dependency
# list never bleeds into the next target.
for match in re.finditer(r'\.(?:test)?[Tt]arget\(', text):
    start = match.end()
    depth = 1
    index = start
    while index < len(text) and depth:
        if text[index] == '(':
            depth += 1
        elif text[index] == ')':
            depth -= 1
        index += 1
    block = text[start:index]

    name = re.search(r'name:\s*"([^"]+)"', block)
    if not name:
        continue

    deps = re.search(r'dependencies:\s*\[', block)
    if not deps:
        continue
    depth = 1
    cursor = deps.end()
    while cursor < len(block) and depth:
        if block[cursor] == '[':
            depth += 1
        elif block[cursor] == ']':
            depth -= 1
        cursor += 1
    body = block[deps.end():cursor]
    # Drop `.product(name: "X", package: "Y")` before harvesting bare literals.
    body = re.sub(r'\.product\([^)]*\)', '', body)

    for dep in re.findall(r'"([^"]+)"', body):
        print(f"{name.group(1)}\t{dep}")
PY
}

# Library products, i.e. the names `test-affected-packages.sh` accepts. Test
# targets also consume their library, but selecting them here would hand the
# runner a target name it cannot schedule.
package_library_targets() {
  local manifest
  manifest=$(package_manifest_path)
  [ -f "$manifest" ] || return 0
  grep -oE '\.library\(name: "[^"]+"' "$manifest" | sed 's/.*"\(.*\)"/\1/' | sort -u
}

# Transitive set of library products that depend on the given target, excluding
# itself.
package_dependents() {
  local target="$1"
  local edges
  local libraries
  edges=$(package_dependency_edges)
  [ -n "$edges" ] || return 0
  libraries=$(package_library_targets)

  printf '%s\n' "$edges" | python3 -c '
import sys
root = sys.argv[1]
reverse = {}
for line in sys.stdin:
    parts = line.rstrip("\n").split("\t")
    if len(parts) != 2:
        continue
    consumer, dependency = parts
    reverse.setdefault(dependency, set()).add(consumer)

seen = set()
queue = [root]
while queue:
    current = queue.pop()
    for consumer in reverse.get(current, ()):
        if consumer not in seen:
            seen.add(consumer)
            queue.append(consumer)

for name in sorted(seen - {root}):
    print(name)
' "$target" | grep -Fxf <(printf '%s\n' "$libraries") - || true
}

# Package directories touched by the candidate.
package_changed_packages() {
  local mode="${1:-worktree}"
  # NF >= 3 excludes `Packages/Package.swift` itself: the manifest is not a
  # package, and treating it as one put "Package.swift" into the scope list.
  validation_paths "$mode" |
    awk -F/ '/^Packages\// && NF >= 3 {print $2}' |
    sort -u |
    sed '/^$/d'
}

# True when the candidate adds or removes a public/open declaration. A private
# change stays inside its own package, so pulling consumers in would only buy
# runtime.
package_public_surface_changed() {
  local mode="${1:-worktree}"
  local diff=""

  if [ "$mode" = "staged" ]; then
    diff=$(git diff --cached --diff-filter=ACMR -- '*.swift' 2>/dev/null || true)
  else
    diff=$(git diff HEAD --diff-filter=ACMR -- '*.swift' 2>/dev/null || true)
    while IFS= read -r path; do
      [ -z "$path" ] && continue
      case "$path" in
        *.swift) [ -f "$path" ] && diff="$diff"$'\n'"$(sed 's/^/+/' "$path")" ;;
      esac
    done <<< "$(git ls-files --others --exclude-standard 2>/dev/null || true)"
  fi

  printf '%s\n' "$diff" |
    grep -E '^[+-]' |
    grep -Ev '^(\+\+\+|---)' |
    grep -qE '\b(public|open)\s+(final\s+)?(func|var|let|init|subscript|struct|class|enum|protocol|actor|typealias)\b'
}

# The packages whose tests the final run must cover.
package_test_scope() {
  local mode="${1:-worktree}"
  local changed=""
  local scope=""
  local package=""

  changed=$(package_changed_packages "$mode")
  [ -n "$changed" ] || return 0
  scope="$changed"

  if package_public_surface_changed "$mode"; then
    while IFS= read -r package; do
      [ -z "$package" ] && continue
      scope="$scope"$'\n'"$(package_dependents "$package")"
    done <<< "$changed"
  fi

  printf '%s\n' "$scope" | sed '/^$/d' | sort -u
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  case "${1:-scope}" in
    scope)
      package_test_scope "${2:-worktree}"
      ;;
    dependents)
      [ "$#" -eq 2 ] || exit 2
      package_dependents "$2"
      ;;
    edges)
      package_dependency_edges
      ;;
    public-surface)
      package_public_surface_changed "${2:-worktree}" && echo yes || echo no
      ;;
    *)
      echo "Usage: package-dependents.sh scope [worktree|staged] | dependents <target> | edges | public-surface [worktree|staged]" >&2
      exit 2
      ;;
  esac
fi
