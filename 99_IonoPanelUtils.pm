##############################################
# 99_IonoPanelUtils.pm
#
# Holt die Master-Liste aller Ionosonden von KC2G
# und extrahiert die Daten für eine spezifische Station.
#
# URL: https://prop.kc2g.com/api/stations.json
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

sub IonoPanel_Update {
    my ($devName) = @_;
    
    # URL der Master-Liste
    my $url = "https://prop.kc2g.com/api/stations.json";
    
    # Station ID aus Attribut (Default: JR055 Juliusruh)
    my $stationID = AttrVal($devName, "station_id", "JR055");
    
    Log3 $devName, 3, "IonoPanel: Lade Stationsliste für Zielstation '$stationID'...";
    
    my $param = {
        url      => $url,
        timeout  => 15,
        hash     => $defs{$devName}, 
        callback => \&IonoPanel_Parse,
        devName  => $devName,
        targetID => $stationID,
        header   => "User-Agent: FHEM/IonoPanel\r\nAccept: application/json"
    };
    
    HttpUtils_NonblockingGet($param);
}

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

    # JSON Decodieren (Array von Stationen)
    my $json_list;
    eval { $json_list = decode_json($data); };
    if ($@) {
        Log3 $devName, 1, "IonoPanel JSON Error: $@";
        return;
    }

    # --- SUCHE NACH DER STATION ---
    my $found_station = undef;
    
    # Das JSON ist eine Liste von Objekten. Wir iterieren durch.
    foreach my $item (@$json_list) {
        # Pfad im JSON: item -> "station" -> "code"
        if (defined $item->{station} && defined $item->{station}->{code}) {
            if ($item->{station}->{code} eq $targetID) {
                $found_station = $item;
                last;
            }
        }
    }

    if (!defined $found_station) {
        Log3 $devName, 1, "IonoPanel: Station '$targetID' nicht in der Liste gefunden! Prüfe prop.kc2g.com für gültige Codes.";
        readingsSingleUpdate($hash, "state", "Error: Station '$targetID' not found", 1);
        return;
    }

    # Daten extrahieren
    my $fof2 = defined($found_station->{fof2}) ? sprintf("%.3f", $found_station->{fof2}) : "---";
    my $mufd = defined($found_station->{mufd}) ? sprintf("%.3f", $found_station->{mufd}) : "---";
    my $last_update = $found_station->{time} || "unknown";
    
    # Zeitformat kürzen (z.B. 2025-02-09T12:00 -> 12:00)
    if ($last_update =~ /T(\d{2}:\d{2})/) {
        $last_update = $1;
    }

    # Historie Helper
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

    # Readings
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "ion_fof2", $fof2);
    readingsBulkUpdate($hash, "ion_mufd", $mufd);
    readingsBulkUpdate($hash, "station",  $targetID);
    
    # Sparklines
    my $svg_fof2 = IonoPanel_GenerateSparkline($hash->{helper}{history_fof2}, '#00ff00'); 
    my $svg_mufd = IonoPanel_GenerateSparkline($hash->{helper}{history_mufd}, '#00ffff'); 

    # HTML UI
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

sub IonoPanel_GenerateSparkline {
    my ($values_ref, $color) = @_;
    my @values = @$values_ref;
    
    return "" if scalar(@values) < 2;

    my $min = min @values;
    my $max = max @values;
    if ($max == $min) { $max++; $min--; }
    my $range = $max - $min;
    
    my @points;
    my $count = scalar @values;
    
    for (my $i = 0; $i < $count; $i++) {
        my $x = ($i / ($count - 1)) * 100;
        my $y = 100 - (($values[$i] - $min) / $range) * 80 - 10;
        push @points, sprintf("%.1f,%.1f", $x, $y);
    }
    
    my $pStr = join(" ", @points);
    return qq(<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="overflow:visible; display:block;"><polyline points="$pStr" fill="none" stroke="$color" stroke-width="2" vector-effect="non-scaling-stroke" /></svg>);
}

1;
