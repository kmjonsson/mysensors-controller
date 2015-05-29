
package MySensors::Radio::Serial;

use strict;
use warnings;

use Thread;
use Thread::Queue;

use Device::SerialPort qw( :PARAM :STAT 0.07 );


sub new {
	my($class) = shift;
	my($opts) = shift // {};
	my $self  = {
		'log' 			=> Log::Log4perl->get_logger(__PACKAGE__),
		# Options
		'timeout'		=> $opts->{'timeout'} // 300,
		'device'   		=> $opts->{'device'} // "/dev/ttyUSB0",
		'baudrate'  	=> $opts->{'baudrate'} // 115200,
		'parity'  		=> $opts->{'parity'} // "none",
		'databits'  	=> $opts->{'databits'} // 8,
		'stopbits'  	=> $opts->{'stopbits'} // 1,
		'handshake'  	=> $opts->{'handshake'} // "none",
		# vars
		'serial'		=> undef,
		'controller'	=> undef,
		'id'			=> undef,
		'inqueue'       => undef,
	};
	bless ($self, $class);
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

	$self->start();

	return $self;
}

sub restart {
	my($self) = @_;
	$self->{log}->info("Restarting " . $self->{host} . ":" . $self->{port});
	$self->shutdown();
	if(defined $self->{'serial'}) {
		$self->{'serial'}->close();
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

	# open..
	$self->{serial} = new Device::SerialPort($self->{device}); 
	if(!defined $self->{'serial'}) {
		$self->{log}->error("Failed to connect to server");
		return;
	}

	$self->{serial}->user_msg(1); 
	$self->{serial}->baudrate($self->{baudrate}); 
	$self->{serial}->parity($self->{parity}); 
	$self->{serial}->databits($self->{databits}); 
	$self->{serial}->stopbits($self->{stopbits}); 
	$self->{serial}->handshake($self->{handshake}); 
	$self->{serial}->write_settings;

	$self->{serial}->read_const_time(500);       # 500 milliseconds = 0.5 seconds
	$self->{serial}->read_char_time(5);          # avg time between read char

	
	$self->{inqueue} = Thread::Queue->new();

	# Start receive thread
	$self->{'recvthr'} = Thread->new(
		 sub { $self->receive_thr(); }
	);
	# Start send thread
	$self->{'sendthr'} = Thread->new(
		 sub { $self->send_thr(); }
	);
	$self->{log}->error("Connected");
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
			$self->{log}->info("Sending: $data");
			my $size = $self->{serial}->write("$data\n");
			if($size != length("$data\n")) {
				$self->{log}->warn("Failed to write message");
			}
		}
	}
	$self->{log}->warn("Exit...");
}

sub receive_thr {
	my($self) = @_;
	return unless defined $self->{'serial'};
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
			while(1) {
				my $b = $self->{'serial'}->read(1);
				last unless defined $b;
				$response .= $b;
				last if $b =~ /[\r\n]/;
			}
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
		# print STDERR "($response)\n";
		my @msgs;
		if($response =~ /[\n\r]+/x && $response =~ /[\r\n]+$/x) {
			push @msgs,split(/[\n\r]+/x,$msg.$response);
			$msg = "";
		} elsif($response =~ /[\n\r]+/x) {
			push @msgs,split(/[\n\r]+/x,$msg.$response);
			$msg = pop @msgs;
		} else {
			$msg .= $response;
		}
		for ( grep { length > 8 && !/^#/ } @msgs ) { 
			#next if /^0;0;/;
			$self->{log}->info("received: '$_'");
			$self->{'controller'}->receive({ type => "PACKET", data => $_ }); 
		}
	}
	$self->{'serial'}->close();
	$self->{'serial'} = undef;
}

1;
