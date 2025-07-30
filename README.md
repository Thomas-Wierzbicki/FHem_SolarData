# FHEM Modul: 98_ionos_kc2g.pm

Dieses Modul integriert ionosphärische Stationsdaten von [https://prop.kc2g.com](https://prop.kc2g.com) in das FHEM-System. Es ruft regelmäßig Informationen zu Empfängerstationen ab, die für HF-Ausbreitungsvorhersagen relevant sind.

## 🌐 Quelle der Daten

- URL: `https://prop.kc2g.com/api/stations.json`
- Format: JSON
- Inhalt: Informationen über ionosphärische Empfängerstationen weltweit

## 📦 Installation

1. Moduldatei `98_ionos_kc2g.pm` in das Verzeichnis `FHEM/` kopieren.
2. FHEM neu starten oder `reload 98_ionos_kc2g.pm` im FHEM-Frontend eingeben.
3. Device definieren:

```perl
define Ionos_KC2G ionos_kc2g
```

## ⚙️ Attribute

| Attribut     | Beschreibung                                           |
|--------------|--------------------------------------------------------|
| `stationId`  | Liste verfügbarer Stationen-IDs (automatisch geladen) |

## 🔄 Funktionen

- `ionos_kc2g_updateStationList`: Lädt die aktuelle Liste der Stationen von kc2g.com herunter und aktualisiert das Attribut `stationId`.

## 📝 Logging (empfohlen)

Zur Auswertung der Logausgaben kann ein FileLog-Device definiert werden:

```perl
define FileLog_ionos_kc2g FileLog ./log/ionos_kc2g-%Y-%m-%d.log ionos_kc2g
attr FileLog_ionos_kc2g logtype text
attr FileLog_ionos_kc2g loglevel 3
```

## 🧪 Beispielausgabe im Log

```text
2025.07.29 20:44:01 3: ionos_kc2g (IONOS): stationId-AttrList gesetzt mit WWV,DK0WCY,JA2IGY,...
```

## 🛠️ TODO

- Anzeige der Stationsdaten im FHEM-Device
- Periodisches Update per Timer
- Unterstützung für weitere APIs von kc2g.com (z. B. MUF, HF-Map)

## 📄 Lizenz

Dieses Modul steht unter der MIT-Lizenz. Siehe `LICENSE` für Details.

## 👤 Autor

Thomas Wierzbicki  
[KC2G Propagation Tools](https://prop.kc2g.com) – Datenquelle
