import Factory
import FitnessStorage
import FitnessTraining

// Container extensions are defined in their respective packages:
// - StorageContainer.swift (FitnessStorage): workoutStorage, exerciseStorage,
//   analyticsStorage, exerciseManagement, totalAnalyticsStorage
// - TrainingContainer.swift (FitnessTraining): sessionTrainingCache
//
// They are automatically available via `@Injected(\.keyPath)` wherever
// Factory and the relevant package are imported.
