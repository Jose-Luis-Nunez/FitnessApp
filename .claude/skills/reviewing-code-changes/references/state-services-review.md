# State, Service, and Coordinator Review

Load for ViewModels, services, use cases, coordinators, caches, protocols, or
concurrency changes.

- One identity has one authoritative mutable state owner.
- Do not introduce a View-owned ViewModel when a keyed coordinator/cache already
  owns the same session.
- Prefer semantic observable state or payload-bearing events over generic
  counters and polling loops.
- Views call coordinators/use cases; persistence remains behind protocols.
- A callback fires only after the operation it announces succeeds.
- Resume, cancel, reset, focus changes, and failure paths preserve the documented
  coordinator contract.
- Protocol changes update production wiring, mocks, spies, and relaxed/default
  behaviors.
- Inject the exact capability a use case requires. Do not accept a broader
  protocol and recover the real dependency through a conditional runtime cast.
- Avoid dual init paths that silently use different dependencies.
- Check actor isolation and cancellation for every long-lived Task.
