# Harness Apply Skill Note

- References used:
  - `harness/manifest.json`
  - `harness/specs/feature-swipe-stack-mvp.md`
  - `harness/adrs/adr-swipe-stack-deterministic-stacking.md`
  - `harness/contracts/contract-swipe-stack-mvp.md`
  - `harness/rules/constraints.md`
  - `harness/rules/golden-rules.md`
- Constraints:
  - Gameplay remains offline and single-player.
  - Gameplay logic remains shared across iPhone and Android.
  - Ads must not interrupt active play and must stay in dedicated layout slots.
- Conflicts or gaps:
  - No approved profile packs are configured; stack guidance remains explicit in repo rules.
- Escalation:
  - Add privacy/support URLs and inject real signing credentials before store submission.
