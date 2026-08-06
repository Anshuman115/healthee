/// The wall-clock time inside a server ISO instant, without leaving its zone.
///
/// `/api/sleep`'s `nights[].midpoint_local` and `/api/today`'s sleep-health
/// block both send a full ISO-8601 instant carrying the owner's own offset
/// (`2026-07-31T02:45:00+05:30`). What the Timing row shows is a **clock face**,
/// not a moment, and those are different questions.
///
/// ## Why this slices the string rather than parsing it
///
/// `DateTime.parse(...)` returns the same instant expressed in the **device's**
/// zone. On a phone that has travelled, or is simply set to UTC, a 02:45 sleep
/// midpoint would render as 21:15 the previous evening — the right moment and
/// the wrong clock, which is the only thing the row is about. The server already
/// did the timezone work; the offset in the string is the proof of it. Slicing
/// keeps that answer.
///
/// This lived privately in `data/models/sleep_health.dart` and was needed a
/// second time by `features/sleep/widgets/sleep_health_card.dart`, whose Timing
/// row was printing the whole ISO string into a 13 px cell. Second occurrence =
/// extract (Standards §1), and it goes to `shared/` rather than to the sleep
/// feature because a model may not import a feature.
library;

/// `HH:MM` out of an ISO-8601 instant, or null when there is nothing to slice.
///
/// Null rather than an echo of the input: a card that cannot read a timestamp
/// should draw its hole, not print the timestamp at the owner.
String? clockOfIso(Object? raw) =>
    raw is String && raw.length >= 16 ? raw.substring(11, 16) : null;
