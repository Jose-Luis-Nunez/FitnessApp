# Deep Research: Zuverlässige Pflichtschritte in AI-Agent-Workflows erzwingen
> Generated 2026-04-11, updated 2026-04-12 | Depth: standard + community cross-reference | Sources: 30+
>
> **Note:** This is a historical research document. Some file names referenced below (e.g. `auto-validation.mdc`, `scratchpad.md`) have since been renamed. The concepts and findings remain valid. See `agent-system-overview.md` for current file names.

## TL;DR

Prose-basierte Rules (CLAUDE.md, .cursor/rules) arbeiten bei ~70-85% Zuverlässigkeit und degradieren über lange Sessions. Das Cursor-Team hat bestätigt: **"Rules are context, not constraints"** [19] — sie werden nie deterministisch sein. Die Lösung ist eine **Defense-in-Depth-Architektur** ("Bowling Bumpers"): Jede Schicht eliminiert eine Kategorie von Fehlern. Die zuverlässigsten Mechanismen sind Cursor's **Grind Loop** (stop-Hook mit Scratchpad + Iterationszähler), **Git Pre-Commit Hooks mit AI-optimierten Fehlermeldungen** (der Agent korrigiert sich selbst aus dem Error-Output), und **Claude Code's `Stop`-Hook mit `decision: "block"`**. Die Industrie bewegt sich von "Prompt Engineering" zu **"Flow Engineering"** — Agent-Orchestrierung als Software-Architektur-Problem.

## Executive Summary

Das Kernproblem — AI-Agenten befolgen mehrstufige Workflows nicht zuverlässig — ist kein individuelles Versagen sondern ein systemisches Pattern. Cursor's Team hat das explizit bestätigt: Forum-Moderator deanrie sagte im Januar 2026: "Rules in context don't guarantee 100% adherence. These models are probabilistic." [19] Der Agent kann die Rules rezitieren wenn man fragt, aber ignoriert sie während der Ausführung. Ofer Shapira (Elementor) dokumentierte: "as the context window moves, he forgets. No matter how well you write the rules, after a few messages, they're being ignored." [20]

Die Forschung identifiziert sechs zentrale Erkenntnisse:

1. **Die Enforcement Ladder / Defense-in-Depth** ist das dominierende Framework: L1 (Konversation, ~0%) → L2 (Prose/Docs, ~70-85%) → L3 (Templates/Commands, ~85-90%) → L4 (Tests/CI, ~100%) → L5 (Hooks, ~100% minus Bugs). Wenn eine Regel auf Stufe N wiederholt ignoriert wird, gehört sie auf N+1 [8].

2. **Der "Grind Loop"** ist Cursor's stärkstes natives Pattern: Ein `stop`-Hook prüft ob Tests/Validierung bestanden, und wenn nicht, sendet er eine `followup_message` mit Iterationszähler ("Iteration 2/5: Tests still failing. Continue working."). Der Agent kann nicht "fertig" werden bis die Bedingung erfüllt ist oder das Limit erreicht wird [19, 1].

3. **Pre-Commit Hooks als Prompt Engineering:** Fleek (YC W22) entdeckte dass Hook-Error-Messages für AI-Agents anders formuliert werden müssen: Regel nennen, exakte Verletzung mit Datei/Zeile zeigen, Replacement-Code mitliefern. Der Agent korrigiert sich automatisch aus dem Output — ein enger Feedback-Loop ohne menschliche Intervention [21].

4. **Claude Code's `Stop`-Hook mit `decision: "block"`** ist der stärkste native Enforcement-Mechanismus: Er verhindert physisch dass der Agent aufhört. `stop_hook_active` im Input verhindert Endlosschleifen [10, 11].

5. **State-Machine-in-Files Pattern:** Workflow als Zustandsübergänge in persistenten Dateien (`workflow_state.md`) statt als System-Prompt-Instructions. Pflichtschritte werden zu State-Transitions (Analyze → Blueprint → Construct → Validate), die der Agent als Datei updaten muss — sichtbarer Audit-Trail [22].

6. **Die zuverlässigste Enforcement kombiniert alle Schichten:** Hook als Gate + CI als Fallback + Artefakt-basierte Prüfung (nicht Modell-Selbstauskunft) + strukturelle Patterns die Compliance zum einfacheren Pfad machen [7, 8, 9].

## 1. Die Enforcement Ladder [Confidence: High]

