#
# Example Plugin Example
#

package MySensors::Plugins::StatsJSON;

use strict;
use warnings;
use Carp;
use Data::Dumper;
use POSIX;

$Data::Dumper::Sortkeys = 1;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		# opts
		'datadir' => $opts->{datadir} // ".", 
		'aggregateby' => $opts->{aggregateby} // "%Y%m%d-%H",
		#'interval' => $opts->{interval} // 3600, # an hour
		'controller' => undef,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
		# vars
	};
	$self->{lastaggregate} = strftime($self->{aggregateby},localtime(time())),
	bless ($self, $class);
	$self->{datadir} .= "/" unless $self->{datadir} =~ m{/$};
	$self->zerostats();
	#$self->zerostatslong();
	
	#$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('process',$self);
	return;
}
sub zerostats {
	my ($self) = @_;
	$self->{stats}{packets} = 0;
	$self->{stats}{acknowledge} = 0;
	$self->{stats}{route} = ();
	$self->{stats}{sendroute} = ();
	$self->{stats}{sendfail} = ();
	$self->{stats}{failtime} = ();
	$self->{stats}{node} = ();
	$self->{stats}{nodesensor} = ();
	$self->{stats}{nodesensortype} = ();
	$self->{stats}{type} = ();
	return;
}
#sub zerostatslong {
#	my ($self) = @_;
#	$self->{statslong}{packets} = 0;
#	$self->{statslong}{acknowledge} = 0;
#	$self->{statslong}{route} = ();
#	$self->{statslong}{sendroute} = ();
#	$self->{statslong}{sendfail} = ();
#	$self->{statslong}{failtime} = ();
#	$self->{statslong}{node} = ();
#	$self->{statslong}{nodesensor} = ();
#	$self->{statslong}{nodesensortype} = ();
#	$self->{statslong}{type} = ();
#	return;
#}
=begin comment
sub _header {
	my ($str,$under) = @_;
	$under //= "-";
	return "\n".$str."\n".($under x (length($str)))."\n";
}

sub updatestatslong {
	my ($self) = @_;
	$self->{statslong}{packets}     += $self->{stats}{packets};
	$self->{statslong}{acknowledge} += $self->{stats}{acknowledge};
	for (keys $self->{stats}{route}) {
		$self->{statslong}{route}{$_} += $self->{stats}{route}{$_};
	}
	for (keys $self->{stats}{sendroute}) {
		$self->{statslong}{sendroute}{$_} += $self->{stats}{sendroute}{$_};
	}
	for (keys $self->{stats}{sendfail}) {
		$self->{statslong}{sendfail}{$_} += $self->{stats}{sendfail}{$_};
	}
	for (keys $self->{stats}{failtime}) {
		$self->{statslong}{failtime}{$_} += $self->{stats}{failtime}{$_};
	}
	for (keys $self->{stats}{node}) {
		$self->{statslong}{node}{$_} += $self->{stats}{node}{$_};
	}
	for (keys $self->{stats}{nodesensor}) {
		$self->{statslong}{nodesensor}{$_} += $self->{stats}{nodesensor}{$_};
	}
	for (keys $self->{stats}{nodesensortype}) {
		$self->{statslong}{nodesensortype}{$_} += $self->{stats}{nodesensortype}{$_};
	}
	for (keys $self->{stats}{type}) {
		$self->{statslong}{type}{$_} += $self->{stats}{type}{$_};
	}
	return;
}
=end comment
=cut

sub hash2json {
	my ($indent,$name,$keyname,$valname,$hash,$transformfunc) = @_;
	my $str = "";
	
	$str .= "\t" x $indent . qq/"$name":[\n/;
	$indent++;
	for my $key (sort keys %{$hash}) {
		my $mykey = $key;
		if (defined $transformfunc) {
			$mykey = $transformfunc->($key);
		}
		$str .= "\t" x $indent . qq/{"$keyname":"$mykey","$valname":$hash->{$key}},\n/;
	}
	chomp($str); # newline begone
	my $x = chop($str);  # , begone
	if ($x ne ',') {
		$str .= $x;
	}
	$str .= "\n";
	$indent--;
	$str .= "\t" x $indent . qq/]/;
	return $str;
}

