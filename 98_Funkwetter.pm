package main;
use strict;
use warnings;
use HttpUtils;
use JSON;

sub Funkwetter_Initialize {
  my ($h) = @_;
  $h->{DefFn}    = 'Funkwetter_Define';
  $h->{UndefFn}  = 'Funkwetter_Undef';
  $h->{GetFn}    = 'Funkwetter_Get';
  $h->{AttrList} = 'interval:300,600,900,1800';
}

sub Funkwetter_Define {
  my ($h, $def) = @_;
  return "Usage: define <name> Funkwetter" unless defined $def;
  $h->{INTERVAL} = AttrVal($h->{NAME}, 'interval', 600);
  RemoveInternalTimer($h);
  Funkwetter_Update($h);
  return undef;
}

sub Funkwetter_Undef {
  my ($h, $n) = @_;
  RemoveInternalTimer($h);
  return undef;
}

sub Funkwetter_Get {
  my ($h,$n,$c) = @_;
  return "Unknown cmd" unless $c eq 'update';
  Funkwetter_Update($h);
  return "Funkwetter manuell aktualisiert";
}

sub Funkwetter_Update {
  my ($h) = @_;
  my $n = $h->{NAME};

  my @requests = (
    [ 'https://services.swpc.noaa.gov/products/noaa-planetary-k-index.json', sub { Funkwetter_ParseK(@_, 'KIndex') } ],  # ok
    [ 'https://services.swpc.noaa.gov/json/f107_cm_flux.json', sub { Funkwetter_ParseFlux(@_, 'SFI') } ],  # ok
    [ 'https://services.swpc.noaa.gov/text/daily-geomagnetic-indices.txt', \&Funkwetter_ParseDailyIndices ], # ok
    [ 'https://services.swpc.noaa.gov/json/geoalert.json', \&Funkwetter_ParseGeoalert ], # nein
    [ 'https://services.swpc.noaa.gov/json/goes/xray-flux.json', \&Funkwetter_ParseXray ], # nein
    [ 'https://services.swpc.noaa.gov/json/drap/global_d_region_absorption.json', \&Funkwetter_ParseDrap ], # nein
    [ 'https://services.swpc.noaa.gov/text/daily-solar-indices.txt', \&Funkwetter_ParseForecast ] # ok
  );

  for my $r (@requests) {
    HttpUtils_NonblockingGet({
      url      => $r->[0],
      timeout  => 15,
      hash     => $h,
      callback => $r->[1]
    });
  }

  my $i = AttrVal($n,'interval',600);
  RemoveInternalTimer($h);
  InternalTimer(gettimeofday()+$i, \&Funkwetter_Update, $h);

#---------------------------------------------------------------
#  use myUtils qw(Funkwetter_UpdateState);
#  Funkwetter_UpdateState($h);
#---------------------------------------------------------------
}


sub Funkwetter_KpToStormLevel {
  my ($kp) = @_;
  return '' if (!defined $kp || $kp !~ /^[0-9.]+$/);
  return 'G5 – Extreme' if $kp >= 9;
  return 'G4 – Severe'  if $kp >= 8;
  return 'G3 – Strong'  if $kp >= 7;
  return 'G2 – Moderate'if $kp >= 6;
  return 'G1 – Minor'   if $kp >= 5;
  return 'G0 – nil'     if $kp >= 0;
  return '';
}



sub Funkwetter_ParseK {
  my ($p, $err, $d, $reading) = @_;
  my $h = $p->{hash};
  return if $err;
  my $j = eval { decode_json($d) };
  return if $@ or ref($j) ne 'ARRAY';
  my $rec = $j->[-1];
  
  readingsSingleUpdate($h, $reading, $rec->[1], 1);
  #
  my $storm = Funkwetter_KpToStormLevel($rec->[1]);
  readingsSingleUpdate($h, "Storm_Level", $storm, 1);
  #
  Funkwetter_UpdateState($h);
}

sub Funkwetter_ParseFlux {
  my ($p, $err, $d, $reading) = @_;
  my $h = $p->{hash};
  my $j = eval { decode_json($d) };
  return if $@ or ref($j) ne 'ARRAY';
  my $rec = $j->[0];
  readingsSingleUpdate($h, $reading, $rec->{flux}, 1) if $rec->{flux};
  Funkwetter_UpdateState($h);
}

