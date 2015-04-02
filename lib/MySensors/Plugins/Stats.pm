#
# Example Plugin Example
#

package MySensors::Plugins::Stats;

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
		'datadir' => $opts->{datadir} // "log", # seconds
		'interval' => $opts->{interval} // 30, # seconds
		'controller' => undef,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
		# vars
		'lastdump' => time(),
	};
	bless ($self, $class);
	$self->{datadir} .= "/" unless $self->{datadir} =~ m{/$};
	$self->zerostats();
	
	$self->{log}->info(__PACKAGE__ . " initialized");
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
sub _header {
	my ($str,$under) = @_;
	$under //= "-";
	return "\n".$str."\n".($under x (length($str)))."\n";
}

sub process{
	my($self,$data,$nodeid,$sensor,$command,$acknowledge,$type,$payload) = @_;
	$self->{stats}{packets}++;
	if ($acknowledge) {
		$self->{stats}{acknowledge}++;
	}
	if ($command == MySensors::Const::MessageType('INTERNAL')) {
		if ($type == MySensors::Const::Internal('LOG_MESSAGE')) {
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
	if (time() > $self->{lastdump} + $self->{interval}) {
		$self->{log}->debug("Dumping statistics");
		#print "Time to dump!\n";
		$self->{lastdump} = time();
		my $filename = strftime("stats.%Y%m%d",localtime(time()));
		open(my $fh, ">>", $self->{datadir}.$filename) || croak "Unable to open ".$self->{datadir}.$filename;
		print $fh _header("Raw dump (debug mode)");
		print $fh Dumper($self->{stats});

		print $fh _header(strftime("Statistics at %Y%m%d-%H%M%S:",localtime(time())),"=");
		print $fh _header("Incoming packets (from-via-to):");
		for my $key (sort keys %{$self->{stats}{route}}) {
			printf $fh "%s %s\n",$key,$self->{stats}{route}{$key};
		}

		print $fh _header("Outgoing packets (from-via-next-to):");
		for my $key (sort keys %{$self->{stats}{sendroute}}) {
			printf $fh "%s %s\n",$key,$self->{stats}{sendroute}{$key};
		}

		print $fh _header("Failed outgoing packets:");
		for my $key (sort keys %{$self->{stats}{sendfail}}) {
			printf $fh "%s %s\n",$key,$self->{stats}{sendfail}{$key};
		}
		
		print $fh _header("Failed times:");
		for my $key (sort keys %{$self->{stats}{failtime}}) {
			printf $fh "%s %s\n",$key,$self->{stats}{failtime}{$key};
		}
		
		print $fh _header("Nodecombo:");
		for my $key (sort keys %{$self->{stats}{nodesensor}}) {
			printf $fh "%s %s\n",$key,$self->{stats}{nodesensor}{$key};
			# TODO datatyp oxo?
		}
		
		print $fh _header("Nodecombo+type:");
		for my $key (sort keys %{$self->{stats}{nodesensortype}}) {
			printf $fh "%s %s\n",$key,$self->{stats}{nodesensortype}{$key};
		}
		
		print $fh _header("Types:");
		for my $key (sort keys %{$self->{stats}{type}}) {
			printf $fh "%s(%s) %s\n",MySensors::Const::SetReqToStr($key),$key,$self->{stats}{type}{$key};
		}
		close($fh);
		
	}
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
