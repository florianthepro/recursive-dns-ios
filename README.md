# Recursive DNS for iOS

```text
Projektname: Recursive DNS
Repository: recursive-dns
App: RecursiveDNS
Bundle-ID: de.florianthepro.recursivedns
```

Recursive DNS löst DNS-Anfragen direkt auf dem iPhone über Root-, TLD- und autoritative Nameserver auf. Es wird kein externer rekursiver Resolver verwendet und kein VPN-Tunnel implementiert.

## Enthalten

- SwiftUI-App zum Aktivieren und Deaktivieren des DNS-Proxys
- DNS-Proxy-Network-Extension
- iterativer Resolver mit Root-Hints, Delegationsverfolgung und Glue-Records
- A-, AAAA- und CNAME-Auflösung
- TTL-basierter Speicher-Cache
- UDP und TCP für eingehende DNS-Anfragen
- UDP mit TCP-Fallback bei abgeschnittenen Antworten
- keine Telemetrie, Konten, Werbung, Cloud oder VPN-Funktion
- Tests für DNS-Namenscodierung und Anfrageerstellung
- MDM-Konfigurationsprofilvorlage

## Erzeugen

Erforderlich: macOS, Xcode 16 oder neuer, Apple-Developer-Team mit freigeschaltetem Network-Extension-Entitlement und XcodeGen.

```sh
chmod +x bootstrap.sh
./bootstrap.sh
```

Danach in Xcode das eigene Development Team für beide Targets wählen, Bundle-IDs bei Bedarf anpassen und auf einem realen iPhone bauen.

## Installation

`NEDNSProxyProvider` wird auf iOS über eine DNS-Proxy-Konfiguration aktiviert. Vor der Geräteinstallation müssen in `Configuration/RecursiveDNS.mobileconfig` die Bundle-IDs und die UUIDs beibehalten beziehungsweise an die signierten Targets angepasst werden. Das Profil muss über eine Geräteverwaltung verteilt werden. Das Beispielprofil ist absichtlich nicht signiert.

## No-Go

DNS-Auflösung darf nicht über ein VPN-Profil umgesetzt werden und keinen VPN-Slot belegen. Vorhandene VPN-Lösungen bleiben unberührt; ob deren eigene DNS-Erzwingung parallel greift, entscheidet die jeweilige VPN-Konfiguration.

## Grenze

Eine signierte IPA kann nicht allgemein mitgeliefert werden, weil Signatur, Team-ID, Provisioning Profile sowie das Network-Extension-Entitlement an das Apple-Developer-Konto und das konkrete Gerät beziehungsweise den Distributionskanal gebunden sind.
