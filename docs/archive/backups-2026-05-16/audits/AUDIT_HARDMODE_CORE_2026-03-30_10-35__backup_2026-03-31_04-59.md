# AUDIT_HARDMODE_CORE

Datum: 2026-03-30 10:35 UTC
Repo: /home/sebastian/repos/LocationHistory2GPX-iOS

## 1) Executive Summary

Der Merge nach `main` hat den groessten Doku-Bruch aus dem Vor-Audit behoben: Heatmap, `Live`-Tab, Upload-Batching und Wrapper-Auto-Restore sind jetzt im Hauptstrang dokumentiert. Sauber ist der Stand trotzdem nicht.

Die haertesten offenen Probleme liegen jetzt nicht mehr primaer in README/ROADMAP/NEXT_STEPS, sondern in den flankierenden Xcode-/Apple-Dokumenten und in der Testklassifizierung. Das Core-Repo behauptet an mehreren Stellen weiterhin implizit oder explizit einen kleineren Produktumfang als der aktuelle Code tatsaechlich hat. Zusaetzlich sind mindestens drei der 14 aktuellen Linux-Testfehler nicht sauber als "plattformbedingt" belegt; zwei Upload-Failures sind direkt durch die aktuelle Batch-Semantik erklaerbar, und der bekannte Background-Failure widerspricht der aktuellen Code-Semantik des Tests selbst.

Schluss fuer dieses Repo: Die Wahrheit ist nicht mehr kaschiert wie im Alt-Audit, aber sie ist noch nicht sauber. Vor neuer Feature-Arbeit sind Testklassifizierung und Xcode-/Apple-Doku nachzuziehen.

## 2) Repo-Status

- Branch: `main`
- Preflight-Status vor Audit-Schreibvorgaengen: clean, `main...origin/main`, Divergenz `0 0`
- Letzter Commit: `6867f52 Merge pull request #1 from dev-roeber/audit-fix-roadmap-granularization`
- Remote: `origin git@github.com:dev-roeber/LocationHistory2GPX-iOS.git`
- Working Tree waehrend dieses Audits: unsauber nur durch Audit-Artefakte
  - `audits/AUDIT_LH2GPX_2026-03-30_09-11__backup_2026-03-30_10-35.md`
  - dieser Report
  - Cross-Repo-Report

## 3) Harte Befunde

### P1 | Tests | Upload-Failures sind nicht sauber "plattformbedingt"

Aussage:
Die aktuelle Doku stuft die Upload-bezogenen Linux-Failures nur als "wirken weiter plattformbedingt" ein. Das ist fuer den aktuellen Code nicht sauber belegt.

Beleg:
- `swift test` am 2026-03-30 endet mit 217 Tests, 2 Skips, 14 Failures
- Test erwartet Upload nach 1 Punkt:
  - `Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelTests.swift:213-243`
- Produktcode blockiert Uploads bis `minimumBatchSize` erreicht ist:
  - `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:389-390`
- Default fuer `minimumBatchSize` ist `5`:
  - `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift:14-19`

Warum relevant:
Die beiden Failures `testAcceptedSamplesUploadToConfiguredServer` und `testFailedUploadRetriesWhenAnotherAcceptedSampleArrives` sind damit direkt durch aktuelle Semantik erklaerbar. Sie sind kein sauber isolierter Linux-Nachweis. Die Testlage wird in ROADMAP und NEXT_STEPS damit zu freundlich beschrieben.

### P1 | Tests | Der bekannte Background-Failure ist aktuell eher Testdrift als belegter Logic-Bug

Aussage:
Der bekannte Problemfall `testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized` ist in der Doku als "unklar und moeglicherweise echter Logic-Bug" geframet. Der aktuelle Code stuetzt diese Einordnung nicht.

Beleg:
- Failender Test erwartet sofortige Client-Aktivierung ohne laufende Aufnahme:
  - `Tests/LocationHistoryConsumerTests/LiveLocationFeatureModelTests.swift:180-190`
- Produktcode aktiviert Background-Tracking beim Setzen der Preference nur, wenn bereits aufgenommen wird:
  - `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:189-193`
- Beim eigentlichen Start der Aufnahme wird die Background-Konfiguration angewendet:
  - `Sources/LocationHistoryConsumerAppSupport/LiveLocationFeatureModel.swift:236-246`

Warum relevant:
Das ist kein harter Beleg fuer einen Produkt-Bug. Es ist ein harter Beleg dafuer, dass Testannahme und aktuelle Semantik nicht sauber zusammenpassen. ROADMAP/NEXT_STEPS formulieren diesen Fall zu unbestimmt.

### P1 | Doku | `README.md` widerspricht sich beim Networking-Scope selbst

Aussage:
Das zentrale README sagt frueh korrekt, dass optionaler Live-Punkt-Upload existiert, nennt die App-Shell spaeter aber weiter "offline-only".

Beleg:
- Feature-Claim mit optionalem Upload:
  - `README.md:11`
  - `README.md:33`
  - `README.md:39`
