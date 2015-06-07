#
# Log Data Plugin
#

package MySensors::Plugins::LogData;

use strict;
use warnings;

use MySensors::Const;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		'controller' => undef,
		'path'       => $opts->{path},
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('saveValue',$self);
	$controller->register('saveBatteryLevel',$self);
	return $self;
}

sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	return $self->saveValue($nodeid,255,38,$batteryLevel);
}

sub saveValue {
	my($self,$nodeid,$sensor,$type,$value) = @_;

	if(!-d $self->{path} . "/$nodeid") {
		if(!mkdir($self->{path} . "/$nodeid")) {
			$self->{log}->error("Can't create: " . $self->{path} . "/$nodeid");
			return;
		}
	}
	if(!-d $self->{path} . "/$nodeid/$sensor") {
		if(!mkdir($self->{path} . "/$nodeid/$sensor")) {
			$self->{log}->error("Can't create: " . $self->{path} . "/$nodeid/$sensor");
			return;
		}
	}

	if(open(my $out,">>",$self->{path} . "/$nodeid/$sensor/$type.txt")) {
		printf $out "%s[%d];%s[%d];%s\n",scalar localtime(time),time,MySensors::Const::SetReqToStr($type),$type,$value;
		close($out) || return;
	}
	return $self;
}

1;

