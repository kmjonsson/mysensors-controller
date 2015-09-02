#
# Base Radio 
#

package MySensors::Radio;

use strict;
use warnings;

use base 'MySensors::Module';

sub moduleType {
	return 'Radio';
}

sub new {
	my($class,$opts) = @_;

	my $self = $class->SUPER::new($opts);
	return unless defined $self;
	return $self;
}

sub _init {
	my($self) = @_;
	$self->{mmq}->subscribe('MySensors::Radio::send', sub { my($self,$queue,$data) = @_; $self->send($data); }, $self );
	$self->{mmq}->subscribe('MySensors::Radio::send#' . $self->{mmq}->id(), sub { my($self,$queue,$data) = @_; $self->send($data); }, $self );
	if($self->can('init')) {
		$self->init();
	}
}

sub run {
	my($self) = @_;
	$self->{mmq}->run();
}

1;
