import CoreFoundation
import SwiftUICore
import CoreGraphics

enum FieldColumn {
    case left
    case right
}

enum ExerciseFieldType: Identifiable {
    case weight(Int, CGFloat?)
    case sets(Int, CGFloat?)
    case reps(Int, CGFloat?)

    var id: String {
        switch self {
        case .weight: return "weight"
        case .sets: return "sets"
        case .reps: return "reps"
        }
    }

    var editField: EditField {
        switch self {
        case .weight: return .weight
        case .sets: return .sets
        case .reps: return .reps
        }
    }

    var prefilledValue: String {
        switch self {
        case .weight(let val, _): return "\(val)"
        case .sets(let val, _): return "\(val)"
        case .reps(let val, _): return "\(val)"
        }
    }

    var valueText: String {
        switch self {
        case .weight(let val, _): return "\(val) kg"
        case .sets(let val, _): return "\(val)x"
        case .reps(let val, _): return "\(val)"
        }
    }

    static func icon(for type: EditField) -> ChipIcon? {
        switch type {
        case .sets:
            return ChipIcon(systemName: "bolt.fill", color: AppStyle.Color.yellow)
        case .reps:
            return ChipIcon(systemName: "arrow.triangle.2.circlepath", color: AppStyle.Color.green)
        default:
            return nil
        }
    }


    var frameHeight: CGFloat? {
        switch self {
        case .weight(_, let height): return height
        case .sets(_, let height): return height
        case .reps(_, let height): return height
        }
    }
    
    var column: FieldColumn {
        switch self {
        case .weight: return .right
        case .sets, .reps: return .left
        }
    }
}
