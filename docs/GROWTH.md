# ShiftBlast — Growth (getting users)

**The bottleneck is users, not revenue-per-user.** With a handful of users —
mostly acquaintances — ad income will always be a few cents, because ads only
pay at thousands-of-users scale. So this is a user-acquisition plan, and it's
built around what the app *actually is*.

## Know your real audience

ShiftBlast looks like a casual block puzzle, but its one differentiated,
pay-worthy feature is the **Claude Code agent alert**: it pings you the moment
your AI agent finishes. That means the audience is **developers who use Claude
Code**, not generic mobile-game players.

This single fact rewrites the growth plan: **do not chase casual-game App Store
keywords.** Go where Claude Code users already are, and let the plugin do the
acquiring.

## The plugin is the funnel (highest-leverage lever)

Every developer who installs the `shiftblast-alert` plugin is a *qualified*
lead: they have the exact pain point and they've already opted in. Make that
path frictionless and discoverable:

1. **One-command public install** (done in this repo): anyone can run
   ```text
   /plugin marketplace add davidecapurr/giochino
   /plugin install shiftblast-alert@shiftblast
   ```
   because there's now a `.claude-plugin/marketplace.json` at the repo root.
2. **Get listed where developers look for plugins:**
   - Open a PR to the **`hesreallyhim/awesome-claude-code`** list (and similar
     "awesome-claude-code" / plugin-directory repos).
   - Submit to any community Claude Code plugin directories.
3. **Make the GitHub repo convert:** the README now leads with the hook and the
   install command, so repo visitors become users.

## Where to post (pick 1–2, do them weekly)

These reach Claude Code / AI-dev users directly — far better fit than casual
gaming channels:

- **r/ClaudeAI** and **r/ClaudeCode** — a short clip + honest "I built this"
  post. (Read each sub's self-promo rules.)
- **Anthropic / Claude Developers Discord** — #show-and-tell / #plugins.
- **X/Twitter** — the AI-coding crowd. A 15-second screen recording: agent
  finishes → phone game pauses → "back to work." That demo *is* the pitch.
- **Show HN** — "Show HN: A puzzle game that pings you when Claude Code is done."
- **Dev newsletters / link roundups** (TLDR, Console.dev, etc.) — submit it.

The demo video is the single best asset: it explains the product in one loop.
Record it once, reuse it everywhere above.

## Monetize the audience you have (since it's small)

With a small, technical audience, the money is in **direct purchases**, not ads:
- Developers convert better on a **one-time purchase** than a subscription, and
  friends who want to support you prefer paying once. Consider a one-time
  "lifetime Premium" alongside the monthly. (~10 buyers × €9.99 ≈ €100.)
- Keep ads on for free players (free upside), but treat **Premium** — the agent
  alert — as the real product, and sell *that* on the paywall and landing page.

## Secondary: App Store presence

Still worth doing, but secondary for this audience:
- Title/subtitle should mention the hook (e.g. "AI agent alerts"), not just
  "block puzzle," so the few people who search find the actual differentiator.
- First two screenshots: show the **"Agent ready — back to work"** pause. That's
  what makes a developer stop scrolling.

## Honest expectations

The plugin funnel + a reusable demo clip + a couple of community posts is the
realistic path from "friends only" to a real user base. Budget ~2–3 hours/week
of posting; for a solo dev it's the highest-ROI unpaid work available.
