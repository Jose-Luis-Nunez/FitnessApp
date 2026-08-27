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

Update the architecture reference only for a structural or public-surface
change. Do not update it for AppStyle tokens of any kind, presentation-only
components such as backgrounds and styling wrappers, token value swaps,
spacing-only layout changes, private refactors, or test expectation edits. The
"AppStyle Tokens" section deliberately carries no token names or values, so a
new token has nothing to record there.

Describe stable ownership and package responsibilities. Do not enumerate
volatile menu contents or transient UI conditions. When a new ADR already
exists, confirm every architecture/ADR index links it.
