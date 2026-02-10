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

# FHEM IonoPanel Utility (OpenHamClock Style)

Ein FHEM-Modul, das Echtzeit-Ionosphären-Daten (Ionosonde) von **KC2G / GIRO** holt und im modernen Design der **OpenHamClock** visualisiert.

**Features in v5:**
* 🔽 **Dropdown-Menü:** Wähle aus über 100 weltweiten Ionosonden direkt in der FHEM-Oberfläche.
* 🛡️ **Robust:** Lädt die Master-Liste aller Stationen (verhindert 404-Fehler bei URL-Änderungen).
* ⚡ **Smart Update:** Verhindert "Ping-Pong"-Effekte bei schnellem Stationswechsel.
* 📈 **Sparklines:** 30-Punkte-Verlaufsdiagramme für foF2 und MUF mit automatischem Clipping (keine Grafikfehler bei Fehlmessungen).
* 📱 **Dashboard Ready:** Perfekt integrierbar in FHEMWEB oder `95_Dashboard.pm`.

![Preview](https://via.placeholder.com/400x220/111111/ffffff?text=IonoPanel+v5+Example)

---

## 📋 Voraussetzungen

* Eine laufende FHEM-Installation.
* Standard Perl-Module: `HttpUtils`, `JSON`, `List::Util` (meist vorinstalliert).
* Internetzugang am FHEM-Server (HTTPS zu `prop.kc2g.com`).

---

## 🛠 Installation

### 1. Utility-Datei erstellen
Erstelle die Datei im FHEM-Modulverzeichnis:

```bash
sudo nano /opt/fhem/FHEM/99_IonoPanelUtils.pm

# FHEM IonoPanel Utility (OpenHamClock Style)

Ein FHEM-Modul, das Echtzeit-Ionosphären-Daten (Ionosonde) von **KC2G / GIRO** holt und im modernen Design der **OpenHamClock** visualisiert.

**Features (v5):**
* 🔽 **Dropdown-Menü:** Wähle aus über 100 weltweiten Ionosonden direkt in der FHEM-Oberfläche.
* 🛡️ **Robust:** Lädt die Master-Liste aller Stationen (verhindert 404-Fehler).
* ⚡ **Smart Update:** Verhindert "Ping-Pong"-Effekte bei schnellem Stationswechsel.
* 📈 **Sparklines:** 30-Punkte-Verlaufsdiagramme für foF2 und MUF mit automatischem Clipping.
* 📱 **Dashboard Ready:** Perfekt integrierbar in FHEMWEB oder `95_Dashboard.pm`.

![Preview](https://via.placeholder.com/400x220/111111/ffffff?text=IonoPanel+v5+Example)

---

## 📋 Voraussetzungen

* Eine laufende FHEM-Installation.
* Standard Perl-Module: `HttpUtils`, `JSON`, `List::Util` (meist vorinstalliert).
* Internetzugang am FHEM-Server.

---

## 🛠 Installation (Schritt-für-Schritt)

### Schritt 1: Datei erstellen
Melde dich per SSH (Putty, Terminal) auf deinem FHEM-Server (z.B. Raspberry Pi) an.
Erstelle die Datei im FHEM-Modulverzeichnis:

```bash
cd /opt/fhem/FHEM
sudo nano 99_IonoPanelUtils.pm



# FHEM IonoPanel Utility (OpenHamClock Style)

Ein FHEM-Modul, das Echtzeit-Ionosphären-Daten (Ionosonde) von **KC2G / GIRO** holt und im modernen Design der **OpenHamClock** visualisiert.

**Features in v5:**
* 🔽 **Dropdown-Menü:** Wähle aus über 100 weltweiten Ionosonden direkt in der FHEM-Oberfläche.
* 🛡️ **Robust:** Lädt die Master-Liste aller Stationen (verhindert 404-Fehler bei URL-Änderungen).
* ⚡ **Smart Update:** Verhindert "Ping-Pong"-Effekte bei schnellem Stationswechsel.
* 📈 **Sparklines:** 30-Punkte-Verlaufsdiagramme für foF2 und MUF mit automatischem Clipping (keine Grafikfehler bei Fehlmessungen).
* 📱 **Dashboard Ready:** Perfekt integrierbar in FHEMWEB oder `95_Dashboard.pm`.

![Preview](https://via.placeholder.com/400x220/111111/ffffff?text=IonoPanel+v5+Example)

---

## 📋 Voraussetzungen

* Eine laufende FHEM-Installation.
* Standard Perl-Module: `HttpUtils`, `JSON`, `List::Util` (meist vorinstalliert).
* Internetzugang am FHEM-Server (HTTPS zu `prop.kc2g.com`).

---

## 🛠 Installation

### 1. Utility-Datei erstellen
Erstelle die Datei im FHEM-Modulverzeichnis:

```bash
sudo nano /opt/fhem/FHEM/99_IonoPanelUtils.pm

sudo chown fhem:dialout /opt/fhem/FHEM/99_IonoPanelUtils.pm
sudo chmod 644 /opt/fhem/FHEM/99_IonoPanelUtils.pm

reload 99_IonoPanelUtils.pm
# 1. Dummy Device definieren
define IonoPanel dummy
attr IonoPanel room Amateurfunk
attr IonoPanel group SpaceWeather
attr IonoPanel icon radar

# 2. Dropdown-Menü vorbereiten
# Wir nutzen das Reading 'station' zur Steuerung
attr IonoPanel readingList station
attr IonoPanel setList station
attr IonoPanel webCmd station

# 3. Anzeige auf das generierte HTML stellen
attr IonoPanel stateFormat html_ui

# 4. Notify für Stationswechsel
# Wenn im Dropdown eine neue Station gewählt wird, sofort Update starten
define IonoPanel_Notify notify IonoPanel:station:.* { IonoPanel_Update("IonoPanel") }

# 5. Timer für automatische Updates (alle 15 Minuten)
define IonoPanel_Timer at +*00:15:00 { IonoPanel_Update("IonoPanel") }
attr IonoPanel_Timer alignTime 00:05:00

# 6. INITIALISIERUNG (Einmalig ausführen!)
# Lädt die Liste aller Stationen für das Dropdown
{ IonoPanel_GetList("IonoPanel") }

# Zuweisung zur Dashboard-Gruppe (Beispiel: SpaceWeather)
attr IonoPanel group SpaceWeather

# Positionierung (Spalte 0, Zeile 0)
attr IonoPanel dashboard_col 0
attr IonoPanel dashboard_row 0

# (Optional) Breite/Höhe fixieren
attr IonoPanel dashboard_width 300
attr IonoPanel dashboard_height 180

