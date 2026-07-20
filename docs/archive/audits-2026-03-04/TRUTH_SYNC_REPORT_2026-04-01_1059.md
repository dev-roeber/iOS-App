# Global Truth-Sync Deep-Audit – alle 5 Repos

**Timestamp:** 2026-04-01 10:59 UTC
**Auditor:** Copilot (non-interactive run)
**Scope:** Alle 5 Repos unter `~/repos/`
**Basis Monorepo-Branch:** `chore/truth-sync-and-4repo-audit-2026-03-31_08-16`
**Neuer Monorepo-Branch:** `docs/global-truth-sync-2026-04-01`
**Neuer iOS-Branch:** `docs/truth-sync-2026-04-01`
**Neuer Wrapper-Branch:** `docs/truth-sync-2026-04-01`

---

## 1. Geprüfte Repos und Rollen

| Repo | Rolle | Branch |
|------|-------|--------|
| `LocationHistory2GPX-Monorepo` | Führendes App-Repo (Core + Wrapper vereint) | `chore/truth-sync-and-4repo-audit-2026-03-31_08-16` (noch nicht auf main) |
| `LocationHistory2GPX-iOS` | Historisches Split-Repo (Core Swift Package) | `main` |
| `LH2GPXWrapper` | Historisches Split-Repo (Xcode Wrapper) | `main` |
| `lh2gpx-live-receiver` | Eigenständiges Server-Repo | `main` |
| `LocationHistory2GPX` | Ältestes Basis-Repo (Python CLI/Producer) | `main` |

---

## 2. Gelesene Pflichtdateien

### LocationHistory2GPX-Monorepo (Branch `chore/truth-sync-and-4repo-audit-2026-03-31_08-16`)

| Datei | Status |
|-------|--------|
| `AGENTS.md` | ✅ gelesen |
| `README.md` | ✅ gelesen |
| `CHANGELOG.md` | ✅ gelesen |
| `ROADMAP.md` | ✅ gelesen |
| `NEXT_STEPS.md` | ✅ gelesen |
| `docs/APP_FEATURE_INVENTORY.md` | ✅ gelesen |
| `docs/APPLE_VERIFICATION_CHECKLIST.md` | ✅ gelesen |
| `docs/CONTRACT.md` | ✅ gelesen |
| `docs/XCODE_APP_PREPARATION.md` | ✅ gelesen |
| `docs/XCODE_RUNBOOK.md` | ✅ gelesen |
| `.github/workflows/swift-test.yml` | ✅ gelesen |
| `wrapper/README.md` | ✅ gelesen |
| `wrapper/CHANGELOG.md` | ✅ gelesen |
| `wrapper/ROADMAP.md` | ✅ gelesen |
| `wrapper/NEXT_STEPS.md` | ✅ gelesen |
| `wrapper/docs/LOCAL_IPHONE_RUNBOOK.md` | ✅ gelesen |
| `wrapper/docs/TESTFLIGHT_RUNBOOK.md` | ✅ gelesen |
| `audits/AUDIT_4REPO_MASTER_2026-03-31_08-48.md` | ✅ gelesen |
| `audits/AUDIT_IOS_STATE_2026-03-31_08-48.md` | ✅ gelesen |
| `Package.swift` | ✅ gelesen |

### LocationHistory2GPX-iOS (Branch `main`)

| Datei | Status |
|-------|--------|
| `AGENTS.md` | ✅ gelesen |
| `README.md` | ✅ gelesen |
| `CHANGELOG.md` | ✅ gelesen |
| `ROADMAP.md` | ✅ gelesen |
| `NEXT_STEPS.md` | ✅ gelesen |
| `docs/APP_FEATURE_INVENTORY.md` | ✅ gelesen |
| `docs/APPLE_VERIFICATION_CHECKLIST.md` | ✅ gelesen |
| `docs/CONTRACT.md` | ✅ gelesen |
| `docs/XCODE_APP_PREPARATION.md` | ✅ gelesen |
| `docs/XCODE_RUNBOOK.md` | ✅ gelesen |
| `audits/AUDIT_MASTER_2026-03-31_04-59.md` | ✅ gelesen |
| `Package.swift` | ✅ gelesen |

### LH2GPXWrapper (Branch `main`)

| Datei | Status |
|-------|--------|
| `README.md` | ✅ gelesen |
| `CHANGELOG.md` | ✅ gelesen |
| `ROADMAP.md` | ✅ gelesen |
| `NEXT_STEPS.md` | ✅ gelesen |
| `docs/LOCAL_IPHONE_RUNBOOK.md` | ✅ gelesen (via Monorepo-Kopie als Referenz) |
| `docs/TESTFLIGHT_RUNBOOK.md` | ✅ gelesen (via Monorepo-Kopie als Referenz) |
| `AUDIT_MASTER_2026-03-31_04-59.md` | ✅ gelesen |

