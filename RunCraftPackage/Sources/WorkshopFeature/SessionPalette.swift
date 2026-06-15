import DesignSystem
import RunCraftModels

/// Maps each `SessionType` onto a `WorkoutCardPalette` — keeps the palette
/// lookup centralised so the Plan tab, Full Schedule, Workshop Templates,
/// and any future session-row consumer stay visually consistent.
public enum SessionPalette {
    public static func palette(for type: SessionType) -> WorkoutCardPalette {
        switch type {
        case .easy:       .easy
        case .tempo:      .threshold
        case .interval:   .interval
        case .long:       .long
        case .repetition: .repetition
        case .rest:       .rest
        case .fartlek:    .fartlek
        case .mixed:      .mixed
        }
    }
}
