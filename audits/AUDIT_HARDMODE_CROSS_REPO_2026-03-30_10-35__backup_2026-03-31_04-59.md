# AUDIT_HARDMODE_CROSS_REPO

Datum: 2026-03-30 10:35 UTC
Repos:
- /home/sebastian/repos/LocationHistory2GPX-iOS
- /home/sebastian/repos/LH2GPXWrapper

Aktiv einbezogene Alt-Audit-Datei:
- `/home/sebastian/repos/LocationHistory2GPX-iOS/audits/AUDIT_LH2GPX_2026-03-30_09-11.md`

Backup in diesem Audit:
- `/home/sebastian/repos/LocationHistory2GPX-iOS/audits/AUDIT_LH2GPX_2026-03-30_09-11__backup_2026-03-30_10-35.md`

## 1) Executive Summary

Der Merge auf `main` hat die grobe Kaschierung aus dem Alt-Audit nicht fortgesetzt. Heatmap, `Live`-Tab, Upload-Batching, HTTPS-Endpunkt und Wrapper-Auto-Restore sind im Hauptstrang angekommen und in ROADMAP/NEXT_STEPS sichtbar. Der schlimmste Vorwurf aus dem Alt-Audit, naemlich dass `main` den echten Produktstand sprachlich kleiner macht, ist fuer die Hauptdokumente weitgehend erledigt.

Sauber ist der Post-Merge-Zustand trotzdem nicht. Die verbleibenden Brueche sitzen jetzt in den flankierenden Dokumenten und in der Testwahrheit. Das Core-Repo fuehrt in `README.md`, `docs/XCODE_RUNBOOK.md` und `docs/XCODE_APP_PREPARATION.md` weiter Offline-/No-Server-Aussagen, die zum aktuellen Produktcode nicht mehr passen. Im Wrapper sind Review-/Privacy-Texte fuer den optionalen Live-Upload immer noch zu positiv: `README.md` spricht von "keine Datenerhebung", das TestFlight-Metadatenmuster sagt sogar "Alle Daten verbleiben lokal", waehrend der Code optionalen HTTPS-Upload von Live-Standortpunkten anbietet.

Zusatzproblem: Die dokumentierte Klassifizierung der Linux-Testfehler ist nicht hart genug. Zwei Upload-Failures lassen sich direkt aus `minimumBatchSize = 5` erklaeren, und der bekannte Background-Failure widerspricht eher einer veralteten Testerwartung als einem sauber belegten Produktbug.

## 2) Repo-Status je Repo

### LocationHistory2GPX-iOS

- Branch: `main`
- Preflight sauber: ja
- Letzter Commit: `6867f52 Merge pull request #1 from dev-roeber/audit-fix-roadmap-granularization`
- `main` vs `origin/main`: `0 0`
- Besondere Auffaelligkeit:
  - waehrend des Audits durch Backup-/Report-Dateien untracked

### LH2GPXWrapper

- Branch: `main`
- Preflight sauber: ja
- Letzter Commit: `636320a Merge pull request #1 from dev-roeber/audit-fix-roadmap-granularization`
- `main` vs `origin/main`: `0 0`
- Besondere Auffaelligkeit:
  - kein `audits/`-Ordner vorhanden
  - Report deshalb bewusst im Repo-Root statt in neu erfundener Struktur

## 3) Harte Befunde

### P0 | Review / Privacy | Das TestFlight-Metadatenmuster ist sachlich falsch

Aussage:
Der vorgeschlagene App-Store-/TestFlight-Text behauptet weiter: "Alle Daten verbleiben lokal". Das ist fuer den aktuellen Produktcode falsch.

Beleg:
- Metadatenmuster:
  - `/home/sebastian/repos/LH2GPXWrapper/docs/TESTFLIGHT_RUNBOOK.md:201-205`
- Produktcode mit optionalem Server-Upload:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift:52-77`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift:6-24`

