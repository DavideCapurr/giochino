# Shift Blast — Growth (getting users for free)

Revenue = **users × revenue per user**. The monetization work (see
`MONETIZATION.md`) raised revenue per user. But with very few users and no
marketing spend, that isn't enough on its own — this is the plan to grow users
**without a budget**.

## Built into the app (this branch)

These are organic, zero-cost acquisition loops added in code:

### 1. Share your score (word of mouth)
Every game-over screen now has a **Share Score** button. It opens the system
share sheet with a brag message + a link to the game:

> "I just set my best score of 12,340 in Shift Blast! 🏆
> Think you can beat me? <link>"

Word of mouth is the #1 organic install driver for casual games. Each shared
score is a free ad sent by a player to friends who are likely to play too.

- `AppPromo.shareMessage(...)`, `ShareSheet`, wired into `GameOverView`.

### 2. Smart review prompt (App Store ranking)
After a player sets a **new best score** (a genuine high point) and has played a
few games, the app asks for a rating once per version. More & better ratings
directly lift App Store search/category ranking → more **free** installs.

- `ContentView.maybeRequestReview()` using `@Environment(\.requestReview)`.

### ⚠️ One-line config to make both stronger
Once the app is live, set the numeric App Store ID in
`AppPromo.appStoreID`. Shares and the review prompt will then deep-link
straight into the App Store instead of the landing page.

## Off-code, still free (do these — they move the needle most)

### App Store Optimization (ASO) — biggest free traffic source
Edit in App Store Connect (no code, ~1 hour, re-do every few weeks):
- **Title (30 chars):** include the genre, e.g. `Shift Blast: Block Puzzle`.
- **Subtitle (30 chars):** keyword-rich benefit, e.g. `Slide, merge & clear lines`.
- **Keywords (100 chars):** comma-separated, no spaces, no repeats of the title.
  e.g. `block,puzzle,slide,2048,merge,brain,blast,tiles,relax,offline,number,grid`.
- **Screenshots:** the first 2 are what convert. Show the board mid-combo + the
  score/leaderboard. Add a 3-word caption per shot.
- **Localize** title/keywords for it/es/de/fr/pt — each locale is a separate
  search index and most indie devs skip this.

### Free distribution channels (pick 1–2, do them weekly)
- **Short-form video:** screen-record satisfying combos/overdrives → post to
  TikTok / Instagram Reels / YouTube Shorts with the App Store link in bio.
  Satisfying puzzle clips travel far at zero cost.
- **Reddit:** r/iosgaming, r/incremental_games, r/puzzlevideogames — share a
  clip + honest "I made this" post. Read each sub's self-promo rules first.
- **Product Hunt / Hacker News "Show HN":** one-time launch spike + backlinks.
- **TestFlight + indie game Discords:** early players, feedback, first ratings.

### Retention = cheaper growth
Players who come back are more likely to share and to convert. The friend
leaderboards, record toasts, and the new "Continue" all push session length and
return rate. Watch crash-free rate and day-1 retention in App Store Connect.

## Honest expectations
- The in-app loops above only compound once there's a base of players to share
  and rate — so the off-code ASO + a steady posting habit are what break the
  cold-start. Budget ~2–3 hours/week of posting; it's the highest-ROI unpaid
  work available for a solo dev.
