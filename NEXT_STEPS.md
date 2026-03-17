# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Lokaler iPhone-Betrieb (aktueller Fokus)** – App auf echten Geraeten (iPhone 15 Pro Max, iPhone 12 Pro Max) verifiziert (2026-03-17): Build, Install, Demo-Daten, Karte, Scrollen, Import (app_export.json) funktionieren. Import-Fehler mit location-history.json behoben. Persistenz-/Restore-Logik code-reviewed: kein Bug gefunden, Tests ergaenzt (60 Tests gruen). Echter Geraete-Restore-Test (Import → App schliessen → Neustart → Datei wiederhergestellt?) steht noch aus – Checkliste in `docs/LOCAL_IPHONE_RUNBOOK.md`. iPad bewusst spaeter.
2. **Phase 20 extern – bewusst geparkt** – Erfordert ASC-Zugang. Screenshots lokal erstellt (docs/appstore-screenshots/, 2026-03-17). Verbleibend: App Store Connect Projekt anlegen, Metadaten eintragen, Screenshots hochladen, Upload, TestFlight-Beta starten. Wird aufgenommen, sobald Zugang verfuegbar ist.
3. **Phase 21: v1.0 Release** – erst nach abgeschlossener Beta-Phase und Feedback-Einarbeitung.
4. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.
