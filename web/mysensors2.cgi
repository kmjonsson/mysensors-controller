#!/usr/bin/perl
use warnings;
use strict;

use Data::Dumper;
use JSON;
use LWP::UserAgent;

use FindBin;
use lib "$FindBin::RealBin/../lib";

use MySensors::Const; 

$Data::Dumper::Sortkeys=1;

sub STATE_STALE { return 4; };
sub STATE_CRIT { return 3; };
sub STATE_WARN { return 2; };
sub STATE_OK { return 1; };

sub BATTERY_SENSOR { return 255; };
sub BATTERY_TYPE { return 38; };

my %currentcss = (
		&STATE_OK => "state_ok",
		&STATE_WARN => "state_warn",
		&STATE_CRIT => "state_crit",
		&STATE_STALE => "state_stale",
);

sub file_content {
	my ($f) = @_;
	open(my $fh, "<", $f);
	my @a = <$fh>;
	chomp(@a);
	my $x = join("<br>\n",@a);
	close($fh);
	return $x;
}

print "Content-type: text/html\r\n\r\n";

print <<EOM;
<html>
<head>
<title>Mysensors</title>
<link rel="stylesheet" type="text/css" href="mysensors.css" >
</head>
<body>
EOM
my %data;

my $baseurl = 'http://your.mysensors.controller:9998';

sub get_data {
        my ($node) = @_;
        my $ua = LWP::UserAgent->new;
        $ua->agent("MySensorsWeb/0.1 ");

        # Create a request
        my $req = HTTP::Request->new(GET => "$baseurl/get/$node");

        # Pass request to the user agent and get a response back
        my $res = $ua->request($req);

        # Check the outcome of the response
        if (!$res->is_success) {
                #print $res->status_line, "\n";
                return;
        }
        return $res->content;
}
sub fail {
	my ($msg) = @_;
	print "<strong>Error: $msg</strong>";
	exit(0);
}
my $data = get_data("nodes") // fail("Unable to get nodes from Controller WS");
my $nodes = from_json($data);
$data = get_data("values") // fail("Unable to get values from Controller WS");
my $values = from_json($data);

#for my $f (glob("/data/mysensors/data/*")) {
#	#print "$f\n";
#	my $f2 = $f;
#	$f2 =~ s{.*/}{};
#	if ($f2 =~ m{^(\d+)\.([a-z].*)$}) {
#		$data{$1}{base}{$2} = file_content($f);
#	}
#	if ($f2 =~ m{^(\d+)\.(\d+)\.([a-z].*)$}) {
#		next if $3 eq "set";
#		$data{$1}{lev1}{$2} = file_content($f);
#	}
#	if ($f2 =~ m{^(\d+)\.(\d+)\.(\d+)\.([a-z].*)$}) {
#		next if $4 eq "set";
#		$data{$1}{lev2}{$2}{$3} = file_content($f);
#	}
#}
sub updatelastseen {
	return -1;
	for my $nodeid (sort {$a <=> $b} keys %data) {
		my $last = 0;
		if (defined $data{$nodeid}{base}{lastseen}) {
			#print "Node $nodeid already has info<br>\n";
			next;
		}
		for my $sensor (sort { $a <=> $b } keys %{$data{$nodeid}{lev2}}) {
			for my $type (sort { $a <=> $b } keys %{$data{$nodeid}{lev2}{$sensor}}) {
				my $t = timeval($data{$nodeid}{lev2}{$sensor}{$type}) // 0;
				if ($t > $last) {
					#print "$nodeid-$sensor-$type has $t, newer than $last<br>\n";
					$last = $t;
				}
			}
		}
		if ($last > 0) {
			$data{$nodeid}{base}{lastseen} = "$last;reconstructed";
		}
	}
	return;
}
sub tableforl2 {
	my ($nodeid,$sensorid) = @_;
	my $x = "";
	$x .= "<table class=\"lev2\">\n";
	for my $k (sort { $a <=> $b } keys %{$values->{values}->{$nodeid}->{sensors}->{$sensorid}->{types}}) {
		$x .= sprintf "<tr><td class=\"l2type\">%s (%s)</td><td class=\"l2data\">%s</td></tr>\n",
			MySensors::Const::SetReqToStr($k),
			$k,
			ls_timeval($values->{values}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$k}->{value},
				   $values->{values}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$k}->{lastseen});
	}
	$x .= "</table>";
	return $x;
}
sub currentornot {
	my ($dat) = @_;
	if (defined $dat) {
		if ($dat =~ /^(\d+)(;.*)?$/) {
			my $t = $1;
			if (time() - $t <= 600) {
				return STATE_OK;
			} elsif (time() - $t <= 86400) {
				return STATE_WARN;
			} elsif (time() - $t <= 10*86400) {
				return STATE_CRIT;
			} else {
				return STATE_STALE;
			}
		} else {
			return STATE_CRIT;
		}
	}
	#else {
		return STATE_CRIT;
	#}
}
sub cssfromtime{
	my ($dat) = @_;
	my ($curr) = currentornot($dat);
	return $currentcss{$curr} // "";
}
sub timeval {
	my ($dat) = @_;
	if (defined $dat) {
		if ($dat =~ /^(\d+)(;.*)?$/) {
			return $1;
		}
	}
	return;
}
sub ls_timeval {
	my ($dat,$time) = @_;
	if (defined $dat && defined $time) {
		$dat =~ s/\&/\&amp;/g;
		my $col="#00bb00";
		if (time() - $time > 600) {
			$col="#bb0000";
		}
		return sprintf "<span style=\"color: $col\">%s - %s</span>", scalar(localtime($time)), $dat;
	} else {
		return "<span style=\"color: red\">-</span>";
	}
}
sub str_timeval {
	my ($dat) = @_;
	if (defined $dat && $dat ne "") {
		if ($dat =~ /^(\d+)(;.*)?$/) {
			my $t = $1;
			my $d = $2 // "";
			$d =~ s/^;//;
			$d =~ s/\&/\&amp;/g;
			my $col="#00bb00";
			if (time() - $t > 600) {
				$col="#bb0000";
			}
			return sprintf "<span style=\"color: $col\">%s - %s</span>", scalar(localtime($t)), $d;
		} else {
			return $dat;
		}
	} else {
		return "<span style=\"color: red\">-</span>";
	}
}
updatelastseen();
#print "<pre>";
#print Dumper(\%data);
#print "</pre>";
	print "<fieldset><legend>Id</legend>";
	print "<table class=\"main\">";
	print "<tr>";
	print "<th class=\"id\" >Id</th>";
	print "<th class=\"ls\" >Lastseen</th>";
	print "<th class=\"lsraw\" >LastseenRaw</th>";
	print "<th class=\"sketchname\" >Sketchname</th>";
	print "<th class=\"sketchversion\" >Sketchver</th>";
	print "<th class=\"version\" >Version</th>";
	print "<th class=\"batterylevel\" >Battery</th>";
	print "</tr>\n";
