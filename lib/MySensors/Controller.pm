
package MySensors::Controller;

use strict;
use warnings;

use MySensors::Const;

sub new {
	my($class) = shift;
	my($opts)  = shift // {};

	my $self  = {
		'backend' => $opts->{backend},
		'socket'  => $opts->{socket},
		'debug'   => $opts->{debug} // 1,
		'timeout' => $opts->{timeout} // 30,
		'config'  => $opts->{config} // 'M',
		'version' => undef,
		'lastMsg' => time,
		'log'     => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{log}->debug("Controller initialized");
	return $self;
}

sub setSocket {
	my($self,$socket) = @_;
	return $self->{socket} = $socket;
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
	                  $acknowledge,$type,$payload) . "\n";

	$self->{log}->debug("Sending: ",msg2str($destination,$sensor,$command,$acknowledge,$type,$payload));

	# send message
	my $size = $self->{socket}->send($td);
	if($size != length($td)) {
		$self->{log}->warn("Failed to write message");
		return;
	}
	return $self;
}

sub sendNextAvailableNodeId {
	my($self) = @_;
	my($id) = $self->{backend}->getNextAvailableNodeId();
	if(!defined $id) {
		$self->{log}->error("Can't get new sensor id");
		return;
	}
	$self->{log}->debug("New ID: " . $id);
	$self->send(MySensors::Const::BroadcastAddress(),
			MySensors::Const::NodeSensorId(),
			MySensors::Const::MessageType('INTERNAL'),
			0,
			MySensors::Const::Internal{'ID_RESPONSE'},
			$id);
}

sub sendValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type");
	if(!$self->{backend}->can("getValue")) {
		$self->{log}->error("Backend does not support 'getValue");
		return;
	}
	my $value = $self->{backend}->getValue($nodeid,$sensor,$type);
	if(!defined $value) {
		$self->{log}->error("Got no value from backend");
		return;
	}
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
	$self->send($nodeid,
			$sensor,
			MySensors::Const::MessageType('INTERNAL'),
			0,
			MySensors::Const::Internal('TIME'),
			time);
}

sub sendConfig {
	my ($self,$dest) = @_;
	$self->{log}->debug("Dest: $dest");
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
	$self->sendReboot();
}

# SAVE #

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	$self->{log}->debug("NodeID: $nodeid protocol: $protocol");
	if($self->{backend}->can("saveProtocol")) {
		return $self->{backend}->saveProtocol($nodeid,$protocol);
	}
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type");
	if($self->{backend}->can("saveSensor")) {
		return $self->{backend}->saveSensor($nodeid,$sensor,$type);
	}
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type value: $value");
	if($self->{backend}->can("saveValue")) {
		return $self->{backend}->saveValue($nodeid,$sensor,$type,$value);
	}
}

sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	$self->{log}->debug("NodeID: $nodeid batteryLevel $batteryLevel");
	if($self->{backend}->can("saveBatteryLevel")) {
		return $self->{backend}->saveBatteryLevel($nodeid,$batteryLevel);
	}
}

sub saveSketchName {
	my($self,$nodeid,$name) = @_;
	$self->{log}->debug("NodeID: $nodeid name: $name");
	if($self->{backend}->can("saveSketchName")) {
		return $self->{backend}->saveSketchName($nodeid,$name);
	}
}

sub saveSketchVersion {
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("NodeID: $nodeid version: $version");
	if($self->{backend}->can("saveSketchVersion")) {
		return $self->{backend}->saveSketchVersion($nodeid,$version);
	}
}

sub saveVersion {
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("Got version: $version");
	if($nodeid == 0) {
		$self->{version} = $version;
		if($self->{backend}->can("saveVersion")) {
			return $self->{backend}->saveVersion($nodeid,$version);
		}
	}
}

# Other

sub msg2str {
	my($nodeid,$sensor,$command,$acknowledge,$type,$payload) = @_;
	my $commandStr = MySensors::Const::MessageTypeToStr($command) . "($command)";
	my $acknowledgeStr = ($acknowledge?'Ack':'NoAck') . "($acknowledge)";
	my $typeStr = $type;
	$typeStr = MySensors::Const::TypeToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('PRESENTATION');
	$typeStr = MySensors::Const::SetReqToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('REQ') or 
												                 $command eq MySensors::Const::MessageType('SET');
	$typeStr = MySensors::Const::InternalToStr($type)  . "($type)" if $command eq MySensors::Const::MessageType('INTERNAL');
	$payload = "" unless defined $payload;
	return join(" ; ","NodeID:$nodeid","Sensor:$sensor",$commandStr,$acknowledgeStr,$typeStr,$payload);
}

sub process {
	my($self,$data) = @_;

	chomp($data);
	if($data !~ /^(\d+);(\d+);(\d+);(\d+);(\d+);(.*)$/) {
		$self->{log}->warn("Got no valid data: $data");
		return;
	}
	my($nodeid,$sensor,$command,
	   $acknowledge,$type,$payload) = ($1,$2,$3,$4,$5,$6);

	$self->{log}->debug("Got: ", msg2str($nodeid,$sensor,$command,$acknowledge,$type,$payload));

	$self->{lastMsg} = time;

	if($command == MySensors::Const::MessageType('STREAM')) {
		$self->{log}->error("STREAM not implemented yet");
		return;
	}
	if($command == MySensors::Const::MessageType('PRESENTATION')) {
		if($sensor == MySensors::Const::NodeSensorId()) {
			$self->saveProtocol($nodeid,$payload);
		}
		$self->saveSensor($nodeid,$sensor,$type);
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
	my($self) = @_;
	# if no message is received in timeout seconds (something is bad).
	if($self->{lastMsg} > 0 && $self->{lastMsg} < time - $self->{timeout}) {
		return 0;
	}
	return 1;
}

1;
