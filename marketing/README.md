# ShiftBlast Promo Assets

This folder contains the first real-gameplay promo batch for ShiftBlast.

Positioning: **a simple second-screen puzzle to play instead of random scrolling
while the TV is on.**

## Recommended Videos: V2 Social Ads

These are the recommended TikTok / Reels / Shorts assets. They are shorter,
faster, tighter-cropped, and built around current social ad patterns: immediate
hook, native vertical format, clear visual message without sound, title card,
accelerated gameplay, and a short CTA.

Silent versions:

| File | Use | Hook |
| --- | --- | --- |
| `final-v2/shiftblast-pov-tv-stop-scroll-6s.mp4` | TikTok/Reels test | POV / relatable second-screen setup |
| `final-v2/shiftblast-stop-scroll-6s.mp4` | TikTok/Reels test | Pattern interrupt |
| `final-v2/shiftblast-wait-for-it-combo-6s.mp4` | TikTok/Reels test | Curiosity / payoff |
| `final-v2/shiftblast-one-more-run-4s.mp4` | Ultra-short feed test | Gameplay-first, no title card |

Synced audio versions:

| File | Use |
| --- | --- |
| `final-v2-audio-synced/shiftblast-pov-tv-stop-scroll-6s-synced.mp4` | TikTok/Reels with effects synced to title -> gameplay -> swipe -> payoff -> CTA |
| `final-v2-audio-synced/shiftblast-stop-scroll-6s-synced.mp4` | TikTok/Reels with effects synced to title -> gameplay -> swipe -> payoff -> CTA |
| `final-v2-audio-synced/shiftblast-wait-for-it-combo-6s-synced.mp4` | TikTok/Reels with effects synced to title -> gameplay -> swipe -> payoff -> CTA |
| `final-v2-audio-synced/shiftblast-one-more-run-4s-synced.mp4` | Ultra-short feed test with effects synced to gameplay motion and payoff |

Use the synced audio versions when uploading organically to TikTok/Reels. You
can still add a trending platform-native sound inside the app before posting,
but keep the synced effects low enough that the visual hits still feel tied to
the beat. Use the silent versions for paid tests if you want the ad platform or
editor to add music later.

The older `final-v2-audio/` folder is kept only as a reference; those first audio
passes used generic beat timing and should not be the default.

## Baseline Videos

All final videos are silent, vertical 9:16, 1080x1920, H.264 MP4.

These are slower baseline/demo cuts. Keep them as backup or App Store/website
material, but use V2 for social acquisition tests.

| File | Use | Notes |
| --- | --- | --- |
| `final/shiftblast-instead-of-scrolling-12s.mp4` | TikTok, Reels, Shorts, X | Main concept: "Instead of scrolling." |
| `final/shiftblast-while-show-is-on-12s.mp4` | TikTok, Reels, Shorts | Second-screen angle: "While the show is on." |
| `final/shiftblast-combo-overdrive-12s.mp4` | Gameplay-first ad test | Direct mechanics: "Swipe. Clear. Combo." |
| `final/shiftblast-appstore-preview-clean-15s.mp4` | App Store preview candidate / clean gameplay | No marketing overlay or end card; cropped to remove the simulator test ad. |

## Source Capture

- `raw/gameplay-session-01-full.mp4` is the original simulator screen recording.
- `raw/launch-screen.png` is the starting screenshot.
- The source capture used the already installed simulator build of
  `com.davide.shiftblast` on the booted iPhone 17 Pro simulator.
- Current source build was not used because `ShiftBlast/SettingsView.swift`
  contains existing Git conflict markers. App code was not modified.

## QA Frames

- `frames/final-contact-sheet.png` shows start/action frames from each final.
- `frames/v2-contact-sheet.png` shows pacing frames from the V2 social ads.
- `frames/audio-sync/` contains waveform previews for the synced audio renders.
- `frames/endcard-contact-sheet.png` verifies the end card frames.
- `frames/raw-action-timing.png` shows the raw timing used to choose the final
  trim.

## Reproducibility

- `scripts/make_overlays.swift` generates the PNG overlays and end card in
  `overlays/`.
- Final videos were rendered from the raw simulator capture with ffmpeg by:
  cropping to `1206x2144` from the top of the simulator recording, scaling to
  `1080x1920`, overlaying the PNG copy, and appending a 3-second end card for
  social variants.
- V2 videos use a tighter crop, faster playback, shorter title cards, and a
  shorter CTA to match TikTok/Reels pacing.

## Creative Principles Used

- TikTok-first vertical creative: 9:16, clear safe-zone text, fast hook.
- Sound-off clarity: the ad must work without audio.
- Short-form pacing: show the payoff in the first few seconds.
- Native-feeling hooks: POV, pattern interrupt, and "wait for it" curiosity.
- Creative testing: produce multiple small variants rather than one polished ad.

## Next Batch Ideas

- Record a fresher run without the iOS "Back to Settings" status-bar breadcrumb.
- Record a run from a clean state with no test ad if the source build is fixed
  or a release/TestFlight build is available.
- Test three hooks: "Instead of scrolling", "While the show is on", and
  "One more run".
