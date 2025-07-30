##############################################
# $Id: myUtilsTemplate.pm 21509 2020-03-25 11:20:51Z rudolfkoenig $
#
# Save this file as 99_myUtils.pm, and create your own functions in the new
# file. They are then available in every Perl expression.

package main;

use strict;
use warnings;


use Exporter qw(import);
our @EXPORT_OK = qw(Funkwetter_UpdateState);



sub
myUtils_Initialize($$)
{
  my ($hash) = @_;
}

# Enter you functions below _this_ line.


sub toComparable {
   my ($date) = @_;
   my ($H,$M,$S) = $date =~ m{^([0-9]{2}):([0-9]{2}):([0-9]{2})}
      or die;
   return "$H$M$S";
}

my %lightsources = ('candle', 1500,
					'sodium-vapor', 2000,
					'bulb40', 2600,
					'bulb60', 2700,
					'bulb100', 2800,
					'bulb200', 3000,
					'halogen', 2750,
					'fluorescent', 4000,
					'morning-evening', 5000,
					'forenoon-afternoon', 5500,
					'noon-cloudy', 5800,
					'cloudy', 7000,
					'fog', 8000,
					'bluehour', 10000,
					'night', 15000
);

sub setColorProgram($@)
{
	# $mode string: 0 - on/off no color change, 1 - random color (rgb), 2 - twilight dependend color and brightness (ct, pct)
	# @lamps array: names of the hue devices
	
	my ($mode, @lamps) = @_;
	foreach (@lamps) {
		if (OldValue($_) eq "off") {	
			if ($mode eq '0') {
			}
			elsif ($mode eq '1')
			{
				my ($r, $g, $b) = (int(rand(256)), int(rand(256)), int(rand(256)));
				{fhem("set $_ rgb ".sprintf("%02x%02x%02x", $r, $g, $b))};;
			}
			elsif ($mode eq '2') {
				{fhem("set $_ pct ".getBrightnessTwilight())};;
				{fhem("set $_ color ".getColorTwilight())};;
			}
			{fhem ("setstate ".$_." on")};;
		} else {
			{fhem("set $_ off")};;
			{fhem ("setstate ".$_." off")};;
		}
	}
}

sub setColorProgram1($@)
{
	# $mode string: 0 - on/off no color change, 1 - random color (rgb), 2 - twilight dependend color and brightness (ct, pct)
	# @lamps array: names of the hue devices
	
	my ($zeit,$mode, @lamps) = @_;
	foreach (@lamps) {
			
			if ($mode eq '0') {
			}
			elsif ($mode eq '1')
			{
				my ($r, $g, $b) = (int(rand(256)), int(rand(256)), int(rand(256)));
				{fhem("set $_ rgb ".sprintf("%02x%02x%02x", $r, $g, $b))};;
                                {fhem("set $_ on-for-timer $zeit ")};;
			}
			elsif ($mode eq '2') {
				{fhem("set $_ pct ".getBrightnessTwilight())};;
				{fhem("set $_ color ".getColorTwilight())};;
                                {fhem("set $_ on-for-timer $zeit ")};;
			
		
		}
	}
}


sub getBrightnessTwilight()
{
	# Returns the brightness calculated with the twilight module named "twilight" in pct
	
	my $licht = ReadingsVal("twilight","light","6");
	my $val = 0;
	# Maximum daylight
	if($licht eq 6){
		$val = 10;
	}
	# Weather twilight
	elsif($licht eq 5){
		$val = 100;
	}
	# Twilight
	elsif($licht eq 4){
		$val = 70;
	}
	# Civil twilight
	elsif($licht eq 3){
		$val = 70;
	}
	# Nautical twilight
	elsif($licht eq 2){
		$val = 80;
	}
	# Astronomical twilight
	elsif($licht eq 1){
	$val = 90;
	}
	# Night
	elsif($licht eq 0){
		$val = 100;
	}
	return $val
}
	
