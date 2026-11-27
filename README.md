# Skyshoot — Native Godot edition

Skyshoot is a native 2D Android jetpack tag-arena game built with Godot 4 and GDScript.

## Current features
- Code-drawn industrial 2D arena with platforms
- Opening screen and solo practice match
- Four AI runners that pursue and jump toward the player
- Jetpack movement and proximity-based tag scoring
- Five-tag match limit, respawning and score tracking
- Touch HUD plus keyboard/mouse controls
- No weapons, projectiles, shooting or damage mechanics

## Android APK
GitHub Actions workflow: `.github/workflows/android-apk.yml`

Every relevant push to `main` and manual workflow dispatch builds a debug APK. Open the repository's **Actions** tab and download the **Skyshoot-Android-APK** artifact from a successful run.

The workflow produces an installable debug APK, not a Play Store-signed release. Online multiplayer, matchmaking, sound, polished sprite animation and device testing remain future work.
