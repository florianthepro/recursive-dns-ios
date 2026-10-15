# Recursive DNS

```text
Projektname: Recursive DNS
Repository: recursive-dns
App: Recursive DNS
Standard-Bundle-ID: de.floriankutzer.recursivedns
```

Recursive DNS ist eine schlanke iOS-App mit DNS-Proxy-Network-Extension. DNS-Anfragen werden lokal iterativ über Root-, TLD- und autoritative Nameserver aufgelöst. Die App verwendet keinen externen rekursiven Resolver, keinen VPN-Tunnel, keine Konten, keine Werbung und keine Telemetrie.

## Repository-Inhalt

- SwiftUI-App und DNS-Proxy-Extension
- iterativer Resolver für A, AAAA und allgemeine DNS-Datensatztypen
- Delegationsverfolgung, Glue-Records, UDP und TCP-Fallback
- positiver und negativer TTL-Cache im Arbeitsspeicher
- App-Icon, Wortmarke und vollständiger Asset-Katalog
- Unit-Tests
- Build-, Test- und Archiv-Skripte
- Datenschutz-, Support- und GitHub-Pages-Website
- App-Store-Metadaten und Review-Hinweise
- klassische MDM-Profilvorlage und iOS-27-DDM-Beispiel

## Mac-Schnellstart

```sh
./Scripts/bootstrap.sh
```

Danach `RecursiveDNS.xcodeproj` öffnen, bei beiden Targets das eigene Apple-Developer-Team auswählen und auf einem echten iPhone testen. Die vollständige menschliche Anleitung steht in [`HUMANS.md`](HUMANS.md).

## Technische Grenze

Die App kann vollständig gebaut und archiviert werden. Eine veröffentlichbare Binärdatei kann jedoch erst auf einem Mac mit Xcode, aktivem Apple-Developer-Team, passenden Provisioning Profiles und DNS-Proxy-Entitlement signiert werden. Die systemweite DNS-Proxy-Aktivierung benötigt außerdem eine von iOS unterstützte Geräteverwaltungskonfiguration.

## No-Go

Die App darf keinen VPN-Tunnel aufbauen, keinen VPN-Slot belegen und keine DNS-Anfragen an einen externen rekursiven Resolver weiterleiten.

## Lizenz

MIT, siehe [`LICENSE`](LICENSE).
