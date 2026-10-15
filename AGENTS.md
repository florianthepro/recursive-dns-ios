# AGENTS.md

- `README.md`, `AGENTS.md`, `HUMANS.md`, `PRIVACY.md` und `SUPPORT.md` sind verbindlich.
- Die App löst DNS-Anfragen selbst iterativ auf.
- Keine externen rekursiven DNS-Resolver verwenden.
- Kein VPN und keinen VPN-Slot verwenden.
- Ausschließlich DNS-Verkehr behandeln.
- Keine Telemetrie, Analytics, Konten, Cloud, Werbung oder Bezahlfunktionen.
- App und Extension müssen ohne externe Swift-Pakete bauen.
- Änderungen müssen `./Scripts/verify.sh` bestehen.
- Bundle-IDs nur über `Config/Project.xcconfig` und anschließend konsistent in den Deployment-Dateien ändern.
- Die kleinste vollständige und überprüfbare Lösung bevorzugen.
