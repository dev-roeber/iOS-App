# NEXT_STEPS

Abgeleitet aus der Roadmap. Nur die konkret naechsten offenen Schritte, repo-wahr und nach aktuellem Code-Stand priorisiert.

## 1. Phase 19.39 – Export-Filter vervollstaendigen

Status: **teilweise umgesetzt**

Bereits drin:
- lokale Filter fuer importierte History nach `From`, `To` und `Max accuracy`
- explizite `Has ...`- und `Activity type`-Filter als Nutzeroberflaeche
- Filter wirken auf Export-Day-Liste, Preview und den eigentlichen Export
- Saved Live Tracks bleiben bewusst ungefiltert

Fehlt noch:
- UI fuer Polygon-/Bounding-Box-Filter
- klare Nutzererklaerung, welche Filter nur importierte History und welche auch Saved Live Tracks betreffen

## 2. Phase 19.40 – Weitere Exportformate

Status: **teilweise umgesetzt**

Bereits drin:
- `GPX` aktiv
- `KML` aktiv
- gemeinsamer Exportpfad fuer importierte Days + Saved Live Tracks

Fehlt noch:
- naechstes wirkliches Zusatzformat festziehen und aktivieren
- sinnvolle Reihenfolge ist `CSV` oder `GeoJSON` vor `KMZ`
- Dateityp-/Dokument-Handling fuer weitere Formate sauber in die bestehende Export-UI einhaengen

## 3. Phase 19.41 – Exportmodi / Waypoints vs Tracks

Status: **offen**

Fehlt noch:
- Benutzerentscheidung oder Produktvorgabe fuer `Tracks`, `Waypoints` oder Mischmodus
- Erweiterung der Export-Builder ohne die aktuellen GPX/KML-Flows zu zerbrechen
- klare UI, wann Visits/Activities als Wegpunkte exportiert werden und wann nicht

## 4. Phase 19.42 – Server-Upload fuer Standortdaten

Status: **offen**

Fehlt noch:
- ein-/ausschaltbare Server-Upload-Option
- Zielserver-/Endpoint-Konfiguration
- Payload-/Authentifizierungsmodell
- Fehler-/Retry-Strategie
- klare Trennung zwischen lokalem Recording und externem Upload

## 5. Phase 19.43 – Background-Recording auf echter Apple-Hardware haerten

Status: **teilweise umgesetzt**

Bereits drin:
- Background-Recording-Codepfad
- `Always Allow`-Upgrade im Live-Location-Modell
- Wrapper-Deklarationen fuer `NSLocationAlwaysAndWhenInUseUsageDescription` und `UIBackgroundModes=location`

Fehlt noch:
- echte Device-Verifikation fuer Permission-Upgrade, laufende Aufnahme im Hintergrund und Stop-/Persistenzverhalten
- separater dokumentierter Nachweis im Apple-/Wrapper-Runbook
- Korrektur verbleibender Produkttexte, falls der reale Device-Flow noch Unterschiede zeigt

## 6. Phase 19.44 – Live-Tracks-Oberflaeche final einordnen

Status: **teilweise umgesetzt**

Bereits drin:
- dedizierte `Saved Live Tracks`-Library
- Editor fuer gespeicherte Tracks
- Export-Unterstuetzung fuer Saved Live Tracks

Fehlt noch:
- Produktentscheidung, ob `Saved Live Tracks` nur ein lokaler Nebenfluss bleibt oder einen eigenen primaeren App-Bereich bekommt
- falls eigener Bereich gewuenscht: Einstieg, Navigation und Informationsarchitektur entsprechend anpassen

## 7. Phase 20 – Apple / ASC / TestFlight / externe Distribution

Status: **bewusst geparkt**

- bleibt ausserhalb des aktuellen Linux-Hosts
- braucht Apple-Hardware, Signierungskontext und reale Distribution statt lokaler Repo-Arbeit

## 8. Phase 21 – spaetere Folgearbeit

Status: **bewusst unberuehrt**

- weitergehende Konkurrenz-/Feature-Recherche
- groessere Produktentscheidungen jenseits des aktuellen lokalen Ausbaupfads

Contract-Files werden weiterhin ausschliesslich vom Producer-Repo aus aktualisiert.
