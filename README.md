# Black Hole Pomodoro

A macOS 14+ menu bar Pomodoro timer visualized as a growing black hole on your
desktop. In live mode, ScreenCaptureKit and Metal distort the actual desktop
content around the black hole. Visual-only mode works without screen-recording
permission.

[中文说明](README.zh-CN.md)

## Features

- Custom focus, short-break, and long-break durations and round count
- Start, pause, resume, skip, and reset controls from the menu bar
- A draggable transparent black-hole window that ignores mouse input while active
- A 30 FPS Metal-rendered black hole with an accretion disk, gravitational lensing,
  particles, and collapse animation
- Real-time desktop distortion powered by ScreenCaptureKit, with automatic fallback
  to visual-only mode
- Multi-display support, persistent state, and completion notifications

## Build

Build and run the tests:

```sh
swift test
```

Build an ad-hoc signed application that can be launched directly:

```sh
./scripts/build-app.sh
open .build/BlackHolePomodoro.app
```

After enabling live desktop distortion for the first time, grant Black Hole
Pomodoro access under **System Settings → Privacy & Security → Screen & System
Audio Recording**, then restart the application.

For public distribution, replace the ad-hoc signature with an Apple Developer ID
signature.

## License

This project is available under the [MIT License](LICENSE).
