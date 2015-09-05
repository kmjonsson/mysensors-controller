#
# Base Radio 
#

package MySensors::Module;

use strict;
use warnings;

sub new {
	my($class,$opts) = @_;

	return unless defined $opts->{name};
	my $self  = {
		'mmq'	 => $opts->{mmq},
		'_name'  => $opts->{name},
		'_start' => 0,
		'_stop'  => 0,
		'log'    => Log::Log4perl->get_logger($opts->{name}),
	};
	bless ($self, $class);
	return $self;
}

sub start {
	my($self) = @_;
	$self->{mmq}->connect() || return;
	$self->{mmq}->rpc_subscribe($self->{_name} . '::ping',  sub { return 'pong'; }, $self );
	$self->{mmq}->rpc_subscribe($self->{_name} . '::start', sub { my($self) = @_; $self->{_start} = 1; return 'OK'; }, $self );
	$self->{mmq}->rpc_subscribe($self->{_name} . '::stop',  sub { my($self) = @_; $self->{_stop}  = 1; return 'OK'; }, $self );
	while(!$self->{_start}) {
		last unless $self->{mmq}->once()
	}
	if($self->can('_init')) {
		$self->_init();
	}
	$self->run();
}

1;
