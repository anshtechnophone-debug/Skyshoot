# Skyshoot — Cartoon Jetpack Tag Arena

Skyshoot is a colorful, cartoon-style 2D mobile arena game built with Godot 4 and GDScript.

## Current game direction
- Landscape 2D arena with a bright, playful cartoon look
- Three selectable world palettes: Sunny Isles, Candy Canyon, and Cloud Kingdom
- Four AI runners, jetpack movement, and proximity-based tag challenges
- Character color selection, score, match timer, and match results
- Touch controls for movement, jetpack, and tagging
- Keyboard controls for desktop testing
- Pause, resume, replay, and return-to-menu flow
- No weapons, projectiles, shooting, or damage mechanics

## Android APK
GitHub Actions workflow: `.github/workflows/android-apk.yml`

Pushes to `main` and manual workflow dispatch build a debug APK. Download the `Skyshoot-Android-APK` artifact from a successful run in the repository's **Actions** tab.

The workflow creates an installable debug APK, not a Play Store-signed release. The game still needs a successful CI export and real-device testing before it should be considered release-ready.
