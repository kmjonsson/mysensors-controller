#
# Base Radio 
#

package MySensors::Backend;

use strict;
use warnings;

use Data::Dumper;

use base 'MySensors::Module';

sub moduleType {
        return 'Backend';
}

sub new {
        my($class,$opts) = @_;
        my $self = $class->SUPER::new($opts);
        return unless defined $self;
        return $self;
}

sub _init {
	my($self) = @_;
	$self->init() || return;
	$self->{mmq}->subscribe('MySensors::Backend::saveProtocol', sub { my($self,$data,$queue) = @_; $self->saveProtocol($data->{node},$data->{protocol}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::saveSensor', sub { my($self,$data,$queue) = @_; $self->saveSensor($data->{node},$data->{sensor},$data->{type},$data->{description}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::saveValue', sub { my($self,$data,$queue) = @_; $self->saveValue($data->{node},$data->{sensor},$data->{type},$data->{value}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::saveSketchName', sub { my($self,$data,$queue) = @_; $self->saveSketchName($data->{node},$data->{sketchname}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::saveSketchVersion', sub { my($self,$data,$queue) = @_; $self->saveSketchVersion($data->{node},$data->{sketchversion}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::saveBatteryLevel', sub { my($self,$data,$queue) = @_; $self->saveBatteryLevel($data->{node},$data->{batteryLevel}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::saveVersion', sub { my($self,$data,$queue) = @_; $self->saveVersion($data->{node},$data->{version}); }, $self );
	$self->{mmq}->subscribe('MySensors::Backend::processLog', sub { my($self,$data,$queue) = @_; $self->processLog($data->{node},$data->{payload}); }, $self );
	$self->{mmq}->rpc_subscribe('MySensors::Backend::getNextAvailableNodeId', sub { my($self) = @_; return $self->getNextAvailableNodeId(); }, $self );
	$self->{mmq}->rpc_subscribe('MySensors::Backend::getValue', sub { my($self,$data) = @_; return $self->getValue($data->{node},$data->{sensor},$data->{type}); }, $self );
	$self->{mmq}->rpc_subscribe('MySensors::Backend::getValueLastSeen', sub { my($self,$data) = @_; return $self->getValueLastSeen($data->{node},$data->{sensor},$data->{type}); }, $self );
	$self->{mmq}->rpc_subscribe('MySensors::Backend::getNodes', sub { my($self,$data) = @_; return $self->getNodes(); }, $self );
	$self->{mmq}->rpc_subscribe('MySensors::Backend::getValues', sub { my($self,$data) = @_; return $self->getValues(); }, $self );
}

sub run {
	my($self) = @_;
	return $self->{mmq}->run();
}

sub sendNodes {
	my($self,$nodes) = @_;
	$self->{mmq}->send($nodes,'MySensors::Plugin::saveNodes');
}

sub sendValues {
	my($self,$values) = @_;
	$self->{mmq}->send($values,'MySensors::Plugin::saveValues');
}

1;
