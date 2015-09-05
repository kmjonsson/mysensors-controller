#
# Base Plugin 
#

package MySensors::Plugin;

use strict;
use warnings;

use base 'MySensors::Module';

sub moduleType {
	return 'Plugin';
}

sub new {
	my($class,$opts) = @_;

	my $self = $class->SUPER::new($opts);
	return unless defined $self;
	return $self;
}

sub _init {
	my($self) = @_;
	$self->{mmq}->subscribe('MySensors::Plugin::updatedConfig', sub { my($self,$data,$queue) = @_; $self->updatedConfig(@{$data}); }, $self ) if $self->can('updatedConfig');;
	$self->{mmq}->subscribe('MySensors::Plugin::sendValue', sub { my($self,$data,$queue) = @_; $self->sendValue(@{$data}); }, $self ) if $self->can('sendValue');;
	$self->{mmq}->subscribe('MySensors::Plugin::sendTime', sub { my($self,$data,$queue) = @_; $self->sendTime(@{$data}); }, $self ) if $self->can('sendTime');;
	$self->{mmq}->subscribe('MySensors::Plugin::sendConfig', sub { my($self,$data,$queue) = @_; $self->sendConfig(@{$data}); }, $self ) if $self->can('sendConfig');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveProtocol', sub { my($self,$data,$queue) = @_; $self->saveProtocol(@{$data}); }, $self ) if $self->can('saveProtocol');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveSensor', sub { my($self,$data,$queue) = @_; $self->saveSensor(@{$data}); }, $self ) if $self->can('saveSensor');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveValue', sub { my($self,$data,$queue) = @_; $self->saveValue(@{$data}); }, $self ) if $self->can('saveValue');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveBatteryLevel', sub { my($self,$data,$queue) = @_; $self->saveBatteryLevel(@{$data}); }, $self ) if $self->can('saveBatteryLevel');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveSketchName', sub { my($self,$data,$queue) = @_; $self->saveSketchName(@{$data}); }, $self ) if $self->can('saveSketchName');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveSketchVersion', sub { my($self,$data,$queue) = @_; $self->saveSketchVersion(@{$data}); }, $self ) if $self->can('saveSketchVersion');;
	$self->{mmq}->subscribe('MySensors::Plugin::saveVersion', sub { my($self,$data,$queue) = @_; $self->saveVersion(@{$data}); }, $self ) if $self->can('saveVersion');;
	$self->{mmq}->subscribe('MySensors::Plugin::process', sub { my($self,$data,$queue) = @_; $self->process(@{$data}); }, $self ) if $self->can('process');;

	$self->{mmq}->subscribe('MySensors::Plugin::saveValues', sub { my($self,$data,$queue) = @_; $self->saveValues($data); }, $self ) if $self->can('saveValues');
	$self->{mmq}->subscribe('MySensors::Plugin::saveNodes',  sub { my($self,$data,$queue) = @_; $self->saveNodes ($data); }, $self ) if $self->can('saveNodes');

	if($self->can('init')) {
		$self->init();
	}
}

sub run {
	my($self) = @_;
	$self->{mmq}->run();
}

sub getNodes {
	my($self) = @_;
	return $self->{mmq}->rpc('MySensors::Backend::getNodes');
}	

sub getValues {
	my($self) = @_;
	return $self->{mmq}->rpc('MySensors::Backend::getValues');
}	

1;

__DATA__
foreach my $x ('updatedConfig', 'sendValue', 'sendTime', 'sendConfig', 'saveProtocol', 'saveSensor', 'saveValue', 'saveBatteryLevel', 'saveSketchName', 'saveSketchVersion' ,'saveVersion', 'process') {
	print <<EOM;
\$self->{mmq}->subscribe('MySensors::Plugin::$x', sub { my(\$self,\$data,\$queue) = \@_; \$self->$x(\@{\$data}); }, \$self ) if \$self->can('$x');;
EOM
}
