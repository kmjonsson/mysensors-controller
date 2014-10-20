
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
		'debug'   => 1,
		'version' => undef,
		'lastMsg' => time,
		'timeout' => $opts->{timeout} // 30,
	};
	bless ($self, $class);
	return $self;
}

sub setSocket {
	my($self,$socket) = @_;
	return $self->{socket} = $socket;
}

sub encode {
	my($self,$destination,$sensor,$command,$acknowledge,$type,$payload) = @_;
	if($command == MySensors::Const::MessageType('STREAM')) {
		die "Not implemented yet...";
		# for my $p (split(//,$payload)) { $msg .= sprintf("%02X",ord($p)); }
	}
	return join(";",$destination,$sensor,$command,$acknowledge,$type,$payload);
}

# Send message
sub send {
	my($self,$destination,$sensor,$command,$acknowledge,$type,$payload) = @_;

	$payload //= "";

	my $td = $self->encode( $destination,
							$sensor,
							$command,
							$acknowledge,
							$type,
							$payload) . "\n";

	printf("Sending: %s\n",msg2str($destination,$sensor,$command,$acknowledge,$type,$payload)) if $self->{debug};
	my $size = $self->{socket}->send($td);
	if($size != length($td)) {
		warn "wrote bad message...";
		return;
	}
	return $self;
}

sub saveProtocol {
	my($self,$sender,$payload) = @_;
	return $self->{backend}->saveProtocol($sender,$payload);
}

sub saveSensor {
	my($self,$sender,$sensor,$type) = @_;
	return $self->{backend}->saveSensor($sender,$sensor,$type);
}


sub sendNextAvailableSensorId {
	my($self) = @_;
	my($id) = $self->{backend}->getNextAvailableSensorId();
	if(!defined $id) {
		warn "Can't get new sensor id";
		return;
	}
	$self->send(MySensors::Const::BroadcastAddress(),
				MySensors::Const::NodeSensorId(),
				MySensors::Const::MessageType('INTERNAL'),
				0,
				MySensors::Const::Internal{'ID_RESPONSE'},
				$id);
}

sub saveValue {
	my ($self,$sender,$sensor,$type,$payload) = @_;
	return $self->{backend}->saveValue($sender,$sensor,$type,$payload);
}

sub sendValue {
	my ($self,$sender,$sensor,$type) = @_;
	my $value = $self->{backend}->getValue($sender,$sensor,$type);
	if(!defined $value) {
		warn "got no value.. :-(";
		return;
	}
	$self->send($sender,
				$sensor,
				MySensors::Const::MessageType('SET'),
				0,
				$type,
				$value);
}

sub msg2str {
	my($sender,$sensor,$command,$acknowledge,$type,$payload) = @_;
	my $commandStr = MySensors::Const::MessageTypeToStr($command) . "($command)";
	my $acknowledgeStr = ($acknowledge?'Ack':'NoAck') . "($acknowledge)";
	my $typeStr = $type;
	$typeStr = MySensors::Const::TypeToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('PRESENTATION');
	$typeStr = MySensors::Const::SetReqToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('REQ') or 
												                 $command eq MySensors::Const::MessageType('SET');
	$typeStr = MySensors::Const::InternalToStr($type)  . "($type)" if $command eq MySensors::Const::MessageType('INTERNAL');
	$payload = "" unless defined $payload;
	return join(" ; ","Sender:$sender","Sensor:$sensor",$commandStr,$acknowledgeStr,$typeStr,$payload);
}

sub process {
	my($self,$data) = @_;

	chomp($data);
	if($data !~ /^(\d+);(\d+);(\d+);(\d+);(\d+);(.*)$/) {
		warn "Got no valid data: $data\n";
		return;
	}
	my($sender,$sensor,$command,$acknowledge,$type,$payload) = ($1,$2,$3,$4,$5,$6);

	printf "Got: (%s) @ %s\n", msg2str($sender,$sensor,$command,$acknowledge,$type,$payload),
								scalar localtime(time);

	$self->{lastMsg} = time;

	if($command == MySensors::Const::MessageType('STREAM')) {
		die "Not implemented yet";
	}
	if($command == MySensors::Const::MessageType('PRESENTATION')) {
		if($sensor == MySensors::Const::NodeSensorId()) {
			$self->saveProtocol($sender,$payload);
		}
		$self->saveSensor($sender,$sensor,$type);
	} elsif($command == MySensors::Const::MessageType('SET')) {
		$self->saveValue($sender,$sensor,$type,$payload);
	} elsif($command == MySensors::Const::MessageType('REQ')) {
		$self->sendValue($sender,$sensor,$type);
	} elsif($command == MySensors::Const::MessageType('INTERNAL')) {
		if($type == MySensors::Const::Internal('BATTERY_LEVEL')) {
			# $self->saveBatteryLevel($sender,$payload);
		} elsif($type == MySensors::Const::Internal('TIME')) {
			# $self->sendTime($sender, $sensor, $socket);
		} elsif($type == MySensors::Const::Internal('VERSION')) {
			$self->gotVersion($sender, $payload);
		} elsif($type == MySensors::Const::Internal('ID_REQUEST')) {
			$self->sendNextAvailableSensorId();
		} elsif($type == MySensors::Const::Internal('ID_RESPONSE')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('INCLUSION_MODE')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('CONFIG')) {
			# $self->sendConfig($sender);
		} elsif($type == MySensors::Const::Internal('PING')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('PING_ACK')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('LOG_MESSAGE')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('CHILDREN')) {
			# Do Nothing
		} elsif($type == MySensors::Const::Internal('SKETCH_NAME')) {
			# saveSketchName($sender,$payload);
		} elsif($type == MySensors::Const::Internal('SKETCH_VERSION')) {
			# saveSketchVersion($sender,$payload);
		} elsif($type == MySensors::Const::Internal('REBOOT')) {
			# Do Nothing
		} else {
			warn "No match :-(";
		}
	} elsif($command == MySensors::Const::MessageType('STREAM')) {
		die "Not implemented yet";
	}
}

sub gotVersion {
	my($self,$sender,$version) = @_;
	if($sender == 0) {
		$self->{version} = $version;
	}
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

# Send version request
sub versionCheck {
	my($self) = @_;
	return $self->send( 0,
						0,
						MySensors::Const::MessageType('INTERNAL'),
						0,
						MySensors::Const::Internal('VERSION')
					);
}

1;