sub dumpstats{
	my($self,$hash,$aggregate,$aggregateby,$filename) = @_;
	#print "Dumping to $filename\n";
	open(my $fh, ">>", $self->{datadir}.$filename) || croak "Unable to open ".$self->{datadir}.$filename;
#print $fh _header("Raw dump (debug mode)");
#print Dumper($hash);
	print  $fh qq/{\n/;
	printf $fh qq/\t"aggregate":"%s",\n/,$aggregate;
	printf $fh qq/\t"aggregateby":"%s",\n/,$aggregateby;
	printf $fh qq/\t"packets":%s,\n/,$hash->{packets};
	printf $fh qq/\t"acknowledge":%s,\n/,$hash->{acknowledge};
	print  $fh qq/\t"data":{\n/;
	my $indent = 2;
	print $fh hash2json($indent, "route","from","num",$hash->{route});
	print $fh ",\n";
	print $fh hash2json($indent, "sendroute","to","num",$hash->{sendroute});
	print $fh ",\n";
	print $fh hash2json($indent, "sendfail","to","num",$hash->{sendfail});
	print $fh ",\n";
	print $fh hash2json($indent, "failtime","time","num",$hash->{failtime});
	print $fh ",\n";
	print $fh hash2json($indent, "node","combo","num",$hash->{node});
	print $fh ",\n";
	print $fh hash2json($indent, "nodesensor","combo","num",$hash->{nodesensor});
	print $fh ",\n";
	print $fh hash2json($indent, "nodesensortype","combo","num",$hash->{nodesensortype});
	print $fh ",\n";
	print $fh hash2json($indent, "type","type","num",$hash->{type},
			    sub {
				    my $x = shift;
				    return MySensors::Const::SetReqToStr($x)."($x)";
			    }
		    );
	print $fh "\n";
	print $fh "\t}\n";
	print $fh "}\n";

=begin comment
	print $fh _header(strftime("Statistics [$type] at %Y%m%d-%H%M%S:",localtime(time())),"=");
	print $fh _header("Incoming packets (from-via-to):");
	for my $key (sort keys %{$hash->{route}}) {
	    printf $fh "%s %s\n",$key,$hash->{route}{$key};
	}

	print $fh _header("Outgoing packets (from-via-next-to):");
	for my $key (sort keys %{$hash->{sendroute}}) {
	    printf $fh "%s %s\n",$key,$hash->{sendroute}{$key};
	}

	print $fh _header("Failed outgoing packets:");
	for my $key (sort keys %{$hash->{sendfail}}) {
	    printf $fh "%s %s\n",$key,$hash->{sendfail}{$key};
	}

	print $fh _header("Failed times:");
	for my $key (sort keys %{$hash->{failtime}}) {
	    printf $fh "%s %s\n",$key,$hash->{failtime}{$key};
	}

	print $fh _header("Nodecombo:");
	for my $key (sort keys %{$hash->{nodesensor}}) {
	    printf $fh "%s %s\n",$key,$hash->{nodesensor}{$key};
# TODO datatyp oxo?
	}

	print $fh _header("Nodecombo+type:");
	for my $key (sort keys %{$hash->{nodesensortype}}) {
	    printf $fh "%s %s\n",$key,$hash->{nodesensortype}{$key};
	}

	print $fh _header("Types:");
	for my $key (sort keys %{$hash->{type}}) {
	    printf $fh "%s(%s) %s\n",MySensors::Const::SetReqToStr($key),$key,$hash->{type}{$key};
	}
=end comment
=cut
	close($fh);
	return;
}
sub lastseen {
	my ($self,$nodeid,$how) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.lastseen") || die;
	printf $fh "%d;%s\n",time,$how;
	close($fh);
	return;
}
sub process{
	my($self,$data,$nodeid,$sensor,$command,$acknowledge,$type,$payload) = @_;

	my $curraggregate = strftime($self->{aggregateby},localtime(time()));
	if ($curraggregate ne $self->{lastaggregate}) {
		my $filename = "stats.$self->{lastaggregate}.json";
		$self->dumpstats($self->{stats},$self->{lastaggregate},$self->{aggregateby},$filename);
		$self->zerostats();
		$self->{lastaggregate} = $curraggregate;
	}
	$self->{stats}{packets}++;
	if ($acknowledge) {
		$self->{stats}{acknowledge}++;
	}
	if ($command == MySensors::Const::MessageType('INTERNAL')) {
		if ($type == MySensors::Const::Internal('LOG_MESSAGE')) {
			if ($payload =~ /read: \d+-(\d+)-\d+/) {
				$self->lastseen($1,"packetrouter");
			}
			if ($payload =~ /read: (\d+-\d+-\d+)/) {
				$self->{stats}{route}{$1}++;
			}
			if ($payload =~ /send: (\d+-\d+-\d+-\d+) .*st=(ok|fail)/) {
				$self->{stats}{sendroute}{$1}++;
				if ($2 eq "fail") {
					$self->{stats}{sendfail}{$1}++;
					$self->{stats}{failtime}{strftime("%H:%M",localtime(time()))}++;
				}
			}
		}
	} elsif ($command == MySensors::Const::MessageType('SET')) {
		$self->{stats}{node}{$nodeid}++;
		$self->{stats}{nodesensor}{$nodeid."-".$sensor}++;
		$self->{stats}{nodesensortype}{$nodeid."-".$sensor."-".$type}++;
		$self->{stats}{type}{$type}++;
	}
#	if (time() > $self->{lastdump} + $self->{interval}) {
#		$self->{log}->debug("Dumping statistics");
#		#print "Time to dump!\n";
#		$self->{lastdump} = time();
#		my $filename = strftime("stats-short.%Y%m%d",localtime(time()));
#		$self->dumpstats("short",$self->{stats},$filename);
#		$self->updatestatslong();
#		$filename = strftime("stats-long.%Y%m%d",localtime(time()));
#		$self->dumpstats("long",$self->{statslong},$filename);
#
#		$self->zerostats(); # zap the short term, keep long
#	}
	#my $crap = shift @_;
	#$self->{log}->debug("$nodeid,$version");
	#print "Dumpalainen: ".Dumper(\@_);
	return ($data,$nodeid,$sensor,$command,$acknowledge,$type,$payload);
}

#	$self->{log}->debug("$nodeid,$sensor,$type,$value");

1;


__END__

2015-04-01T20:58:03 lib/MySensors/Controller.pm:311 in MySensors::Controller::process - Got: NodeID:0 ; Sensor:0 ; INTERNAL(3) ; NoAck(0) ; LOG_MESSAGE(9) ; read: 8-250-0 s=0,c=1,t=0,pt=7,l=5:2.5
2015-04-01T20:58:03 lib/MySensors/Controller.pm:52 in MySensors::Controller::call_back - call_back(process,0;0;3;0;9;read: 8-250-0 s=0,c=1,t=0,pt=7,l=5:2.5,0,0,3,0,9,read: 8-250-0 s=0,c=1,t=0,pt=7,l=5:2.5)
Dumpalainen: $VAR1 = [
          '0;0;3;0;9;read: 8-250-0 s=0,c=1,t=0,pt=7,l=5:2.5',
          '0',
          '0',
          '3',
          '0',
          '9',
          'read: 8-250-0 s=0,c=1,t=0,pt=7,l=5:2.5'