Warum relevant:
Das ist kein wording-kosmetisches Detail. Es ist eine falsche Privacy-/Store-Aussage zu Standortdaten. Solange dieser Text als Submission-Basis im Repo steht, ist die Review-/Privacy-Lage nicht sauber.

### P1 | Review / Privacy | Wrapper-README beschreibt das Privacy-Manifest zu positiv

Aussage:
Das Wrapper-README sagt "keine Datenerhebung", obwohl der Code optionalen Upload akzeptierter Live-Recording-Punkte an einen konfigurierbaren Endpoint anbietet.

Beleg:
- zu positiver Claim:
  - `/home/sebastian/repos/LH2GPXWrapper/README.md:42`
- Produktcode:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift:52-77`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:386-404`

Warum relevant:
Auch wenn der Upload optional und nutzerkonfiguriert ist, ist "keine Datenerhebung" als Kurzform fuer den aktuellen Produktstand zu absolut.

### P1 | Doku | Core-Xcode-Dokumente sind nach dem Merge noch immer sachlich hinter dem Code

Aussage:
Die Haupt-Roadmap wurde nachgezogen. Die Xcode-/Apple-Dokumente nicht.

Beleg:
- `README.md` innerhalb desselben Dokuments widerspruechlich:
  - Upload vorhanden: `/home/sebastian/repos/LocationHistory2GPX-iOS/README.md:11`, `:33`, `:39`
  - spaeter "offline-only": `/home/sebastian/repos/LocationHistory2GPX-iOS/README.md:111`
- `docs/XCODE_RUNBOOK.md`:
  - "Keine Maps, keine Persistenz, keine Suche": `:13`
  - "kein Sync und keine Cloud-/Server-Anteile": `:229`
- `docs/XCODE_APP_PREPARATION.md`:
  - "offline-only": `:37`
  - "keine Cloud-/Server-Funktionen": `:44`

Warum relevant:
Die Wahrheit ist nach dem Merge nicht mehr in ROADMAP/NEXT_STEPS kaschiert, aber immer noch in zentralen Apple-/Xcode-Dokumenten.

### P1 | Tests | Die aktuelle Fehlerklassifizierung ist zu weich und teilweise sachlich falsch

Aussage:
Die Doku behandelt aktuelle Linux-Failures zu freundlich. Nicht alle sind sauber "plattformbedingt" oder "unklar".

Beleg:
- `swift test` im Core:
  - 217 Tests
  - 2 Skips
  - 14 Failures
- Upload-Tests erwarten Upload nach 1 Punkt:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelTests.swift:213-243`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelTests.swift:273-327`
- Code batcht standardmaessig erst ab 5 Punkten:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift:14-19`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:389-390`
- Background-Test erwartet Client-Aktivierung ohne laufende Aufnahme:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelTests.swift:180-190`
- Produktcode aktiviert im Setter nur waehrend Aufnahme:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:189-193`

Warum relevant:
Diese Punkte verzerren Priorisierung. Wer sie fuer "Linux-only" oder "unklar" haelt, arbeitet am falschen Problem.

### P1 | Tests | Neue Kernpfade bleiben ohne passende direkte Tests

Aussage:
Der Merge hat Dokumentation fuer Heatmap und Wrapper-Auto-Restore hochgezogen. Direkte Regressionstests dafuer fehlen weiter.

Beleg:
- Heatmap produktiv vorhanden:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:443-449`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:746-756`
- Suche im Core-Testbaum:
  - `rg -n 'Heatmap|AppHeatmap' /home/sebastian/repos/LocationHistory2GPX-iOS/Tests/LocationHistoryConsumerTests` -> kein Treffer
- Wrapper-Tests decken Auto-Restore nicht direkt ab:
  - `rg -n 'restoreBookmarkedFile|ImportBookmarkStore' /home/sebastian/repos/LH2GPXWrapper/LH2GPXWrapperTests /home/sebastian/repos/LH2GPXWrapper/LH2GPXWrapperUITests`
  - nur Kommentar-Treffer in `LH2GPXWrapperTests.swift:39`

