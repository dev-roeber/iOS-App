# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte.

1. **Lokaler iPhone-Betrieb (aktueller Fokus)** – App auf echten Geraeten (iPhone 15 Pro Max, iPhone 12 Pro Max) verifiziert (2026-03-17): Build, Install, Demo-Daten, Karte, Scrollen funktionieren. Import-Fehler mit location-history.json behoben: Google-Takeout-Format (Array-Root) wird jetzt klar abgelehnt mit verstaendlicher Fehlermeldung statt generischem Decode-Fehler. Persistenz/Restore: noch offen (manuell zu pruefen). Device-Run-Doku: `docs/LOCAL_IPHONE_RUNBOOK.md` (Wrapper-Repo). iPad bewusst spaeter.
2. **Phase 20 extern – bewusst geparkt** – Erfordert ASC-Zugang. Screenshots lokal erstellt (docs/appstore-screenshots/, 2026-03-17). Verbleibend: App Store Connect Projekt anlegen, Metadaten eintragen, Screenshots hochladen, Upload, TestFlight-Beta starten. Wird aufgenommen, sobald Zugang verfuegbar ist.
3. **Phase 21: v1.0 Release** – erst nach abgeschlossener Beta-Phase und Feedback-Einarbeitung.
4. Contract-Files weiter ausschliesslich vom Producer-Repo aus aktualisieren.
