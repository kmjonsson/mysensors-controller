#
# Example Plugin Example
#

package MySensors::Plugins::RRD;

use strict;
use warnings;

use MySensors::Const;

use RRDs;
use File::Copy;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		'controller' => undef,
		'path'       => $opts->{path},
		'template'   => $opts->{template},
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
	return;
}

sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	$self->saveValue($nodeid,255,38,$batteryLevel);
	return ($nodeid,$batteryLevel);
}

sub saveValue {
	my($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("RRD $nodeid,$sensor,$type,$value");
	my $file = $self->{path} . "/$nodeid-$sensor-$type.rrd";
	my($id) = $self->{controller}->backend()->getValue($nodeid,$sensor,MySensors::Const::SetReq('VAR4')); # Should be ID after next release of MySensors
	if(defined $id) {
		$self->{log}->debug("Resolved $nodeid-$sensor to $id from its VAR4 (".MySensors::Const::SetReq('VAR4').")");
		$file = $self->{path} . "/$id.rrd";
	}
	my $typestr = MySensors::Const::SetReqToStr($type);
	if(!-f $file) {
		my $template = $self->{template} . "/${typestr}.rrd";
		if(!-f $template) {
			$self->{log}->debug("ERROR Could not find $template");
			return ($nodeid,$sensor,$type,$value);
		}
		if(!copy($template,$file)) {
			$self->{log}->error("ERROR Can't copy $template -> $file");
			return ($nodeid,$sensor,$type,$value);
		}
	}
	my $t = time;
	if((RRDs::last($file) // 0) >= $t) {
		return ($nodeid,$sensor,$type,$value);
	}
	$typestr = "\L$typestr";
	$self->{log}->debug("Update: $file ($nodeid,$sensor,$typestr\[$type\]) <- $t:$value {--template $typestr $t:$value}");
	RRDs::update($file,"--template", $typestr ,"$t:$value");
	return ($nodeid,$sensor,$type,$value);
}

1;

