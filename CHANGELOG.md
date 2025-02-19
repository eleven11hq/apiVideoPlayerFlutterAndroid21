# Changelog
All changes to this project will be documented in this file.

## [1.1.0] - 2023-07-26
- Add support for private videos
- Add support for playback speed
- iOS: add support from iOS 11
- Web: close player events when player is disposed
- Web: remove CSS border on player
- Web: fix player sdk event on release and profile mode
- Web: fix `getVideoSize` API that caused a bad aspect ratio with border
- Android: fix the duration of the video when the video is not loaded
- Android: fix crash when the current time < 0
- Android: fix a crash due to obfuscation (see [#43](https://github.com/apivideo/api.video-flutter-player/issues/43))

## [1.0.0] - 2022-10-10
- First version
