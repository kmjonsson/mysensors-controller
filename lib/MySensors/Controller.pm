
package MySensors::Controller;

=head1 MySensors::Controller

Basic module for MySensors

=head2 AUTHOR

Magnus Jonsson <fot@fot.nu>

=head2 CONTRIBUTOR

Tomas Forsman <>

=head2 LICENSE

GNU GENERAL PUBLIC LICENSE Version 2 

(See LICENSE file)

=head2 Methods

=cut

use threads;

use strict;
use warnings;

use Thread::Queue;

use MySensors::Const;

use base 'MySensors::Module';

sub new {
	my($class) = shift;
	my($opts)  = shift // {};

	$opts->{name} = __PACKAGE__;

	my $self = $class->SUPER::new($opts);
	return unless defined $self;

	$self->{timeout}  = $opts->{timeout} // 300;
	$self->{config}   = $opts->{config} // 'M';
	$self->{cfg}      = $opts->{cfg};
	$self->{route}    = {};
	$self->{version}  = undef;
	$self->{lastMsg} = {};

	$self->{log}->info("Controller initialized");
	return $self;
}

sub callBack {
	my($self,$method,@arg) = @_;
	$self->{mmq}->send(\@arg,'MySensors::Controller::' . $method);
}

# Send an updated config to plugins that needs the config.
sub updatedConfig {
	my($self,$msg) = @_;
	$self->callBack('updatedConfig',$msg);
	return $self;
}

# Send #

# Send message
sub send {
	my($self,$destination,$sensor,$command,$acknowledge,$type,$payload) = @_;

	# Not implemented (yet)
	if($command == MySensors::Const::MessageType('STREAM')) {
		$self->{log}->error("STREAM is not implemented yet");
		return;
		# for my $p (split(//,$payload)) { $msg .= sprintf("%02X",ord($p)); }
	}

	$payload //= "";

	# encode message
	my $td = join(";",$destination,$sensor,$command,
	                  $acknowledge,$type,$payload);

	$self->{log}->debug("Sending: ",msg2str($destination,$sensor,$command,$acknowledge,$type,$payload));

	# send message
	if(defined $self->{route}->{$destination}) {
		$self->{mmq}->send($td,'MySensors::Radio::send#' . $self->{route}->{$destination});
	} else {
		$self->{mmq}->send($td,'MySensors::Radio::send');
	}
	return $self;
}

sub sendNextAvailableNodeId {
	my($self) = @_;
	my($id) = $self->{mmq}->rpc('MySensors::Backend::getNextAvailableNodeId');
	if(!defined $id) {
		$self->{log}->error("Can't get new sensor id");
		return;
	}
	$self->{log}->debug("New ID: " . $id);
	$self->send(MySensors::Const::BroadcastAddress(),
			MySensors::Const::NodeSensorId(),
			MySensors::Const::MessageType('INTERNAL'),
			0,
			MySensors::Const::Internal('ID_RESPONSE'),
			$id);
}

sub sendValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type");
	my($value) = $self->{mmq}->rpc('MySensors::Backend::getValue',{node => $nodeid, sensor => $sensor, type => $type});
	if(!defined $value) {
		$self->{log}->debug("Got no value from backend :-( sending empty string");
		$value = "";
	}
	$self->callBack('sendValue', $nodeid, $sensor, $type, $value);
	$self->send($nodeid,
			$sensor,
			MySensors::Const::MessageType('SET'),
			0,
			$type,
			$value);
}

sub sendTime {
	my ($self,$nodeid,$sensor) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor");
	my $t = time;
	$self->callBack('sendTime', $nodeid, $t);
	$self->send($nodeid,
			$sensor,
			MySensors::Const::MessageType('INTERNAL'),
			0,
			MySensors::Const::Internal('TIME'),
			$t);
}

sub sendConfig {
	my ($self,$dest) = @_;
	$self->callBack('sendConfig', $dest, $self->{config});
	$self->send($dest,
			MySensors::Const::NodeSensorId(),
			MySensors::Const::MessageType('INTERNAL'),
			0,
			MySensors::Const::Internal('CONFIG'),
			$self->{config});
}

sub sendVersionCheck {
	my($self) = @_;
	$self->{log}->debug("Sending version request");
	return $self->send( 0,
				0,
				MySensors::Const::MessageType('INTERNAL'),
				0,
				MySensors::Const::Internal('VERSION')
			);
}

sub sendReboot {
	my($self,$nodeid) = @_;
	$self->{log}->debug("Sending reboot request to $nodeid");
	return $self->send( $nodeid,
				0,
				MySensors::Const::MessageType('INTERNAL'),
				0,
				MySensors::Const::Internal('REBOOT')
			);
}

