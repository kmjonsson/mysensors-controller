
package MySensors::Config;

use strict;
use warnings;

use Thread::Queue;

sub new {
	my($class) = shift;
	my($opts)  = shift // {};

	my $self  = {
		'controller' => $opts->{controller},
		'log'        => Log::Log4perl->get_logger(__PACKAGE__),
		'inqueue'    => Thread::Queue->new(),
	};
	bless ($self, $class);
	return $self->init();
}

sub init {
	my($self) = @_;
	$self->reload();
	$self->{log}->info("Init complete");
	return $self;
}

sub reload {
	my($self) = @_;
	$self->{log}->info("(re)load config");
	$self->{config} = $self->{controller}->{backend}->getConfig();
	return $self->sendSignal();
}

# Signal controller of updated config
sub sendSignal {
	my($self) = @_;
	$self->{log}->info("sendSignal");
	$self->{controller}->updatedConfig($self->{config});
}

# check for a signal..
sub check {
	my($self) = @_;
	while (defined(my $msg = $self->{inqueue}->dequeue())) {
		if($msg->{type} eq 'UPDATE') {
			$self->reload();
		}
	}
}

sub signal {
	my($self) = @_;
	$self->{log}->info("signal");
	$self->{inqueue}->enqueue({type => 'UPDATE'});
}

1;
