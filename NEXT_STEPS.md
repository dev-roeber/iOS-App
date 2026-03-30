# NEXT_STEPS

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Audit-/Doku-Sync aus Phase 19.50 ist in diesem Batch geschlossen und steht deshalb nicht mehr als offener Punkt hier.

## 1. Phase 19.51 – Heatmap testen und auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `AppHeatmapView` ist implementiert und als eigenes Heatmap-Sheet verdrahtet
- Heatmap ist jetzt in README, ROADMAP und Feature-Inventar repo-wahr dokumentiert

Fehlt noch:
- dedizierte Testabdeckung fuer Heatmap-Modell/Logik
- visuelle Apple-Verifikation auf echter Apple-Hardware
- Performance-Nachweis fuer groessere Imports auf Apple-Hardware

## 2. Phase 19.52 – Linux-Failures klassifizieren und auf Apple/macOS gegenpruefen

Status: **offen**

Bereits drin:
- frischer Linux-`swift test`-Lauf mit 217 ausgefuehrten Tests, 2 Skips und 14 Failures
- erste Klassifizierung in plattformbedingt vs. unklar ist vorbereitet

Fehlt noch:
- macOS-/Xcode-Gegenlauf fuer denselben Repo-Stand
- `LiveLocationFeatureModelTests.testAcceptedSamplesUploadToConfiguredServer` und `LiveLocationFeatureModelTests.testFailedUploadRetriesWhenAnotherAcceptedSampleArrives` gegen Apple/macOS abgleichen, bevor sie als rein plattformbedingt abgeschlossen werden
- den bekannten Problemfall `LiveLocationFeatureModelTests.testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` gezielt gegenpruefen und als plattformbedingt oder echter Bug klassifizieren
- verbleibende Linux-Failures sauber nach `plattformbedingt`, `unklar` oder `potenziell echter Bug` einordnen

## 3. Phase 19.53 – Background-Recording auf echtem iPhone verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- Background-Recording-Codepfad
- `Always Allow`-Upgrade im Live-Location-Modell
- Wrapper-Deklarationen fuer `NSLocationAlwaysAndWhenInUseUsageDescription` und `UIBackgroundModes=location`

Fehlt noch:
- echte Device-Verifikation fuer Permission-Upgrade, laufende Aufnahme im Hintergrund und Stop-/Persistenzverhalten
- separater dokumentierter Nachweis im Apple-/Wrapper-Runbook

## 4. Phase 19.54 – Wrapper-Auto-Restore auf echtem iPhone erneut verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- Core-App-Shell haelt Auto-Restore bewusst geparkt
- Wrapper ruft `restoreBookmarkedFile()` beim Start wieder auf
- README und Runbooks beschreiben den Status jetzt repo-wahr

Fehlt noch:
- frische Device-Verifikation fuer den seit 2026-03-20 wieder aktiven Restore-Pfad
- dokumentierter Nachweis fuer positiven Restore, Datei-fehlt-Fallback und Clear-nach-Restore

## 5. Phase 19.55 – Server-Upload / Review / Privacy finalisieren

Status: **teilweise umgesetzt**

Bereits drin:
- HTTPS-Endpunktvalidierung
- optionaler Bearer-Token
- Retry-on-next-sample
- Upload-Batching
- repo-wahre Review-/Runbook-Wording-Basis

Fehlt noch:
- End-to-End-Device-Verifikation mit echtem HTTPS-Endpunkt
- finale Review-/Privacy-Texte fuer den optionalen Upload-Pfad
- Entscheidung, ob Privacy-Dokumentation ueber den aktuellen Manifest-/Runbook-Stand hinaus erweitert werden muss

## 6. Phase 19.56 – Erst danach weitere Feature-Arbeit

Status: **bewusst nachgelagert**

Kommt erst nach den Verifikations- und Wahrheitsthemen oben:
- weitere Exportformate wie `CSV` oder `KMZ`
- mehr Insight-Module und Zeitraumsauswahl
- breitere Lokalisierungsabdeckung

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.
