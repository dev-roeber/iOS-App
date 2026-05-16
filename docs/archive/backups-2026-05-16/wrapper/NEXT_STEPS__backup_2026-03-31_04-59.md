# NEXT_STEPS

Abgeleitet aus der ROADMAP. Nur die aktuell offenen, fachlich sinnvoll priorisierten Folgepakete.
Der Audit-/Doku-Sync aus Phase 19.50 ist in diesem Batch geschlossen und steht deshalb nicht mehr als offener Punkt hier.

## 1. Phase 19.51 – Heatmap testen und auf Apple verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- `AppHeatmapView` ist implementiert und als eigenes Heatmap-Sheet verdrahtet
- Heatmap ist jetzt in README, ROADMAP und Feature-Inventar repo-wahr dokumentiert
- kleine dedizierte Heatmap-Regressionstests liegen im Core-Repo vor
- echter iPhone-15-Pro-Max-AX-Snapshot aus dem Wrapper zeigt `Heatmap` bei geladenem Import sichtbar im Uebersichtsbildschirm

Fehlt noch:
- echtes Oeffnen des Heatmap-Sheets auf Apple-Hardware
- visuelle Apple-Verifikation auf echter Apple-Hardware
- Performance-Nachweis fuer groessere Imports auf Apple-Hardware

## 2. Phase 19.52 – Apple-CLI-Stand stabil halten

Status: **teilweise umgesetzt**

Erledigt:
- macOS-Build-Fehler behoben (Core-Compile-Fehler, Wrapper-SPM-Pfad)
- `swift test` im Core-Repo laeuft auf diesem Linux-Server durch: 217 Tests, 2 Skips, 0 Failures
- Apple-only Heatmap-Renderingstests sind fuer non-Apple-Plattformen korrekt gegated
- `xcodebuild build -scheme LH2GPXWrapper -destination generic/platform=iOS`: BUILD SUCCEEDED
- `xcodebuild test -scheme LH2GPXWrapper -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max,OS=latest' -only-testing:LH2GPXWrapperTests`: TEST SUCCEEDED
- die 3 audit-relevanten Problemfaelle sind als Test-Drift klassifiziert und im Core-Repo behoben
- die 2 zusaetzlichen Apple-Test-Widersprueche (`AppPreferencesTests...`, `DayDetailPresentationTests...`) sind in Apple Stabilization Batch 2 repo-wahr geklaert
- der letzte dokumentierte Apple-CLI-/Device-Stand vom 2026-03-30 bleibt im Repo erhalten

Fehlt noch:
- frischer `xcodebuild`-Gegenlauf fuer genau diesen konsolidierten Wrapper-Stand; auf diesem Server derzeit nicht moeglich

## 3. Phase 19.53 – Background-Recording auf echtem iPhone verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- Background-Recording-Codepfad
- `Always Allow`-Upgrade im Live-Location-Modell
- Wrapper-Deklarationen fuer `NSLocationAlwaysAndWhenInUseUsageDescription` und `UIBackgroundModes=location`
- echter iPhone-15-Pro-Max-Lauf bestaetigt stabilen Wrapper-Launch; der eigentliche Recording-/Background-Pfad wurde dabei noch nicht bedient

Fehlt noch:
- echte Device-Verifikation fuer Permission-Upgrade, laufende Aufnahme im Hintergrund und Stop-/Persistenzverhalten
- separater dokumentierter Nachweis im Apple-/Wrapper-Runbook

## 4. Phase 19.54 – Wrapper-Auto-Restore auf echtem iPhone erneut verifizieren

Status: **teilweise umgesetzt**

Bereits drin:
- Core-App-Shell haelt Auto-Restore bewusst geparkt
- Wrapper ruft `restoreBookmarkedFile()` beim Start wieder auf
- README und Runbooks beschreiben den Status jetzt repo-wahr
- echter iPhone-15-Pro-Max-Lauf zeigte beim App-Start bereits wiederhergestellte Quelle `Imported file: location-history.zip`

Fehlt noch:
- kontrollierte Device-Verifikation fuer den seit 2026-03-20 wieder aktiven Restore-Pfad
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
- Apple-Review-/Privacy-Einordnung fuer den optionalen Upload-Pfad ueber die jetzt korrigierten lokalen Texte hinaus
- Entscheidung, ob Privacy-Dokumentation ueber den aktuellen Manifest-/Runbook-Stand hinaus erweitert werden muss

## 6. Phase 19.56 – Erst danach weitere Feature-Arbeit

Status: **bewusst nachgelagert**

Kommt erst nach den Verifikations- und Wahrheitsthemen oben:
- weitere Exportformate wie `CSV` oder `KMZ`
- mehr Insight-Module und Zeitraumsauswahl
- breitere Lokalisierungsabdeckung

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.
