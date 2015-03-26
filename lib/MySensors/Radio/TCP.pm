
package MySensors::Radio::TCP;

use strict;
use warnings;

use Thread;
use Thread::Queue;

use IO::Socket::INET;

sub new {
	my($class) = shift;
	my($opts) = shift // {};
	my $self  = {
		'timeout'		=> $opts->{'timeout'} // 300,
		'host'    		=> $opts->{'host'} // '127.0.0.1',
		'port'    		=> $opts->{'port'} // 5003,
		'reconnect'		=> $opts->{'reconnect'} // 0,
		'socket'		=> undef,
		'controller'	=> undef,
		'log' 			=> Log::Log4perl->get_logger(__PACKAGE__),
		'inqueue'       => Thread::Queue->new(),
	};
	bless ($self, $class);
	return $self;
}

sub init {
	my($self,$controller) = @_;

	$self->{controller} = $controller;

	eval {
		local $SIG{ALRM} = sub { }; # do nothing but interrupt the syscall.
		alarm($self->{'timeout'});
		# create a connecting socket
		$self->{log}->info("Connecting to " . $self->{host} . ":" . $self->{port});
		$self->{'socket'} = IO::Socket::INET->new (
		  PeerHost => $self->{host},
		  PeerPort => $self->{port},
		  Proto => 'tcp',
		  Timeout => $self->{'timeout'},
		  Reuse	=> 1,
		);
		alarm(0);
	};
	alarm(0); # race cond.
	
	if(!defined $self->{'socket'}) {
		$self->{log}->error("Failed to connect to server");
		return;
	}

	# Start send thread
	$self->{'sendthr'} = Thread->new(
		 sub { $self->send_thr(); }
	);
	# Start receive thread
	$self->{'recvthr'} = Thread->new(
		 sub { $self->receive_thr(); }
	);
	return $self;
}

sub status {
	my($self) = @_;
	my $status = 0;
	if($self->{'sendthr'}->done()) {
		$self->{'sendthr'}->join();
		$status = 1;
	}
	if($self->{'recvthr'}->done()) {
		$self->{'recvthr'}->join();
		$status = 1;
	}
	return $status;
}

sub send {
	my($self,$msg) = @_;
	$self->{inqueue}->enqueue($msg);
	return length($msg);
}

sub send_thr {
	my($self) = @_;
	while (defined(my $msg = $self->{inqueue}->dequeue())) {
		last if $msg eq '# SHUTDOWN #';
		my $size = $self->{socket}->send("$msg\n");
		if($size != length("$msg\n")) {
			$self->{log}->warn("Failed to write message");
		}
	}
	$self->{log}->warn("Exit...");
}

sub shutdown {
	my($self) = @_;
	$self->{'inqueue'}->enqueue("# SHUTDOWN #"); 
}

sub receive_thr {
	my($self) = @_;
	return unless defined $self->{'socket'};
	return unless defined $self->{'controller'};

	# receive a response of up to 256 characters from server
	my $msg = "";
	while(1) {
		my $response = "";

		# Message timeout.
		my $status;
		eval {
			local $SIG{ALRM} = sub { }; # do nothing but interrupt the syscall.
			alarm($self->{'timeout'}*2); # Only half the timeout
			$self->{'socket'}->recv($response, 256);
			alarm(0);
		};
		alarm(0); # race cond.

		if($response eq '') {
			$self->shutdown(); 
			$self->{'controller'}->shutdown(); 
			$self->{log}->warn("Exit...");
			last;
		}

		# Split messages up based on '\n'. Only process messages
		# that are longer then 8 chars.
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
		for ( grep { length > 8 && !/^#/ } @msgs ) { 
			$self->{'controller'}->receive($_); 
		}
	}
	$self->{'socket'}->close();
	$self->{'socket'} = undef;
}

1;
