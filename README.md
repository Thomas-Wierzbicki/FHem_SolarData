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

# FHEM SolarPanel Utility (OpenHamClock Style)

Dieses FHEM-Erweiterungsmodul bringt die moderne Solar-Daten-Anzeige der **OpenHamClock** in dein FHEM Dashboard. Es ruft aktuelle Weltraumwetter-Daten der NOAA ab und visualisiert diese mit **SVG-Sparklines** (Verlaufsdiagrammen) direkt im FHEMWEB.

![Preview](https://via.placeholder.com/400x200/111111/ffffff?text=Solar+Panel+Preview) 
*(Beispiel: Zeigt SFI, SSN, A-Index und K-Index im Dark Mode)*

## 🚀 Features

* **Datenquelle:** Direkter Abruf der `daily-solar-indices.txt` vom NOAA SWPC.
* **Visualisierung:**
    * **SSN (Sunspot Number):** Aktueller Wert + 30-Tage-Verlauf (Cyan).
    * **SFI (Solar Flux Index):** Aktueller Wert + 30-Tage-Verlauf (Amber).
    * **Indizes:** K-Index (mit Farbwarnung grün/rot) und A-Index.
* **Technologie:** Generiert reines HTML/SVG, das in jedem FHEM-Browser (Desktop & Mobile) ohne zusätzliche Plugins funktioniert.
* **Non-Blocking:** Der Datenabruf erfolgt asynchron via `HttpUtils`, sodass FHEM während des Ladens nicht einfriert.

## 📋 Voraussetzungen

* Eine laufende FHEM-Installation.
* Standard Perl-Module (meistens bereits vorinstalliert):
    * `HttpUtils` (Teil von FHEM)
    * `List::Util` (Core Perl Modul)
* Internetzugang für den FHEM-Server (für HTTPS-Zugriff auf `services.swpc.noaa.gov`).

## 🛠 Installation

### 1. Utility-Datei erstellen
Erstelle eine neue Datei im FHEM-Modulverzeichnis (meist `/opt/fhem/FHEM/`):

```bash
sudo nano /opt/fhem/FHEM/99_SolarPanelUtils.pm

# FHEM IonoPanel Utility (OpenHamClock Style)

Dieses FHEM-Modul holt Echtzeit-Ionosphären-Daten (Ionosonde) von **KC2G / GIRO** und visualisiert sie im modernen Design der **OpenHamClock**. Es zeigt die kritische Frequenz (**foF2**) und die maximal nutzbare Frequenz (**MUF**) für eine gewählte Station an, inklusive historischer Verlaufsdiagramme (Sparklines).

![Preview](https://via.placeholder.com/400x200/111111/ffffff?text=IonoPanel+Preview+foF2+MUF)
*(Beispiel: Zeigt foF2 und MUF für Juliusruh oder Dourbes im Dark Mode)*

## 🚀 Features

* **Datenquelle:** Lädt die Master-Liste von `prop.kc2g.com` und extrahiert die gewünschte Station.
* **Visualisierung:**
    * **foF2:** Kritische Frequenz der F2-Schicht (Grün).
    * **MUF(3000):** Maximum Usable Frequency für 3000km Sprungdistanz (Cyan).
    * **Sparklines:** 30-Punkte-Verlaufsdiagramm direkt im Reading.
* **Robustheit:** * Fängt HTTP- und JSON-Fehler ab.
    * Funktioniert auch, wenn die Station nicht unter einer direkten URL erreichbar ist (durch Parsen der Gesamtliste).
* **Non-Blocking:** Der FHEM-Server friert während des Ladens nicht ein.

## 📋 Voraussetzungen

* Laufende FHEM-Installation.
* Perl-Module (Standard): `HttpUtils`, `JSON`, `List::Util`.
* Internetzugang am FHEM-Server.

## 🛠 Installation

### 1. Utility-Datei erstellen
Erstelle eine neue Datei im FHEM-Verzeichnis:

```bash
sudo nano /opt/fhem/FHEM/99_IonoPanelUtils.pm
