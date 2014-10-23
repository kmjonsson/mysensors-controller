
package MySensors;

use strict;
use warnings;

use Carp;
use IO::Socket::INET;

use MySensors::Controller;

sub new {
	my($class) = shift;
	my($opts) = shift // {};
	my $self  = {
		'timeout'		=> $opts->{'timeout'} // 300,
		'host'    		=> $opts->{'host'},
		'port'    		=> $opts->{'port'} // 5003,
		'debug'    		=> $opts->{'debug'} // 0,
		'controller'	=> MySensors::Controller->new({backend => $opts->{'backend'}, timeout => $opts->{'timeout'} // 300, debug => $opts->{debug}}),
	};
	bless ($self, $class);
	return $self;
}

sub connect {
	my($self) = @_;

	eval {
		local $SIG{ALRM} = sub { }; # do nothing but interrupt the syscall.
		alarm($self->{'timeout'});
		# create a connecting socket
		$self->{'socket'} = IO::Socket::INET->new (
		  PeerHost => '192.168.2.10',
		  PeerPort => '5003',
		  Proto => 'tcp',
		  Timeout => $self->{'timeout'},
		);
		alarm(0);
	};
	alarm(0); # race cond.
	
	if(!defined $self->{'socket'}) {
		croak "cannot connect to the server $!\n";
	}

	$self->{'controller'}->setSocket($self->{'socket'});

	return $self;
}

sub run {
	my($self) = @_;
	return unless defined $self->{'socket'};
	return unless defined $self->{'controller'};
	# receive a response of up to 1024 characters from server
	my $msg = "";
	while(1) {
		my $response = "";

		# Message timeout.
		eval {
			local $SIG{ALRM} = sub { }; # do nothing but interrupt the syscall.
			alarm($self->{'timeout'}/2); # Only half the timeout
			$self->{'socket'}->recv($response, 1024);
			alarm(0);
		};
		alarm(0); # race cond.

		# if no message received do version check.
		if($response eq "") {
			# Send version request (~gateway ping).
			$self->{'controller'}->versionCheck();
			# Check if no message received in timeout s.
			if(!$self->{'controller'}->timeoutCheck()) {
				print "timeout.. existing..\n";
				last;
			}
			next;
		}

		my @msgs;
		if($response =~ /\n/x && $response =~ /\n$/x) {
			push @msgs,split(/\n/x,$msg.$response);
			$msg = "";
		} elsif($response =~ /\n/x) {
			push @msgs,split(/\n/x,$msg.$response);
			$msg = pop @msgs;
		} else {
			$msg .= $response;
		}
		for ( grep { length } @msgs ) { 
			$self->{'controller'}->process($_); 
		}
	}
	$self->{'socket'}->close();
	$self->{'socket'} = undef;
}

1;
