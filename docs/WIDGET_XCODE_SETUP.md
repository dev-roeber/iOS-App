# Widget Extension – Xcode Target Setup

## Status
- Swift-Quelldateien: ✅ vorhanden in `wrapper/LH2GPXWidget/`
- Xcode-Target: ⏳ manuell einzurichten (einmalig, kein Developer-Account nötig für lokalen Build)

## Schritte

1. Öffne `wrapper/LH2GPXWrapper.xcodeproj` in Xcode
2. File → New → Target → Widget Extension
3. Name: `LH2GPXWidget`
4. Bundle ID: `de.roeber.LH2GPXWrapper.Widget`
5. "Include Live Activity": ✅ aktivieren
6. "Include Configuration App Intent": ❌ deaktivieren
7. Xcode fragt "Activate scheme?" → "Activate"
8. Im neuen Target unter "Build Phases → Compile Sources":
   - Füge NICHT die von Xcode generierten Stub-Dateien hinzu
   - Lösche Xcode-generierte .swift-Dateien im Target-Ordner
   - Füge stattdessen hinzu: `wrapper/LH2GPXWidget/TrackingLiveActivityWidget.swift` + `LH2GPXWidgetBundle.swift`
9. Unter "General → Frameworks and Libraries":
   - Füge `LocationHistoryConsumerAppSupport` hinzu
10. Embedding im App-Target (LH2GPXWrapper):
    - General → Frameworks, Libraries, and Embedded Content
    - "LH2GPXWidget.appex" → "Embed Without Signing" (für Debug/lokale Tests)
11. Widget Extension Deployment Target: iOS 16.2+
12. Build → ⌘B

## Signing-Hinweis
Für lokalen Simulator-Build: Signing kann auf "Automatically manage signing" bleiben (kein aktiver Developer Account nötig).
Für Device-Build: Provisioning Profile für die Widget Extension Bundle ID erforderlich (Developer Account).

## Verifikation
```bash
xcodebuild -scheme LH2GPXWidget -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | tail -5
```
