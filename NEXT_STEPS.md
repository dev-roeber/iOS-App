# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Lokale Produktweiterentwicklung (aktiver Fokus)** – Phase 19.9 abgeschlossen. Naechster Schritt: Phase 19.10 bestimmen. Kandidaten: Card-Redesign (Visit/Activity/Path-Cards visuell differenzieren), AppSourceSummaryCard vereinfachen (technische Details reduzieren).
2. **Phase 20 / Phase 21 – bewusst geparkt** – Erfordert Apple Developer Account / ASC-Zugang. Kein aktiver Fokus.
3. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.

**Abgeschlossene Phase 19.9 (2026-03-18):**
- Toolbar-Buttons in Actions-Menu konsolidiert (ein Button statt drei)
- NavigationStack fuer Empty State: App-Name "LH2GPX" als Titel sichtbar
- Empty State zentriert mit Karten-Icon: modernes iOS-Muster
- Overview-Button zeigt Text-Label statt nur Icon

**Abgeschlossene Phase 19.8 (2026-03-18):**
- Day List als Landing auf iPhone compact: kein Auto-Push in Day Detail beim Laden
- Overview-Button in Day-List-Toolbar (compact/iOS): explizit zugaenglich
- "sidebar"-Text korrigiert zu "list" (platform-neutral)

**Abgeschlossene Phase 19.7 (2026-03-18):**
- Rohe Google Place IDs aus Visit-Cards entfernt: kein technisches Rauschen mehr in visitCard()
- Visit-Cards zeigen Typ-Label und Zeitspanne – klar und nutzbar

**Abgeschlossene Phase 19.6 (2026-03-18):**
- AppSourceSummaryCard aus Empty State entfernt: kein technisches Rauschen mehr im Idle-Zustand
- Empty State zeigt nur Titel, Beschreibung, Fehler (falls vorhanden) und Aktions-Buttons
- AppSourceSummaryCard bleibt unveraendert im geladenen Overview-Pane (sinnvoll dort)

**Abgeschlossene Phase 19.5 (2026-03-18):**
- Auto-Restore deaktiviert: App startet immer manuell (Open / Demo)
- Persistenz-Code vollstaendig erhalten (geparkt, kommentiert)
- iPhone-Einstieg klar und vorhersehbar

**Abgeschlossene Phase 19.4 (2026-03-18):**
- formatDistance() durch Measurement.formatted(.measurement(width: .abbreviated, usage: .road)) ersetzt
- US-Locale zeigt Meilen/Feet statt km/m
- Konsistent mit Datum/Uhrzeit-Locale-Awareness aus Phase 19.1

**Abgeschlossene Phase 19.3 (2026-03-18):**
- statsActivityTypes in Overview-Statistik mit .capitalized formatiert

**Abgeschlossene Phase 19.2 (2026-03-18):**
- Ghost-Button nach clearContent() beseitigt (Clear-Loop geloest)

**Abgeschlossene Phase 19.1 (2026-03-18):**
- Tool-Name im Empty-State kommuniziert, Zeitangaben formatiert, Typ-Labels formatiert

**Lokaler iPhone-Betrieb: vollstaendig verifiziert (2026-03-17)** – iPhone 15 Pro Max und iPhone 12 Pro Max. iPad bewusst spaeter.
