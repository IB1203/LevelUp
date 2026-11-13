# Health Connect data-safety declaration — Level Up

Level Up optionally integrates with Google Health Connect on Android. This declaration describes how that data is handled.

## Scope

Health Connect access is opt-in. The app never reads or writes Health Connect data unless the user turns the Health Connect setting on in Settings and grants the Android permission.

## Data read

- Steps and active calories (to surface activity context inside the Hunter System)

## Data written

- None. The app only reads; it never writes to Health Connect.

## Use

Health Connect data is displayed on-device only: daily step context alongside training sessions. It is never uploaded to a server, never shared with third parties, and never used for advertising.

## Retention

Data read from Health Connect is not stored separately by the app beyond the current session's context. Revoking the permission (Android settings or inside the app) stops all reads immediately.

## User control

- Enable/disable: Settings → Health
- Revoke permission: Android Settings → Apps → Level Up → Permissions

## Store submission notes

Declare Health Connect as a "core feature"? No — it is optional. The app remains fully functional without it.
