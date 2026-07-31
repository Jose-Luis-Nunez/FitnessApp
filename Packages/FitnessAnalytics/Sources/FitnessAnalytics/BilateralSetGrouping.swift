import FitnessCore

struct BilateralSetGroup: Identifiable, Equatable, Sendable {
    let logicalSetIndex: Int
    let left: SetProgress
    let right: SetProgress

    var id: Int { logicalSetIndex }

    init(logicalSetIndex: Int, left: SetProgress, right: SetProgress) {
        self.logicalSetIndex = logicalSetIndex
        self.left = left
        self.right = right
    }
}

enum BilateralSetGrouping {
    /// Returns paired groups only for a complete, unambiguous bilateral entry.
    /// Legacy or mixed data returns `nil` and keeps the standard flat UI.
    static func groups(for progress: [SetProgress]) -> [BilateralSetGroup]? {
        guard !progress.isEmpty,
              progress.allSatisfy({ $0.side != nil && $0.logicalSetIndex != nil }) else {
            return nil
        }

        let grouped = Dictionary(grouping: progress) { $0.logicalSetIndex! }
        let groups = grouped.keys.sorted().compactMap { logicalIndex -> BilateralSetGroup? in
            guard let values = grouped[logicalIndex],
                  values.count == 2,
                  let left = values.first(where: { $0.side == .left }),
                  let right = values.first(where: { $0.side == .right }) else {
                return nil
            }
            return BilateralSetGroup(
                logicalSetIndex: logicalIndex,
                left: left,
                right: right
            )
        }

        return groups.count == grouped.count ? groups : nil
    }

    static func setRepsLabel(for progress: [SetProgress], reps: Int) -> String {
        setRepsLabel(forEntries: [progress], reps: reps)
    }

    /// Builds a daily label without flattening separate sessions. Flattening
    /// would merge equal logical indices from multiple bilateral sessions and
    /// incorrectly fall back to six physical steps per session.
    static func setRepsLabel(
        forEntries entries: [[SetProgress]],
        reps: Int
    ) -> String {
        let nonEmptyEntries = entries.filter { !$0.isEmpty }
        let bilateralGroups = nonEmptyEntries.map(groups(for:))
        let isEntirelyBilateral = !nonEmptyEntries.isEmpty
            && bilateralGroups.allSatisfy { $0 != nil }
        let count = isEntirelyBilateral
            ? bilateralGroups.compactMap { $0?.count }.reduce(0, +)
            : nonEmptyEntries.reduce(0) { $0 + $1.count }
        let suffix = isEntirelyBilateral ? " / side" : ""
        return "\(count)×\(reps)\(suffix)"
    }
}