Warum relevant:
Genau die Feature-Bloecke, die in NEXT_STEPS als offen bleiben, haben weiter schwachen oder fehlenden Testunterbau.

### P2 | Cross-Repo | Lokaler Wrapper-Buildpfad passt nicht zu diesem Workspace

Aussage:
Das Wrapper-Projekt referenziert das Core-Repo nicht ueber den hier vorliegenden Workspace-Pfad.

Beleg:
- Wrapper-Projekt:
  - `/home/sebastian/repos/LH2GPXWrapper/LH2GPXWrapper.xcodeproj/project.pbxproj:613-615`
  - `relativePath = "../../../Code/LocationHistory2GPX-iOS";`
- aktueller Workspace-Pfad:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS`

Warum relevant:
Kein Produktbug, aber ein realer lokaler Reproduzierbarkeitsbruch fuer genau diesen Workspace.

## 4) Widerlegte oder relativierte fruehere Annahmen

### Alt-Audit gegen aktuellen Stand

- Heatmap wirklich implementiert?
  - bestaetigt
- Heatmap wirklich getestet?
  - teilweise bestaetigt
  - Code ja, dedizierte Tests nein
- Heatmap Apple-seitig wirklich verifiziert?
  - widerlegt
- Live-Tab wirklich vorhanden?
  - bestaetigt
- Live-Tab repo-wahr dokumentiert?
  - bestaetigt fuer README/ROADMAP/Feature-Inventar
- Upload-Batch-Preference wirklich vorhanden und dokumentiert?
  - bestaetigt
- Default-Endpunkt ueberall konsistent?
  - bestaetigt fuer aktuellen Code und aktuelle Hauptdoku
- Auto-Restore im Wrapper wirklich aktiv?
  - bestaetigt
- Core- vs Wrapper-Aussagen zu Auto-Restore widerspruchsfrei?
  - bestaetigt fuer README/ROADMAP/NEXT_STEPS
  - Verifikation bleibt offen
- Upload-/Networking-Aussagen wirklich review-tauglich?
  - formal kaschiert, aber sachlich weiter offen
- Historische Testaussagen vs aktueller Teststand sauber getrennt?
  - teilweise bestaetigt
  - ROADMAP/NEXT_STEPS ja, Xcode-/Review-Doku nein
- Wurden offene Punkte nur sprachlich entschaerft?
  - teilweise bestaetigt
  - grobe Doku-Drift behoben, aber Review-/Privacy- und Testdrift offen

## 5) Test- und Verifikationslage

### Exakte ausgefuehrte Commands

- `date -u +%Y-%m-%d_%H-%M`
- `rg --files /home/sebastian/repos/LocationHistory2GPX-iOS/audits`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS status --short --branch`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS branch --show-current`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS log --oneline -1`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS remote -v`
- `git -C /home/sebastian/repos/LH2GPXWrapper status --short --branch`
- `git -C /home/sebastian/repos/LH2GPXWrapper branch --show-current`
- `git -C /home/sebastian/repos/LH2GPXWrapper log --oneline -1`
- `git -C /home/sebastian/repos/LH2GPXWrapper remote -v`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS fetch --all --prune`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS rev-list --left-right --count main...origin/main`
- `git -C /home/sebastian/repos/LH2GPXWrapper fetch --all --prune`
- `git -C /home/sebastian/repos/LH2GPXWrapper rev-list --left-right --count main...origin/main`
- `swift test` (workdir `/home/sebastian/repos/LocationHistory2GPX-iOS`)
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS diff --check`
- `git -C /home/sebastian/repos/LH2GPXWrapper diff --check`
- diverse `rg`, `sed`, `nl -ba`, `find`, `wc -l`

### Reproduzierbare Failures

