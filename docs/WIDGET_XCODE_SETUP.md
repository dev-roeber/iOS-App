# Widget Extension – Xcode Setup / Rebuild Notes

## Status
- Swift-Quelldateien: ✅ vorhanden in `wrapper/LH2GPXWidget/`
- Xcode-Target: ✅ bereits im Projekt vorhanden (`LH2GPXWidget`)
- CLI-Status: ✅ `xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj -scheme LH2GPXWrapper -destination 'generic/platform=iOS' build` baut die App inklusive eingebettetem Widget

## Rebuild-Hinweise

Diese Datei ist nur noch fuer den Fall relevant, dass das bestehende Widget-Target neu aufgebaut oder manuell repariert werden muss. Fuer den Normalfall gilt: das Target existiert bereits und wird ueber das App-Scheme mitgebaut.

## Signing-Hinweis
Für lokalen Simulator-Build: Signing kann auf "Automatically manage signing" bleiben (kein aktiver Developer Account nötig).
Für Device-Build: Provisioning Profile für die Widget Extension Bundle ID erforderlich (Developer Account).

## Verifikation
```bash
xcodebuild -project wrapper/LH2GPXWrapper.xcodeproj \
  -scheme LH2GPXWrapper \
  -destination 'generic/platform=iOS' \
  build
```