sub getColorTwilight()
{
	# Returns the color temperature calculated with the twilight module named "twilight" in ct.
	
	my $t_now = localtime->strftime('%H%M%S');
	my $t_sunrise = toComparable(ReadingsVal("twilight","sr","06:00:00"));
	my $t_bluehour_sunrise = toComparable(ReadingsVal("twilight","sr_civil","06:00:00"));
	my $t_sunset = toComparable(ReadingsVal("twilight","ss","06:00:00"));
	my $t_bluehour_sunset = toComparable(ReadingsVal("twilight","ss_civil","06:00:00"));
	my $t_begin = '000000';
	my $t_end = '235900';
	my $t_noon = '120000';
	my $t_beforenoon = '100000';
	my $t_afternoon = '140000';
	my $colortemp = 3000;

	# Night till blue hour in the morning
	if ($t_now >= $t_begin && $t_now < $t_bluehour_sunrise) {
		$colortemp = $lightsources{'halogen'};
	}
	# Blue hour till sunrise
	elsif ($t_now >= $t_bluehour_sunrise && $t_now < $t_sunrise) {
		$colortemp = $lightsources{'halogen'};
	}
	# Sunrise till forenoon
	elsif ($t_now >= $t_sunrise && $t_now < $t_beforenoon) {
		$colortemp = $lightsources{'morning-evening'};
	}
	# Forenoon till noon
	elsif ($t_now >= $t_beforenoon && $t_now < $t_noon) {
		$colortemp = $lightsources{'forenoon-afternoon'};
	}
	# Noon till afternoon
	elsif ($t_now >= $t_noon && $t_now < $t_afternoon) {
		$colortemp = $lightsources{'noon-cloudy'};
	}
	# Afternoon till evening
	elsif ($t_now >= $t_afternoon && $t_now < $t_bluehour_sunrise) {
		$colortemp = $lightsources{'forenoon-afternoon'};
	}
	# Evening till sunset
	elsif ($t_now >= $t_sunrise && $t_now < $t_sunset) {
		$colortemp = $lightsources{'morning-evening'};
	}
	# Sunset till blue hour
	elsif ($t_now >= $t_sunset && $t_now < $t_bluehour_sunset) {
		$colortemp = $lightsources{'halogen'};
	}
	# Blue hour till night
	elsif ($t_now >= $t_bluehour_sunset) {
		$colortemp = $lightsources{'halogen'};
	}
	return $colortemp
}

sub Funkwetter_UpdateState {
  my ($h) = @_;
  my $n = $h->{NAME};

  # Basis-Readings
  my $sfi   = ReadingsVal($n, 'SFI', '?');
  my $k     = ReadingsVal($n, 'KIndex', '?');
  my $a     = ReadingsVal($n, 'AIndex_Planetary', '?');
  my $drap  = ReadingsVal($n, 'DrapIndex', '?');
  my $alert = ReadingsVal($n, 'GeoAlert', '');
  my $storm = ReadingsVal($n, 'Storm_Level', '');

  my $state = "K:$k A:$a SFI:$sfi";

  # -------------------------
  # SunspotNumber automatisch erkennen
  my $sunspot = '';
  foreach my $r (keys %{ $h->{READINGS} }) {
    if ($r =~ /sunspot.*number/i || $r =~ /^ssn$/i) {
      my $val = ReadingsVal($n, $r, '');
      if ($val ne '') {
        $sunspot = $val;
        Log3 $n, 4, "Funkwetter_UpdateState: gefundenes SunspotNumber-Reading '$r' => $val";
        last;
      }
    }
  }
  $state .= " SSN:$sunspot" if $sunspot ne '';

  # -------------------------
  # SunspotArea automatisch erkennen
  my $sunspot_area = '';
  foreach my $r (keys %{ $h->{READINGS} }) {
    if ($r =~ /sunspot.*area/i) {
      my $val = ReadingsVal($n, $r, '');
      if ($val ne '') {
        $sunspot_area = $val;
        Log3 $n, 4, "Funkwetter_UpdateState: gefundenes SunspotArea-Reading '$r' => $val";
        last;
      }
    }
  }
  $state .= " SSA:$sunspot_area" if $sunspot_area ne '';

  # -------------------------
  # XRay automatisch erkennen
  my $xray = '';
  foreach my $r (keys %{ $h->{READINGS} }) {
    if ($r =~ /xray/i || $r =~ /^x[\-_]?class/i) {
      my $val = ReadingsVal($n, $r, '');
      if ($val ne '') {
        $xray = $val;
        Log3 $n, 4, "Funkwetter_UpdateState: gefundenes XRay-Reading '$r' => $val";
        last;
      }
    }
  }
  $state .= " XC:$xray" if $xray ne '';

  # -------------------------
  # Weitere optionale Angaben
  $state .= " D:$drap" if $drap ne '?';
  $state .= " [$storm]" if $storm ne '';
  $state .= " ⚠" if $alert ne '';

  readingsSingleUpdate($h, 'state', $state, 1);
}

sub updateIonosState {
  my ($name) = @_;
  return "no device name given" unless $name;
  my $hash = $defs{$name};
  return "device not found" unless $hash;

  # Werte auslesen (mit Fallback-Werten)
  my $station = ReadingsVal($name, "CityCountry", "n/a");
  my $fof2    = ReadingsVal($name, "fof2", "?");
  my $mufd    = ReadingsVal($name, "mufd", "?");
  my $tec     = ReadingsVal($name, "tec", "?");

  # STATE zusammensetzen (anpassbar)
  my $state = "foF2: $fof2 MHz, MUFD: $mufd MHz, TEC: $tec @ $station";

  # STATE setzen – als Reading UND intern
  readingsSingleUpdate($hash, "state", $state, 1);
  $hash->{STATE} = $state;

  return "STATE updated: $state";
}

1;
