# Skyshoot — Native Godot edition

Skyshoot is being rebuilt as a native 2D Android game using Godot 4 and GDScript. The Phaser/TypeScript prototype is retained in Git history, but the native Godot project is now the main game.

## Current prototype features
- Native Godot 4 project, no browser or WebView runtime
- Original code-drawn industrial 2D arena
- Opening screen and solo practice match
- Four AI opponents that pursue, jump and shoot
- Jetpack movement, platforms, projectiles, health, scoring and respawning
- Touch HUD plus keyboard/mouse controls

## Android APK
GitHub Actions workflow: `.github/workflows/android-apk.yml`

Every relevant push to `main` and manual workflow dispatch builds a debug APK. Open the repository's **Actions** tab and download the **Skyshoot-Android-APK** artifact from a successful run.

This repository build pipeline produces an installable debug APK; it does not yet produce a Play Store-signed release. Online multiplayer, matchmaking servers, sound, polished sprite animation and device testing remain future work.
