import Foundation

extension SponsorSegment {
    /// `nil` for categories we don't recognize (forward-compatible with
    /// new SponsorBlock categories) or for non-`skip` action types like
    /// `mute`/`poi`, which aren't supported by the auto-skip logic yet.
    init?(sponsorBlockSegment dto: SponsorBlockSegmentDTO) {
        guard let category = SponsorBlockCategory(rawValue: dto.category) else { return nil }
        if let actionType = dto.actionType, actionType != "skip" { return nil }
        guard dto.segment.count == 2 else { return nil }

        self.init(
            uuid: dto.uuid,
            category: category,
            startTime: dto.segment[0],
            endTime: dto.segment[1],
            votes: dto.votes ?? 0,
            locked: (dto.locked ?? 0) != 0
        )
    }
}
