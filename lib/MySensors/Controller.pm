
package MySensors::Controller;

use strict;
use warnings;

use MySensors::Const;

sub new {
	my($class)   = shift;
	my($backend) = shift;
	my($socket)  = shift;

	my $self  = {
		'backend' => $backend,
		'socket'  => $socket,
		'debug'   => 0,
	};
	bless ($self, $class);
	return $self;
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

	my $td = $self->encode( $destination,
							$sensor,
							$command,
							$acknowledge,
							$type,
							$payload) . "\n";

	print "Sending: $td" if $self->{debug};
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

sub process {
	my($self,$data) = @_;

	chomp($data);
	if($data !~ /^(\d+);(\d+);(\d+);(\d+);(\d+);(.*)$/) {
		warn "Got no valid data: $data\n";
		return;
	}
	my($sender,$sensor,$command,$acknowledge,$type,$payload) = ($1,$2,$3,$4,$5,$6);

	printf "Got: ($sender,$sensor,$command,$acknowledge,$type,$payload) @ %s\n", scalar localtime(time);

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
			# Do Nothing?
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

1;
