# AUDIT_HARDMODE_WRAPPER

Datum: 2026-03-30 10:35 UTC
Repo: /home/sebastian/repos/LH2GPXWrapper

Hinweis:
Dieses Repo hat keinen `audits/`-Ordner. Der Report liegt deshalb bewusst im Repo-Root. Keine neue Struktur erfunden.

## 1) Executive Summary

Der Wrapper ist nach dem Merge auf `main` fuer Auto-Restore, Heatmap, `Live`-Tab und optionalen Upload deutlich ehrlicher dokumentiert als vor dem Alt-Audit. Der kritische Restfehler liegt hier nicht mehr im Funktionsstatus, sondern in Review-/Privacy-Wording und in der Verifikationshaerte.

Die haerteste Wahrheit: Der Wrapper traegt weiterhin Submission-Texte, die fuer den aktuellen Code zu positiv oder sachlich falsch sind. `README.md` sagt "keine Datenerhebung". Das TestFlight-Metadatenmuster sagt "Alle Daten verbleiben lokal". Beides passt nicht zu optionalem HTTPS-Upload akzeptierter Live-Standortpunkte. Zusaetzlich behauptet das README "App Review Guidelines geprueft: konform", waehrend das Runbook selbst wenige Zeilen spaeter weiter offene Privacy-/Review-Punkte dokumentiert.

## 2) Repo-Status

- Branch: `main`
- Preflight-Status: clean
- Letzter Commit: `636320a Merge pull request #1 from dev-roeber/audit-fix-roadmap-granularization`
- `main` vs `origin/main`: `0 0`
- Remote: `origin https://github.com/dev-roeber/LH2GPXWrapper.git`

## 3) Harte Befunde

### P0 | Review / Privacy | App-Store-Metadatenmuster ist sachlich falsch

Aussage:
Das TestFlight-/ASC-Runbook enthaelt weiter ein Beschreibungsfragment, das Local-Only behauptet.

