# Xcode App Preparation

## Zweck

Diese Notiz beschreibt die kleinste aktuell sinnvolle Apple-/Xcode-nahe Vorbereitung in diesem Repo.
Sie fuehrt bewusst kein `.xcodeproj` und keine ungetesteten Produkt-App-Dateien ein.

## Aktueller Einstieg

Der vorgesehene Apple-/Xcode-nahe Einstieg ist weiterhin das Swift Package:

```bash
open Package.swift
```

Alternativ kann das Verzeichnis in Xcode geoeffnet werden. Die produktnahe App-Schicht liegt im Target `LocationHistoryConsumerApp`.

## Schichten

- `LocationHistoryConsumer`
  - Consumer-Core fuer Contract, Decoder und Query-Layer
- `LocationHistoryConsumerDemoSupport`
  - fixture-zentrierte Demo-Unterstuetzung
- `LocationHistoryConsumerDemo`
  - lokale Harness-/Verifikationsoberflaeche
- `LocationHistoryConsumerAppSupport`
  - produktnahe Session-, Import- und Inhaltsdarstellungs-Helfer
- `LocationHistoryConsumerApp`
  - kleiner produktnaher App-Einstieg fuer lokalen `app_export.json`-Import

## Was fuer Apple vorbereitet ist

- SwiftUI-basierte Demo- und App-Shell-Targets sind im Swift Package getrennt vorhanden.
- `LocationHistoryConsumerApp` ist import-first und als spaetere Apple-Produkt-App-Huelle positioniert.
- Gemeinsame app-nahe Session-/Import-Logik ist in `LocationHistoryConsumerAppSupport` gekapselt statt in Demo-Views.
- Das Repo bleibt offline-only und konsumiert ausschliesslich `app_export.json` nach dem eingefrorenen Consumer-Contract.

## Was bewusst noch nicht vorbereitet ist

- kein `.xcodeproj`
- kein signierter Apple-App-Build
- keine `Info.plist`-/Bundle-/Icon-/Entitlement-Ausarbeitung
- keine Persistenz, Maps, Suche oder Cloud-Funktionen
- kein Google-Rohdatenimport

## Lokale Verifikation

Unter Linux ist ehrlich verifiziert:

- `swift test`
- Linux-Build der SwiftPM-Targets
- Linux-Fallback-Mains der Apple-UI-nahen Executables

Unter Linux ist nicht verifiziert:

- echter Xcode-Run
- echter iOS-/macOS-SwiftUI-Lauf
- `fileImporter` auf Apple-Plattformen
- Signierung, Sandbox, Bundle-Metadaten

## Naechster Apple-Schritt

Wenn eine echte Apple-Validierung moeglich ist, sollte der naechste kleine Schritt nicht neue Features oeffnen, sondern:

1. `Package.swift` in Xcode oeffnen
2. `LocationHistoryConsumerApp` als Apple-App-Shell pruefen
3. minimale Apple-Bundle-Metadaten nur dann ergänzen, wenn sie fuer einen echten lokalen Run noetig sind
4. weiterhin keine Persistenz-, Maps- oder Sync-Ausweitung vorziehen
