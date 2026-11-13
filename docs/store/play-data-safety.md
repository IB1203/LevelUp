# Google Play data-safety declaration — Level Up

This document records the data-safety answers to declare in the Google Play Console for Level Up. Nothing here is fabricated: the app is local-first and ships no analytics, ads, or backend.

## Data collected or shared

- **Collected:** No personal or sensitive user data is collected by the developer.
- **Shared:** No user data is shared with third parties.
- **Transferred:** No user data is transferred off the device.
- **Account deletion:** N/A — the app has no accounts.

## Data types (device-local only)

The following categories exist only on the user's device and never leave it:

| Data type | Source | Purpose | Ephemeral | Required |
|---|---|---|---|---|
| Health & fitness (workouts, bodyweight, progress photos) | User input | Training log & Hunter System progression | No | Yes |
| Device or other identifiers | App-generated | Local data integrity / idempotency | No | Yes |
| App settings (theme, units, reminders, notification sounds) | User input | App behaviour | No | Yes |

## Health Connect

The app optionally reads/writes step and activity data through Google Health Connect only when the user enables it in Settings. This data stays on-device and is not shared.

## Safety sections

- **No data collected / shared / transferred to developer** → select "No" across the board.
- **Data is not encrypted in transit** → not applicable (nothing leaves the device).
- **Data is not ephemeral** → workout history is persistent by design; users may delete it.
- **No account deletion mechanism** → no accounts exist.

## Screenshots

The screenshots in `docs/screenshots` are inherited assets from the GymMane upstream and need regeneration for store submission; they are not part of this declaration.
