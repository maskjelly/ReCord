# ReCord — Product Description

## Hero Section

**Headline:** ReCord — Screen Recording with Auto-Zoom Intelligence

**Tagline:** Capture your screen. Follow the story. Export like a pro.

**Sub-headline:** Native macOS screen recorder that automatically zooms and follows your cursor, then exports smooth cinematic footage — no manual editing required.

**CTA Primary:** Download for macOS (Free)
**CTA Secondary:** Watch Demo

---

## Problem

Most screen recordings are static, boring, and hard to follow. When you need to show someone a feature, a bug, or a workflow, the viewer has to hunt for the cursor on a full-screen canvas. Post-production zooms are tedious — keyframe by keyframe, zoom in, zoom out, pan across. Hours of manual work for a 2-minute clip.

**The pain:**
- Static screen captures lose the viewer's attention
- Manual zoom editing in Premiere/Final Cut is slow and repetitive
- Cursor tracking in post requires frame-by-frame work
- Resulting videos feel amateur without smooth camera movement

---

## Solution

ReCord is a native macOS screen recorder that handles the camera work for you.

1. **Record** your screen with one click
2. **ReCord automatically tracks** your mouse and generates cinematic zoom keyframes from clicks
3. **Export** a smooth, professional MP4 with gradient zooms and follow-cursor camera movement

No timeline editing. No keyframe animation. Just record, review, export.

---

## Key Features

### Auto-Zoom on Clicks
ReCord detects every mouse click during recording and automatically drops a zoom keyframe at that moment. The camera smoothly ramps into a zoom, holds for context, then gracefully ramps back out. Never miss the action.

### Cursor-Following Camera
During active zooms, the viewport gently follows your cursor with configurable smoothness. No more static frames — the camera drifts with your mouse like a trained operator.

### Drag Detection
ReCord knows the difference between a click and a drag. When you're dragging a window or selecting text, zoom stays disabled so the footage stays clean and readable.

### Manual Zoom Markers
Drop custom zoom markers during recording with `Cmd+Shift+Z`. Focus on any part of the screen, anytime.

### Native macOS Integration
- ScreenCaptureKit for pixel-perfect capture
- Global cursor tracking via CGEventTap
- System audio + microphone recording
- 60fps export in 1080p

### Smoothness Controls
Every zoom and camera movement is fully configurable:
- **Zoom Duration** — how long zooms ramp in and out
- **Zoom Smoothing** — blends overlapping zoom transitions so they never snap
- **Camera Follow** — how gently the camera lags behind the cursor (prevents violent shaking)

### One-Click Export
Choose your smoothness settings, hit Export MP4, and get a cinematic H.264 file in seconds. No external editors needed.

---

## How It Works

### 1. Record
Open ReCord, pick your screen or window, and hit Record. The app hides the native cursor from the capture and tracks it independently for perfect compositing later.

### 2. Review
Your recording appears instantly in the editor. Drag zoom keyframes on the timeline. Add manual markers. Watch the live preview with viewport overlay so you know exactly what gets exported.

### 3. Export
Hit Export. ReCord post-processes every frame with Core Image — crops to the animated viewport, scales to 1080p, composites the system cursor, and writes a clean MP4 with system audio.

---

## Use Cases

- **Product demos** — Show features with automatic emphasis on every click
- **Tutorial creators** — Let the camera do the zooming so you focus on teaching
- **Bug reports** — Record once, export a clear follow-along video
- **Design walkthroughs** — Cursor-led storytelling without editing
- **Meeting recordings** — Automatic zoom focus on what's being discussed

---

## Technical Specs

- **Platform:** macOS 13+ (Ventura and later)
- **Capture:** ScreenCaptureKit, 60fps
- **Audio:** System audio + separate microphone track
- **Export:** 1920×1080 H.264 MP4 at 60fps
- **Cursor:** Native NSCursor compositing, not a custom sprite
- **Privacy:** All processing happens locally. No cloud. No upload.
- **License:** Free tier with watermark. Pro tier removes watermark.

---