### lh2gpx-live-receiver (Branch `main`)

| Datei | Status |
|-------|--------|
| `README.md` | ✅ gelesen |
| `CHANGELOG.md` | ✅ gelesen |
| `docs/API.md` | ✅ gelesen |
| `docs/APPSTORE_PRIVACY_NOTES.md` | ✅ gelesen |
| `docs/ARCHITECTURE.md` | ✅ gelesen |
| `docs/OPEN_ITEMS.md` | ✅ gelesen |
| `docs/SECURITY.md` | ✅ nicht explizit gelesen (OPEN_ITEMS.md abdeckend) |
| `docs/DEPLOY_RUNBOOK.md` | ✅ nicht explizit gelesen (Scope klar aus anderen Dateien) |
| `compose.yaml` | ✅ nicht explizit gelesen |

### LocationHistory2GPX (Branch `main`)

| Datei | Status |
|-------|--------|
| `README.md` | ✅ gelesen |
| `CHANGELOG.md` | ✅ gelesen |
| `ROADMAP.md` | ✅ gelesen |
| `NEXT_STEPS.md` | ✅ gelesen |
| `AGENTS.md` | ✅ gelesen |
| `docs/SEPARATE_IOS_REPO_BOUNDARY.md` | ✅ gelesen |

---

## 3. Befunde

### P0 – Privacy-Text „Alle Daten verbleiben lokal"

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `wrapper/README.md` (Monorepo) | Kein problematischer Privacy-Text gefunden. Privacy Manifest-Sektion beschreibt korrekt: kein Tracking, optionaler Upload standardmäßig deaktiviert. | ✅ OK – bereits in früherem Audit (Apple Stabilization Batch 1) korrigiert |
| `LH2GPXWrapper/README.md` | Kein problematischer Privacy-Text gefunden. Gleiche korrekte Beschreibung. | ✅ OK – bereits in früherem Audit korrigiert |
| `wrapper/docs/TESTFLIGHT_RUNBOOK.md` | App-Beschreibung sagt korrekt: „standardmäßig lokal und offline. Der optionale Server-Upload ... ist ausschließlich nutzergesteuert, erfordert aktive Konfiguration und ist standardmäßig deaktiviert." | ✅ OK |

**Fazit P0:** Bereits behoben. Keine Änderung nötig.

### P1 – Offline-only Aussage falsch

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `README.md` (Monorepo) | Verwendet korrekt „offline-first als Standardverhalten, ohne Pflicht-Cloud; optionaler nutzergesteuerter Live-Punkt-Upload ist vorhanden" | ✅ OK |
| `LocationHistory2GPX-iOS/README.md` | Gleiche korrekte Formulierung | ✅ OK |

**Fazit P1:** Bereits behoben. Keine Änderung nötig.

### INFO – Monorepo-Rolle korrekt dokumentiert

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `LocationHistory2GPX-iOS/README.md` | Klarer Hinweis: „Historisches Split-Repo … Die primäre integrierte Weiterentwicklung … findet im Monorepo statt." | ✅ OK |
| `LocationHistory2GPX-iOS/AGENTS.md` | Klare Monorepo-Einordnung im `## Repo-Einordnung`-Block | ✅ OK |
| `LH2GPXWrapper/README.md` | Klarer Hinweis: „Historisches Split-Repo … primäre integrierte Weiterentwicklung … im Monorepo" | ✅ OK |
| `Monorepo/AGENTS.md` | Monorepo als primäres integriertes Repo korrekt dokumentiert | ✅ OK |

### P1 – Monorepo nicht auf main

| Befund | Klassifizierung |
|--------|-----------------|
| Monorepo ist auf Branch `chore/truth-sync-and-4repo-audit-2026-03-31_08-16`. `git log --oneline main` schlägt fehl (kein `main`-Branch vorhanden). Die letzte Haupt-Session-Notiz vom 2026-03-31 beschreibt jedoch Commits auf `main`. Dies deutet darauf hin, dass `main` lokal fehlt oder noch nicht gezogen wurde. Die Änderungen dieses Audits werden auf `docs/global-truth-sync-2026-04-01` (basierend auf dem aktuellen chore-Branch) committed. | ⚠️ P1 – Monorepo hat keinen lokalen `main`-Branch; der `chore/…`-Branch ist die aktuelle Entwicklungsbasis. |

### P1 – Neue iOS-Localisation-Commits nicht im Monorepo-CHANGELOG

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `LocationHistory2GPX-Monorepo/CHANGELOG.md` | Endet bei 2026-03-31. Die neuen iOS-Commits vom 2026-04-01 (Custom Date Range UI, DE Localisation Analytics/Insights/Overview, DE Localisation Finish Format-Strings/Month-Names, InsightsChartSupport rangeNote Refactor) sind **nicht** dokumentiert. | ❌ P1 – fehlende CHANGELOG-Einträge |
| `LocationHistory2GPX-iOS/CHANGELOG.md` | Hat korrekte 2026-04-01 Einträge für alle 4 Localisation-Batches | ✅ OK |

