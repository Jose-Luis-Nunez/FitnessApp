import Foundation
import FitnessCore

/// Visual state of the feedback entry-point icon shown in `BottomActionBarView`.
/// Resolved per **active training session** from in-memory draft + committed
/// storage. Each state maps to a dedicated bitmap asset shipped by the
/// designer (`feedback_entry`, `feedback_entry_draft`, `feedback_entry_done`).
///
/// State transitions during a single training session for one exercise:
/// - Sheet never opened, no content → `.entry`
/// - User edited and closed (Cancel / X / Swipe) without Save → `.draft`
/// - User tapped Save in the sheet → `.done`. Reopening the `.done` icon and
///   editing temporarily **does not** demote the icon to draft; only re-Save
///   updates the same DB record (upsert by `sessionId`).
public enum FeedbackEntryIconState: Equatable {
    /// No draft, no committed feedback for this session of the active exercise.
    case entry
    /// User has touched the form but not yet saved (only an in-memory draft
    /// exists for the active exercise).
    case draft
    /// A committed Done record exists in storage **for the current session**.
    /// Done outranks Draft because editing a committed feedback temporarily
    /// resurrects a draft in memory — closing the sheet without Save must not
    /// visually demote the Done.
    case done

    /// Image-asset name shipped in `FitnessApp/Assets.xcassets/`. All three
    /// assets share an identical 1024×1024 canvas with the orange plus-cross
    /// centred at (0.500, 0.499); `.draft` and `.done` overlay an additional
    /// green status badge on top — the render path is therefore uniform.
    public var assetName: String {
        switch self {
        case .entry: return "feedback_entry"
        case .draft: return "feedback_entry_draft"
        case .done:  return "feedback_entry_done"
        }
    }

    /// Voice-Over label for the entry-point button.
    public var accessibilityLabel: String {
        switch self {
        case .entry: return "Add feedback"
        case .draft: return "Feedback draft in progress"
        case .done:  return "Feedback saved"
        }
    }
}

/// Pure resolver: turns the (draft, storage, sessionId) tuple for a given
/// exercise into the icon state that should be rendered. Stateless, testable
/// in isolation.
@MainActor
public enum FeedbackEntryIconResolver {
    public static func state(
        for exerciseId: UUID,
        sessionId: UUID?,
        draftStore: ExerciseFeedbackDraftStore,
        storage: FeedbackStoring
    ) -> FeedbackEntryIconState {
        if let sessionId,
           storage.load(for: exerciseId).contains(where: { $0.sessionId == sessionId }) {
            return .done
        }
        if draftStore.draft(for: exerciseId)?.hasAnyContent == true { return .draft }
        return .entry
    }
}
