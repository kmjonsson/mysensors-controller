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
	$self->{mmq}->subscribe('MySensors::Plugins::updatedConfig', sub { my($self,$queue,$data) = @_; $self->updatedConfig(@{$data}); }, $self ) if $self->can('updatedConfig');
	$self->{mmq}->subscribe('MySensors::Plugins::sendValue', sub { my($self,$queue,$data) = @_; $self->sendValue(@{$data}); }, $self ) if $self->can('sendValue');
	$self->{mmq}->subscribe('MySensors::Plugins::sendTime', sub { my($self,$queue,$data) = @_; $self->sendTime(@{$data}); }, $self ) if $self->can('sendTime');
	$self->{mmq}->subscribe('MySensors::Plugins::sendConfig', sub { my($self,$queue,$data) = @_; $self->sendConfig(@{$data}); }, $self ) if $self->can('sendConfig');
	$self->{mmq}->subscribe('MySensors::Plugins::saveProtocol', sub { my($self,$queue,$data) = @_; $self->saveProtocol(@{$data}); }, $self ) if $self->can('saveProtocol');
	$self->{mmq}->subscribe('MySensors::Plugins::saveSensor', sub { my($self,$queue,$data) = @_; $self->saveSensor(@{$data}); }, $self ) if $self->can('saveSensor');
	$self->{mmq}->subscribe('MySensors::Plugins::saveValue', sub { my($self,$queue,$data) = @_; $self->saveValue(@{$data}); }, $self ) if $self->can('saveValue');
	$self->{mmq}->subscribe('MySensors::Plugins::saveBatteryLevel', sub { my($self,$queue,$data) = @_; $self->saveBatteryLevel(@{$data}); }, $self ) if $self->can('saveBatteryLevel');
	$self->{mmq}->subscribe('MySensors::Plugins::saveSketchName', sub { my($self,$queue,$data) = @_; $self->saveSketchName(@{$data}); }, $self ) if $self->can('saveSketchName');
	$self->{mmq}->subscribe('MySensors::Plugins::saveSketchVersion', sub { my($self,$queue,$data) = @_; $self->saveSketchVersion(@{$data}); }, $self ) if $self->can('saveSketchVersion');
	$self->{mmq}->subscribe('MySensors::Plugins::saveVersion', sub { my($self,$queue,$data) = @_; $self->saveVersion(@{$data}); }, $self ) if $self->can('saveVersion');
	$self->{mmq}->subscribe('MySensors::Plugins::process', sub { my($self,$queue,$data) = @_; $self->process(@{$data}); }, $self ) if $self->can('process');
	if($self->can('init')) {
		$self->init();
	}
}

sub run {
	my($self) = @_;
	$self->{mmq}->run();
}

1;

__DATA__
foreach my $x ('updatedConfig', 'sendValue', 'sendTime', 'sendConfig', 'saveProtocol', 'saveSensor', 'saveValue', 'saveBatteryLevel', 'saveSketchName', 'saveSketchVersion' ,'saveVersion', 'process') {
	print <<EOM;
\$self->{mmq}->subscribe('MySensors::Plugins::$x', sub { my(\$self,\$queue,\$data) = \@_; \$self->$x(\@{\$data}); }, \$self ) if \$self->can('$x');;
EOM
}
