##############################################
# 99_IonoPanelUtils.pm
#
# FHEM Utility für OpenHamClock IonoPanel
# V5: Fix für "Ping-Pong" Updates & Loop-Schutz
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
# Hilfsfunktion: Lädt ALLE Stationen für das Dropdown
# -------------------------------------------------------------------------
sub IonoPanel_GetList {
    my ($devName) = @_;
    Log3 $devName, 3, "IonoPanel: Lade Stationsliste für Dropdown...";
    
    my $param = {
        url      => "https://prop.kc2g.com/api/stations.json",
        timeout  => 15,
        hash     => $defs{$devName}, 
        callback => \&IonoPanel_BuildSetList,
        devName  => $devName,
        header   => "User-Agent: FHEM/IonoPanel\r\nAccept: application/json"
    };
    HttpUtils_NonblockingGet($param);
}

sub IonoPanel_BuildSetList {
    my ($param, $err, $data) = @_;
    my $devName = $param->{devName};
    
    if($err) { Log3 $devName, 1, "IonoPanel: Fehler beim Laden der Liste: $err"; return; }

    my $json_list;
    eval { $json_list = decode_json($data); };
    if ($@) { return; }

    my @stations;
    foreach my $item (@$json_list) {
        if (defined $item->{station} && defined $item->{station}->{code}) {
            my $code = $item->{station}->{code};
            push @stations, "$code";
        }
    }
    @stations = sort @stations;
    my $listStr = join(",", @stations);
    
    fhem("attr $devName setList station:$listStr");
    Log3 $devName, 3, "IonoPanel: Dropdown aktualisiert.";
}

# -------------------------------------------------------------------------
# Haupt-Update Funktion
# -------------------------------------------------------------------------
sub IonoPanel_Update {
    my ($devName) = @_;
    
    # Aktuelle Auswahl lesen
    my $stationID = ReadingsVal($devName, "station", AttrVal($devName, "station_id", "JR055"));
    
    # Fallback, falls Reading leer
    if(ReadingsVal($devName, "station", "na") eq "na") {
        readingsSingleUpdate($defs{$devName}, "station", $stationID, 0);
    }

    Log3 $devName, 3, "IonoPanel: Update gestartet für '$stationID'...";
    
    my $param = {
        url      => "https://prop.kc2g.com/api/stations.json",
        timeout  => 15,
        hash     => $defs{$devName}, 
        callback => \&IonoPanel_Parse,
        devName  => $devName,
        targetID => $stationID,  # Wir merken uns, welche Station wir angefragt haben
        header   => "User-Agent: FHEM/IonoPanel\r\nAccept: application/json"
    };
    
    HttpUtils_NonblockingGet($param);
}

# -------------------------------------------------------------------------
# Parsing
# -------------------------------------------------------------------------
sub IonoPanel_Parse {
    my ($param, $err, $data) = @_;
    my $devName  = $param->{devName};
    my $targetID = $param->{targetID}; # Das war die Station BEIM START der Anfrage
    my $hash     = $defs{$devName};
    
    # 1. LOOP-SCHUTZ & PING-PONG FIX
    # Prüfen, ob die aktuell eingestellte Station immer noch die ist, die wir angefragt haben.
    # Wenn der User inzwischen gewechselt hat, verwerfen wir diese alten Daten.
    my $current_selection = ReadingsVal($devName, "station", "");
    if ($targetID ne $current_selection) {
        Log3 $devName, 3, "IonoPanel: Verwerfe alte Daten für '$targetID' (Aktuell gewählt: '$current_selection').";
        return;
    }

    if($err) {
        readingsSingleUpdate($hash, "state", "HTTP Error", 1);
        return;
    }

    my $json_list;
    eval { $json_list = decode_json($data); };
    if ($@) { return; }

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
        readingsSingleUpdate($hash, "state", "Error: Station not found", 1);
        return;
    }

    # Daten extrahieren & Filter
    my $raw_fof2 = $found_station->{fof2};
    my $raw_mufd = $found_station->{mufd};
    my $fof2 = (defined($raw_fof2) && $raw_fof2 > 0.5 && $raw_fof2 < 40) ? sprintf("%.3f", $raw_fof2) : "---";
    my $mufd = (defined($raw_mufd) && $raw_mufd > 0.5 && $raw_mufd < 80) ? sprintf("%.3f", $raw_mufd) : "---";
    
    my $last_update = $found_station->{time} || "unknown";
    if ($last_update =~ /T(\d{2}:\d{2})/) { $last_update = $1; }

    # Historie resetten bei Stationswechsel
    if ( defined($hash->{helper}{last_station}) && $hash->{helper}{last_station} ne $targetID ) {
         $hash->{helper}{history_fof2} = [];
         $hash->{helper}{history_mufd} = [];
    }
    $hash->{helper}{last_station} = $targetID;

    $hash->{helper}{history_fof2} = [] unless defined $hash->{helper}{history_fof2};
    $hash->{helper}{history_mufd} = [] unless defined $hash->{helper}{history_mufd};

    if($fof2 ne "---") {
        push @{$hash->{helper}{history_fof2}}, $fof2;
        shift @{$hash->{helper}{history_fof2}} if scalar(@{$hash->{helper}{history_fof2}}) > 30;
    }
    if($mufd ne "---") {
        push @{$hash->{helper}{history_mufd}}, $mufd;
        shift @{$hash->{helper}{history_mufd}} if scalar(@{$hash->{helper}{history_mufd}}) > 30;
    }

    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "ion_fof2", $fof2);
    readingsBulkUpdate($hash, "ion_mufd", $mufd);
    
    # FIX 2: Wir aktualisieren NICHT mehr das Reading "station".
    # Das hat den Loop ausgelöst. Das Reading ist eh schon korrekt (vom User gesetzt).
    # readingsBulkUpdate($hash, "station",  $targetID);  <-- ENTFERNT!
    
    my $svg_fof2 = IonoPanel_GenerateSparkline($hash->{helper}{history_fof2}, '#00ff00'); 
    my $svg_mufd = IonoPanel_GenerateSparkline($hash->{helper}{history_mufd}, '#00ffff'); 
    
    my $station_name = $found_station->{station}->{name} // $targetID;

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
# SVG Generator (mit Überlauf-Schutz)
# -------------------------------------------------------------------------
sub IonoPanel_GenerateSparkline {
    my ($values_ref, $color) = @_;
    my @values = @$values_ref;
    return "" if scalar(@values) < 2;

    my $min = min @values;
    my $max = max @values;
    if ($max == $min) { $max = $min + 0.1; }
    my $range = $max - $min; 
    $range = 0.1 if ($range < 0.001);

    my @points;
    my $count = scalar @values;
    for (my $i = 0; $i < $count; $i++) {
        my $x = ($i / ($count - 1)) * 100;
        my $val = $values[$i];
        $val = $max if $val > $max; 
        $val = $min if $val < $min;
        my $y = 100 - (($val - $min) / $range) * 80 - 10;
        push @points, sprintf("%.1f,%.1f", $x, $y);
    }
    my $pStr = join(" ", @points);
    return qq(<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="overflow:hidden; display:block;"><polyline points="$pStr" fill="none" stroke="$color" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" /></svg>);
}

1;
