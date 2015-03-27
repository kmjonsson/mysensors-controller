
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
		'id'			=> undef,
		'log' 			=> Log::Log4perl->get_logger(__PACKAGE__),
		'inqueue'       => undef,
	};
	bless ($self, $class);
	$self->start();
	return $self;
}

sub id {
	my($self) = @_;
	return $self->{id};
}

sub init {
	my($self,$controller,$id) = @_;

	$self->{controller} = $controller;
	$self->{id} = $id;

	return $self;
}

sub restart {
	my($self) = @_;
	$self->{log}->info("Restarting " . $self->{host} . ":" . $self->{port});
	$self->shutdown();
	if(defined $self->{'socket'}) {
		$self->{'socket'}->close();
	}
	if(defined $self->{'sendthr'} && $self->{'sendthr'}->done()) {
		$self->{'sendthr'}->join();
	}
	if(defined $self->{'recvthr'} && $self->{'recvthr'}->done()) {
		$self->{'recvthr'}->join();
	}
	if(defined $self->{inqueue}) {
		$self->{inqueue}->end();
	}
	return $self->start();
}

sub start {
	my($self) = @_;
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
	
	$self->{inqueue} = Thread::Queue->new();

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
	return 1 unless defined $self->{'sendthr'};
	return 1 unless defined $self->{'recvthr'};
	my $status = 0;
	if($self->{'sendthr'}->done()) {
		$self->{'sendthr'}->join();
		$self->{'sendthr'} = undef;
		$status = 1;
	}
	if($self->{'recvthr'}->done()) {
		$self->{'recvthr'}->join();
		$self->{'recvthr'} = undef;
		$status = 1;
	}
	return $status;
}

sub send {
	my($self,$msg) = @_;
	if(defined $self->{inqueue}) {
		$self->{inqueue}->enqueue($msg);
	}
	return $self;
}

sub shutdown {
	my($self) = @_;
	if(defined $self->{inqueue}) {
		$self->{'inqueue'}->enqueue({ type => "SHUTDOWN"}); 
	}
}

sub send_thr {
	my($self) = @_;
	while (defined(my $msg = $self->{inqueue}->dequeue())) {
		last if $msg->{type} eq 'SHUTDOWN';
		if($msg->{type} eq 'PACKET') {
			my $data = $msg->{data};
			my $size = $self->{socket}->send("$data\n");
			if($size != length("$data\n")) {
				$self->{log}->warn("Failed to write message");
			}
		}
	}
	$self->{log}->warn("Exit...");
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
			$self->{'controller'}->receive({ type => "PACKET", data => $_ }); 
		}
	}
	$self->{'socket'}->close();
	$self->{'socket'} = undef;
}

1;