for my $key (sort {$a <=> $b} keys %{$nodes->{nodes}}) {
	my $ls=$values->{values}->{$key}->{lastseen};
	$data{$key}{base}{current} = currentornot($ls);
	my $curr = $currentcss{$data{$key}{base}{current}};
	printf "<tr class=\"$curr\"><td>%s</td>", $key;
	printf "<td class=\"%s\">%s</td>", cssfromtime($ls),str_timeval($ls);
	for (qw(lastseen)) {
		my $d = $values->{values}->{$key}->{$_} // "-";
		$d =~ s/\&/\&amp;/g;
		printf "<td>%s</td>", $d;
	}
	for (qw(sketchname sketchversion version)) {
		my $d = $nodes->{nodes}->{$key}->{$_} // "-";
		$d =~ s/\&/\&amp;/g;
		printf "<td>%s</td>", $d;
	}
	my $battval = $values->{values}->{$key}->{sensors}->{&BATTERY_SENSOR}->{types}->{&BATTERY_TYPE}->{value};
	my $batttime = $values->{values}->{$key}->{sensors}->{&BATTERY_SENSOR}->{types}->{&BATTERY_TYPE}->{lastseen};
	my $batt;
	if (defined $battval && defined $battval) {
		$batt = "$batttime;$battval";
	}
	printf "<td class=\"%s\">%s%%</td>", cssfromtime($batt),str_timeval($batt);
	print "</tr>\n";
}
	print "</table>";
	print "</fieldset>";
print "<br><br><br>";
for my $node (sort {$a <=> $b} keys %{$values->{values}}) {
	my $curr = $currentcss{currentornot($values->{values}->{$node}->{lastseen})};
	print "<fieldset class=\"$curr\"><legend>Sensor node $node</legend>";
	print "<table class=\"lev1 $curr\"><tr><th class=\"sensorid\">SensorId</th><th class=\"type\">Type</th><th class=\"data\">Data</th></tr>\n";

	for my $sensor (sort { $a <=> $b } keys %{$nodes->{nodes}->{$node}->{sensors}}) {
		printf "<tr><td>%s</td><td>%s (%s)</td><td>%s</td></tr>\n",
		       $sensor,
		       MySensors::Const::PresentationToStr($nodes->{nodes}->{$node}->{sensors}->{$sensor}->{type} // ""),
		       $nodes->{nodes}->{$node}->{sensors}->{$sensor}->{type} // "",
		       tableforl2($node,$sensor);
	}
	print "</table>";
	print "</fieldset>";
	print "<br>";
}