- Spaeterer Gegenclaim:
  - `README.md:111`

Warum relevant:
Das ist kein historischer Alttext in einer klar abgegrenzten Phase, sondern ein aktueller Widerspruch im selben Hauptdokument. Genau solche Formulierungen erzeugen falsche Architektur- und Review-Annahmen.

### P1 | Doku | `docs/XCODE_RUNBOOK.md` ist fuer den aktuellen Produktstand sachlich ueberholt

Aussage:
Das Xcode-Runbook beschreibt weiterhin einen deutlich kleineren App-Umfang als der aktuelle Code.

Beleg:
- "Keine Maps, keine Persistenz, keine Suche":
  - `docs/XCODE_RUNBOOK.md:13`
- "kein Sync und keine Cloud-/Server-Anteile":
  - `docs/XCODE_RUNBOOK.md:229`
- Repo-Truth dagegen:
  - Map/Heatmap/Vorschaukarte: `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:443-449`, `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:749-756`
  - Persistenz/Bookmarks: `Sources/LocationHistoryConsumerApp/AppShellRootView.swift` nutzt `ImportBookmarkStore.save(url:)`
  - Suche: Day-Search ist produktiv im AppSupport enthalten
  - optionaler Server-Upload: `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift:6-24`

Warum relevant:
`docs/XCODE_RUNBOOK.md` ist ein kanonisches Apple-Dokument. In seinem aktuellen Wortlaut verkleinert es den Produktumfang sachlich falsch.

### P1 | Doku | `docs/XCODE_APP_PREPARATION.md` ist fuer den Networking-Scope veraltet

Aussage:
Auch die vorbereitende Xcode-Notiz behauptet weiter Offline-/No-Server-Scope, obwohl der aktuelle Produktcode optionalen Upload enthaelt.

Beleg:
- "Das Repo bleibt offline-only":
  - `docs/XCODE_APP_PREPARATION.md:37`
- "keine Cloud-/Server-Funktionen":
  - `docs/XCODE_APP_PREPARATION.md:44`
- Produktcode mit optionalem Server-Upload:
  - `Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift:52-77`
  - `Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift:6-24`

Warum relevant:
Die Datei ist zwar als historische Vorbereitungsnotiz deklariert, wird in README und CONTRACT aber weiter aktiv als Referenz genannt. Ihr Scope ist fuer den aktuellen Code nicht mehr repo-wahr.

### P1 | Tests | Es gibt weiterhin keine dedizierte Heatmap-Testabdeckung

Aussage:
Die Heatmap ist produktiv verdrahtet, aber im Testbaum gibt es keine direkte Heatmap-Abdeckung.

Beleg:
- Produktiver Heatmap-Code:
  - `Sources/LocationHistoryConsumerAppSupport/AppHeatmapView.swift`
  - `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:443-449`
  - `Sources/LocationHistoryConsumerAppSupport/AppContentSplitView.swift:746-756`
- Suche im Testbaum:
  - `rg -n 'Heatmap|AppHeatmap' Tests/LocationHistoryConsumerTests` -> kein Treffer

Warum relevant:
Die Heatmap ist genau der offene Verifikationsblock, der nach dem Merge weiter als teilweise offen gefuehrt wird. Der fehlende Testunterbau ist weiterhin real.

### P2 | Repo-Hygiene | Lokale Build-Artefakte vorhanden, aber nicht getrackt

Aussage:
Im Core-Repo liegt lokal `.build/` vor.

Beleg:
- `find . -maxdepth 2 ...` -> `./.build`
- `.gitignore` ignoriert `.build/`

Warum relevant:
Kein Git-Hygiene-Fehler im Repo-Inhalt, aber als lokaler Audit-Befund dokumentationswert.

## 4) Widerlegte oder relativierte fruehere Annahmen

- Heatmap "nur geplant": widerlegt
  - produktiv vorhanden und dokumentiert
- `Live`-Tab "Doku kennt ihn nicht": widerlegt
  - README, ROADMAP und Feature-Inventar kennen ihn jetzt
- Auto-Restore im Wrapper "Doku sagt deaktiviert": weitgehend widerlegt
  - README, ROADMAP und Wrapper-Runbook beschreiben den aktiven Wrapper-Pfad jetzt korrekt
- Upload-Failures "plattformbedingt": teilweise widerlegt
  - die aktuelle Batch-Semantik liefert direkten Gegenbeleg
- Background-Failure "moeglicherweise echter Logic-Bug": relativiert
  - aktueller Test widerspricht der aktuellen Produktsemantik

## 5) Test- und Verifikationslage

### Exakte ausgefuehrte Commands

- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS status --short --branch`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS branch --show-current`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS log --oneline -1`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS remote -v`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS fetch --all --prune`
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS rev-list --left-right --count main...origin/main`
- `swift test` (workdir `/home/sebastian/repos/LocationHistory2GPX-iOS`)
- `git -C /home/sebastian/repos/LocationHistory2GPX-iOS diff --check`
- mehrere `rg`, `sed`, `nl -ba`-Lesebefehle fuer Doku- und Codebelege

