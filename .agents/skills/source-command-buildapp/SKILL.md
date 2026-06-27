---
name: "source-command-buildapp"
description: "Build, install, and launch FitnessApp on ONE target — physical iPhone or booted simulator"
---

# source-command-buildapp

Use this skill when the user asks to run the migrated source command `buildApp`.

## Command Template

# /buildApp

Run `scripts/buildApp.sh` from the repo root. Single-target by design — never deploys to both at once, so the user can keep an old build on one runtime while comparing it to a new build on the other.

## Argument mapping

User input → script invocation:

| User says | Run |
|---|---|
| `/buildApp` (no arg, both targets up) | `./scripts/buildApp.sh` and surface the "pick one" error verbatim. Then ask the user to pick. |
| `/buildApp` (no arg, only one target up) | `./scripts/buildApp.sh` (script auto-resolves to the only available target) |
| `/buildApp iphone` / `/buildApp device` / `/buildApp phone` | `./scripts/buildApp.sh --device` |
| `/buildApp sim` / `/buildApp simulator` / `/buildApp emulator` | `./scripts/buildApp.sh --sim` |

## Steps

1. Map the user's argument as above and execute the script.
2. Report the target header (`=== Device: …` or `=== Simulator: …`) and the `Done in Ns.` timing line. If any step failed, surface the error verbatim and stop.

## Troubleshooting (only if a step errors)

- **`both iPhone and simulator are available — pick one explicitly`** → the user invoked `/buildApp` with no arg while both are up. Ask them which they want this time.
- **`--device requested but no iPhone in 'connected' state`** → ask the user to plug in the iPhone, unlock it, and confirm via `xcrun devicectl list devices`.
- **`--sim requested but no '<name>' simulator booted`** → ask the user to boot the simulator (Xcode → Simulator app, or `xcrun simctl boot <udid>`). Override preferred name via `PREFERRED_SIM_NAME=…`.
- **`Unable to launch … device was not, or could not be, unlocked`** → the iPhone is locked. Ask the user to unlock it and retry.
- **`Unable to find a device matching the provided destination specifier` (device branch)** → iPhone paired but not yet blessed for development. User must open Xcode once → Window → Devices and Simulators (⇧⌘2) → select the iPhone → "Use for Development". After that the CLI works.
- **Provisioning / signing errors (device branch)** → script already passes `-allowProvisioningUpdates`. If signing still fails, the user's developer certificate or device registration is out of sync with the Apple Developer Portal — one-time Xcode UI fix.
- **Override** scheme, bundle id, or simulator preference: export `SCHEME=…`, `BUNDLE_ID=…`, or `PREFERRED_SIM_NAME=…` before invoking.
