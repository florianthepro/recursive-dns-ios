hinweiß für appstore: https://florianthepro.github.io/recursive-dns-ios/ sind support und datenschutzseite zu finden

# HUMANS.md

## Von diesem Repository zur App-Store-Version

1. Am Mac eine Apple-ID mit Zwei-Faktor-Authentifizierung vorbereiten.
2. Unter <https://developer.apple.com/programs/enroll/> das Apple Developer Program als Einzelperson buchen.
3. Xcode aus dem Mac App Store installieren und die Apple-ID unter **Xcode → Settings → Accounts** anmelden.
4. Dieses Repository laden und `./Scripts/bootstrap.sh` ausführen.
5. In `Config/Project.xcconfig` weltweit eindeutige Bundle-IDs festlegen. Danach dieselben IDs in `Shared/Preferences.swift`, `Deployment/RecursiveDNS.mobileconfig` und `Deployment/NetworkDNSProxy.json` eintragen.
6. In Xcode bei `RecursiveDNS` und `RecursiveDNSProxy` unter **Signing & Capabilities** dein Team auswählen.
7. Für beide Targets die App Group aktivieren. Für `RecursiveDNSProxy` zusätzlich **Network Extensions → DNS Proxy** aktivieren.
8. `./Scripts/test.sh` ausführen und alle Fehler beheben.
9. Auf einem echten iPhone bauen. Die DNS-Proxy-Konfiguration über eine kompatible Geräteverwaltung installieren und WLAN, Mobilfunk, IPv4, IPv6, UDP/TCP 53, Netzwerkwechsel, NXDOMAIN und große Antworten testen.
10. Unter **Settings → Pages** GitHub Pages mit Quelle `main` und Ordner `/docs` aktivieren. Prüfen, dass Start-, Support- und Datenschutzseite öffentlich ohne Anmeldung erreichbar sind.
11. In App Store Connect einen App-Eintrag mit der Bundle-ID der Haupt-App anlegen. Die Texte aus `AppStore/metadata-de-DE.md`, Screenshots der finalen App, Support-URL und Datenschutz-URL eintragen.
12. In App Store Connect unter App Privacy „No, we do not collect data from this app“ nur dann auswählen, wenn der finale Build weiterhin keine Daten an den Entwickler oder Dritte übermittelt.
13. In Xcode **Product → Archive**, anschließend **Distribute App → App Store Connect → Upload**.
14. Den Build zuerst intern über TestFlight installieren und mit der produktiven DNS-Proxy-Konfiguration testen.
15. Die Review-Hinweise aus `AppStore/review-notes-de.txt` eintragen und die Testkonfiguration bereitstellen.
16. **Add for Review → Submit for Review**. Bei Rückfragen im Resolution Center antworten.

## Release-Befehle

```sh
./Scripts/bootstrap.sh
./Scripts/verify.sh
./Scripts/test.sh
./Scripts/archive.sh
```

## Wichtige Grenze

Das Repository enthält alle projektseitigen Dateien. Apple-Signatur, Team-ID, Provisioning Profiles, Entitlement-Freigabe, Geräteverwaltung und App-Store-Review entstehen außerhalb des Repositories und können nicht vorab in eine öffentliche ZIP eingebettet werden.
