#
# Example Plugin
#

package MySensors::Plugin::Example;

use base MySensors::Plugin;

use strict;
use warnings;

sub new {
	my($class,$opts) = @_;
	$opts //= {};
	$opts->{name} = __PACKAGE__;
	my $self = $class->SUPER::new($opts);
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
	my($self,$nodeid,$sensor,$type,$description) = @_;
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
	my($self,$data,$nodeid,$sensor,$command,$acknowledge,$type,$payload) = @_;
	return $self;
}

1;
