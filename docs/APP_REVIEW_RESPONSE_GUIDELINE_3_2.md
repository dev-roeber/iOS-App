# App Review Response — Guideline 3.2 (Business)

Stand: 2026-05-05

---

## Ablehnung (Apple Review — 2026-05-01)

| Feld | Wert |
|------|------|
| Version | 1.0 |
| Build | 74 |
| Submission ID | 1d2cc080-13cd-45cd-b3e0-c0259a75ce5c |
| Datum | 2026-05-01 |
| Status | **Abgelehnt** |
| Guideline | **3.2 — Business / Other Business Model Issues** |
| Zusammenfassung | Apple sah die App als Lösung für eine spezifische Organisation/Firma, nicht als öffentliche Consumer-/Utility-App |

---

## Sachverhalt

LH2GPX ist eine **öffentliche Consumer-App** für Einzelnutzer, die ihre persönliche Google-Maps-Standorthistorie lokal importieren, auswerten und als GPX/KML/CSV exportieren möchten.

**Die App hat keine Organisationsbindung:**
- Kein Account, kein Login, keine Anmeldepflicht
- Kein Organisations- oder Unternehmensaccount erforderlich
- Kein verpflichtender Server-Upload oder Zentraldienst
- Alle importierten Daten verbleiben lokal auf dem Gerät des Nutzers

**Was den optionalen Live-Upload betrifft:**
- Die Live-Aufzeichnungsfunktion ist standardmäßig deaktiviert
- Ein Server-Upload ist nur möglich, wenn der Nutzer explizit eine eigene Server-URL einträgt
- Es gibt keinen zentralen/betriebsgebundenen Server — der Nutzer betreibt ggf. einen eigenen Endpunkt
- Der optionale Upload betrifft ausschließlich Live-GPS-Aufzeichnungen des Nutzers selbst, nicht importierte historische Daten

---

## Response-Entwurf (für App Store Connect → Contact Us / Reply to Review)

> Dear App Review Team,
>
> Thank you for reviewing LH2GPX. We would like to clarify why we believe LH2GPX is a public consumer utility app, not an app designed for a specific organization or business.
>
> **What LH2GPX does:**
> LH2GPX is a personal location history viewer and GPX exporter. Any individual who has ever used Google Maps and wants to view or export their own location history privately on their iPhone can use this app. No account, login, organization membership, or company affiliation is required.
>
> **Key points:**
> - The app is designed for the general public — anyone who wants to review and export their personal Google Maps location history
> - All imported data stays entirely on the user's device; there is no mandatory server, no central service, no cloud sync for location history
> - The optional "Live Recording" feature (disabled by default) allows a user to record their own GPS position and optionally send it to a server of their own choosing; this is a self-hosted, user-configured option, not a corporate backend
> - There is no account system, no organization ID, no employee or client credentials required at any point in the app
>
> **Demo instructions for Review team:**
> 1. Launch the app
> 2. Tap "Load Demo Data" — no login or account needed
> 3. Browse days, view the map, open Insights and Export tabs
> 4. All features work without any external service, server URL, or organization credential
>
> We believe the confusion may have arisen from the optional Live Recording upload feature. We are happy to add additional clarifying language in the app's onboarding or description if that would help.
>
> We respectfully request reconsideration under Guideline 3.2.
>
> Thank you,
> Sebastian Röber

---

## Nächste Schritte (manuell von Sebastian)

1. In App Store Connect → Meine Apps → LH2GPX → Version 1.0 → „Ablehnung anfechten" / „Reply to Review"
2. Obigen Response-Entwurf einfügen (ggf. anpassen)
3. Wenn Apple „Needs Developer Action" oder neue Information anfordert: in dieser Datei dokumentieren
4. Wenn Review erneut gestartet: ASC-Status in Repo nachziehen

---

## Offene Fragen

- Muss Review-Note in ASC die optionale Server-URL-Funktion noch expliziter als rein nutzergesteuert beschreiben?
- Müssen App-Store-Beschreibung oder Screenshots die Consumer-/Utility-Natur noch stärker betonen?
- Ist Guideline 3.2 der einzige Ablehnungsgrund, oder gibt es weitere Feedback-Punkte?

---

## Historische Submissions

| Version | Build | Datum | Status | Submission ID |
|---------|-------|-------|--------|---------------|
| 1.0 | 52 | ~2026-04-30 | Review gestartet (Build 52 in Queue) | — |
| 1.0 | 71 | ~2026-04-30 | Xcode Cloud Build 71 in ASC | — |
| 1.0 | 73 | 2026-05-01 | Xcode Cloud Build 73, Zielkandidat | — |
| 1.0 | **74** | **2026-05-01** | **Abgelehnt — Guideline 3.2** | `1d2cc080-13cd-45cd-b3e0-c0259a75ce5c` |