# SAVE #

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	$self->{log}->debug("NodeID: $nodeid protocol: $protocol");
	$self->callBack('saveProtocol', $nodeid, $protocol);
	return $self->{mmq}->send({ node => $nodeid, protocol => $protocol}, 'MySensors::Backend::saveProtocol');
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type,$description) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type description: $description");
	$self->callBack('saveSensor', $nodeid, $sensor, $type, $description);
	return $self->{mmq}->send({ node => $nodeid, sensor => $sensor, type => $type, description => $description}, 'MySensors::Backend::saveSensor');
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type value: $value");
	$self->callBack('saveValue', $nodeid, $sensor, $type, $value);
	return $self->{mmq}->send({ node => $nodeid, sensor => $sensor, type => $type, value => $value}, 'MySensors::Backend::saveValue');
}

sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	$self->{log}->debug("NodeID: $nodeid batteryLevel $batteryLevel");
	$self->callBack('saveBatteryLevel', $nodeid, $batteryLevel);
	return $self->{mmq}->send({ node => $nodeid, batteryLevel => $batteryLevel}, 'MySensors::Backend::saveBatteryLevel');
}

sub saveSketchName {
	my($self,$nodeid,$name) = @_;
	$self->{log}->debug("NodeID: $nodeid name: $name");
	$self->callBack('saveSketchName', $nodeid, $name);
	return $self->{mmq}->send({ node => $nodeid, name => $name}, 'MySensors::Backend::saveSketchName');
}

sub saveSketchVersion {
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("NodeID: $nodeid version: $version");
	$self->callBack('saveSketchVersion', $nodeid, $version);
	return $self->{mmq}->send({ node => $nodeid, version => $version}, 'MySensors::Backend::saveSketchVersion');
}

sub saveVersion {
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("Got version: Node=$nodeid Version=$version");
	if($nodeid == 0) {
		$self->callBack('saveVersion', $nodeid, $version);
		$self->{version} = $version;
		return $self->{mmq}->send({ node => $nodeid, version => $version}, 'MySensors::Backend::saveVersion');
	}
}

sub processLog {
	my($self,$nodeid,$payload) = @_;
	$self->{log}->debug("NodeID: $nodeid logmsg: $payload");
	$self->callBack('processLog', $nodeid, $payload);
	return $self->{mmq}->send({ node => $nodeid, payload => $payload}, 'MySensors::Backend::processLog');
}

# Other

sub msg2str {
	my($nodeid,$sensor,$command,$acknowledge,$type,$payload) = @_;
	my $commandStr = MySensors::Const::MessageTypeToStr($command) . "($command)";
	my $acknowledgeStr = ($acknowledge?'Ack':'NoAck') . "($acknowledge)";
	my $typeStr = $type;
	$typeStr = MySensors::Const::PresentationToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('PRESENTATION');
	$typeStr = MySensors::Const::SetReqToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('REQ') or 
												                 $command eq MySensors::Const::MessageType('SET');
	$typeStr = MySensors::Const::InternalToStr($type)  . "($type)" if $command eq MySensors::Const::MessageType('INTERNAL');
	$payload = "" unless defined $payload;
	return join(" ; ","NodeID:$nodeid","Sensor:$sensor",$commandStr,$acknowledgeStr,$typeStr,$payload);
}

sub send_msg {
	my($self,$msg) = @_;
	return 0 if defined $self->send(
		$msg->{destination},
		$msg->{sensor},
		$msg->{command},
		$msg->{acknowledge},
		$msg->{type},
		$msg->{payload}
	);
	return 1;
}

sub reboot_msg {
	my($self,$msg) = @_;
	return 0 if defined $self->sendReboot($msg->{nodeid});
	return 1;

}

sub X_handle_msg {
	my($self,$msg) = @_;
	return 0 if !defined $msg;
	return 1 if !defined $msg->{type};

	return 1 if $msg->{type} eq 'SHUTDOWN';
	return $self->process($msg) if $msg->{type} eq 'RADIO';
	return $self->send_msg($msg) if $msg->{type} eq 'SEND';
	return $self->updatedConfig($msg) if $msg->{type} eq 'CONFIG';
	return $self->reboot_msg($msg) if $msg->{type} eq 'REBOOT';

	$self->{log}->error("unknown message type: " . $msg->{type});
	return 1;
}

sub cron {
	my($self) = @_;
	$self->{log}->debug("Cron event");
	$self->callBack('cron');
}


=item
sub main {
	my($self) = @_;
	my($timeout) = time + $self->{timeout}; # just to exit the loop and let "run" do someting now and then...
	my($cron) = 0;
	while (defined(my $msg = $self->dequeue(30))) {
		if($cron < time) {
			$self->cron();
			$cron = (int(time / 60)+1)*60; # Every minute..
		}
		my $r = $self->handle_msg($msg);
		last if !defined $r;
		last if $r == 1;
		last if $timeout < time;
	}
}
=cut

#----

sub _init {
	my($self) = @_;
	$self->{mmq}->subscribe('MySensors::Controller::receive', sub { my($self,$data,$queue) = @_; $self->process($data); } , $self );
}

