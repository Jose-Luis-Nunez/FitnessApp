# 0006 — Versionierte Git-Hooks via `core.hooksPath`

* Status: accepted
* Date: 2026-04-19
* Deciders: Jose Nunez (für ein 5-Personen-Team)

## Context

Die Pre-Commit-Pipeline (`.git/hooks/pre-commit`) erzwingt fünf Architektur-
Invarianten:

1. Validation-Stamp für Swift-Änderungen (Layer 4 von
   `code-changes-enforcement.mdc`)
2. `print()` in Production-Code blockiert
3. ADR-Pflicht bei strukturellen Änderungen (`adr-required.sh` aus T0d)
4. UI-State-Sync-Anti-Pattern (`ui-state-sync-enforcement.mdc` aus T0a)
5. Architecture-Documentation-Sync (`architecture-documentation-sync.mdc`)

Bislang lebte der Hook ausschließlich in `.git/hooks/pre-commit` — also
**nicht versioniert**. Das hatte für eine 1-Person-Entwicklung keinen
Effekt; mit fünf Contributors entsteht jedoch sofort ein Loch:

- Vier von fünf Maschinen haben den Hook nicht.
- Architektur-Regressionen (z. B. Wiederbeleben von `changeVersion`-Polling)
  passieren still und werden erst im Code-Review entdeckt — wenn überhaupt.
- ADR-0001/0002/0003/0005/0006 verlieren ihre Hauptdurchsetzung; die
  `mdc`-Rules sind nur L2-advisory, der echte L4-Block kommt aus dem Hook.
- Die ganze Investition aus T0a–T0e wird für 4/5 des Teams nutzlos.

Git unterstützt seit 2.9 die Konfigurations-Option `core.hooksPath`, mit der
ein Repository auf einen versionierten Hook-Ordner umgeleitet werden kann.
Apple liefert mit Xcode 16 (verwendet von `~/Downloads/Xcode.app`) Git ≥ 2.45,
also kompatibel.

## Options

- **A — Status quo behalten**
  Hooks lokal in `.git/hooks/`. Jeder im Team installiert sie selbst.
  Verlässlichkeit: 0 — niemand wird das tun.

- **B — Husky / Lefthook / pre-commit-Framework**
  Externe Tools (Node bzw. Go bzw. Python). Vorteile: ausgereifte
  Konfigurations-Sprache, parallele Ausführung. Nachteile: zusätzliche
  Toolchain-Abhängigkeit (Node) für ein Swift-Repo, das aktuell **null**
  Node-Abhängigkeiten hat. `pre-commit` (Python-Tool) wäre näher am
  bestehenden Setup, ändert aber den Diagnose-Output und müsste die
  RULE/VIOLATION/FIX-Formatierung der existierenden Checks neu nachbauen.

- **C — `core.hooksPath` auf versioniertes `.githooks/`-Verzeichnis** ✅
  Apple-/Git-First-Party-Mechanismus. Keine externe Toolchain.
  Setup: einmal `scripts/install-hooks.sh` ausführen pro Clone (idempotent).
  Hook-Inhalte sind identisch zur heutigen `.git/hooks/pre-commit` — keine
  Verhaltensänderung, nur Versionierung der Datei.

- **D — `core.hooksPath` plus Auto-Install via `post-checkout`/`post-merge`**
  Wie C, aber zusätzlich versucht der Hook sich selbst zu aktivieren.
  Risiko: laufzeitkritische Magie. Wenn das Auto-Install scheitert, weiß
  niemand warum die Validierungen plötzlich greifen oder nicht greifen.
  Verworfen wegen Diagnose-Klarheit.

## Decision

**Option C**: Repository-versioniertes `.githooks/`-Verzeichnis und manuelles
einmaliges Setup pro Clone via `scripts/install-hooks.sh`.

Begründung:

- **Zero zusätzliche Toolchain**: das Repo bleibt ein reines Xcode-Projekt,
  keine `package.json`, kein `pre-commit-config.yaml`.
- **Erkennbar**: jeder Contributor sieht beim ersten `git status` nach Clone
  `.githooks/` und das `scripts/install-hooks.sh`. Onboarding-Doku
  (`docs/adr/ONBOARDING.md`) erwähnt es als ersten Schritt.
- **Keine Verhaltensänderung**: die Hook-Inhalte sind identisch zu heute —
  Tests/Validierungen wie zuvor, nur jetzt für alle.
- **Reversible**: `git config --unset core.hooksPath` deaktiviert sofort.
  Falls jemand mal lokal einen Hook ausschalten will, ist `--no-verify`
  der dokumentierte Weg (siehe `code-changes-enforcement.mdc`).

## Consequences

**Positive**

- Pre-Commit-Architektur-Schutz wirkt auf allen 5 Maschinen.
- Hook-Änderungen kommen als normale PRs ins Review — keine
  „Schatten-Konfiguration" mehr.
- ADR-0001/0002/0003/0005 sind end-to-end durchsetzbar (L4-Layer
  funktioniert team-weit).

**Negative**

- Ein zusätzlicher Setup-Schritt nach Clone (`./scripts/install-hooks.sh`).
  Mitigation: dokumentiert in `docs/adr/ONBOARDING.md` und im Repo-`README.md`
  (siehe Folge-Task).

**Neutral**

- Wer den Setup-Schritt vergisst, bekommt eine Code-Review-Belehrung statt
  einer Hook-Blockade. Das ist akzeptabel — kein neues Risiko, nur das
  bekannte „Hook fehlt" eines Status-quo-Setups.

## References

- ADR-0001 — `@Model` als UI SoT (durchgesetzt via Hook-Check 4)
- ADR-0005 — Schema-Migration-Strategie (durchgesetzt via Hook-Check 3)
- `.cursor/rules/code-changes-enforcement.mdc` — beschreibt die L1–L5-Layer
- `scripts/install-hooks.sh` — Setup-Skript
- `.githooks/pre-commit` — versioniertes Hook-Skript

Co-authored-by: Cursor <cursor@cursor.com>
