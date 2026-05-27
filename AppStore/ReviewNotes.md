# App Store Review Notes — LH2GPX 1.0.2 (171)

> Repo-Truth-Stand: `MARKETING_VERSION = 1.0.2`, `CURRENT_PROJECT_VERSION = 171`
> (pbxproj + Info.plist App + Widget konsistent, verifiziert 2026-05-26 HEAD `a5d506e`).
> Hinweis: Höhere Build-Nummern in TestFlight-Historie (z. B. 190) stammen aus
> Xcode-Cloud-Builds; der Repo-Stempel ist die kanonische Quelle für neue Submissions
> aus diesem Branch.

## Test-Account

Nicht erforderlich. Die App funktioniert ohne Account, ohne Login und ohne
Organisationszugehörigkeit. Alle Daten bleiben lokal auf dem Gerät; nichts wird
an einen zentralen Dienst übertragen.

## Demo-Daten

Im Onboarding kann „Demo laden" gewählt werden. Damit ist die App auch ohne
eigenen Standortverlauf sofort vollständig testbar (Tage, Insights, Heatmap,
Export, Live-Aufzeichnung).

## Background-Location

Die App fragt `NSLocationAlwaysAndWhenInUseUsageDescription` nur an, wenn der
Nutzer in den Live-Recording-Settings „Background Recording" aktiviert.
Standard ist OFF.

Begründung für `UIBackgroundModes = location`:
- LiveTracks können stundenlang laufen (Hiking, Cycling).
- Tracking auf Basis Apple-eigener CoreLocation-API mit User-konfigurierter
  Sample-Rate (5–60 s).
- Keine Heimat-/Arbeitsplatz-Erkennung, keine Werbe-IDs, kein Server-Sync
  außer expliziter User-Konfiguration.

## CloudKit

Verwendet ausschließlich den privaten CloudKit-Bereich
(`iCloud.de.roeber.LH2GPXWrapper`). Keine geteilten oder öffentlichen
Datenbanken. Identifier in den iCloud-Settings sichtbar. iCloud ist
opt-in/default AUS; nur Live-Track-Metadaten und LiveTrack-Point-Batches
gehen — nach expliziter User-Aktion — in die private DB. Importierte Google-
History-Daten, importierte Historien und Exportdateien werden **nicht**
automatisch in iCloud gesichert.

## Optionaler Server-Upload

Disabled by default (`sendsLiveLocationToServer = false`). User muss explizit
eigenen HTTPS-Endpoint + Bearer-Token konfigurieren. Es werden ausschließlich
Live-Recording-Punkte gesendet, kein History-Import. Es existiert kein
zentraler Dienst und kein Pflicht-Endpoint; ein Referenz-Receiver liegt
optional unter `dev-roeber/lh2gpx-live-receiver`.

## Datenschutz

Privacy-Manifeste sind im App-Target (`wrapper/LH2GPXWrapper/PrivacyInfo.xcprivacy`)
und im Widget-Target (`wrapper/LH2GPXWidget/PrivacyInfo.xcprivacy`) enthalten.
Keine Tracking-Domains, keine Werbe-SDKs. Erfasste Reason-Codes:
`NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1) und
`NSPrivacyAccessedAPICategoryFileTimestamp` (0A2A.1). Optionale präzise
Location ist als Linked=false, Tracking=false, Purpose=AppFunctionality
deklariert.

## Plattform-Support

- iPhone iOS 26: Liquid-Glass-Design (5-Tab-Layout: Karte · Tage · Live ·
  Insights · Suche), neuer Record-FAB, `tabViewBottomAccessory`.
- iPhone iOS 17–25: läuft im iPad-Fallback-Layout (`AppContentSplitView`),
  keine Glas-Optik. `IPHONEOS_DEPLOYMENT_TARGET = 17.0`.
- iPad ab iOS 17: nutzt `AppContentSplitView`. Three-Pane-Layout für iPad
  ist in einer späteren Phase geplant.

## Bekannte Einschränkungen

- iPad-Three-Pane-Layout in dieser Version nicht enthalten.
- Live-Wetter-Pill nutzt WeatherKit Current Weather, sofern Entitlement, Developer-Portal-Capability, Provisioning Profile und Standortberechtigung gültig sind. Day/Overview/Export-Wetterlayer sind weiterhin nur vorbereitet/Platzhalter und als „Wetter vorbereitet“ gekennzeichnet.
- Echtes Road-/Path-Matching (Netzwerk-Snapping) ist nicht implementiert;
  `Simplified` ist GPS-Ausreisserfilterung + Douglas-Peucker.

## Verifikations-Hinweis für Reviewer

`AGENTS.md` § Repo-Truth-Lock dokumentiert, dass `dev-roeber/iOS-App` das
einzige aktive Arbeits-Repo ist. Andere LH2GPX-Repos sind historisch.
Die App ist eine öffentliche Consumer-/Utility-App — keine
Organisationsbindung, kein zentraler Dienst.
