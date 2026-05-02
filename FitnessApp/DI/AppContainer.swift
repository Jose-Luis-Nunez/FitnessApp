import Factory
import FitnessStorage
import FitnessTraining

// Container extensions are defined in their respective packages:
// - StorageContainer.swift (FitnessStorage): workoutStorage, exerciseStorage,
//   analyticsStorage, exerciseManagement, totalAnalyticsStorage
// - TrainingContainer.swift (FitnessTraining): trainingCoordinatorCache, use cases
//
// They are automatically available via `@Injected(\.keyPath)` wherever
// Factory and the relevant package are imported.