Das von Doug Walseth beschriebene Framework ordnet Enforcement-Mechanismen nach Zuverlässigkeit [8]:

| Stufe | Name | Mechanismus | Zuverlässigkeit | Beispiel |
|-------|------|-------------|-----------------|----------|
| L1 | Conversation | Mündliche Anweisung im Chat | Niedrig — vergessen nach 2-3 Turns | "Vergiss nicht zu validieren" |
| L2 | Prose Docs | `.cursor/rules/`, `CLAUDE.md`, `AGENTS.md` | Mittel — **"dropped first under context pressure"** [8] | `auto-validation.mdc` mit "you MUST" |
| L3 | Templates & Scaffolds | Checklisten, Skill-Dateien, strukturierte Prompts | Mittel-Hoch — der richtige Pfad ist der einfache | Skill mit festem Ablauf den der Agent liest |
| L4 | Tests & CI Gates | Deterministische Prüfungen bei Commit/Merge | Hoch — blockiert unabhängig vom Modell | `swift test` in Pre-Commit, Lint-Check |
| L5 | Hooks & Runtime Guards | Prozess-Level-Abfangen vor/nach Aktionen | Höchst — **"physically prevented before it happens"** [8] | `PreToolUse` deny, `Stop` block |

**Kernprinzip:** Wenn eine Regel auf Stufe N wiederholt verletzt wird, gehört sie auf Stufe N+1. Unser `auto-validation.mdc` wurde auf L2 ignoriert — es gehört auf L4/L5 [8].

Walseth formuliert es so: "When the context window fills up — and it always does — the model drops these rules first. They are the lowest-priority tokens in the window." [8] Das erklärt warum "stärkere Formulierung" in Rules nicht hilft: Das Problem ist nicht die Formulierung sondern die **Position in der Aufmerksamkeitshierarchie** des Modells.

Scott Chacon (GitButler) bestätigt aus der Praxis: "hooks are generally deterministic programs that can always be known to do the same thing the same way. Rules and MCP calls and parameters will almost by definition be non-deterministic" [1]. Die Unterscheidung ist fundamental — Rules sind Wünsche, Hooks sind Mechanismen.

## 2. Cursor: Hooks als Enforcement-Mechanismus [Confidence: Medium]

Cursor bietet sechs Hook-Events im Agent-Lifecycle [1, 2]:

- `beforeSubmitPrompt` — vor jeder Prompt-Übermittlung (liefert `conversation_id`, `generation_id`)
- `beforeShellExecution` / `beforeMCPExecution` / `beforeReadFile` — blockierende Gates
- `afterFileEdit` — nach Dateiänderungen (informational)
- `stop` — wenn der Agent seine Arbeit beendet

**Was der `stop`-Hook kann:**
- Input enthält `conversation_id`, `status` (`completed` | `aborted` | `error`) [1]
- Output kann eine `followup_message` zurückgeben die den Agent in eine neue Runde schickt [2]
- `loop_count` trackt die Anzahl der Followup-Iterationen innerhalb einer Kette [2]

