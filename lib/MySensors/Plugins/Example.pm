#
# Example Plugin Example
#

package MySensors::Plugins::Example;

use strict;
use warnings;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		'controller' => undef,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{log}->debug(__PACKAGE__ . " initialized");
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
	return;
}

1;

