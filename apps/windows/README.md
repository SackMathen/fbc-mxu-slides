# MxU Slides for Windows

The Windows build of MxU Slides. It reuses the platform-neutral Swift packages
under `apps/mac/Packages` (the document model, library, show state, scene
builder and Local API) and adds a host that serves the app's user interface and
renders the output.

## What it is today

- `MxUSlidesHost` (`mxu-slides.exe`): opens the library, runs the show state,
  serves the Local API on port 6980 (the same REST/WebSocket contract as the
  Mac, so remotes and control surfaces work), serves the UI on
  `http://127.0.0.1:6981/` and shows it in the app's own window.
- `CWebView2Host`: that window. A Win32 window with a WebView2 control (the
  Edge engine that ships with Windows 11), dark title bar, per-monitor DPI.
  It runs on its own thread; the main thread keeps serving.
- `web/`: the user interface, built from the Mac app's SwiftUI views and design
  system: the Service Flow and Libraries sidebar, the Present view with the
  continuous service grid, the Output Preview, and the Service Controls rail.
- `web/renderer.js`: draws the scene model (text, shapes, fills, stills) on a
  canvas, both for thumbnails and for the output window.
- `--demo` seeds an empty library with a starter theme, its overlays, the
  welcome deck, four public-domain hymns and a service.

Presenting works: pick a service, click a slide or use the arrow keys, open the
output window from Service Controls › Outputs and drag it to the projector.
Overlays and ad-hoc alerts fire.

Not on Windows yet (the Mac engines they need are Metal/AVFoundation-only):
the editor, media and audio playback, timers, the scheduler, outputs beyond the
browser window (NDI, DeckLink, screen roles), streaming and recording, MIDI,
and ProPresenter/PowerPoint import from the UI.

## Build and run

Prerequisites (all through winget): Visual Studio 2022 Build Tools with the C++
workload, the Swift 6.4 toolchain, Rust, and Node 24. `scripts/windows/dev-env.ps1`
lists the exact commands.

```powershell
. .\scripts\windows\dev-env.ps1             # Visual Studio + Swift environment
.\scripts\windows\build-automerge-ffi.ps1   # once: the Automerge native library
.\scripts\windows\fetch-webview2.ps1        # once: the WebView2 SDK into apps/windows/Vendor
.\scripts\windows\run-app.ps1 --demo        # build and run
```

`run-app.ps1` runs the one-time steps itself when their output is missing, and
passes its arguments to `mxu-slides.exe`:

```
mxu-slides [--library <path>] [--web <path>] [--port 6981] [--api-port 6980]
           [--no-api] [--browser] [--no-browser] [--demo] [--verbose]
```

The library lives in `%LOCALAPPDATA%\MxU Slides\Library` unless `--library`
says otherwise. The UI opens in the app's own window; closing it quits.
`--browser` opens Microsoft Edge in app mode instead (also the fallback when
the WebView2 runtime is missing), and `--no-browser` only serves, for you to
open the URL yourself.

The debug build finds the Swift runtime DLLs through `dev-env.ps1`; a
shipping build will carry them next to the executable.

Tests:

```powershell
cd apps\windows
swift test
```

## Layout

```
apps/windows/
  Package.swift              the host package (depends on ../mac/Packages/*)
  Sources/CWebView2Host/     the native window (C++: Win32 + WebView2)
  Sources/WindowsHost/       HostModel (show state + library), HostAPIBridge (Local API),
                             UIServer (the UI's routes), SceneJSON, DemoLibrary,
                             NativeWindow (Swift side of the window), BrowserLauncher
  Sources/MxUSlidesHost/     main.swift (the executable)
  Tests/WindowsHostTests/
  Vendor/WebView2/           the WebView2 SDK (fetched, not checked in)
  web/                       index.html, app.css, app.js, renderer.js, output.html
```

## How the Mac code maps to Windows

| Mac | Windows |
| --- | --- |
| `AppModel` + `ServiceControls` | `HostModel` (the presenting subset) |
| `AppAPIBridge` | `HostAPIBridge` |
| `AppShell`, `LibraryView`, `PresentGridView`, `LivePanel`, `ServiceControlsPanel` | `web/app.js` + `web/app.css` |
| `MetalSceneView` / `Compositor` | `web/renderer.js` (canvas) |
| `RenderContext` outputs | the `/output` window |
| `NSWindow` (SwiftUI `WindowGroup`) | `CWebView2Host` + `NativeWindow` |

The shared packages are unchanged in behaviour; the platform differences sit
behind `#if canImport(...)` and the `PortableSupport` package.
