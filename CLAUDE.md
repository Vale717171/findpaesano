# FlagPost — Project Context for Claude

## What is this app
Mobile app for travelers to find compatriots nearby, share local tips and info.
Works also within the same country (e.g. Italians in Alto Adige).
Stack: Flutter + Firebase (Firestore, Auth) + OpenStreetMap + AdMob
Target: Android (primary), iOS (future)

## Developer profile
- No prior coding experience
- Explain every code block step by step
- Proceed in small verifiable steps

## Current status
- ✅ Fase 0 — Dev environment
- ✅ Fase 1 — App skeleton
- ✅ Fase 2 — Firebase + Auth + Onboarding + Settings
- ✅ Fase 3 — Board (5 category channels, report, block user)
- ✅ Fase 4 — Radar (map, GPS, fuzzy position, radius)
- ✅ Fase 5 — Chat 1:1 (signal, accept/decline, messages)
- ⏳ Fase 6 — Polish + publish (in progress)

## Fase 6 completed
- ✅ Bundle ID → app.findpaesano
- ✅ App name → FlagPost
- ✅ App icon (custom logo)
- ✅ Dark/light theme
- ✅ Buy me a coffee → buymeacoffee.com/vale71
- ✅ AdMob banner (test mode, real ID ready)

## Fase 6 remaining
- ⏳ Google Play Store submission
- 🔒 Replace AdMob test ID with real ID before publish
- 🔒 Unblock users from Settings
- 🔒 Multilanguage (l10n) — future
- 🔒 Full-text search on Board (Algolia) — future
- 🔒 Photo attachments (Firebase Storage/Blaze) — future
- 🔒 Tablet layout optimization — future
- 🔒 Clean up SSD — future

## AdMob IDs
- App ID: ca-app-pub-7139282315739803~3803375258
- Banner Ad Unit ID (real): ca-app-pub-7139282315739803/8930611253
- Banner Ad Unit ID (test): ca-app-pub-3940256099942544/6300978111

## File structure
lib/
  main.dart — app entry, routing, MainScreen, AdBanner
  ad_banner.dart — AdMob banner widget
  onboarding_screen.dart — 3-step onboarding
  board_screen.dart — board with 5 category channels
  settings_screen.dart — settings with delete account, theme, buy me a coffee
  radar_screen.dart — map with nearby compatriots
  chat_screen.dart — chat 1:1 with signal system

## Firestore collections
- users/{uid} — nickname, countryCode, countryFlag, travelStatus, destination, location, locationUpdatedAt
- messages/{id} — text, category, authorUid, authorNickname, authorFlag, createdAt
- reports/{id} — messageId, reportedBy, createdAt
- users/{uid}/blockedUsers/{blockedUid} — blockedAt
- chatRequests/{id} — fromUid, fromNickname, fromFlag, toUid, toNickname, toFlag, status, createdAt
- chats/{id} — participants, participantFlags, participantNicknames, lastMessage, lastMessageAt
- chats/{id}/messages/{id} — text, senderUid, createdAt

## Keystore (IMPORTANTE — non perdere mai)
- File: ~/Library/Mobile Documents/com~apple~CloudDocs/upload-keystore.jks
- Password: FlagPost2026!
- Key alias: upload
- Backup: iCloud Drive
- Senza questo file non puoi aggiornare l'app su Play Store
