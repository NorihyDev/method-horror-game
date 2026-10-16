# Economy

## Principles

- Coins are earned by playing and spent only on **cosmetics** (flashlight
  styles, profile badges). Nothing purchasable changes gameplay.
- **No real-money purchases, ads or loot boxes** in this release.
- Two wallets that never merge automatically:
  - **Local wallet** (offline, implemented): stored on the device, tamperable by
    design, used for solo play.
  - **Verified wallet** (online, planned M3/M4): server-side ledger; the only one
    that could ever back cross-device or competitive features.

## Reward table (per map, `resources/maps/*.tres`)

| Source | The Abandoned House |
|---|---|
| Escape | 100 |
| First escape from this location | 150 |
| Each optional objective completed | 25 |
| Each **new** METHOD file (first time found) | 10 |
| Difficulty multiplier on escape totals | Story ×0.75 · Normal ×1 · Hard ×1.5 · Nightmare ×2 |

Defeat pays only for newly found files (no multiplier).

### Balance assumptions

- A typical first Normal escape with 2 optional objectives and 3 new files:
  100 + 150 + 50 + 30 = **330 coins**; later Normal escapes ≈ 125–175.
- Catalog: 120–600 coins. The cheapest item is affordable after one escape; the
  most expensive (METHOD Field Unit, 600) takes ≈ 3–4 Normal escapes or ≈ 2 Hard.
- Collectibles pay once per file per profile so replaying cannot farm them.

## Transactions

`Wallet` (shared logic for the local wallet; mirrored server-side later):

- `apply_reward(reward_id, amount)` — refuses empty ids, negative amounts and
  any id already applied. Match rewards use `match:<match_id>`, so a repeated
  results screen or retry cannot pay twice (tested).
- `purchase(item_id, catalog)` — price comes from `CosmeticCatalog`, never the
  caller; insufficient funds changes nothing; owned items cannot be re-bought.
- Ledger keeps the last 200 entries; applied reward ids keep the last 500.

## What survives a reinstall

Nothing local. There is no account linking or cloud save in this version and
the UI says so (Profile → Identity). Online guest identities (M3) are also
device-bound until a later, documented account-linking milestone.

## Conflict handling (planned)

When online arrives, the verified wallet is authoritative and separate; the
local balance is shown separately and is never uploaded or merged.
