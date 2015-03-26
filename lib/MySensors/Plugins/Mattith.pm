#
# Mattith plugin
#

package MySensors::Plugins::Mattith;

use strict;
use warnings;
use MySensors::Const;

use Digest::MD5  qw(md5 md5_hex md5_base64);
use IO::Socket::INET;

my $socket;
my $error;
#my $server = "bozz.i.stric.se:2324";
my $server;# = "bozz.i.stric.se:2324";
my %passwords;

sub sensorid($$);
sub sensorid($$) {
        my ($node, $sensorid) = @_;
	return sprintf("50.00.00.01.00.00.%02X.%02X",$node,$sensorid);
}
sub getpwd {
        my($sensor) = @_;
	return "pkoopkoopkoopkoo";
#	if (defined $passwords{$sensor}) {
#		return $passwords{$sensor};
#	}
#        open(IN,"</home/pi/mattith/secret/shadow.pwd") || die;
#        while(<IN>) {
#                chomp;
#                if(/^$sensor:(.*)/) {
#                        close(IN);
#			$passwords{$sensor} = $1;
#                        return $1;
#                }
#        }
#        close(IN);
#        print "Password for sensor $sensor not found!\n";
#        return;
}
sub create_id {
        my($token,$passwd) = @_;
	my $x = time.$passwd.$token;
	print "[[$x]]\n";
        return md5_base64($x);
}

sub auth {
        my($id,$passwd) = @_;
        my($res) = sendcmd("token $id");
        my $token;
        return unless defined $res;
        if($res =~ /^290 $id (\S+)$/) {
                $token = $1;
        } else { 
                return 0;
        }
        my $key = create_id($token,$passwd);
        ($res) = sendcmd("auth $id $key");
        return unless defined $res;
        return 1 if $res =~ /^2/;
        return 0;
}       

sub putdata {
        my($sensor,$temp,$t) = @_;
        my($res) = sendcmd("put $sensor=$temp $t");
        return unless defined $res;
	#print "{$res}\n";
        #if($self->{verbose}) {
                #Log::logmsg "[$res]";
        #}
        return 1 if $res =~ /^2/;
        return 0;
}

sub sendcmd {
        my($cmd) = @_;
        my @data;
        eval {
                local $SIG{ALRM} = sub { $error = 1; die "Sendcmd alarm timed out"};
                alarm(10);
                my $sock = $socket;
                unless(print $sock "$cmd\n") {
                        $error = 1;
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
	my $greet;
        eval {
                local $SIG{ALRM} = sub {die "Connect alarm timed out";};

                alarm(10);
                $socket = IO::Socket::INET->new(PeerAddr => $server,
                                Proto           => 'tcp',
                                Timeout => 10);
                alarm(0);
        };
        if($@) {
                print $@;
                undef $socket;
        }

        eval { 
                local $SIG{ALRM} = sub {die "Greet alarm timed out"};

                alarm(10);
                $greet = <$socket>;
                alarm(0);
        };
        if($@) {
                print $@;
                undef $socket;
                return;
        }

        if(!defined $greet || $greet !~ /^200 /) {
                print "No valid greeting from server";
                undef $socket;
                return;
        }

}

sub new {
	my($class,$opts) = @_;

	my $self  = {
		'host' => $opts->{'host'},
		'controller' => undef,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{log}->info(__PACKAGE__ . " initialized");
	$server = $self->{host};
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('saveValue',$self);
	$controller->register('saveVersion',$self);
	return;
}

sub saveVersion{
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("$nodeid,$version");
	return;
}

sub saveValue {
	my($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("$nodeid,$sensor,$type,$value");
	if (!$socket) {
		_connect();
	}
	if ($type ==  MySensors::Const::SetReq('RAIN')) {
		$value = sprintf "%.2f",(1024-$value)/10.24;
	}
	my $sens = sensorid($nodeid,$sensor);
	my $pass = getpwd($sens);
	my $y = auth($sens,$pass);
	my $z = putdata($sens,$value,time());
	print "$sens ([0;32m$nodeid.$sensor type $type (".MySensors::Const::SetReqToStr($type).")[0m) at ".time()." --- [0;32m$value[0m\n";
	return;
}

1;

