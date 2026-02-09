##############################################
# 99_SolarPanelUtils.pm
#
# FHEM Utility für OpenHamClock Solar Panel
# Holt NOAA Daten und generiert SVG Sparklines
##############################################
package main;

use strict;
use warnings;
use HttpUtils;
use List::Util qw(min max);

sub SolarPanelUtils_Initialize {
    my ($hash) = @_;
}

# -------------------------------------------------------------------------
# Hauptfunktion: Startet den Download
# Aufruf in FHEM: { SolarPanel_Update("DeinDummyName") }
# -------------------------------------------------------------------------
sub SolarPanel_Update {
    my ($devName) = @_;
    
    # Prüfen, ob Device existiert
    if(!defined($defs{$devName})) {
        Log3 undef, 1, "SolarPanelUtils: Device $devName existiert nicht!";
        return;
    }

    my $url = "https://services.swpc.noaa.gov/text/daily-solar-indices.txt";
    
    my $param = {
        url      => $url,
        timeout  => 15,
        hash     => $defs{$devName}, 
        callback => \&SolarPanel_Parse,
        devName  => $devName
    };
    
    HttpUtils_NonblockingGet($param);
}

# -------------------------------------------------------------------------
# Callback: Daten empfangen, parsen und HTML generieren
# -------------------------------------------------------------------------
sub SolarPanel_Parse {
    my ($param, $err, $data) = @_;
    my $devName = $param->{devName};
    my $hash = $defs{$devName};
    
    if($err) {
        Log3 $devName, 1, "SolarPanelUtils Error: $err";
        readingsSingleUpdate($hash, "state", "Error: $err", 1);
        return;
    }

    my @lines = split("\n", $data);
    my @history;
    
    # Daten Parsen (Format: YYYY MM DD SFI SSN ...)
    foreach my $line (@lines) {
        next if ($line =~ /^#|^:/ || $line =~ /^\s*$/);
        
        # Regex für Fixed-Width Format der NOAA
        if ($line =~ /(\d{4})\s+(\d{2})\s+(\d{2})\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
            push @history, {
                date => "$1-$2-$3",
                sfi  => $4, # Solar Flux
                ssn  => $5, # Sunspot Number
                a    => $6, # A-Index
                k    => $7  # K-Index
            };
        }
    }

    # Wenn keine Daten gefunden wurden
    if (!@history) {
        Log3 $devName, 1, "SolarPanelUtils: Keine validen Daten im NOAA Feed gefunden.";
        return;
    }

    # Nur die letzten 30 Tage nehmen
    my @last30 = @history > 30 ? @history[-30 .. -1] : @history;
    my $current = $last30[-1];
    
    # Readings schreiben
    readingsBeginUpdate($hash);
    readingsBulkUpdate($hash, "solar_ssn", $current->{ssn});
    readingsBulkUpdate($hash, "solar_sfi", $current->{sfi});
    readingsBulkUpdate($hash, "solar_a",   $current->{a});
    readingsBulkUpdate($hash, "solar_k",   $current->{k});
    readingsBulkUpdate($hash, "solar_date", $current->{date});
    
    # SVGs Generieren (Cyan für SSN, Amber für SFI)
    my $svg_ssn = SolarPanel_GenerateSparkline(\@last30, 'ssn', '#00ffff', 0); 
    my $svg_sfi = SolarPanel_GenerateSparkline(\@last30, 'sfi', '#ffb432', 60);

    # HTML UI Generieren (Modern Layout)
    my $k_color = $current->{k} >= 4 ? '#ff4444' : '#00ff00';
    
    my $html = qq(
        <div style="background:#1a1a1a; color:#eee; font-family:sans-serif; padding:10px; border-radius:6px; border:1px solid #333; min-width:280px;">
            <div style="border-bottom:1px solid #444; margin-bottom:10px; padding-bottom:4px; font-weight:bold; color:#ffb432; font-size:14px;">SOLAR DATA</div>
            
            <div style="display:grid; grid-template-columns: 1fr 1fr; gap:10px; margin-bottom:10px;">
                <div style="background:#262626; padding:8px; border-radius:4px;">
                    <div style="font-size:11px; color:#888; margin-bottom:4px;">SSN</div>
                    <div style="display:flex; justify-content:space-between; align-items:flex-end;">
                        <div style="font-size:24px; font-weight:bold; color:#00ffff; line-height:1;">$current->{ssn}</div>
                        <div style="width:60px; height:35px;">$svg_ssn</div>
                    </div>
                </div>

                <div style="background:#262626; padding:8px; border-radius:4px;">
                    <div style="font-size:11px; color:#888; margin-bottom:4px;">SFI</div>
                    <div style="display:flex; justify-content:space-between; align-items:flex-end;">
                        <div style="font-size:24px; font-weight:bold; color:#ffb432; line-height:1;">$current->{sfi}</div>
                        <div style="width:60px; height:35px;">$svg_sfi</div>
                    </div>
                </div>
            </div>

            <div style="display:flex; gap:10px; font-size:13px;">
                <div style="background:#333; padding:4px 8px; border-radius:3px; flex:1; display:flex; justify-content:space-between;">
                    <span style="color:#aaa;">K-Index</span>
                    <span style="font-weight:bold; color:$k_color;">$current->{k}</span>
                </div>
                <div style="background:#333; padding:4px 8px; border-radius:3px; flex:1; display:flex; justify-content:space-between;">
                    <span style="color:#aaa;">A-Index</span>
                    <span style="font-weight:bold;">$current->{a}</span>
                </div>
            </div>
        </div>
    );
    
    # HTML bereinigen (Newlines entfernen für stateFormat)
    $html =~ s/[\r\n]//g;
    
    readingsBulkUpdate($hash, "html_ui", $html);
    readingsBulkUpdate($hash, "state", "Updated: " . TimeNow());
    readingsEndUpdate($hash, 1);
}

# -------------------------------------------------------------------------
# Helper: Generiert SVG Sparkline Code
# -------------------------------------------------------------------------
sub SolarPanel_GenerateSparkline {
    my ($data_ref, $key, $color, $min_limit) = @_;
    my @values = map { $_->{$key} } @$data_ref;
    
    return "" unless @values;

    my $min = min @values;
    my $max = max @values;
    
    # Skalierungs-Logik verbessern
    $min = $min_limit if (defined $min_limit && $min > $min_limit);
    $max = $min + 10 if ($max <= $min); 
    my $range = $max - $min;
    
    my @points;
    my $count = scalar @values;
    
    for (my $i = 0; $i < $count; $i++) {
        my $x = ($i / ($count - 1)) * 100;
        # Y invertieren (SVG 0,0 ist oben links), 10% Padding oben/unten
        my $val = $values[$i];
        my $y = 100 - (($val - $min) / $range) * 80 - 10;
        push @points, sprintf("%.1f,%.1f", $x, $y);
    }
    
    my $points_str = join(" ", @points);
    
    # SVG return (Inline Style wichtig für FHEMWEB)
    return qq(<svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none" style="overflow:visible"><line x1="0" y1="50" x2="100" y2="50" stroke="rgba(255,255,255,0.15)" stroke-width="1" vector-effect="non-scaling-stroke"/><polyline points="$points_str" fill="none" stroke="$color" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke" /></svg>);
}

1;
