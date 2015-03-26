
package MySensors;

use strict;
use warnings;

use Carp;
use IO::Socket::INET;

use threads;
use Thread::Queue;

use MySensors::Controller;

sub new {
	my($class) = shift;
	my($opts) = shift // {};
	my $self  = {
		'timeout'		=> $opts->{'timeout'} // 300,
		'radio'    		=> $opts->{'radio'},
		'debug'    		=> $opts->{'debug'} // 0,
		'plugins'		=> $opts->{'plugins'},
		'controller'	=> MySensors::Controller->new({
														radio => $opts->{radio},
														backend => $opts->{'backend'}, 
														timeout => $opts->{'timeout'} // 300, 
														debug => $opts->{debug}, 
														plugins => $opts->{plugins},
													}),
		'log' 			=> Log::Log4perl->get_logger(__PACKAGE__),
		'inqueue'		=> Thread::Queue->new(),
	};
	bless ($self, $class);
	return $self;
}

sub run {
	my($self) = @_;
	return unless defined $self->{'controller'};

	$self->{controller}->sendVersionCheck();

	# receive a response of up to 1024 characters from server
	my $msg = "";
	while(1) {
		my $response = "";

		$self->{controller}->run($self->{timeout});

		# Check radio status
		if($self->{radio}->status()) {
			$self->{log}->error("Radio failed. Exiting");
			last;
		}

		# Send version request (~gateway ping).
		$self->{'controller'}->sendVersionCheck();

		# Check if no message received in timeout s.
		if(!$self->{'controller'}->timeoutCheck()) {
			$self->{log}->error("Timeout. Exiting");
			last;
		}
	}
}

1;
