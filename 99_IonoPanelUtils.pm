##############################################
# 99_IonoPanelUtils.pm
#
# FHEM Utility für OpenHamClock IonoPanel Style
# Datenquelle: KC2G Ionosonde API (Master List)
#
# Features:
# - Lädt stations.json (vermeidet 404 Fehler)
# - Filtert Fehlmessungen (Sanity Check)
# - Generiert Sparklines mit Clipping (kein Überlaufen)
##############################################
package main;

use strict;
use warnings;
use HttpUtils;
use JSON;
use List::Util qw(min max);

sub IonoPanelUtils_Initialize {
    my ($hash) = @_;
}

# -------------------------------------------------------------------------
# Update Funktion
# -------------------------------------------------------------------------
sub IonoPanel_Update {
    my ($devName) = @_;
    
    # URL der Master-Liste aller Stationen
    my $url = "https://prop.kc2g.com/api/stations.json";
    
    # Station ID aus Attribut lesen (Default: JR055 Juliusruh)
    my $stationID = AttrVal($devName, "station_id", "JR055");
    
    Log3 $devName, 3, "IonoPanel: Lade Stationsliste für Ziel '$stationID'...";
    
    my $param = {
        url      => $url,
        timeout  => 15,
        hash     => $defs{$devName}, 
        callback => \&IonoPanel_Parse,
        devName  => $devName,
        targetID => $stationID,
        # Wichtig: User-Agent setzen, sonst blockiert KC2G manchmal
        header   => "User-Agent: FHEM/IonoPanel\r\nAccept: application/json"
    };
    
    HttpUtils_NonblockingGet($param);
}

