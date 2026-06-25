# Constraints

- Default policy mode: warn on drift, block critical gaps.
- Every feature change needs a feature spec in `harness/specs/`.
- Architectural or cross-cutting decisions need an ADR in `harness/adrs/`.
- AI responses must cite the spec, ADRs, and rules they used.
- If the repo state contradicts the spec or ADR, escalate instead of guessing.

## Detected Stack Summary

- Flutter mobile timing-stack game repository with spec-driven harness artifacts.
- Gameplay logic stays shared across iPhone and Android.
- Ads must remain outside active play and use dedicated layout slots.

## Suggested Profile Pack Constraints

No approved profile packs are configured. Keep stack guidance explicit in this rules file until a profile pack is reviewed and approved.
