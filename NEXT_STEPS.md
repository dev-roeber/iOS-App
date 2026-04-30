# NEXT_STEPS

Stand: 2026-04-30

Diese Datei enthaelt bewusst nur offene, priorisierte Arbeit. Abgeschlossene oder rein historische Batches bleiben im `CHANGELOG.md` und in den archivierten Phasen der `ROADMAP.md`.

## P0 — Release / Review / Hardware-Verifikation

- [ ] Live-Session-Restore gegen Fehl-Persistenz haerten: `sessionStartedAt` / `sessionID` werden derzeit laut Code-Audit zu frueh gesetzt; denied/restricted bzw. abgelehntes `Always`-Upgrade brauchen saubere Bereinigung plus Regressionstests
- [ ] App Review auf Build `52` weiter beobachten und Apple-Feedback dokumentieren. Kein Nachreichen von Build `57` ohne Apple-Feedback oder bestaetigten release-kritischen Fehler.
- [ ] Support-URL in App Store Connect eintragen: `https://dev-roeber.github.io/iOS-App/support.html`
- [ ] Privacy-URL in App Store Connect eintragen: `https://dev-roeber.github.io/iOS-App/privacy.html`
- [ ] App-Store-Screenshots in App Store Connect hochladen: `docs/app-store-assets/screenshots/iphone-67/`
- [ ] GitHub Pages fuer `/docs` final aktivieren bzw. den echten Live-Status repo-wahr nachtragen
- [ ] Live Activity / Dynamic Island auf echter Hardware vervollstaendigen: Lock Screen, `minimal`, Primärwert-Wechsel (`Dauer`, `Punkte`, `Upload-Status`) sowie Fallback bei deaktivierten / nicht verfuegbaren Live Activities
- [ ] Performance-Smoke-Test auf echtem iPhone mit grosser realer History (>20 MB, Gesamtzeitraum) fuer Overview-/Explore-Karte dokumentieren

## P1 — Produktverifikation und Ausbau vorhandener Flaechen

- [ ] Chart-Share / ImageRenderer auf Apple-Hardware gezielt verifizieren
- [ ] app-weite Landscape-Verifikation fuer `Overview`, `Days`, `Insights`, `Export`, `Live`
- [ ] Homescreen-Widget auf echter Hardware gezielt verifizieren
- [ ] Track-Editor-Verhalten gegen reale Export-Erwartung entscheiden und dokumentieren: Mutations bleiben derzeit display-only und fliessen bewusst nicht in Exporte ein
- [ ] Wrapper-Simulator-Testlauf fuer `LH2GPXWrapperTests` auf diesem Host stabilisieren oder auf anderem Apple-Host gegentesten (`NSMachErrorDomain Code=-308`)

## P2 — Nachgelagerte Optimierung

- [ ] Apple-Review-/Privacy-Einordnung fuer den optionalen Server-Upload weiter beobachten und nach Review-Feedback repo-wahr nachziehen
- [ ] `docs/NOTION_SYNC_DRAFT.md` nur noch als manuell gepflegten Snapshot nutzen oder spaeter durch einen schlankeren Status-Export ersetzen
- [ ] historische Split-Repos `LocationHistory2GPX-iOS` und `LH2GPXWrapper` konsistent als historisch/mirror markieren
- [ ] echtes Road-/Path-Matching nur als spaeteren separaten Produktentscheid evaluieren; aktueller Stand bleibt bewusst `Simplified` statt Snapping
