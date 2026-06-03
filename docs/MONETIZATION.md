# Shift Blast — Monetization

The goal: turn the game from "a few cents" into real revenue.

## Why it was earning almost nothing

The app shipped with only **one** revenue source for free players: a single
**banner ad**. Banners have a very low eCPM (≈ €0.10–0.50 per 1,000
impressions), so even thousands of sessions add up to pocket change. The only
other option was a **€2.99/month subscription** — a hard sell for a casual
puzzle game, since most players will never commit to a recurring charge.

## What changed

Three higher-value levers were added. In rough order of revenue impact for a
casual game:

### 1. Rewarded "Continue" at game over (biggest lever)
When a run ends, free players can **watch a rewarded ad to continue** — the
board is cleared of breathing room and the pulse is refilled so they keep their
score. Rewarded ads have by far the highest eCPM (often €5–€30) *and* they
increase session length and retention, which lifts every other ad metric.
Allowed once per run to keep the game fair.

- Implemented in `FullScreenAdCoordinator.showRewardedContinue()`
- Board revive logic in `GameEngine.revive(in:)`
- Wired through `GameViewModel.revive()` and the `GameOverView` Continue button

### 2. Interstitial between games
Free players see an **interstitial every 3rd game over** (paced so it isn't
annoying). Standard, reliable fill for casual games.

- `FullScreenAdCoordinator.registerGameOverAndMaybeShowInterstitial(...)`

### 3. Lifetime Premium (best path for a small, technical audience)
A one-time **non-consumable** unlock (`com.shiftblast.premium.lifetime`,
suggested €9.99) that grants everything Premium does — the **AI agent alert**
and no ads — with a single payment. Developers and friends-supporting-you
convert far better on a lifetime unlock than on a recurring subscription, so for
a small audience this is the most realistic route to the first €100 (≈ 10 buyers).

- `SubscriptionStore.purchasePremiumLifetime()`; entitlement sets `isPremium`
- Surfaced prominently on the paywall, which now **leads with the agent-alert
  value** instead of "remove ads"

### 4. One-time "Remove Ads" purchase
A **non-consumable IAP** (`com.shiftblast.removeads`, suggested €3.99) sits next
to the subscription on the paywall. Many players who would never subscribe will
happily pay once to remove ads — this typically converts several times better
than a monthly sub. Buyers also get the "Continue" perk for free.

- `SubscriptionStore.removesAds` now gates ads (subscription **or** remove-ads)
- `isPremium` still gates the AI Agent perk (subscription only)

## ⚠️ Required before this earns money in production

These steps need AdMob / App Store Connect access (account
`ca-app-pub-2326857958249865`) and cannot be done from code:

1. **Create the ad units in AdMob** (same publisher account as the banner):
   - one **Rewarded** unit
   - one **Interstitial** unit
2. **Paste the unit IDs** into `FullScreenAdCoordinator.AdUnits`:
   - `productionRewarded`
   - `productionInterstitial`

   Until these are filled in, release builds simply **skip** the full-screen
   formats (policy-safe — test ads are never shipped). DEBUG builds always use
   Google's official test units, so you can verify the flows in the simulator.

3. **Create the IAPs in App Store Connect** (both **non-consumable**), then
   submit them for review with the build. They're already in
   `ShiftBlast.storekit` for local StoreKit testing:
   - `com.shiftblast.premium.lifetime` — Lifetime Premium, ~€9.99
   - `com.shiftblast.removeads` — Remove Ads, ~€3.99

## Testing locally

- Run a DEBUG build: test rewarded + interstitial ads appear automatically.
- Lose a game → tap **Continue** → test rewarded ad → run resumes with a cleared
  board. Lose again → no Continue (one per run).
- Restart 3 times → interstitial appears.
- Open the paywall → the "Remove Ads" one-time option appears under the
  subscription (StoreKit config drives the price in the simulator).
