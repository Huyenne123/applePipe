import SwiftUI

/// A sheet that lets the user choose which SponsorBlock categories
/// auto-skip during playback. Changes take effect immediately on the
/// next segment check; no restart needed.
///
/// The binding is to `PlayerViewModel.enabledCategories` so this view
/// owns no state of its own — it's purely a UI projection of the VM.
struct SponsorBlockCategorySheet: View {
    @Binding var enabledCategories: Set<SponsorBlockCategory>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(SponsorBlockCategory.allCases, id: \.self) { category in
                Toggle(isOn: Binding(
                    get: { enabledCategories.contains(category) },
                    set: { enabled in
                        if enabled {
                            enabledCategories.insert(category)
                        } else {
                            enabledCategories.remove(category)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.displayName)
                            .font(.subheadline)
                        Text(category.segmentDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Skip Segments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private extension SponsorBlockCategory {
    var segmentDescription: String {
        switch self {
        case .sponsor:
            return "Paid promotion, paid placement, or paid sponsorship."
        case .selfpromo:
            return "Unpaid promotion of the creator's own content or merch."
        case .interaction:
            return "Requests to like, subscribe, follow, or leave a comment."
        case .intro:
            return "Intro animation or recap of previous episodes."
        case .outro:
            return "Endcards, credits, or outro animations."
        case .preview:
            return "Preview or recap of this video's own content."
        case .musicOfftopic:
            return "Non-music content in a music video."
        case .filler:
            return "Tangents or filler that don't contribute to the topic."
        case .exclusiveAccess:
            return "Footage only possible due to paid exclusive access."
        }
    }
}

#Preview {
    SponsorBlockCategorySheet(
        enabledCategories: .constant(
            Set(SponsorBlockCategory.allCases.filter(\.isSkippedByDefault))
        )
    )
}
