#
# Log Data Plugin
#

package MySensors::Plugin::LogData;

use strict;
use warnings;

use base 'MySensors::Plugin';

use MySensors::Const;

sub new {
	my($class,$opts) = @_;
	$opts //= {};
	$opts->{name} = __PACKAGE__;
	my $self = $class->SUPER::new($opts);
	$self->{path} = $opts->{path};
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