### Exakte Ergebnisse

- `main` ist aktuell gegen `origin/main`: `0 0`
- Preflight-Working-Tree war sauber
- `git diff --check`: sauber
- `swift test`:
  - 217 ausgefuehrte Tests
  - 2 Skips
  - 14 Failures

### Reproduzierbar fehlgeschlagen

- `AppPreferencesTests.testStoredValuesAreLoaded`
  - Failt auf Linux reproduzierbar
  - Ursache im aktuellen Repo-Truth: Keychain-Fallback liest aus `UserDefaults.standard`, der Test schreibt in eine Suite-Domain
- `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`
  - Failt auf Linux reproduzierbar
  - plattformspezifische Formatierungsdifferenz weiterhin plausibel, aber in diesem Audit nicht auf Apple gegengetestet
- `LiveLocationFeatureModelTests.testAcceptedSamplesUploadToConfiguredServer`
  - Failt reproduzierbar
  - durch aktuelle Batch-Default-Semantik direkt erklaerbar
- `LiveLocationFeatureModelTests.testBackgroundPreferenceActivatesClientWhenAlwaysAuthorized`
  - Failt reproduzierbar
  - Testannahme passt nicht zur aktuellen Aktivierungslogik
- `LiveLocationFeatureModelTests.testFailedUploadRetriesWhenAnotherAcceptedSampleArrives`
  - Failt reproduzierbar
  - erster Upload wird durch Batch-Default nicht erreicht

### Plattformbedingt plausibel

- `DayDetailPresentationTests.testTimeRangeFormattingAvoidsRawISOStrings`
  - weiterhin plausibel plattformbedingt
  - kein Apple-Gegenbeleg in dieser Session

### Unklar

- Keine zusaetzlichen unklaren Core-Failures ausserhalb der oben belegten Semantik-/Plattformgruppe

### Apple-/Mac-/iPhone-only offen

- Heatmap visuell/performance-seitig auf Apple-Hardware
- `Live`-Tab auf iPhone
- Background-Recording auf echtem Geraet
- Wrapper-Auto-Restore nach Reaktivierung
- Server-Upload end-to-end auf echtem Geraet

## 6) Doku-Drift / Status-Drift

- `README.md` ist im Hauptpfad besser als vor dem Merge, enthaelt aber weiterhin einen aktuellen Offline-Only-Gegenclaim
- `docs/XCODE_RUNBOOK.md` beschreibt einen kleineren Scope als der aktuelle Produktcode
- `docs/XCODE_APP_PREPARATION.md` beschreibt weiter No-Server-/Offline-Scope
- ROADMAP und NEXT_STEPS sind nach dem Merge deutlich naeher am Code als im Alt-Audit
- Historische Aussagen und aktueller Teststand sind in ROADMAP/NEXT_STEPS getrennt, aber die konkrete Fail-Klassifizierung ist zu weich

## 7) Review-/Privacy-Risiken

### P1 relevant

- Das Core-Repo selbst enthaelt optionalen Location-Upload zu nutzerdefiniertem Endpoint, aber zentrale Xcode-Doku spricht weiter von No-Server-/Offline-Scope
- Damit ist die technische Grundlage fuer Apple-/Review-Dokumente im Core-Repo noch nicht konsistent

### P2 beobachtbar

- `AppLanguageSupport.swift` enthaelt noch einen aelteren String zu "no server transfer", waehrend die aktive Privacy-UI bereits korrekt von optionalem Server-Upload spricht
- Kein harter Produktfehler, aber ein Signal fuer Restdrift in Textbausteinen

## 8) Priorisierte naechste Schritte

1. Upload-Testlage bereinigen: zuerst sauber dokumentarisch klassifizieren, dass die aktuellen Upload-Failures durch Batch-Semantik erklaerbar sind und nicht belegt Linux-only sind.
2. Den bekannten Background-Failure sauber neu einordnen: Testannahme gegen aktuelle Semantik pruefen statt weiter "unklar" stehenlassen.
3. `docs/XCODE_RUNBOOK.md` und `docs/XCODE_APP_PREPARATION.md` hart gegen den realen Produktumfang synchronisieren.
4. Dedizierte Heatmap-Testabdeckung planen und den Apple-Nachweisblock erst danach oder parallel fahren.
5. Erst danach weitere Feature-Arbeit.

## 9) Schlussurteil

GELB

Der Merge nach `main` hat die groesste Doku-Kaschierung des Vor-Audits beseitigt. Das Repo ist aber noch nicht sauber genug fuer sorgenfreie Weiterarbeit. Die Kernprobleme sind jetzt konzentrierter: Testklassifizierung ist teilweise sachlich falsch, und zentrale Apple-/Xcode-Dokumente beschreiben weiter einen kleineren Scope als der aktuelle Code. Das ist keine Katastrophe, aber es ist echte Nacharbeit vor neuer Feature-Arbeit. Neue Features sind vertretbar erst nach einem kurzen Audit-Follow-up fuer Tests und Xcode-/Apple-Doku.
