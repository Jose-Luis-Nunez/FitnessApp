# D: Coverage Gaps

Check the production code that the tests cover:

1. List all `public` / `internal` methods on ViewModels, Coordinators, UseCases, and Services
2. For each method, check if at least one test exercises it
3. Flag untested methods, prioritized by:
   - **Critical:** State-mutating methods (e.g. `completeExercise`, `editMore`, `resetExercise`)
   - **Warning:** Query methods (e.g. `getDailyWeightProgression`, `totalWeight`)
   - **Info:** Convenience/delegation methods

Also check for untested edge cases:
- Empty collections (no exercises, no analytics entries)
- Boundary values (weight = 0, sets = 0, reps = 0)
- Concurrent state changes (exercise completion during edit)