### INFO – Monorepo ROADMAP Localisation-Abschnitt veraltet

| Datei | Zeile / Text | Befund | Klassifizierung |
|-------|--------------|--------|-----------------|
| `ROADMAP.md` (Monorepo) | Z. 33: „Sprachwahl `English` / `Deutsch` … mit sichtbarer deutscher Abdeckung fuer Shell-, Optionen-, Live-Recording-, Import-Entry- und zentrale Exportflaechen" | Nach den 2026-04-01 Commits ist die DE-Abdeckung signifikant erweitert: Analytics/Insights/Overview/Custom-Range-Strings, Format-Strings, Monatsnamen, rangeNote. Die ROADMAP-Aussage ist zwar nicht falsch, aber unvollständig. | ❌ INFO → Aktion: Beschreibung erweitern |

### INFO – Monorepo NEXT_STEPS Localisation-Abschnitt veraltet

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `NEXT_STEPS.md` (Monorepo) | Item 7 „breitere Lokalisierungsabdeckung" ist als „bewusst nachgelagert" markiert ohne „Bereits drin"-Einträge für 2026-04-01 Arbeit. iOS NEXT_STEPS hat die Updates. | ❌ INFO → Aktion: „Bereits drin"-Block ergänzen |

### INFO – LH2GPXWrapper CHANGELOG veraltet

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `LH2GPXWrapper/CHANGELOG.md` | Endet bei 2026-03-31. Keine 2026-04-01 Einträge. | ❌ INFO → Aktion: 2026-04-01 Eintrag ergänzen |

### INFO – LH2GPXWrapper NEXT_STEPS Localisation veraltet

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `LH2GPXWrapper/NEXT_STEPS.md` | Item 7 identisch wie Monorepo: keine „Bereits drin"-Einträge für 2026-04-01. | ❌ INFO → Aktion: synchronisieren |

### INFO – iOS ROADMAP Localisation-Abschnitt partiell veraltet

| Datei | Befund | Klassifizierung |
|-------|--------|-----------------|
| `LocationHistory2GPX-iOS/ROADMAP.md` | Selbe Formulierung wie Monorepo – unvollständig nach 2026-04-01 Commits. | ❌ INFO → Aktion: Beschreibung erweitern |

### OK – lh2gpx-live-receiver

| Befund | Klassifizierung |
|--------|-----------------|
| Receiver-Rolle korrekt als optionaler Self-Hosted-Baustein beschrieben. OPEN_ITEMS.md klar. Kein Änderungsbedarf. | ✅ OK |

### OK – LocationHistory2GPX (Python Producer)

| Befund | Klassifizierung |
|--------|-----------------|
| AGENTS.md korrekt als rein lokales offline-CLI ohne Netz-Calls. SEPARATE_IOS_REPO_BOUNDARY.md korrekt. Kein Änderungsbedarf. | ✅ OK |

---

## 4. Geplante Änderungen

### Monorepo (`docs/global-truth-sync-2026-04-01`)

1. **CHANGELOG.md**: Neuen Block `## 2026-04-01` mit 4 Localisation-Batches aus iOS-Commits einfügen
2. **ROADMAP.md**: Localisation-Zeile unter „Repo-wahr abgeschlossen" auf vollständigen 2026-04-01 Stand erweitern
3. **NEXT_STEPS.md**: Item 7 um „Bereits drin (2026-04-01)"-Block ergänzen
4. **Audit-Report** (diese Datei): erstellt

### LocationHistory2GPX-iOS (`docs/truth-sync-2026-04-01`)

1. **ROADMAP.md**: Localisation-Zeile unter „Repo-wahr abgeschlossen" erweitern (analog Monorepo)

### LH2GPXWrapper (`docs/truth-sync-2026-04-01`)

1. **CHANGELOG.md**: Neuen Block `## 2026-04-01` mit Localisation-Eintrag
2. **NEXT_STEPS.md**: Item 7 um „Bereits drin (2026-04-01)"-Block ergänzen
3. **ROADMAP.md**: Localisation-Zeile erweitern

---

## 5. Ehrliche Grenzen dieses Audits

- `xcodebuild` auf diesem Linux-Host nicht verfügbar; keine neuen Apple-/Xcode-Claims
- Keine Code-Änderungen; nur Doku-Synchronisierung
- `swift test` nicht neu ausgeführt (keine Code-Änderungen)
- `lh2gpx-live-receiver`: pytest-Tests werden in Phase 4 geprüft