# -------------------------------------------------------------------------
# Callback: JSON Parsen und HTML bauen
# -------------------------------------------------------------------------
sub IonoPanel_Parse {
    my ($param, $err, $data) = @_;
    my $devName  = $param->{devName};
    my $targetID = $param->{targetID};
    my $hash     = $defs{$devName};
    
    if($err) {
        Log3 $devName, 1, "IonoPanel Error: HTTP Fehler: $err";
        readingsSingleUpdate($hash, "state", "HTTP Error", 1);
        return;
    }

    # JSON Decodieren
    my $json_list;
    eval { $json_list = decode_json($data); };
    if ($@) {
        Log3 $devName, 1, "IonoPanel JSON Error: $@";
        return;
    }

    # --- SUCHE NACH DER STATION IN DER LISTE ---
    my $found_station = undef;
    foreach my $item (@$json_list) {
        if (defined $item->{station} && defined $item->{station}->{code}) {
            if ($item->{station}->{code} eq $targetID) {
                $found_station = $item;
                last;
            }
        }
    }

    if (!defined $found_station) {
        Log3 $devName, 1, "IonoPanel: Station '$targetID' nicht in der Liste gefunden! Bitte prop.kc2g.com prüfen.";
        readingsSingleUpdate($hash, "state", "Error: Station not found", 1);
        return;
    }

    # --- DATEN EXTRAHIEREN & SANITY CHECK ---
    # Ionosonden liefern oft Müll (z.B. 99MHz oder -1). Wir filtern das.
    
    my $raw_fof2 = $found_station->{fof2};
    my $raw_mufd = $found_station->{mufd};

    # Filter: Nur Werte zwischen 0.5 und 60 MHz sind realistisch
    my $fof2 = (defined($raw_fof2) && $raw_fof2 > 0.5 && $raw_fof2 < 40) ? sprintf("%.3f", $raw_fof2) : "---";
    my $mufd = (defined($raw_mufd) && $raw_mufd > 0.5 && $raw_mufd < 80) ? sprintf("%.3f", $raw_mufd) : "---";
    
    # Zeit formatieren
    my $last_update = $found_station->{time} || "unknown";
    if ($last_update =~ /T(\d{2}:\d{2})/) { $last_update = $1; }

    # --- HISTORIE ---
    $hash->{helper}{history_fof2} = [] unless defined $hash->{helper}{history_fof2};
    $hash->{helper}{history_mufd} = [] unless defined $hash->{helper}{history_mufd};

    # Nur pushen, wenn valide Zahl (kein "---")
    if($fof2 ne "---") {
        push @{$hash->{helper}{history_fof2}}, $fof2;
        shift @{$hash->{helper}{history_fof2}} if scalar(@{$hash->{helper}{history_fof2}}) > 30;
    }
    if($mufd ne "---") {
        push @{$hash->{helper}{history_mufd}}, $mufd;
        shift @{$hash->{helper}{history_mufd}} if scalar(@{$hash->{helper}{history_mufd}}) > 30;
    }

    # --- READINGS UPDATE ---
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "ion_fof2", $fof2);
    readingsBulkUpdate($hash, "ion_mufd", $mufd);
    readingsBulkUpdate($hash, "station",  $targetID);
    
    # --- SVG GENERIERUNG ---
    my $svg_fof2 = IonoPanel_GenerateSparkline($hash->{helper}{history_fof2}, '#00ff00'); 
    my $svg_mufd = IonoPanel_GenerateSparkline($hash->{helper}{history_mufd}, '#00ffff'); 
    
    my $station_name = $found_station->{station}->{name} // $targetID;

    # --- HTML UI (Modern Layout) ---
    my $html = qq(
        <div style="background:#111; color:#eee; font-family:sans-serif; padding:10px; border-radius:5px; border:1px solid #333; min-width:280px;">
            <div style="border-bottom:1px solid #444; margin-bottom:10px; padding-bottom:4px; font-weight:bold; color:#00ff00; font-size:14px;">
                IONO: $station_name ($targetID)
            </div>
            
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:10px;">
                <div style="background:#222; padding:8px; border-radius:4px;">
                    <div style="font-size:11px; color:#888;">foF2 (MHz)</div>
                    <div style="display:flex; justify-content:space-between; align-items:flex-end;">
                        <div style="font-size:24px; font-weight:bold; color:#00ff00; line-height:1;">$fof2</div>
                        <div style="width:60px; height:35px;">$svg_fof2</div>
                    </div>
                </div>

                <div style="background:#222; padding:8px; border-radius:4px;">
                    <div style="font-size:11px; color:#888;">MUF(3000)</div>
                    <div style="display:flex; justify-content:space-between; align-items:flex-end;">
                        <div style="font-size:24px; font-weight:bold; color:#00ffff; line-height:1;">$mufd</div>
                        <div style="width:60px; height:35px;">$svg_mufd</div>
                    </div>
                </div>
            </div>
            <div style="font-size:11px; color:#666; text-align:right;">Updated: $last_update</div>
        </div>
    );

    $html =~ s/[\r\n]//g;
    readingsBulkUpdate($hash, "html_ui", $html);
    readingsBulkUpdate($hash, "state", "Updated " . TimeNow());
    readingsEndUpdate($hash, 1);
}

# -------------------------------------------------------------------------
# Helper: Generiert SVG Code
# Fix: overflow:hidden verhindert, dass Linie aus dem Bild springt
# -------------------------------------------------------------------------
sub IonoPanel_GenerateSparkline {
    my ($values_ref, $color) = @_;
    my @values = @$values_ref;
    
    # Keine Linie wenn zu wenig Daten
    return "" if scalar(@values) < 2;

    my $min = min @values;
    my $max = max @values;
    
    # Division durch Null verhindern bei flacher Linie
    if ($max == $min) { $max = $min + 0.1; }
    
    my $range = $max - $min;
    $range = 0.1 if ($range < 0.001); # Sicherheitsnetz

    my @points;
    my $count = scalar @values;
    
    for (my $i = 0; $i < $count; $i++) {
        my $x = ($i / ($count - 1)) * 100;
        
        my $val = $values[$i];
        
        # Clamp Values (Sicherstellen, dass Wert innerhalb Range ist)
        $val = $max if $val > $max;
        $val = $min if $val < $min;
        
        # Y berechnen (10% Padding oben/unten)
        my $y = 100 - (($val - $min) / $range) * 80 - 10;
        
        push @points, sprintf("%.1f,%.1f", $x, $y);
    }
    
    my $pStr = join(" ", @points);
    
    # WICHTIG: style="overflow:hidden" schneidet Überstände ab!
    return qq(<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="overflow:hidden; display:block;"><polyline points="$pStr" fill="none" stroke="$color" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" /></svg>);
}

1;
    
