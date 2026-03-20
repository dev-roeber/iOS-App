# CHANGELOG

## 2026-03-20

### Navigation / Search / Sheet Stability
- `Days`-Suche funktioniert jetzt in compact und regular width und matcht nicht nur ISO-Datum, sondern auch formatiertes Datum, Wochentag und Monat
- iPhone-`Days` reagiert auf erneutes Tab-Selektieren, setzt Suche/Navigationspfad zurueck und springt auf den aktuellen Tag, wenn dieser im Import vorhanden ist
- `AppContentSplitView` nutzt jetzt einen einzigen Sheet-Praesentationszustand fuer Export, Optionen und Saved-Live-Track-Library statt konkurrierender `.sheet`-Ketten am Actions-Menue

### Saved Live Tracks / Local Recording
- Saved-Live-Track-Wording ueber Overview, Day Detail, Library, Sheet-Fallback und Editor vereinheitlicht
- gespeicherte Live-Tracks werden klarer als lokaler Nebenfluss ausserhalb importierter History bezeichnet
- Track-Editor-Titel benennt jetzt konkret das Bearbeiten eines gespeicherten Tracks
- Overview-Primary-Actions, Actions-Menue und Day Detail fuehren jetzt direkt in dieselbe dedizierte `Saved Live Tracks`-Library
- der Live-Recording-Bereich zeigt keinen zweiten halben Library-Flow mehr, sondern verweist gezielt auf die separate Library-Seite
- die Library-Seite selbst zeigt jetzt auch Zusammenfassung und neuesten gespeicherten Track als eigenen lokalen Arbeitsbereich

### Insights / Empty-State Hardening
- Insights zeigen jetzt explizite Fallbacks fuer no-days-, low-data- und chart-unverfuegbare Faelle statt halbleerer Flaechen
- fehlende Distanz-, Activity-, Visit-, Weekday- und Period-Daten werden pro Sektion erklaert
- Imports mit sehr duennen, aber gueltigen Daten zeigen einen sichtbaren `Limited Insight Data`-Hinweis

### Charts / Export Polish
- Distance-, Activity-, Visit- und Weekday-Charts zeigen explizitere Achsen, Wertehinweise und Erklaertexte
- Export zeigt Auswahlzusammenfassung, Dateinamenvorschau und explizite Disabled-Reasons direkt im Flow
- Tage ohne GPX-faehige Routen werden in der Export-Liste klarer markiert und ausgewaehlte Zeilen deutlicher hervorgehoben
- gespeicherte Live-Tracks koennen jetzt direkt in derselben Exportseite mit ausgewaehlt und als GPX zusammen mit importierten Tagen exportiert werden

### Overview / Days / Day Detail Polish
- Overview startet jetzt mit Status und einer `Primary Actions`-Sektion fuer Open, Days, Insights und Export
- Export-Selektion ist in der Day-Liste sichtbarer und fuehrt ueber einen expliziten Export-Kontext schneller in den Export-Flow
- Day Detail trennt importierte Tagesdaten klarer von lokalem Live Recording und gespeicherten Live-Tracks

## 2026-03-19

### Navigation / Dead-End Hardening
- no-content-Tage bleiben in der Day-Liste sichtbar, werden aber in compact und regular nicht mehr wie normale Detailziele behandelt
- initiale Tagesauswahl bevorzugt jetzt contentful days statt blind den ersten Kalendertag
- Export-Badge in gruppierter und ungruppierter Day-Liste vereinheitlicht

### Lokale Optionen / Produktsteuerung
- lokale Optionen-Seite fuer Distanz-Einheit, Start-Tab, Kartenstil und technische Importdetails eingebaut
- `AppPreferences` als zentrale `UserDefaults`-Domain fuer Core-App und Wrapper verdrahtet
- Distanz-/Speed-Formatierung, Kartenstil, Start-Tab und technische Metadaten folgen denselben Preferences

### Repo-Truth / Dokumentation
- repo-wahres Feature-Inventar ergaenzt und 19.x-Roadmap auf aktuelle lokale Priorisierung bereinigt
- README, ROADMAP und NEXT_STEPS auf den tatsaechlichen Stand von Optionen, Day-Navigation und offenem Fokus synchronisiert

## 2026-03-18

### Export / Recorded Tracks
- GPX-Export mit app-weiter Tagesselektion, Export-Tab/-Sheet und Dateinamenvorschlag eingebaut
- Recorded-Track-Library und Track-Editor fuer gespeicherte Live-Tracks eingefuehrt
- Track-Editor-Zugang in Overview und Live-Recording-Bereich auffindbarer gemacht

### Import Truth Sync
- verbliebene Core-UI-Texte von `app_export`-Spezialfall auf den echten JSON-/ZIP-Import-Scope umgestellt
- ZIP-Fehlermeldungen auf aktuelle Unterstuetzung fuer LH2GPX- und Google-Timeline-Archive korrigiert
- `AGENTS.md`, README und Apple-/Xcode-Doku auf den realen Importstand synchronisiert

### Live Recording MVP
- foreground-only Live-Location fuer die Kartenansicht eingebaut
- manuellen Ein/Aus-Schalter mit sauber modellierten Permission-Zustaenden hinzugefuegt
- Live-Track mit Accuracy-/Dedupe-/Mindestdistanz-Filtern und Polyline-Rendering umgesetzt
- abgeschlossene Live-Tracks getrennt von importierter History in einem dedizierten Store persistiert
- bewusst offen gelassen: Background-Tracking, Auto-Resume von Drafts, Export aufgezeichneter Live-Tracks
