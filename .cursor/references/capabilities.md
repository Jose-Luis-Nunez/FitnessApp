# Capabilities — was der User heute schon tun kann

> Pure Bullet-Liste. Wenn eine Idee an einem dieser Punkte schon dranhängt: erweitern statt neu bauen.

## Workouts verwalten

- Mehrere Workouts anlegen (kein Limit)
- Workouts umbenennen (Free-Text)
- Workouts duplizieren (inkl. aller enthaltenen Exercises mit eigenen UUIDs)
- Workouts löschen (Confirmation-Step, **Invariante: ≥1 Workout muss bleiben**)
- Ein Workout als "Default" markieren — beim App-Start wird direkt dorthin navigiert
- Pro Workout-Tile sichtbar: Anzahl Exercises (im farbigen Ring oben links)

## Exercises pro Workout & Muskelgruppe verwalten

- Übungen anlegen mit folgenden Properties:
  - **Name** (Free-Text)
  - **Gewicht** (Picker, vordefinierte Optionen via `WeightOptionsGenerator`)
  - **Reps** (1...50)
  - **Sätze** (1...10)
  - **Sitzeinstellung** (Free-Text, optional, mit `noSeats`-Flag wenn nicht relevant)
  - **Icon** (Auswahl aus Asset-Catalog via `IconPickerView`)
  - **Kategorie** (`MuscleCategoryGroup`: arms / chest / back / legs / abs)
  - **Goal** (Ziel-Reps oder -Gewicht — von `AnalyticsView` gelesen)
- Übungen einzeln editieren (Name / Gewicht / Sitz / komplett — vier `ExerciseEditMode`s)
- Übungen löschen
- Übungen pro Übung "resetten" (Sätze auf "noch nicht erledigt", behält die Übung)
- **Reset all** für eine ganze Kategorie über das Mini-Menü auf Home

## Trainieren (Live-Session)

- Trainingseinheit pro Übung starten — Coordinator wird gecached pro Kategorie
- Pro Satz drei Aktionen:
  - **Done** (Reps wie geplant geschafft → `completedDone`)
  - **More** (mehr Reps geschafft → `completedMore`, prompt für tatsächliche Anzahl)
  - **Less** (weniger geschafft → `completedLess`, prompt für tatsächliche Anzahl)
- Während eines Sets:
  - **Live-Timer** (Sekunden tickend)
  - Inline-Edit der aktuellen Reps oder des Gewichts vor dem Set-Abschluss
- Training abbrechen (mit Bestätigung) — alle bisherigen Sätze der Session werden verworfen
- Training ist **resilient gegen Pop**: User kann mitten im Set rauspoppen und zurücknavigieren, der Stand bleibt (`TrainingCoordinatorCache`)
- Bei abgeschlossener Übung springt der State der Card auf "completed" — sichtbar live ohne Refresh dank `@Model`-Binding

## Live Activity (Lock-Screen / Dynamic Island)

- Während ein Training aktiv ist, erscheint die Activity **automatisch** auf dem Lock-Screen
- Drei Buttons: Done / More / Less
- User kann komplette Sets durchklicken **ohne die App zu öffnen** — wirkt direkt in den Coordinator zurück

## Post-Exercise Feedback

- Nach dem letzten Satz öffnet sich automatisch ein Feedback-Sheet (zwei Detents)
- Erfassen kann der User:
  - **Symptome** multi-select: Schmerz / Schwindel / Übelkeit / Muskelschwäche
  - **Schmerz-Region** (wenn "Schmerz" gewählt) — Body-Map mit 32 Regionen
  - **Energie-Level** 1...5 (wenn ≥1 Symptom)
  - **Notiz** (Free-Text, single-line, wenn ≥1 Symptom)
- Pro Trainingseinheit ein Record (`sessionId`-scoped)
- Sheet wegswipen ohne Save → Draft bleibt im Memory bis Übungs-Wechsel
- Letztes Feedback derselben Übung wird als Vorbelegung geladen