sub Funkwetter_ParseDailyIndices {
  my ($p, $err, $d) = @_;
  my $h = $p->{hash};
  my $n = $h->{NAME};
  if ($err) {
    readingsSingleUpdate($h, 'AIndex_Error', "Fehler: $err", 1);
    return;
  }

  my %targets = map {
    sprintf("%04d-%02d-%02d", $_->[0], $_->[1], $_->[2]) => 1
  } (
    [ (localtime)[5]+1900, (localtime)[4]+1, (localtime)[3] ],
    [ (localtime(time - 86400))[5]+1900, (localtime(time - 86400))[4]+1, (localtime(time - 86400))[3] ]
  );

  my $found = 0;
  foreach my $line (split /\n/, $d) {
    next unless $line =~ /^\s*\d{4}/;
    my @f = split /\s+/, $line;
    my ($y, $m, $d1) = @f[0,1,2];
    my $key = sprintf("%04d-%02d-%02d", $y, $m, $d1);
    next unless $targets{$key};

    my ($Ap, $Amid, $Ahigh) = @f[3, 23, 33];
    readingsBeginUpdate($h);
    readingsBulkUpdate($h, 'AIndex_Planetary', $Ap);
    readingsBulkUpdate($h, 'AIndex_MidLat',    $Amid);
    readingsBulkUpdate($h, 'AIndex_HighLat',   $Ahigh);
    readingsBulkUpdate($h, 'AIndex_Error',     '');
    readingsEndUpdate($h, 1);
    Funkwetter_CheckWarning($h, $Ap);
    Funkwetter_UpdateState($h);
    $found = 1;
    last;
  }

  readingsSingleUpdate($h, 'AIndex_Error', 'Kein Tageswert gefunden', 1) unless $found;
}

sub Funkwetter_ParseGeoalert {
  my ($p, $err, $d) = @_;
  my $h = $p->{hash};
  my $j = eval { decode_json($d) };
  return if $@ or ref($j) ne 'ARRAY';
  my $a = $j->[0]{message};
  readingsSingleUpdate($h, 'GeoAlert', $a, 1) if $a;
}

sub Funkwetter_ParseXray {
  my ($p, $err, $d) = @_;
  my $h = $p->{hash};
  my $j = eval { decode_json($d) };
  return if $@ or ref($j) ne 'ARRAY';
  my $latest = $j->[-1];
  readingsSingleUpdate($h, 'XRayFlux', $latest->{flux}, 1) if $latest->{flux};
}

sub Funkwetter_ParseDrap {
  my ($p, $err, $d) = @_;
  my $h = $p->{hash};
  my $j = eval { decode_json($d) };
  return if $@ or ref($j) ne 'HASH';
  my $value = $j->{drap_index};
  readingsSingleUpdate($h, 'DrapIndex', $value, 1) if defined $value;
}



sub Funkwetter_ParseForecast {
  my ($p, $err, $d) = @_;
  my $h = $p->{hash};
  my $n = $h->{NAME};

  if ($err) {
    readingsSingleUpdate($h, 'Forecast_Error', "Fehler: $err", 1);
    return;
  }

  my ($yy, $mm, $dd) = (localtime(time + 86400))[5,4,3];
  $yy += 1900; $mm += 1;

  my $target = sprintf("%04d %2d %2d", $yy, $mm, $dd);
  my $last_line = '';
  my $matched = 0;

  foreach my $line (reverse split /\n/, $d) {
    next unless $line =~ /^\s*\d{4}/;
    $last_line ||= $line;
    if ($line =~ /^\s*$yy\s+$mm\s+$dd/) {
      $last_line = $line;
      $matched = 1;
      last;
    }
  }

  if ($last_line) {
    my @f = split /\s+/, $last_line;

    my $flux   = $f[3];
    my $ssn    = $f[4];
    my $area   = $f[5];
    my $xclass = $f[9];

    readingsBeginUpdate($h);
    readingsBulkUpdate($h, 'SFI_DSD', $flux);
    readingsBulkUpdate($h, 'SunspotNumber_DSD', $ssn);
    readingsBulkUpdate($h, 'SunspotArea_DSD', $area);
    readingsBulkUpdate($h, 'XRayClass_DSD', $xclass);
    readingsBulkUpdate($h, 'Forecast_Error', $matched ? '' : 'Kein Wert für morgen, letzter Wert verwendet');
    readingsEndUpdate($h, 1);
  } else {
    readingsSingleUpdate($h, 'Forecast_Error', 'Keine brauchbaren Werte in Datei gefunden', 1);
  }
}




sub Funkwetter_CheckWarning {
  my ($h, $aindex) = @_;
  my $kindex = ReadingsVal($h->{NAME}, 'KIndex', ReadingsVal($h->{NAME}, 'KIndex_Planetary', 0));
  return unless ($aindex > 30 && $kindex > 6);
  my $msg = "Warnung: A-Index $aindex und K-Index $kindex – schlechte Funkbedingungen.";
  fhem("set say text2speech $msg");
}

1;

