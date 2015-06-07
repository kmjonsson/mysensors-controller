#
# Example Plugin
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
	$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('updatedConfig',$self);
	$controller->register('sendValue',$self);
	$controller->register('sendTime',$self);
	$controller->register('sendConfig',$self);
	$controller->register('saveProtocol',$self);
	$controller->register('saveSensor',$self);
	$controller->register('saveValue',$self);
	$controller->register('saveBatteryLevel',$self);
	$controller->register('saveSketchName',$self);
	$controller->register('saveSketchVersion',$self);
	$controller->register('saveVersion',$self);
	$controller->register('process',$self);
	return $self;
}

sub updatedConfig {
	my($self) = @_;
	return $self;
}
sub sendValue {
	my($self,$nodeid, $sensor, $type, $value) = @_;
	return $self;
}
sub sendTime {
	my($self,$nodeid,$time) = @_;
	return $self;
}
sub sendConfig {
	my($self,$dest,$config) = @_;
	return $self;
}
sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	return $self;
}
sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	return $self;
}
sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	return $self;
}
sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	return $self;
}
sub saveSketchName {
	my($self,$nodeid, $name) = @_;
	return $self;
}
sub saveSketchVersion {
	my($self,$nodeid,$version) = @_;
	return $self;
}
sub saveVersion {
	my($self,$nodeid, $version) = @_;
	return $self;
}
sub process {
	my($self,$data,$nYodeid,$sensor,$command,$acknowledge,$type,$payload) = @_;
	return $self;
}

1;