# TODO:
# Fix cron.. 
# fix stuff from 
sub run {
	my($self) = @_;
	$self->{log}->info("Controller: is running :-)\n");
	#$self->{mmq}->{mmq}->{x_debug} = 1;
	while(!$self->{mmq}->once(60)) {
		#$self->sendVersionCheck();
	}

=item
	while(1) {
		$self->main();

		# Check if no message received in timeout s or radio failed.
		foreach my $r (@{$self->{radio}}) {
			if($r->status() || !$self->timeoutCheck($r->id())) {
				$self->{log}->error("Radio " . $r->id() . " failed. Restarting");
				$r->restart();
			}
		}

		# Send version request (~gateway ping).
		$self->sendVersionCheck();
	}
=cut
}

1;
#----

sub process {
	my($self,$msg) = @_;

	my $data = $msg->{data};

	chomp($data);
	if($data !~ /^(\d+);(\d+);(\d+);(\d+);(\d+);(.*)$/) {
		$self->{log}->warn("Got no valid data: $data");
		return;
	}
	my($nodeid,$sensor,$command,
	   $acknowledge,$type,$payload) = ($1,$2,$3,$4,$5,$6);

	$self->{log}->debug("Got(raw): ", $data);
	$self->{log}->debug("Got: ", msg2str($nodeid,$sensor,$command,$acknowledge,$type,$payload));

	# call plugin with data
	$self->callBack('process',$data,$nodeid,$sensor,$command,$acknowledge,$type,$payload);

	$self->{route}->{$nodeid} = $msg->{radio} if $nodeid > 0 && $nodeid < 255;

	$self->{lastMsg}->{$nodeid} = time;

	if($command == MySensors::Const::MessageType('STREAM')) {
		$self->{log}->error("STREAM not implemented yet");
		return;
	}
	if($command == MySensors::Const::MessageType('PRESENTATION')) {
		if($sensor == MySensors::Const::NodeSensorId()) {
			$self->saveProtocol($nodeid,$payload);
		} else {
			$self->saveSensor($nodeid,$sensor,$type,$payload);
		}
	} elsif($command == MySensors::Const::MessageType('SET')) {
		$self->saveValue($nodeid,$sensor,$type,$payload);
	} elsif($command == MySensors::Const::MessageType('REQ')) {
		$self->sendValue($nodeid,$sensor,$type);
	} elsif($command == MySensors::Const::MessageType('INTERNAL')) {
		if($type == MySensors::Const::Internal('BATTERY_LEVEL')) {
			$self->saveBatteryLevel($nodeid,$payload);
		} elsif($type == MySensors::Const::Internal('TIME')) {
			$self->sendTime($nodeid, $sensor);
		} elsif($type == MySensors::Const::Internal('VERSION')) {
			$self->saveVersion($nodeid, $payload);
		} elsif($type == MySensors::Const::Internal('ID_REQUEST')) {
			$self->sendNextAvailableNodeId();
		} elsif($type == MySensors::Const::Internal('ID_RESPONSE')) {
			# Do Nothing (Response to ID_REQUEST)
		} elsif($type == MySensors::Const::Internal('INCLUSION_MODE')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('CONFIG')) {
			$self->sendConfig($nodeid);
		} elsif($type == MySensors::Const::Internal('FIND_PARENT')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('FIND_PARENT_RESPONSE')) {
			# Do Nothing (Response to FIND_PARENT)
		} elsif($type == MySensors::Const::Internal('LOG_MESSAGE')) {
			$self->processLog($nodeid,$payload);
			# Do logging..
		} elsif($type == MySensors::Const::Internal('CHILDREN')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('SKETCH_NAME')) {
			$self->saveSketchName($nodeid,$payload);
		} elsif($type == MySensors::Const::Internal('SKETCH_VERSION')) {
			$self->saveSketchVersion($nodeid,$payload);
		} elsif($type == MySensors::Const::Internal('REBOOT')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('GATEWAY_READY')) {
			# Do Nothing
		} else {
			$self->{log}->error("Unknown message type");
		}
	} else {
		$self->{log}->error("Unknown message type");
	}
	return $self;
}

sub getVersion {
	my($self) = @_;
	return $self->{version};
}

# 1 = OK
# 0 = FAIL
sub timeoutCheck {
	my($self,$id) = @_;
	# if no message is received in timeout seconds (something is bad).
	if(defined $id) {
		if($self->{lastMsg}->{$id} > 0 && $self->{lastMsg}->{$id} < time - $self->{timeout}) {
			return 0;
		}
	} else {
		foreach my $r (@{$self->{radio}}) {
			if($self->{lastMsg}->{$r->id()} > 0 && $self->{lastMsg}->{$r->id()} < time - $self->{timeout}) {
				return 0;
			}
		}
	}
	return 1;
}

1;