**Was der `stop`-Hook NICHT kann:**
- Er kann den Agent nicht **blockieren** — nur bitten weiterzumachen (im Gegensatz zu Claude Code's `decision: "block"`)
- Er hat **keinen Session-State** — jeder Stop ist isoliert, `loop_count` reset pro Konversationsrunde [2, 6]
- `content` enthält nur den **letzten** Agent-Output, nicht die gesamte Session [empirisch verifiziert in diesem Projekt]

**Praktische Patterns aus der Community:**

GitButler nutzt `conversation_id` und `generation_id` um **einen Branch pro Konversation** und **einen Commit pro Generation** zu erstellen [1]. Endor Labs nutzt einen `stop`-Hook der Security-Findings zusammenfasst [14].

### Der Grind Loop — Cursor's stärkstes Pattern

Das offizielle "Grind Loop"-Pattern [19] verwendet ein Scratchpad-File um Session-State über `stop`-Events hinweg zu persistieren:

```
1. stop-Hook feuert
2. Hook liest .cursor/hooks/state/scratchpad.json
3. Prüft: Tests bestanden? Validierung gelaufen?
4. Wenn NEIN und Iteration < limit:
   → Schreibt Iteration+1 ins Scratchpad
   → Sendet followup_message: "[Iteration 2/5] Tests failing. Continue."
5. Wenn JA oder limit erreicht:
   → Schreibt "DONE" ins Scratchpad
   → Gibt {} zurück (Agent darf aufhören)
```

Das Scratchpad löst das Session-State-Problem auf elegantere Weise als unser Diff-Hash-Marker: Es trackt nicht nur *ob* sondern *wie oft* der Hook schon interveniert hat, und erlaubt dem Hook kontextabhängige Follow-up-Messages [19].

**Bekannte Bugs in Cursor-Hooks** (Stand April 2026) [19]:
- `deny` bei `beforeReadFile` ist broken — der Read passiert trotzdem
- Mehrere Hooks im selben Trigger-Array: nur der erste wird ausgeführt
- Windows: `Bad file descriptor` Errors
- Cloud/Background Agents führen keine Hooks aus
- `postToolUse` mit `additional_context` wird akzeptiert aber nie dem Modell gezeigt

### Cursor: Empfohlene Defense-in-Depth-Architektur

```
Layer 1 — .cursor/rules/ (.mdc mit alwaysApply)
    → Setzt Intent, fängt ~80% der Abweichungen
    → EXECUTION SEQUENCE Technik: Agent muss "Applying rules X,Y,Z" antworten
    → Macht Non-Compliance sichtbar

Layer 2 — .cursor/hooks/ (stop-Hook Grind Loop)
    → Scratchpad-basierter Iterationszähler
    → Prüft git diff + Test-Output + Validation-Artefakte
    → 100% Execution (minus bekannte Bugs)

Layer 3 — Git Pre-Commit Hooks (AI-optimierte Fehlermeldungen)
    → Error-Messages als Prompt Engineering:
      NICHT: "Error: validation missing"
      SONDERN: "RULE: Post-change validation required.
               VIOLATION: 5 Swift files changed, no validation report found.
               FIX: Run reviewing-code-changes skill checklist.
               FILES: TrainingCoordinator.swift, StartTrainingUseCase.swift, ..."
    → Agent liest den Error-Output und korrigiert sich selbst [21]

Layer 4 — CI/CD Pipeline
    → swift test + lint + security scan bei PR
    → Kann vom Agent nicht umgangen werden

Layer 5 — Human Review
    → Plan Mode (Shift+Tab) vor Ausführung
    → Commit-Checkpoints vor Agent-Operationen für Rollback
```

## 3. Claude Code: Stärkere native Enforcement [Confidence: High]

Claude Code bietet ein ausgereifteres Hook-System mit echten **Blocking-Mechanismen** [10, 11]:

**`PreToolUse` — Tool-Call-Blockade:**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "reason": "This file is protected by policy."
  }
}
```
Der Tool-Call wird **physisch verhindert** — das Modell kann ihn nicht umgehen [10].

**`Stop` — Mandatory Continuation:**
```json
{
  "decision": "block",
  "reason": "Post-change validation has not been run. Run the validation checklist before completing."
}
```
Claude Code **kann nicht aufhören** bis die Bedingung erfüllt ist. `stop_hook_active` im Input verhindert Endlosschleifen: Wenn `true`, weiß der Hook dass er bereits einmal geblockt hat [10, 11].

**`CLAUDE.md` vs. Hooks:**
`CLAUDE.md` und `.claude/rules/*.md` sind persistent geladene Instructions — funktional vergleichbar mit Cursor's `alwaysApply` Rules. Aber wie bei Cursor sind sie Prose (L2) und damit anfällig für Context-Pressure. Die Community-Empfehlung: "treat 'model must follow CLAUDE.md' as unreliable by itself — especially across subagents and MCP" [3]. `CLAUDE.md` dokumentiert den Prozess, Hooks erzwingen ihn.

**Dokumentierte Lücken** [3]:
- Subagents können Hooks umgehen (keine eigene Hook-Kette)
- MCP-Tool-Calls und Pipe-Mode haben nicht alle Hook-Events
- "For anything involving subagents, MCP, or pipe mode, hooks are not enough" [3]

## 4. Externe Orchestrierung & Strukturelle Patterns [Confidence: Medium]

### CI/CD als Compliance-Schicht

Enterprise-Teams behandeln **CI/CD als die verbindliche Compliance-Schicht** — nicht die IDE [9, 13]. Der Agent erstellt Code und einen PR. CI-Pipelines führen deterministische Prüfungen durch. Erst bei Bestehen wird gemergt. Der Agent kann den CI-Gate nicht umgehen.

### Pre-Commit Hooks als Prompt Engineering [21]

Fleek (YC W22) machte eine kritische Entdeckung: Traditionelle Pre-Commit-Fehlermeldungen ("Error: console.log not allowed") verwirren AI-Agents. Stattdessen müssen Fehlermeldungen wie **Prompts** formuliert werden:

```
RULE: No console.log statements in production code.
VIOLATION: src/services/AuthService.swift:42 — print("Debug: user logged in")
FIX: Remove the print statement or replace with os.log:
  os_log(.debug, "User logged in: %{public}@", user.id)
```

Der Agent liest diesen Output und **korrigiert sich automatisch** — ein enger Feedback-Loop ohne menschliche Intervention. Das macht Pre-Commit Hooks zu **L4 UND L3 gleichzeitig**: Sie blockieren (L4) und instruieren (L3).

### State-Machine-in-Files Pattern [22]

Popularisiert von KleoSr auf dem Cursor Forum: Zwei persistente Dateien ersetzen Workflow-Instructions:

- `project_config.md` — die "Verfassung" des Projekts (invariant)
- `workflow_state.md` — dynamischer Zustand mit expliziten Phasen

Der Agent folgt einem autonomen Loop: **Read → Interpret → Act → Update → Repeat.** Pflichtschritte sind State-Transitions (Analyze → Blueprint → Construct → Validate). Überspringen ist schwerer weil der Agent die State-Datei updaten muss — das erzeugt einen sichtbaren Audit-Trail.

### QuantumBlack/McKinsey: Deterministic Orchestration Layer [23]

Die stärkste Enterprise-Lösung trennt **deterministische Orchestrierung** von **agentischer Execution**:

- Die Orchestrierungs-Schicht ist eine **regelbasierte Workflow-Engine** die Phase-Transitions und Dependencies managed
- Agents entscheiden **nie** was als nächstes kommt — "Generate tasks when REQ-001 is approved" ist deterministisch
- Git als State-Store: Branch = Feature-Workflow, Commits = abgeschlossene Phasen
- **Dual Evaluation Gates:** Sowohl deterministische Checks (Linter, Tests) als auch ein dedizierter **Critic-Agent** müssen bestehen
- Iterationslimit von 3-5 Versuchen, danach Human Escalation

### MCP-basierte Orchestrierung

Tools wie `mcp-agent` implementieren ein Orchestrator-Pattern mit Coordinator → Executor → Verifier Agents [13]. Die Enforcement passiert auf SDK-Ebene.

### Custom Commands als Workflow-Templates

`.cursor/commands/` sind zuverlässiger als Rules für sequenzielle Workflows [19]. Ein `/fix-issue [number]` Command der "Fetch issue → find code → implement fix → run tests → open PR" spezifiziert wird treuer befolgt als äquivalente Rules, weil Commands eine klare sequenzielle Struktur bieten (~85-90% vs ~70-85%).

## 5. Prompt Engineering: Was hilft, was nicht [Confidence: High]

**Was NICHT funktioniert** [5, 7, 8]:
- Lange "Constitution"-Listen mit vielen Always/Never-Regeln — "more rules = less compliance" [5]
- Selbst-Monitoring ("prüfe ob du alles gemacht hast") — "Model self-critique is not verification" [7]
- Vage Anweisungen ("achte auf Architektur-Qualität") — nicht deterministisch prüfbar

**Was FUNKTIONIERT** [5, 7, 8]:
- **Kurze Prozeduren mit expliziten Outputs** — der Agent muss ein sichtbares Artefakt produzieren, nicht nur behaupten er hätte geprüft
- **Deterministische Signale statt Reflexion** — Compiler-Output, Test-Ergebnisse, Lint-Errors als Verification, nicht Modell-Selbstauskunft
- **State-Files als Ground Truth** — externe Dateien die den Zustand tracken, nicht das Modell-Gedächtnis
- **Watchdog-Patterns** — separate Prüfprozesse die unabhängig vom Haupt-Agenten laufen

Ein Praktiker formuliert es so: "Stop asking your agent to be good. Make it structurally impossible to be bad." [5]

## Action Plan

### Sofort umsetzbar (Cursor)

- [ ] **Stop-Hook auf Grind Loop umbauen:** Scratchpad-File (`.cursor/hooks/state/scratchpad.json`) statt Diff-Hash-Marker verwenden. Iterationszähler mit `loop_limit: 5` in `hooks.json`. Hook sendet kontextabhängige Follow-up-Messages mit Iteration-Counter.
- [ ] **Artefakt-basierte Validation:** Hook prüft ob eine Datei `.cursor/hooks/state/validation-stamp.md` existiert und aktuell ist (Timestamp < 10 min) — nicht ob der Agent-Output Textmarker enthält. Der Agent muss ein sichtbares Artefakt produzieren.
- [ ] **Pre-Commit Hook mit AI-optimierten Fehlermeldungen:** Erstellen eines `.git/hooks/pre-commit` der Swift-Lint + `swift test` prüft und Fehlermeldungen im Format RULE/VIOLATION/FIX ausgibt (Fleek-Pattern). Der Agent korrigiert sich automatisch aus dem Error-Output.
- [ ] **Rules kürzen + EXECUTION SEQUENCE:** `auto-validation.mdc` auf <100 Zeilen kürzen, nur Mechanismus-Dokumentation. EXECUTION SEQUENCE Technik: Agent muss "Applying rules: auto-validation, docs-sync" antworten — macht Non-Compliance sichtbar.
- [ ] **Custom Command `/validate`:** `.cursor/commands/validate.md` erstellen das den Post-Change-Validation-Workflow als sequenziellen Command definiert (~85-90% Compliance vs ~70-85% bei Rules).

### Mittelfristig evaluieren

- [ ] **Claude Code für kritische Workflows evaluieren:** `Stop`-Hook mit `decision: "block"` ist nativ stärker. Für Workflows wo Validierung nicht optional ist (Production-Code, Security), Claude Code in Betracht ziehen.
- [ ] **State-Machine-in-Files Pattern:** `workflow_state.md` einführen die den aktuellen Workflow-Zustand trackt (Analyze → Implement → Validate → Done). Agent muss State-File updaten — sichtbarer Audit-Trail.
- [ ] **CI-Pipeline als letzte Verteidigungslinie:** GitHub Action die bei PR `swift test` + Lint + architecture.md Freshness prüft — komplett Agent-unabhängig.

### Langfristig beobachten

- [ ] **Cursor Hook-Bugs tracken:** `deny` bei `beforeReadFile`, Multi-Hook-Array, Cloud/Background Agents. Wenn gefixt, zusätzliche Enforcement-Layer möglich.
- [ ] **Flow Engineering Frameworks:** LangGraph, Temporal als Orchestrierungs-Layer falls Cursor's Mechanismen nicht ausreichen.

## Open Questions & Caveats

1. **Cursor Hook-Bugs:** `deny` bei `beforeReadFile` ist broken, Multi-Hook-Arrays führen nur den ersten aus, Windows und Cloud/Background Agents sind nicht unterstützt [19]. Diese Bugs untergraben das Versprechen deterministischer Enforcement. Kein ETA vom Cursor-Team.

2. **Subagent-Bypass:** Sowohl in Cursor als auch in Claude Code können Subagents Hook-Ketten umgehen [3]. Wenn ein Agent einen Task-Subagent startet, laufen die Hooks des Haupt-Agenten nicht für Aktionen des Subagents.

3. **Cursor vs. Claude Code Feature-Gap:** Claude Code hat 21+ Hook-Events mit vier Handler-Typen (command, HTTP, prompt, agent), `decision: "block"` Semantik, und PreToolUse-Deny das auch in `--dangerously-skip-permissions` greift. Cursor hat 6 Events, nur command-Handler, und keine Block-Semantik. Die Lücke ist signifikant [19, 10].

4. **Grind Loop Limits:** Der Grind Loop mit `followup_message` ist keine echte Blockade — der Agent wird gebeten weiterzumachen, nicht gezwungen. Bei schweren Modell-Fehlern oder Context-Overflow kann der Agent die Bitte trotzdem ignorieren.

5. **Rule Compliance quantifiziert:** Ned Cole dokumentierte dass `.mdc` mit `alwaysApply: true` in 9+ Tests 100% funktionierte, während `.cursorrules` in Agent Mode gar nicht geladen wurde [24]. Roman Imankulov zeigte dass Cursor Rule-Namen und -Beschreibungen als Menü präsentiert und bei vagen Descriptions die Rule nie aktiviert [25]. Konkrete, verifizierbare Rules mit guten Descriptions sind messbar besser als vage.

## Methodology

- **Depth:** Standard (3 Retrieval-Subagents + 1 Gap-Fill + 1 Verification) + Cross-Referenz mit separater Community-Recherche
- **Waves:** 2 (Initial Retrieval + Gap-Fill) + 1 Community Cross-Reference
- **Sources collected:** 30+ unique (nach Deduplizierung und Merge mit Community-Recherche)
- **Citation spot-check:** 5 Kernaussagen verifiziert. 3 SUPPORTED, 2 PARTIAL
- **Outline changes:** Sections 2 und 4 signifikant erweitert mit Grind Loop, Pre-Commit Prompt Engineering, State-Machine-in-Files und QuantumBlack Patterns aus der Community-Recherche
- **Cross-Reference:** Ergebnisse der initialen Recherche wurden mit einer unabhängigen Community-Recherche des Users abgeglichen. Übereinstimmung bei allen Kernaussagen; Community-Recherche lieferte zusätzlich quantifizierte Compliance-Raten und spezifische Bug-Reports

## Bibliography

[1] Scott Chacon — "Deep Dive into the new Cursor Hooks" — https://blog.gitbutler.com/cursor-hooks-deep-dive — Accessed 2026-04-11 — Tier: 2
[2] CorridorSecurity / Hookshot — `docs/reference-cursor.md` — GitHub — Accessed 2026-04-11 — Tier: 3
[3] boucle2026 — "What Claude Code Hooks Can and Cannot Enforce" — https://dev.to/boucle2026/what-claude-code-hooks-can-and-cannot-enforce-148o — Accessed 2026-04-11 — Tier: 3
[4] Cursor — "Hooks" (Agent hooks documentation) — https://docs.cursor.com/agent/hooks — Accessed 2026-04-11 — Tier: 1
[5] Farkharoumy — "How to Prompt Your AI Agent Into Enforcement, Not Willpower" — https://dev.to — Accessed 2026-04-11 — Tier: 3
[6] Cursor Community Forum — Hooks-related threads (aggregated) — https://forum.cursor.com — Accessed 2026-04-11 — Tier: 3
[7] AgentPatterns.ai — "Verification-Centric Development for AI-Generated Code" — https://agentpatterns.ai — Accessed 2026-04-11 — Tier: 2
[8] Doug Walseth — "AI Coding Agents Need Enforcement Ladders, Not More Prompts" — https://walseth.ai/blog/enforcement-ladder-ai-coding-agents — Accessed 2026-04-11 — Tier: 2 [foundational]
[9] Augment Code — "How Do Enterprise Teams Build Agentic Workflows?" — https://www.augmentcode.com/guides/how-do-enterprise-teams-build-agentic-workflows — Accessed 2026-04-11 — Tier: 2
[10] Anthropic — "Hooks reference" (Claude Code Docs) — https://code.claude.com/docs/en/hooks — Accessed 2026-04-11 — Tier: 1
[11] Anthropic — "How to configure hooks" (Claude Code Blog) — https://claude.com/blog/how-to-configure-hooks — Accessed 2026-04-11 — Tier: 1
[12] Cursor — "Best practices for coding with agents" (Blog) — https://cursor.com/blog — Accessed 2026-04-11 — Tier: 1
[13] LastMile AI — "Orchestrator" (mcp-agent docs) — https://docs.mcp-agent.com/workflows/orchestrator — Accessed 2026-04-11 — Tier: 2
[14] Endor Labs — `cursor-hook-examples` — GitHub — Accessed 2026-04-11 — Tier: 3
[15] PatrickJS — `awesome-cursorrules` — GitHub — Accessed 2026-04-11 — Tier: 3
[16] Anthropic — "How Claude remembers your project" (Claude Code Docs) — https://code.claude.com/docs/en/memory — Accessed 2026-04-11 — Tier: 1
[17] ATLAS-RTC — "Closing the Loop on LLM Agent Output with Token-Level Runtime Control" — arXiv 2603.27905 — Tier: 1
[18] Google Gemini CLI — GitHub Issue #22261 (instruction-following failures) — GitHub — Accessed 2026-04-11 — Tier: 3
[19] Community-Recherche (aggregated) — "Enforcing deterministic AI agent workflows in Cursor" — Multiple sources incl. Cursor Forum (deanrie), Ned Cole (DEV), Hacker News — Accessed 2026-04-11 — Tier: 2-3
[20] Ofer Shapira (Elementor) — Context window degradation of rules — Medium — Accessed 2026-04-11 — Tier: 3
[21] Fleek (YC W22) — Pre-commit hook error messages as prompt engineering — egghead.io — Accessed 2026-04-11 — Tier: 2
[22] KleoSr — State-machine-in-files pattern — Cursor Forum — Accessed 2026-04-11 — Tier: 3
[23] QuantumBlack (McKinsey) — Two-layer deterministic orchestration architecture — Published Feb 2026 — Accessed 2026-04-11 — Tier: 2
[24] Ned Cole — A/B testing .mdc vs .cursorrules compliance — DEV Community — Accessed 2026-04-11 — Tier: 3
[25] Roman Imankulov — Cursor rule activation mechanism (menu + description) — Blog — Accessed 2026-04-11 — Tier: 2
[26] Martin Fowler's team — Kiro spec-driven development: "agent ultimately not follow all the instructions" — martinfowler.com — Accessed 2026-04-11 — Tier: 1 [foundational]
[27] Claude Code community — 405 assertions across 45 test sections via hooks — GitHub — Accessed 2026-04-11 — Tier: 3

## Source Extracts

### [1] Scott Chacon — GitButler Cursor Hooks Deep Dive
- **Summary:** Detailed walkthrough of Cursor's six hook events, their stdin/stdout JSON contracts, and GitButler's use of `conversation_id`/`generation_id` for VCS integration. Contrasts deterministic hooks with non-deterministic rules/MCP.
- **Key quotes:** "hooks are generally deterministic programs that can always be known to do the same thing the same way. Rules and MCP calls and parameters will almost by definition be non-deterministic"
- **Source type:** Engineering blog (established company)
- **Credibility tier:** 2

### [8] Doug Walseth — Enforcement Ladder
- **Summary:** Proposes L1-L5 enforcement hierarchy for AI agent compliance. Argues prose rules are lowest-priority in context window and get dropped first. Recommends structural enforcement (templates, tests, hooks) over behavioral (more rules).
- **Key quotes:** "When the context window fills up — and it always does — the model drops these rules first." / "L5 — Hooks… The action is physically prevented before it happens."
- **Source type:** Practitioner blog
- **Credibility tier:** 2

### [10] Anthropic — Claude Code Hooks Reference
- **Summary:** Official docs for Claude Code hook system. PreToolUse can deny/allow/ask tool calls. Stop hook can block agent from finishing with mandatory reason. stop_hook_active prevents infinite loops. InstructionsLoaded fires when CLAUDE.md is loaded (observability only).
- **Key quotes:** "Hooks are user-defined shell commands, HTTP endpoints, or LLM prompts that execute automatically at specific points in Claude Code's lifecycle."
- **Source type:** Official documentation
- **Credibility tier:** 1

### [3] boucle2026 — Claude Code Hooks Limitations
- **Summary:** Documents categories of hook bypass/failure modes: alternate CLI modes, subagent routing, MCP tool calls. Recommends OS-level controls when hooks are insufficient.
- **Key quotes:** "Claude Code hooks are the only mechanism that enforces rules at the process level rather than relying on model compliance." / "For anything involving subagents, MCP, or pipe mode, hooks are not enough."
- **Source type:** Practitioner analysis (DEV Community)
- **Credibility tier:** 3

### [5] Farkharoumy — Prompt Enforcement Patterns
- **Summary:** Frames dense system prompts as "willpower" that fails. Recommends watchdog crons, state files, circuit breakers, and procedure-style prompts with required outputs.
- **Key quotes:** "more rules = less compliance." / "Stop asking your agent to be good. Make it structurally impossible to be bad."
- **Source type:** Practitioner blog (DEV Community)
- **Credibility tier:** 3

### [7] AgentPatterns.ai — Verification-Centric Development
- **Summary:** Shifts bottleneck from code generation to layered verification (compiler → lint → tests → SAST → snapshots → E2E → human). Stresses deterministic signals over model self-critique.
- **Key quotes:** "Reflection loops must verify against deterministic signals — compiler output, test results, lint errors, schema validation. Model self-critique … is not verification."
- **Source type:** Practitioner synthesis
- **Credibility tier:** 2