- `AppPreferencesTests.testStoredValuesAreLoaded`
- `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`
- `LiveLocationFeatureModelTests.testAcceptedSamplesUploadToConfiguredServer`
- `LiveLocationFeatureModelTests.testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized`
- `LiveLocationFeatureModelTests.testFailedUploadRetriesWhenAnotherAcceptedSampleArrives`

### Plattformbedingt plausibel

- `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`

### Nicht sauber als plattformbedingt belegt

- `testAcceptedSamplesUploadToConfiguredServer`
- `testFailedUploadRetriesWhenAnotherAcceptedSampleArrives`
- `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized`

### Apple-/Mac-/iPhone-only offen

- Heatmap Apple-Visual-/Performance-Nachweis
- `Live`-Tab auf echtem iPhone
- Background-Recording end-to-end
- Wrapper-Auto-Restore nach Reaktivierung
- Server-Upload mit echtem Geraet und echtem Endpoint

## 6) Doku-Drift / Status-Drift

- Haupt-Roadmap und NEXT_STEPS sind deutlich sauberer als im Alt-Audit
- Kern-Feature-Dokumentation fuer Heatmap/`Live`-Tab/Upload-Batching ist jetzt im Hauptstrang vorhanden
- Restdrift sitzt in den flankierenden Apple-/Xcode-/Review-Dokumenten
- Core-intern gibt es weiter Offline-/No-Server-Aussagen trotz aktuellem Upload-Code
- Wrapper-intern gibt es weiter Privacy-/Store-Wording, das den optionalen Upload zu stark weichzeichnet

## 7) Review-/Privacy-Risiken

### P0 kritisch

- App-Store-/TestFlight-Metadatenmuster sagt "Alle Daten verbleiben lokal", obwohl optionaler Location-Upload existiert

### P1 relevant

- Wrapper-README sagt "keine Datenerhebung"
- TestFlight-Runbook sagt zugleich `5.1.1 Data Collection = teilweise` und wenige Zeilen spaeter "Kein unmittelbarer Review-Blocker"
- `PrivacyInfo.xcprivacy` deklariert keine collected data types, waehrend der Code optionalen Upload von Live-Standortpunkten anbietet
  - ob das formal im Manifest oder nur in App-Privacy-Angaben aufgeloest werden muss, ist in diesem Audit nicht abschliessend verifizierbar
  - Risiko bleibt real

### P2 beobachtbar

- Core-Textbausteine und Xcode-Doku enthalten noch aeltere Offline-/No-Server-Reste

## 8) Priorisierte naechste Schritte

1. Review-/Privacy-Texte hart bereinigen, bevor weitere Feature-Arbeit oder Store-Arbeit beginnt.
2. Upload-Testklassifizierung korrigieren: Batch-Semantik und Testerwartung sauber auseinanderziehen.
3. Den bekannten Background-Failure neu bewerten: Testdrift vs Produktbug nicht weiter unscharf lassen.
4. Core-Xcode-/Apple-Dokumente auf den realen Scope bringen.
5. Danach Heatmap-/Restore-/Upload-Verifikation auf Apple-Hardware nachziehen.
6. Erst dann weitere neue Features.

## 9) Schlussurteil

ROT

Der Merge auf `main` hat die groessten Alt-Widersprueche zwar sichtbar reduziert, aber das Projekt ist fuer ehrliche Weiterarbeit noch nicht gruen. Die Hauptgefahr liegt jetzt nicht mehr in ROADMAP/NEXT_STEPS, sondern in Review-/Privacy-Aussagen und in einer zu weichen Fehlerklassifizierung. Die Submission-Basis im Wrapper enthaelt weiterhin eine sachlich falsche Local-Only-Behauptung. Gleichzeitig beschreiben zentrale Core-Xcode-Dokumente einen Produktumfang, den der aktuelle Code laengst ueberholt hat. Vor weiterer Feature-Arbeit ist ein Audit-Follow-up fuer Privacy-/Review-Texte und Testtruth noetig.
