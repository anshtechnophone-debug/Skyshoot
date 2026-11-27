# Skyshoot

An original 2D side-scrolling jetpack arena shooter. It takes inspiration from the broad genre of 2D arena shooters, not another game's code, maps, branding, or art.

## Current build
- Phaser 3 + TypeScript + Vite
- Original code-drawn industrial arena map
- Opening screen and Play Practice flow
- Player movement, gravity and jetpack thrust
- Three AI training opponents that pursue and fire at the player
- Health, damage, respawn and score
- Mouse/keyboard controls and on-screen touch buttons
- Capacitor Android wrapper and GitHub Actions debug APK workflow

## Run in browser
Requires Node.js 20+.

```bash
npm install
npm run dev
```

## Controls
- A / D or Left / Right: move
- W / Up / Space: jetpack
- Mouse: aim and click to fire
- Touch: use the on-screen movement, JET and FIRE buttons

## Android APK
The workflow at `.github/workflows/android-apk.yml` builds a debug APK on pushes to main (when game files change) or when manually started from GitHub Actions.

Open the repository's **Actions** tab, choose **Build Android APK**, run the workflow, then download the `skyshoot-debug-apk` artifact from the completed run.

This is an early practice prototype. Online multiplayer, matchmaking, polished original art, audio, and production hardening are future milestones.