## Why ReCord vs. Other Tools

| Feature | ReCord | OBS | Screen Studio | Premiere |
|---------|--------|-----|---------------|----------|
| Native macOS | Yes | No | Yes | No |
| Auto-zoom from clicks | Yes | No | Manual | Manual |
| Post-process export | Yes | No | Yes | N/A |
| Cursor follow camera | Yes | No | Partial | Manual |
| Drag detection | Yes | No | No | Manual |
| No timeline editing needed | Yes | Yes | No | No |
| Free tier | Yes | Yes | No | No |

---

## Design Direction for Landing Page

**Mood:** Dark, industrial, premium. Think Figma meets DaVinci Resolve.

**Palette:**
- Background: `#0B0B0C` (deep black)
- Surfaces: `#141414`, `#1C1C1E` (dark gray layers)
- Text: `#F3F0EE` (warm cream) and `#8E8E93` (muted gray)
- Accent: `#CF4500` (signal orange) for CTAs, dots, and recording indicators
- Success: `#30D158` for checkmarks and "exported" states

**Typography:**
- System rounded sans (SF Rounded / Inter) with tight tracking on headlines
- Headlines: weight 600, -2% letter-spacing
- Body: weight 400, comfortable line-height
- Eyebrow labels: uppercase, 10px, muted gray, with an orange dot prefix

**Visual Language:**
- Pill-shaped buttons (20px+ radius) or full capsules
- Cards with 16px radius on dark elevated surfaces
- No gradients. Solid colors with subtle shadows (`rgba(0,0,0,0.3)` soft lift)
- Circular indicators and dot accents
- Screenshots should show the dark UI with cream text on black

**Layout Notes:**
- Hero should feel like a video editor darkroom
- Feature sections should alternate between screenshot panels and text
- "How It Works" should be a 3-step horizontal flow with minimal icons
- Demo video embed is critical — show before/after (static vs. auto-zoom)
- Footer should be warm dark (`#141414`) with clean link columns

**Assets Needed:**
1. Hero screenshot of the dark editor with a recording loaded
2. Before/After comparison: static screen recording vs. ReCord auto-zoom export
3. 3-step diagram: Record → Review → Export
4. Feature screenshot: timeline with orange diamond markers
5. Settings screenshot: smoothness sliders in dark mode
6. App icon on dark background (large, centered)

---

## Headline Options for A/B Testing

1. **"Screen Recording That Follows the Story"**
2. **"The Screen Recorder with a Camera Operator Built In"**
3. **"Record Once. Zoom Automatically. Export Like a Pro."**
4. **"Auto-Zoom Screen Recording for macOS"**
5. **"Your Cursor Deserves a Cinematographer"**

---

## Pricing (for landing page)

**Free**
- Unlimited recordings
- Auto-zoom on clicks
- 1080p export
- Watermarked output

**Pro — One-time purchase**
- Watermark-free exports
- Priority support
- Future updates included

---

## Trust Signals

- Native macOS app — not Electron, not a web wrapper
- Offline-only processing — your screen never leaves your machine
- Used by product teams, tutorial creators, and design studios
- Built with ScreenCaptureKit and Core Image for maximum quality

---

## FAQ Snippets (for landing page sections)

**Q: Does it work with multiple monitors?**
A: Yes. Pick any screen or window before recording.

**Q: Can I hide the watermark in the free version?**
A: Upgrade to Pro for watermark-free exports.

**Q: What formats does it export?**
A: MP4 (H.264) at 1920×1080, 60fps.

**Q: Does it record audio?**
A: Yes — system audio and microphone to separate tracks.

**Q: Is there a Windows version?**
A: Not yet. ReCord is macOS-only for now.

---

## Meta / SEO

**Title:** ReCord — Auto-Zoom Screen Recorder for macOS
**Description:** Native macOS screen recorder that automatically follows your cursor and creates smooth cinematic zooms. No editing required. Free download.
**Keywords:** screen recorder mac, auto zoom screen recording, cursor follow recording, screen capture macOS, tutorial recording tool, product demo recorder
