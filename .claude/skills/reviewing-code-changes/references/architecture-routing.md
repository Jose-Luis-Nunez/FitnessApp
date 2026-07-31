# Architecture Context Routing

Do not read all of `architecture-documentation.md`.

Use `rg -n '^## |^### '` to locate headings, then read only the relevant
section:

| Change | Architecture section |
|---|---|
| Feature/package | Feature Map |
| Domain type | Domain Models |
| Service/storage | Services |
| Use case | Use Cases |
| Shared UI | Shared Components |
| Coordinator/state | State & Navigation |
| Route | Navigation |
| New/renamed AppStyle token | AppStyle Tokens |

Update the architecture reference only for a structural or public-surface
change. Do not update it for token value swaps, spacing-only layout changes,
private refactors, or test expectation edits.
