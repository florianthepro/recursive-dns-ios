from pathlib import Path
import json, plistlib, sys
root=Path(__file__).resolve().parents[1]
required=['README.md','AGENTS.md','HUMANS.md','PRIVACY.md','SUPPORT.md','LICENSE','project.yml','Config/Project.xcconfig','App/RecursiveDNSApp.swift','App/ContentView.swift','Proxy/DNSProxyProvider.swift','Resolver/DNSWire.swift','Resolver/IterativeResolver.swift','docs/index.html','docs/support.html','docs/privacy.html','Deployment/RecursiveDNS.mobileconfig','Deployment/NetworkDNSProxy.json','App/Assets.xcassets/AppIcon.appiconset/Contents.json']
missing=[p for p in required if not (root/p).is_file()]
if missing: raise SystemExit('Fehlende Dateien: '+', '.join(missing))
plistlib.loads((root/'Deployment/RecursiveDNS.mobileconfig').read_bytes())
json.loads((root/'Deployment/NetworkDNSProxy.json').read_text())
json.loads((root/'App/Assets.xcassets/AppIcon.appiconset/Contents.json').read_text())
text='\n'.join((root/p).read_text(errors='ignore') for p in ['README.md','Config/Project.xcconfig','Shared/Preferences.swift','Deployment/RecursiveDNS.mobileconfig','Deployment/NetworkDNSProxy.json'])
for value in ['de.floriankutzer.recursivedns','de.floriankutzer.recursivedns.proxy','group.de.floriankutzer.recursivedns']:
    if value not in text: raise SystemExit('Inkonsistente Kennung: '+value)
for p in root.rglob('*'):
    if p.is_file() and p.stat().st_size==0: raise SystemExit('Leere Datei: '+str(p.relative_to(root)))
print('Repository-Prüfung erfolgreich.')