Beleg:
- `/home/sebastian/repos/LH2GPXWrapper/docs/TESTFLIGHT_RUNBOOK.md:201-205`
- Produktcode fuer optionalen Upload liegt im Core-Package:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift:52-77`
  - `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/LiveLocationServerUploader.swift:6-24`

Warum relevant:
Das ist kein harmloser Formulierungsfehler. Es ist eine falsche Aussage zu Standortdaten im vorgeschlagenen Store-Text.

### P1 | Review / Privacy | README beschreibt Privacy zu positiv

Aussage:
Das README nennt das Manifest "kein Tracking, keine Datenerhebung". Der aktuelle Produktcode bietet optionalen Upload akzeptierter Live-Standortpunkte.

Beleg:
- `/home/sebastian/repos/LH2GPXWrapper/README.md:42`
- `/home/sebastian/repos/LH2GPXWrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy`
- `/home/sebastian/repos/LocationHistory2GPX-iOS/Sources/LocationHistoryConsumerAppSupport/AppOptionsView.swift:52-77`

Warum relevant:
Ob Apple dies im Manifest, in App Privacy oder in beiden Ebenen sehen will, ist hier nicht abschliessend verifiziert. Dass "keine Datenerhebung" fuer den aktuellen Produktstand zu absolut ist, ist dagegen repo-wahr.

### P1 | Review / Privacy | Wrapper-Doku ist intern nicht hart genug konsistent

Aussage:
Das README sagt Review-konform. Das TestFlight-Runbook sagt gleichzeitig `5.1.1 Data Collection = teilweise`, `5.1.2 Privacy Manifests = teilweise`, aber danach "Kein unmittelbarer Review-Blocker".

Beleg:
- `/home/sebastian/repos/LH2GPXWrapper/README.md:115-118`
- `/home/sebastian/repos/LH2GPXWrapper/docs/TESTFLIGHT_RUNBOOK.md:33-37`

Warum relevant:
Der Repo-Truth ist "offen, nicht abschliessend geklaert", nicht "konform". Diese Unterscheidung ist fuer Review-Vorbereitung wesentlich.

### P1 | Tests | Der Wrapper hat fuer den reaktivierten Auto-Restore-Pfad keinen direkten Regressionstest

Aussage:
Der Wrapper aktiviert `restoreBookmarkedFile()` beim Start, aber die Wrapper-Tests pruefen diesen aktiven Pfad nicht direkt.

Beleg:
- Aktivierung:
  - `/home/sebastian/repos/LH2GPXWrapper/LH2GPXWrapper/ContentView.swift` `.task { restoreBookmarkedFile() }`
- Testsuche:
  - `rg -n 'restoreBookmarkedFile|ImportBookmarkStore' LH2GPXWrapperTests LH2GPXWrapperUITests`
  - nur Kommentar-Treffer in `LH2GPXWrapperTests.swift:39`

Warum relevant:
Gerade der reaktivierte Pfad ist laut Runbook offen und device-verifikationsbeduerftig. Direkte Testabsicherung fehlt.

### P2 | Cross-Repo / Reproduzierbarkeit | Lokaler Package-Pfad passt nicht zu diesem Workspace

Aussage:
Das Xcode-Projekt zeigt auf `../../../Code/LocationHistory2GPX-iOS`, nicht auf den hier vorliegenden Workspace-Pfad.

Beleg:
- `/home/sebastian/repos/LH2GPXWrapper/LH2GPXWrapper.xcodeproj/project.pbxproj:613-615`
- aktueller Workspace-Core:
  - `/home/sebastian/repos/LocationHistory2GPX-iOS`

Warum relevant:
Kein Produkt- oder Merge-Bug, aber ein echter lokaler Reproduzierbarkeitsbruch.

## 4) Widerlegte oder relativierte fruehere Annahmen

- Wrapper-Auto-Restore "deaktiviert": widerlegt
  - im aktuellen `main` aktiv
- Heatmap / `Live`-Tab / Upload-Batching im Wrapper "nicht dokumentiert": widerlegt
  - README und ROADMAP/NEXT_STEPS enthalten sie jetzt
- "kein Netzwerk": widerlegt
  - der fruehere Fehler ist in den Haupt-Runbooks bereinigt, aber die Submission-Metadaten sind weiter zu positiv

## 5) Test- und Verifikationslage

### Exakte ausgefuehrte Commands

- `git -C /home/sebastian/repos/LH2GPXWrapper status --short --branch`
- `git -C /home/sebastian/repos/LH2GPXWrapper branch --show-current`
- `git -C /home/sebastian/repos/LH2GPXWrapper log --oneline -1`
- `git -C /home/sebastian/repos/LH2GPXWrapper remote -v`
- `git -C /home/sebastian/repos/LH2GPXWrapper fetch --all --prune`
- `git -C /home/sebastian/repos/LH2GPXWrapper rev-list --left-right --count main...origin/main`
- `git -C /home/sebastian/repos/LH2GPXWrapper diff --check`
- mehrere `rg`, `sed`, `nl -ba`-Lesebefehle

### Exakte Ergebnisse

- Wrapper-Preflight: sauber
- `main` aktuell gegen `origin/main`
- kein lokaler Xcode-/Simulator-Test moeglich in dieser Linux-Session
- Repo enthaelt nur 8 Wrapper-Unit-Tests; keine direkte Restore-Abdeckung sichtbar

### Weiterhin nicht belastbar

- frische Device-Verifikation fuer reaktivierten Auto-Restore
- frische Device-Verifikation fuer optionales Background-Recording
- frische Device-Verifikation fuer optionalen Server-Upload
- reale Simulator-/Xcode-Ausfuehrung in dieser Session

## 6) Doku-Drift / Status-Drift

- Funktionsstatus ist nach dem Merge weitgehend synchronisiert
- Review-/Privacy-Wording ist nicht synchronisiert
- README und TestFlight-Runbook geben weiter zu positive oder falsche Aussagen fuer den Upload-/Privacy-Scope

## 7) Review-/Privacy-Risiken

### P0 kritisch

- vorgeschlagene App-Store-Beschreibung behauptet Local-Only trotz optionalem Upload

### P1 relevant

- README: "keine Datenerhebung"
- README: "Review Guidelines geprueft: konform"
- TestFlight-Runbook: "Kein unmittelbarer Review-Blocker"
- `PrivacyInfo.xcprivacy` ohne `NSPrivacyCollectedDataTypes`, waehrend optionaler Upload von Live-Standortpunkten existiert
  - formale Apple-Pflicht hier nicht abschliessend verifiziert
  - Risiko bleibt offen und real

### P2 beobachtbar

- lokaler Xcode-Package-Pfad nicht an diesen Workspace angepasst

## 8) Priorisierte naechste Schritte

1. Submission-/Review-/Privacy-Texte hart bereinigen.
2. Auto-Restore nach Reaktivierung auf echtem iPhone gezielt nachweisen.
3. Optionalen Upload end-to-end auf Geraet pruefen.
4. Erst danach neue Store-/Beta-Arbeit oder neue Features.

## 9) Schlussurteil

ROT

Der Wrapper ist funktional nach dem Merge deutlich wahrheitsnaeher dokumentiert als vorher. Fuer Review-/Privacy-Vorbereitung ist er trotzdem nicht sauber. Solange das Repo fuer denselben Code gleichzeitig "keine Datenerhebung", "alle Daten verbleiben lokal" und "Review Guidelines geprueft: konform" traegt, ist die Submission-Basis nicht belastbar. Vor weiterer Feature-Arbeit ist Audit-Follow-up fuer Privacy-/Review-Wording noetig.
