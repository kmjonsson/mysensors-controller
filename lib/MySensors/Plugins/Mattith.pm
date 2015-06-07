#
# Mattith plugin
#

package MySensors::Plugins::Mattith;

use strict;
use warnings;
use MySensors::Const;

use Digest::MD5  qw(md5 md5_hex md5_base64);
use IO::Socket::INET;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		# opts
		'host' => $opts->{'host'},
		'defaultpass' => $opts->{'defaultpass'},
		'passfile' => $opts->{'passfile'},
		'sensorprefix' => $opts->{'sensorprefix'} // "50.00.00.01.00.00",
		# vars
		'controller' => undef,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
		'socket' => undef,
		'passwords' => {},
	};
	bless ($self, $class);
	$self->_connect();
	$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('saveValue',$self);
	$controller->register('saveVersion',$self);
	$controller->register('saveBatteryLevel',$self);
	return $self;
}
sub _sensorid {
	my ($self,$node, $sensorid) = @_;
	return sprintf("%s.%02X.%02X",$self->{sensorprefix},$node,$sensorid);
}
sub _getpwd {
	my($self,$sensor) = @_;
	if (defined $self->{passwords}{$sensor}) {
		return $self->{passwords}{$sensor};
	}
	if (defined $self->{passfile}) {
		open(my $fh, "<", $self->{passfile}) || die;
		while(<$fh>) {
			chomp;
			if(/^$sensor:(.*)/) {
				close($fh);
				$self->{passwords}{$sensor} = $1;
				return $self->{passwords}{$sensor};
			}
		}
		close($fh);
	}
	if (defined $self->{defaultpass}) {
		$self->{passwords}{$sensor} = $self->{defaultpass};
		return $self->{passwords}{$sensor};
	}
	print "Password for sensor $sensor not found!\n";
	return;
}
sub _create_id {
	my($self,$token,$passwd) = @_;
	my $x = time.$passwd.$token;
	print "[[$x]]\n";
	return md5_base64($x);
}

sub _auth {
	my($self,$id,$passwd) = @_;
	my($res) = $self->_sendcmd("token $id");
	my $token;
	return unless defined $res;
	if($res =~ /^290 $id (\S+)$/) {
		$token = $1;
	} else { 
		return 0;
	}
	my $key = $self->_create_id($token,$passwd);
	($res) = $self->_sendcmd("auth $id $key");
	return unless defined $res;
	return 1 if $res =~ /^2/;
	return 0;
}       

sub _putdata {
	my($self,$sensor,$temp,$t) = @_;
	my($res) = $self->_sendcmd("put $sensor=$temp $t");
	return unless defined $res;
#print "{$res}\n";
#if($self->{verbose}) {
#Log::logmsg "[$res]";
#}
	return 1 if $res =~ /^2/;
	return 0;
}

sub _sendcmd {
	my($self,$cmd) = @_;
	my @data;
	eval {
		local $SIG{ALRM} = sub { die "Sendcmd alarm timed out"};
		alarm(10);
		my $sock = $self->{socket};
		unless(print $sock "$cmd\n") {
			alarm(0);
			die "Socket write fail: $!";
		}
		print "S: $cmd\n";
		while(<$sock>) {
			s/[\r\n]+//g;
			if(/^(\d{3}) (\+|\-)\s+(.*)/) {
				my($code,$extra,$msg) = ($1,$2,$3);
				print "R: $code $msg\n";
				push @data, "$code $msg";
				last if $extra eq '-';
			}
		}
		alarm(0);
	};
	return @data;
}
sub _connect {
	my ($self) = @_;
	my $greet;
	eval {
		local $SIG{ALRM} = sub {die "Connect alarm timed out";};

		alarm(10);
		$self->{socket} = IO::Socket::INET->new(
				PeerAddr => $self->{host},
				Proto    => 'tcp',
				Timeout  => 10);
		alarm(0);
	};
	if($@) {
		print $@;
		undef $self->{socket};
	}

	eval { 
		local $SIG{ALRM} = sub {die "Greet alarm timed out"};

		alarm(10);
		my $s = $self->{socket};
		$greet = <$s>;
		alarm(0);
	};
	if($@) {
		print $@;
		undef $self->{socket};
		return;
	}

	if(!defined $greet || $greet !~ /^200 /) {
		print "No valid greeting from server";
		undef $self->{socket};
		return;
	}

}


sub saveVersion{
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("$nodeid,$version");
	return $self;
}

sub saveValue {
	my($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("$nodeid,$sensor,$type,$value");
	if (!$self->{socket}) {
		$self->_connect();
	}
	if ($type ==  MySensors::Const::SetReq('RAIN')) { #ugly temp hack, will fix ;)
		$value = sprintf "%.2f",(1024-$value)/10.24;
	}
	my $sens = $self->_sensorid($nodeid,$sensor);
	my $pass = $self->_getpwd($sens);
	my $y = $self->_auth($sens,$pass);
	my $z = $self->_putdata($sens,$value,time());
	print "$sens (\e[0;32m$nodeid.$sensor type $type (".MySensors::Const::SetReqToStr($type).")\e[0m) at ".time()." --- \e[0;32m$value\e[0m\n";
	return $self;
}
sub saveBatteryLevel {
	my ($self,$nodeid,$level) = @_;
	my $sensor = 0xBA; # ahem. batteri.
	$self->{log}->debug("$nodeid,batt=$level");
	if (!$self->{socket}) {
		$self->_connect();
	}
	my $sens = $self->_sensorid($nodeid,$sensor); # ahem. id=0xBA == batteri.. ish.
	my $pass = $self->_getpwd($sens);
	my $y = $self->_auth($sens,$pass);
	my $z = $self->_putdata($sens,$level,time());
	print "$sens (\e[0;32m$nodeid.$sensor battery at ".time()." --- \e[0;32m$level\e[0m\n";
	return $self;
}

1;

