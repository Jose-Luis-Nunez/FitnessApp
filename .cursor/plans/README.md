# Plans

Versionierte Plan-Dokumente für größere Features, Refactorings und Recherchen.
Wird **nicht** vom `agent-infrastructure-enforcement`-Hook getrackt
(`.cursor/plans/` ist explizit ausgenommen — siehe Rule
[agent-infrastructure-enforcement.mdc](../rules/agent-infrastructure-enforcement.mdc)).

## Wofür

- **Plan**: konkrete Implementierungs-Roadmap für ein Feature/Refactoring
  (Architektur, Files, Tests, To-dos)
- **Research**: Deep-Research-Berichte mit Quellen und Begründungen für
  Designentscheidungen
- **Wireframe**: ASCII-/Mermaid-Skizzen der UI-States vor der Implementierung
- **Task-Splits**: bei größeren Initiativen ein Ordner mit `T0`, `T1`, …
  einzelnen Teil-Tasks (siehe [observable-models-sot/](observable-models-sot/))

Der Cursor-Plan-Mode legt Pläne standardmäßig unter
`~/.cursor/plans/<slug>_<hash>.plan.md` ab. Die werden bei Bedarf hierher
verschoben/kopiert, damit sie versioniert sind und für Reviews, künftige
Sessions und andere Maintainer verfügbar bleiben.

## Struktur

```
.cursor/plans/
├── README.md                      ← diese Datei
├── <feature-name>/                ← ein Ordner pro Feature/Initiative
│   ├── PLAN.md
│   ├── RESEARCH.md                (optional)
│   ├── WIREFRAME.md               (optional)
│   └── TN_<task>.md               (optional, bei großen Splits)
└── <single-doc>.md                ← Einzeldokumente für kleine Pläne ohne Begleitmaterial
```

## Konventionen

### Status-Header

Jedes Dokument bekommt am Anfang (nach Title) einen Status-Block:

```markdown
> Status: active | Created: YYYY-MM-DD
> Companion: [RESEARCH.md](RESEARCH.md), [WIREFRAME.md](WIREFRAME.md)
```

**Status-Werte:**

| Status | Bedeutung |
|--------|-----------|
| `active` | Plan ist aktuell, Feature in Arbeit oder noch nicht implementiert |
| `done` | Implementierung abgeschlossen, Plan als historische Referenz |
| `superseded` | Durch neueren Plan ersetzt — Link auf Nachfolger im Header |
| `dropped` | Wird nicht implementiert — kurze Begründung im Header |

### Naming

- Ordner: `kebab-case` und beschreibend (`weight-recommendation`,
  `observable-models-sot`)
- Dateien innerhalb: `PLAN.md`, `RESEARCH.md`, `WIREFRAME.md` (UPPERCASE)
  oder `T0_<task-name>.md` für Task-Splits

### Lifecycle

1. Cursor erstellt Plan in `~/.cursor/plans/...`
2. Wenn der Plan bleiben soll: nach `.cursor/plans/<feature>/PLAN.md`
   verschieben + Status-Header eintragen
3. Begleit-Dokumente (Research, Wireframes) daneben legen, untereinander
   verlinken
4. Nach Implementierung: Status auf `done` setzen, **nicht löschen** —
   Plan dient als Historie für Reviews und künftige Maintainer
5. Bei wesentlichen Änderungen: neuen Plan erstellen, alten auf
   `superseded` setzen, gegenseitig verlinken

### Aufräumen

Periodischer Pass (~quartalsweise): `dropped`-Pläne können nach 3 Monaten
gelöscht werden, `done`/`superseded` bleiben dauerhaft als Historie.

## Bestehende Pläne

| Plan | Status |
|------|--------|
| [weight-recommendation/](weight-recommendation/) | active |
| [observable-models-sot/](observable-models-sot/) | (siehe Ordner) |
