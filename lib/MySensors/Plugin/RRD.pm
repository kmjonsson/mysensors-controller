#
# RRD Plugin
#

package MySensors::Plugin::RRD;

use strict;
use warnings;

use base 'MySensors::Plugin';

use MySensors::Const;

use RRDs;
use File::Copy;

sub new {
	my($class,$opts) = @_;
	$opts //= {};
	$opts->{name} = __PACKAGE__;
	my $self = $class->SUPER::new($opts);
	$self->{cfg}      = $opts->{cfg};
	$self->{path}     = $opts->{path};
	$self->{template} = $opts->{template};
	return $self;
}

sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	return $self->saveValue($nodeid,255,38,$batteryLevel);
}

sub _createRRD {
	my($self,$type,$file) = @_;
	my $ts = MySensors::Const::SetReqToStr($type);
	return unless defined $ts;
	return if $ts eq 'N/A';
	my $ds;
	my @rra;
	my $step;
	if($self->{cfg}->SectionExists("MySensors::Plugin::RRD Template $ts")) {
		$ds  = $self->{cfg}->val("MySensors::Plugin::RRD Template $ts",'ds');
		@rra = $self->{cfg}->val("MySensors::Plugin::RRD Template $ts",'rra');
		$step= $self->{cfg}->val("MySensors::Plugin::RRD Template $ts",'step');
	} elsif($self->{cfg}->SectionExists("MySensors::Plugin::RRD Template")) {
		$ds  = $self->{cfg}->val("MySensors::Plugin::RRD Template",'ds');
		@rra = $self->{cfg}->val("MySensors::Plugin::RRD Template",'rra');
		$step= $self->{cfg}->val("MySensors::Plugin::RRD Template",'step');
	} else {
		$self->{log}->error("'MySensors::Plugin::RRD Template' section is not defined");
		return;
	}
	if(!defined $ds) {
		$self->{log}->error("'ds' is not defined");
		return;
	}
	if(!scalar @rra) {
		$self->{log}->error("no 'rra' defined");
		return;
	}
	$step //= 300;
	$ds =~ s,^\s+,,g;
	$ds =~ s,\s+$,,g;
	if($ds !~ /^(GAUGE|COUNTER|DERIVE|ABSOLUTE):\d+:(-?\d+|U):(-?\d+|U)$/) {
		$self->{log}->error("DS string ($ds) is malformed");
		return;
	}
	$ts = "\L$ts";
	$ds = "DS:$ts:$ds";
	foreach (@rra) {
		s,^\s+,,g;
		s,\s+$,,g;
		if(!/^(AVERAGE|MIN|MAX|LAST):([\d+\.]+):(\d+):(\d+)$/) {
			$self->{log}->error("RRA string ($_) is malformed");
			return;
		}
		$_ = "RRA:$_";
	}
	RRDs::create($file,"--start","-24hours","--step",$step,$ds,@rra);
	my $err = RRDs::error;
	if($err) {
		$self->{log}->error("RRD create: $err");
		return;
	}
	return $self;
}

sub saveValue {
	my($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("RRD $nodeid,$sensor,$type,$value");
	my $file = $self->{path} . "/$nodeid-$sensor-$type.rrd";
	my($id) = $self->{mmq}->rpc('MySensors::Backend::getValue', { node => $nodeid, sensor => $sensor, type => MySensors::Const::SetReq('VAR4')}); # Should be ID after next release of MySensors
	if(defined $id) {
		$self->{log}->debug("Resolved $nodeid-$sensor to $id from its VAR4 (".MySensors::Const::SetReq('VAR4').")");
		$file = $self->{path} . "/$id.rrd";
	}
	my $typestr = MySensors::Const::SetReqToStr($type);
	if(!-f $file) {
		if(!$self->_createRRD($type,$file)) {
			$self->{log}->error("Can't create RRD");
			return;
		}
	}
	my $t = time;
	if((RRDs::last($file) // 0) >= $t) {
		return $self;
	}
	$typestr = "\L$typestr";
	$self->{log}->debug("Update: $file ($nodeid,$sensor,$typestr\[$type\]) <- $t:$value {--template $typestr $t:$value}");
	RRDs::update($file,"--template", $typestr ,"$t:$value");
	return $self;
}

1;

