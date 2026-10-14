# CLAUDE.md

Coding rules, Swift/SwiftUI conventions and git workflow live in AGENTS.md — follow them:

@AGENTS.md

This file covers what AGENTS.md doesn't: how to build this fork, what it adds on top of upstream
[jsattler/BetterCapture](https://github.com/jsattler/BetterCapture), where that code lives, and what's next.

## What this fork is

Reco is a macOS menu bar screen recorder (ScreenCaptureKit + AVAssetWriter, not sandboxed since 2026-10-01, spec 0007), forked from BetterCapture
and renamed: its own bundle ID (`com.diip3sh.Reco`), `reco://` links, and Reco in every name.
This fork is working towards a free Screen Studio / CleanShot X alternative: record input telemetry
now, build an editor (auto-zoom, smooth cursor, backgrounds) on top of it later.

Architecture of the original app: `docs/architecture/OVERVIEW.md`, `docs/architecture/OUTPUT.md`,
`docs/concepts/VIDEO.md`, `docs/concepts/AUDIO.md`.

## Build, run, test

The project is signed with upstream's team (`DMX24B5FC3`), which you won't have. Build with your
own Apple Development certificate — don't commit signing changes:

```sh
# Find your team ID: the OU= field
security find-identity -v -p codesigning
security find-certificate -c "Apple Development" -p | openssl x509 -noout -subject

TEAM=<YOUR_TEAM_ID>
xcodebuild -scheme Reco -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/bc-build/dd \
  CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM=$TEAM \
  CODE_SIGN_STYLE=Manual PROVISIONING_PROFILE_SPECIFIER="" build -quiet \
  && { pkill -x Reco; open /tmp/bc-build/dd/Build/Products/Debug/Reco.app; }
```

- Tests: same command with `test` instead of `build -quiet` (Swift Testing, 969 tests at spec 0026). `ExportServiceTests.keepsATransparentBackgroundInProRes4444`
  reads alpha 254 instead of 255 with Xcode 26.0.1 on macOS 26.5.2, also without this fork's later changes.
- Lint: `swiftlint lint --quiet <files>` — new code must be clean. Pre-existing warnings:
  `AssetWriter.swift` (file_length, type_body_length, 2× function_body_length) and
  `RecorderViewModel.swift` (file_length, type_body_length). Don't make them worse; SwiftLint skips
  extensions for type_body_length, so new logic goes in same-file extensions or new types.
- Keep build output outside the repo (`/tmp/bc-build`). If the build fails with "There is no
  XCFramework found", `rm -rf /tmp/bc-build` and rebuild (moved DerivedData breaks SPM paths).
- **Don't use ad-hoc signing (`CODE_SIGN_IDENTITY="-"`)**: the code hash changes every build, so
  macOS forgets the Screen Recording permission and prompts forever. If a permission gets stuck:
  `tccutil reset ScreenCapture com.diip3sh.Reco`, then relaunch.
- New `.swift` files need no pbxproj edit (file-system synchronized groups).
- Don't add `.metal` files: Xcode 26 builds them only with the separately downloaded Metal Toolchain,
  which every builder and CI would need. Core Image kernels are `.metal.txt` resources compiled at run
  time (`FieldRenderer`).
- Don't call an ObjC API whose completion handler is `() -> Void` through Swift's async import
  (`await writer.finishWriting()`). `AVAssetExportSession.export(to:as:)` is back-deployed below
  macOS 26, so its body is compiled into the app with a same-named but incompatible thunk, and the
  linker may keep that copy: `AssetWriter` crashed on every stop. Use an explicit continuation, as
  `AVAssetWriter.finishWritingWithoutAsyncImport()` does.
- App target defaults to MainActor isolation (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`), Swift 6
  language mode. Types used off the main actor must be marked `nonisolated`: Swift 6 checks
  isolation at runtime too, so main-actor code called from a capture queue crashes instead of racing.
  ScreenCaptureKit isn't Sendable-annotated; files that pass its types across actors use
  `@preconcurrency import ScreenCaptureKit`.
- Test suites that touch main-actor app types (most models) are marked `@MainActor`.

## Release builds

**Rule:** every push to `main` that touches the app is built, tested and published to users as an
update by GitHub Actions. **Before pushing to `main`, read `docs/RELEASE.md` and follow its
checklist**; it also covers the workflow, versions, secrets and installing.

## Quality bar

We are building a small, fast, polished app. Every change is minimal, clean and production quality;
AGENTS.md's rules apply, and these add to them.

### Architecture

MVVM with `@Observable` (Apple's pattern, and upstream's), built as a **functional core with an
imperative shell**. No TCA, VIPER, Clean-Architecture layers or DI frameworks: they add a dependency
or indirection that doesn't pay for itself in an AVFoundation app.

| Layer | Holds | Rules |
|---|---|---|
| Core (`Model/`, pure helpers in `Service/`) | Value types and pure functions: time mapping, geometry, pauses, dedup, auto-zoom, smoothing, settings rules | `nonisolated`, `Sendable`, no side effects or singletons, fully unit tested. E.g. `RecordingPauses`, `CursorShapeTracker`, `InputTelemetry.videoPixel` |
| Shell (`Service/`) | One service per system boundary: ScreenCaptureKit, AVAssetWriter, event taps, files | Thin: gather input, call the core, apply the result. Explicit isolation: `@MainActor`, or `nonisolated` + a lock |
| `ViewModel/` | `@MainActor @Observable` state and intents | Calls services; no rules that belong in the core |
| `View/` | Layout | Reads view-model state, calls intents; no logic |

- Dependencies point down only: View → ViewModel → Service → Core. Services report up through
  delegates or `async` results, never by reaching into a view model.
- New features get a feature folder, `Reco/<Feature>/{Model,Render,Service,ViewModel,View}`
  (see spec 0003). Existing layer folders stay as they are.
- One rule, one place: logic lives in exactly one function that every caller reuses (e.g.
  `SettingsStore.capturesCursor` drives both the capture and the telemetry). Never re-derive it.
- Protocols only where a test needs a fake or there are two real conformers.

### Code

- The smallest change that fully solves the problem. Delete before adding; no speculative options,
  wrappers or "just in case" code.
- Match the surrounding code. Name things by meaning. Comments say *why*, and record measured facts
  with their numbers (like `shadowTopFraction`) so nobody re-derives them.
- Done means: zero compiler warnings, all tests pass, SwiftLint clean on touched files, new logic
  has tests, and docs (this file, `docs/FEATURES.md`, specs) match the code.

### Performance

The app records 4K60 in real time, and the editor must render a frame in under 8 ms.
- Hot paths (capture queue, compositor, per-frame and per-event code): no allocation that grows
  with recording length, no I/O or logging per sample, no main-actor hops, locks held only briefly.
- Precompute once, look up per frame (binary search, O(1) sampled tracks); build images once, never
  per frame.
- Keep heavy work off the main actor (`@concurrent`) and high-frequency values out of observed state.
- Measure before and after optimising (`OSSignposter`, Instruments). A performance claim needs a number.
- Prefer Apple frameworks (AVFoundation, Core Image on Metal, Accelerate) over hand-rolled or
  third-party code.

## Features

What each feature does, its files and every measured fact are in **`docs/FEATURES.md`**, a section per feature;
the design is in its spec. Update that section with every change. Status of every item and what to build next:
`docs/FEATURES.md`, "Roadmap status".

| ID | Feature | Code | Spec |
|---|---|---|---|
| F1 | Input telemetry sidecar `<video>.telemetry.json` (format v3 in FEATURES.md) | `Model/InputTelemetry.swift`, `Service/InputTelemetryRecorder.swift` | |
| F2 | Cursor sprites; the cursor left out of the video for the editor to redraw | `Service/CursorShapeTracker.swift`, `StandardCursors.swift` | |
| F4 | Pause / resume | `Service/RecordingPauses.swift`, `AssetWriter` | |
| F5 | Countdown | `Service/RecordingCountdown.swift`, `View/Countdown*` | |
| C1 | Screenshots: area, window, screen | `Screenshot/` | |
| C2, C7, C8, C14 | Quick Access card, text recognition, pins, copy | `QuickAccess/` | |
| S1 | Editor: playback, render pipeline, trim and cut, auto-zoom, cursor, canvas, design | `Editor/` | 0003 |
| S2 | Web recordings | `WebRecording/` | 0005 |
| S3 | Agent bridge: MCP over a Unix socket | `AgentBridge/` | 0006 |
| S4 | Record with AI Agent bar; no App Sandbox | `AgentRecording/` | 0007 |
| S5 | Agent chat, reliable web takes | `AgentRecording/`, `WebRecording/` | 0008 |
| N | Cursor loop, hold and tilt, motion blur, GIF, cancel and restart, `export_recording`, typing, shown elements | | 0009 |
| S6 | Motion editor: `.motion` bundles, lifted UI, the grammar, agent tools | `Motion/` | 0011 |
| S7 | Motion quality: fields, satin, glass, typing, macro, whip, looks; `reco-launch-film` | `Motion/Render/`, `Motion/Grammar/` | 0012 |
| S8 | Motion sound | `Motion/Sound/` | 0013 |
| S9–S12 | Film kinds, a skill each: motion design, story, flow, editorial | `AgentRecording/Skills/` | 0014–0017 |
| S13–S20 | The director skill, brand taste, graphic seams, depth and pool, actions, transitions, the site's pictures, state moves, the site's kit | `AgentRecording/Skills/reco-director.md`, `Motion/` | 0018–0026 |

## Pitfalls already paid for

Platform:
- `Binding(_:)` unwrapping an optional traps if its view outlives the value (the zoom focus pad crashed): read the view
  model with a fallback.
- The system `.inspector` on macOS 26 crashed in a layout loop when toggled: the side panel is `EditorSidePanel`. As a
  window's own content, `NSHostingView` shrank the editor window to its minimum: host it a level down (`contained(_:)`).
- `ImageRenderer` can't draw glass, AppKit controls, `ScrollView`s or the player: check the look in the app.
- `AgentProcess` reads pipes with `read(2)`: `availableData` threw on a non-blocking pipe and crashed the app.
- A composition whose video track is only empty time has a duration of 0: motion drives its compositor with a 1-frame
  placeholder movie stretched by `scaleTimeRange`. A track holds its asset weakly: an `AVURLAsset` released before
  insertion fails with -12780. `AVComposition` isn't Sendable.
- H.264 at 4K stops at 30 fps: 4K60 is HEVC. ImageIO keeps every GIF frame until it's finalized (3.1 GB for 750 frames),
  so `GIFWriter` encodes frames one at a time and splices them.
- `vDSP.DFT` is deprecated on macOS 26: use `vDSP.DiscreteFourierTransform`.

Core Image:
- The compositor's `CIContext` has color management off: frames stay in the source's encoding and overlays blend in it.
- `CIColorMatrix` works on unpremultiplied colour: scaling RGB and alpha both darkens by the share squared. Fade by
  alpha alone (`fading(to:)`).
- Kernels compiled together drew only the first sampling kernel: each is compiled alone (`#define <name>_ONLY`).
- Two images of one stitchable kernel moved differently in one frame drew streaks: pass the camera's move to the
  kernel as an argument, never as a transform on its output.
- `CIPerspectiveTransform` maps an image's extent out to whole pixels: lifts and images are drawn at whole pixels, and
  a revealed text keeps its whole extent.
- A 1-pixel ramp scaled 100,000× had its region of interest rounded to nothing: clamp it instead.
  `CIRoundedRectangleStrokeGenerator` draws its line inside the extent.

WebKit:
- A plain mouse move is hit-tested only in an active window: `sendPointer(.move)` sends a right-button drag. A page in an
  offscreen window is hidden unless the window reports itself visible (`OffscreenWebWindow`).
- Two 8× snapshots at once made WebKit's GPU process quit: one capture at a time (`UICapture.isCapturing`).
- App Transport Security blocks plain `http://` (localhost loads). `data:` pages can't link to each other: renderer
  tests serve pages with `RecoTests/LocalPages.swift`.

Agents and tests:
- The test host is Reco, so its bridge takes `agent.sock` from a running Reco: don't run tests during an agent run.
- Claude Code: `--tools` hides the Skill tool unless `Skill` is listed; `--setting-sources project` would drop the
  user's settings, so it isn't used.
- A missing golden frame fails its test and writes the frame to the temporary folder to review and copy in.
- ffmpeg reads AVFoundation's BT.709 HEVC 1.7–2.4 levels darker than AVFoundation does: compare pixels through
  AVFoundation.

## UI design

- Two visual families, one motion system: the system-native popover and Settings, and the studio look (editor,
  Recordings, Web Recording, the agent bar, the floating capture panels).
- System colors by role (`EditorTheme`), following the user's appearance; one accent (`EditorTheme.accent`, a warm orange)
  for the playhead and the selection. No gradients or glows in the chrome, no cards or badges where a native control
  works, no all-caps titles; hover is a fill step, only a press scales.
- Glass only on controls over the stage, never on the timeline or over live video (each glass shape costs a GPU pass the
  compositor shares), never glass on glass.
- Motion follows the apple-design skill and `EditorTheme`'s tokens: respond on press, move 1:1 from the grab point, springs
  from the current value, bounce only after a flick, enter and exit symmetric from the source; Reduce Motion cross-fades.

## Making a film from the app

- Start a run: `open -g -a /tmp/bc-build/dd/Build/Products/Debug/Reco.app "reco://record-agent?url=<enc>&prompt=<enc>&mode=launch"`
  (send it again if the app had only just launched). The agent writes `~/Movies/Reco/<name>.motion` and exports
  `<name>-edited.mp4` at 4K60; runs take 15–30 min. Keep test prompts neutral: never name a reference film or style.
- Re-export through the app: `Reco.app/Contents/MacOS/Reco --mcp` with `RECO_BRIDGE_TOKEN` from
  `defaults read com.diip3sh.Reco agentBridgeToken`, then `export_recording` until it's done.
- Stillness, as `preview_motion` measures it: the picture at 32 × 18 grey, 0.5 s apart; a mean change under 2 levels is still.

## Permission findings and the sandbox decision

**2026-10-01: the App Sandbox is removed** (spec 0007): agent command lines need the user's `PATH`,
logins and settings, and a sandboxed parent's children inherit the sandbox. Entitlements are only
`device.audio-input` and `device.camera`. Paths: `URL.userHome` (passwd, ignores `$HOME`),
`URL.recoSupport` (`~/Library/Application Support/com.diip3sh.Reco`: `WebScript.json`, `agent.sock`,
`AgentRun/`). `ContainerMigration` moves the old container's settings (agent token included) and
Application Support files over once. Test `UserDefaults` suites come from `TemporaryDefaults` (named by a temp path, so no plists
land in `~/Library/Preferences`). Unsandboxed, `startAccessingSecurityScopedResource()` returns false for a plain
`NSOpenPanel` URL, so never treat false as failure.

The findings below were measured while sandboxed; the TCC facts (Accessibility, Input Monitoring)
should hold but need re-measuring.


- `NSEvent.mouseLocation` polling works without any permission. Global mouse/scroll monitors need
  Accessibility (Apple DTS, developer.apple.com/forums/thread/811443): on macOS 26.3 two recordings
  made while clicking got no clicks or scrolls.
- Global `NSEvent` **key** monitors never fire in the sandbox (need Accessibility) — don't use them.
- Listen-only `CGEvent.tapCreate(.cgSessionEventTap, …, .listenOnly)` works once Input Monitoring is
  granted; no entitlement or Info.plist key needed. It records keys, clicks and scrolls.
- `NSCursor.currentSystem` works in the sandbox.

## Reference repos

Reference repos for later work: `syi0808/screenize` and `imbhargav5/open-recorder` are Apache-2.0
(portable with attribution). `lzhgus/Capso` (BSL, bans screen-capture use) and
`lihaoyun6/QuickRecorder` (AGPL) are **ideas only — never copy code**.

## Known open items

- Not yet verified on real recordings: area capture mapping, a window moved/resized mid-recording.
- `RecorderViewModel` is over SwiftLint's file length limit (pre-existing, 711 lines after cancel/restart); split it before adding more.

## Verifying against real recordings

Recordings can be scripted: select content once in the menu, then drive the running build with
`open -g -a /tmp/bc-build/dd/Build/Products/Debug/Reco.app "reco://toggle"` (starts
when content is selected, stops when recording; no countdown), `reco://pause` and
`reco://edit-last` (opens the editor); `open -a <app> <movie>` opens any recording in the editor. Use `-a` with the path:
a plain `open` may launch another copy (e.g. Xcode's DerivedData build). Play `afplay` ticks at
logged wall times, then check each tick lands where expected in the audio, shifted by the paused time.
Watch the app's logs with `/usr/bin/log stream --level info --predicate 'subsystem == "com.diip3sh.Reco"'`
(the full path matters: in zsh, `log` is a builtin).

Frame-level checks beat eyeballing. With `ffmpeg`/`ffprobe` (Homebrew):
- Stream lengths: `ffprobe -v error -show_entries stream=codec_type,duration,nb_frames -of compact <file>`
- Frame at a time: `ffmpeg -ss <t> -i <file> -frames:v 1 out.png`, crop around
  `InputTelemetry.videoPixel(...)` to check the cursor tip lands on the prediction.
