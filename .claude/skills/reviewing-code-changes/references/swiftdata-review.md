# SwiftData Review

Load when the diff contains `@Model`, `@Query`, `#Predicate`, `ModelContext`,
schema, migration, or storage changes.

- Prefer denormalized stable IDs in predicates over relationship optional
  chains or `persistentModelID`.
- Dynamic query filters must be rebound by View identity, normally `.id(...)`
  on the parent query host.
- A View rendering `@Model` state should observe that model directly; do not
  copy live models into an unrelated snapshot cache.
- Mutations and referential cleanup that must succeed together use the same
  `ModelContext`.
- Background/model-actor writes require an integration test proving active
  main-actor queries update.
- Schema changes require persistence and restart coverage. Require migration
  coverage only when installed data compatibility is a product requirement.