## Analytics & Progress

### Per-Übung (`AnalyticsView`)

- **Hill-Chart** — visualisiert Fortschritt einer Übung über Zeit
- **Weight-Milestones** — markante Punkte wo das Gewicht hochgegangen ist
- **Result-Liste** — chronologische Liste aller Trainings dieser Übung
  - Einzelne Sätze eines Eintrags löschen
  - Bestehende Einträge editieren
- **Manueller Eintrag** über `AddAnalyticsEntryView` (für historische Daten)
- **Calendar-Picker** — zu einem bestimmten Datum springen, Tage mit Daten sind highlighted
- **Goal setzen** für die Übung (gestrichelte Linie im Chart)

### Aggregiert (`TotalAnalyticsView`)

- **Overall Stats** als Tile-Grid (Anzahl Sessions, Anzahl abgeschlossene Übungen, …)
- **Category Progress** — pro Muskelgruppe wie viel trainiert wurde
- **Calendar** mit Highlight aller Trainingstage über alle Workouts hinweg

## Schedule

- **Monatskalender** mit Indikator pro Trainingstag
- **Streak-Banner** (aktuelle Streak in Tagen)
- **Wochen-Übersicht** (Mo–So mit Day-Indikator)
- **Day-Detail** (welche Übungen wurden an dem Tag trainiert)
- Schedule ist immer **scoped auf das aktuelle Workout** — Workout-Wechsel reloaded die Daten

## Profile

- **Nickname** setzen — wird als "Hey {nickname}" oben im Profile-Tab angezeigt
- **Body-Daten** in aufklappbarer Karte: Gewicht (kg), Größe (cm), Alter
- **BMI** — wird über externe REST-API berechnet, mit Refresh-Button, in aufklappbarer Karte
- **BVG-Tram-Karte**: nächste 3 Abfahrten der Tram 21 zwischen Blockdammweg ↔ Marktstr.
  - Auto-Refresh alle 60 s solange aufgeklappt + App `.active`
  - Start ↔ Destination per horizontalem Pfeil swappen
  - Manueller Refresh-Button
  - Offline-Fallback aus UserDefaults-Cache mit gelbem Stale-Indikator

## Plattform-Features

- **iOS-Native**, läuft auf iPhone (iPhone 17 Pro Max ist der Test-Sim)
- **Glass-Effekt-UI** durchgängig (iOS 26 Liquid Glass), mit Fallback auf `.ultraThinMaterial` für ältere Versionen
- **Single-User**, alles lokal in SwiftData persistiert (keine Cloud, kein Account)
- **Offline-first** — die einzigen Online-Calls sind BMI-API und BVG-Tram-API, beide mit Cache-Fallback
- **Swipe-Back-Gesture** auf jedem Push (`enableSwipeBack()`)
- **Keyboard-aware**: BottomBar versteckt sich automatisch wenn Tastatur erscheint

## Was es heute (noch) nicht gibt

- Keine Pause-/Resume-Logik für Trainings über App-Restart hinweg (Cache verfällt mit dem Coordinator)
- Keine Templates / Vorlagen für Workouts (jeder muss man-uell aufsetzen)
- Keine "1RM"-Berechnung oder andere abgeleitete Stärke-Metriken
- Keine Kalorien-/Nährwert-Berechnung
- Kein Export von Daten (CSV / Health-App / etc.)
- Keine Eingabe von Körpermaßen jenseits von Gewicht/Größe (kein Bauchumfang, Bodyfat, etc.)
- Keine Reminder/Notifications für geplante Trainings
- Keine Übungs-Bibliothek mit Beschreibungen / Anleitungen / Videos
- Keine Foto-Logs (Progress-Fotos)
- Keine Workout-Pläne mit Wochen-Zyklen (PPL, Push/Pull, etc.)
