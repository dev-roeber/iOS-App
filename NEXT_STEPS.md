# NEXT_STEPS

Stand: 2026-05-05

Diese Datei enthaelt bewusst nur offene, priorisierte Arbeit. Abgeschlossene oder rein historische Batches bleiben im `CHANGELOG.md` und in den archivierten Phasen der `ROADMAP.md`.

## P0 — Release / Review / Hardware-Verifikation

- [ ] **Review-Response senden (Guideline 3.2)**: Sebastian muss manuell in ASC → Version 1.0 → Reply to Review — Entwurf: `docs/APP_REVIEW_RESPONSE_GUIDELINE_3_2.md`. Klarstellen: öffentliche Consumer-App, kein Account/Org-Binding, optionaler Upload = nutzerkonfiguriert self-hosted, default OFF. Ergebnis abwarten und ASC-Status nachziehen.
- [ ] **Nach positivem Review-Outcome**: neuen Build (aktuell 74) + neue Screenshots einreichen. Runbook: `docs/ASC_SUBMIT_RUNBOOK.md`
- [ ] **Neue Screenshots aufnehmen**: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausführen → 8 neue PNGs in `docs/app-store-assets/screenshots/iphone-67/` (01–08). Aktuell vorhanden: 01–06 mit altem Layout aus Build 44.
- [x] Support-URL in App Store Connect eingetragen: `https://dev-roeber.github.io/iOS-App/support.html` (2026-04-30)
- [x] Privacy-URL in App Store Connect eingetragen: `https://dev-roeber.github.io/iOS-App/privacy.html` (2026-04-30)
- [x] GitHub Pages fuer `/docs` live und oeffentlich erreichbar (HTTP 200 verifiziert 2026-04-30): `https://dev-roeber.github.io/iOS-App/`, `/support.html`, `/privacy.html`
- [ ] Live Activity / Dynamic Island auf echter Hardware vervollstaendigen: Lock Screen, `minimal`, Fallback bei deaktivierten / nicht verfuegbaren Live Activities, No-Dynamic-Island-Geraet (Pending-/Restart-Pfad jetzt gruen)
- [ ] Live Tracking / Live Tracks Library auf echter Apple-Hardware visuell verifizieren: Sticky Bottom Bar, Mint-Polyline, Status-Chips, Library-Zeilen (Redesign-Screens noch nicht auf echtem Gerät neu verifiziert)
- [ ] Performance-Smoke-Test auf echtem iPhone mit grosser realer History (>20 MB, Gesamtzeitraum) fuer Overview-/Explore-Karte dokumentieren

## P1 — Produktverifikation und Ausbau vorhandener Flaechen

- [ ] Chart-Share / ImageRenderer auf Apple-Hardware gezielt verifizieren
- [ ] app-weite Landscape-Verifikation fuer `Overview`, `Days`, `Insights`, `Export`, `Live`
- [ ] Homescreen-Widget auf echter Hardware gezielt verifizieren
- [ ] Track-Editor-Verhalten gegen reale Export-Erwartung entscheiden und dokumentieren: Mutations bleiben derzeit display-only und fliessen bewusst nicht in Exporte ein
- [ ] Wrapper-Simulator-Testlauf fuer `LH2GPXWrapperTests` auf diesem Host stabilisieren oder auf anderem Apple-Host gegentesten (`NSMachErrorDomain Code=-308`)

## P2 — Nachgelagerte Optimierung

- [x] Design-System: Export-Checkout-Redesign abgeschlossen (2026-05-01); alle Screens Start/Overview/Days/DayDetail/Insights/Export jetzt im LH2GPX-Dark-Redesign
- [x] Design-System: Live-Tracking-Redesign abgeschlossen (2026-05-01); Live Tracking + Live Tracks Library jetzt im LH2GPX-Dark-Redesign
- [x] Design-System: Options + Widget/Live Settings Redesign abgeschlossen (2026-05-01); alle 8 Sections modular, RecordingPreset-Wiring, Token nur als SecureField, 830 Tests
- [x] Final Truth-Sync: fehlende DE-Strings ergänzt (Invalid URL, Widget & Live Activity, Reachable/Unreachable, Test Connection, Automatic Widget Update etc.), widgetAutoUpdate/maximumRecordingGapSeconds getestet; 832 Tests (2026-05-01)
- [ ] App-Store-Screenshot-Aktualisierung auf neue Designs: UITest `testAppStoreScreenshots` auf iPhone 15 Pro Max ausführen → neue 8 Slots 01–08 aufnehmen und nach `iphone-67/` kopieren (s. `docs/ASC_SUBMIT_RUNBOOK.md`)
- [ ] Widget/Dynamic-Island nur bei sicherem Token-Pfad weiter ausbauen
- [ ] `LHCollapsibleMapHeader` in erste echte Seite einbauen (Kandidat: Insights-Heatmap-Kontext oder Overview-Map); nur wenn Daten sauber verfügbar
- [ ] Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter beobachten und nach Review-Feedback repo-wahr nachziehen
- [ ] `docs/NOTION_SYNC_DRAFT.md` nur noch als manuell gepflegten Snapshot nutzen oder spaeter durch einen schlankeren Status-Export ersetzen
- [ ] historische Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` konsistent als historisch/mirror markieren
- [ ] echtes Road-/Path-Matching nur als spaeteren separaten Produktentscheid evaluieren; aktueller Stand bleibt bewusst `Simplified` statt Snapping
