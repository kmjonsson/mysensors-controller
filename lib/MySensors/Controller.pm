
package MySensors::Controller;

use strict;
use warnings;

use Thread::Queue;

use MySensors::Const;

sub new {
	my($class) = shift;
	my($opts)  = shift // {};

	my $self  = {
		'backend' => $opts->{backend},
		'radio'   => $opts->{radio},
		'plugins' => $opts->{plugins},
		'timeout' => $opts->{timeout} // 300,
		'config'  => $opts->{config} // 'M',
		'callbacks' => {},
		'route'   => {},
		'version' => undef,
		'lastMsg' => {},
		'log'     => Log::Log4perl->get_logger(__PACKAGE__),
		'inqueue' => Thread::Queue->new(),
	};
	bless ($self, $class);
	if(defined $self->{'plugins'}) {
		foreach my $p (@{$self->{plugins}}) {
			$p->register($self);
		}
	}
	my $id = 0;
	foreach my $r (@{$self->{radio}}) {
		$self->{lastMsg}->{$id} = time;
		return unless $r->init($self,$id++);
	}
	$self->{log}->info("Controller initialized");
	return $self;
}

sub register {
	my($self,$method,$object) = @_;
	$self->{callbacks}->{$method} //= [];
	push @{$self->{callbacks}->{$method}},$object;
	return $self;
}

sub call_back {
	my($self,$method,@arg) = @_;
	$self->{log}->debug("call_back($method," . join(",",@arg) . ")");
	return unless defined $self->{callbacks}->{$method};
	foreach my $o (@{$self->{callbacks}->{$method}}) {
		$o->$method(@arg);
	}
}

sub backend {
	my($self) = @_;
	return $self->{backend};
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
	foreach my $r (@{$self->{radio}}) {
		next if defined $self->{route}->{$destination} && $_->id() != $self->{route}->{$destination};
		$self->{log}->debug("Sending via " . $r->id());
		my $ret = $r->send({ type => 'PACKET', data => $td });
		if(!defined $ret) {
			$self->{log}->warn("Failed to write message via " . $r->id());
			return;
		}
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
			MySensors::Const::Internal('ID_RESPONSE'),
			$id);
}

sub sendValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type");
	if(!$self->{backend}->can("getValue")) {
		$self->{log}->error("Backend does not support 'getValue");
		return;
	}
	my($value) = $self->{backend}->getValue($nodeid,$sensor,$type);
	if(!defined $value) {
		$self->{log}->debug("Got no value from backend :-( sending empty string");
		$value = "";
	}
	$self->send($nodeid,
			$sensor,
			MySensors::Const::MessageType('SET'),
			0,
			$type,
			$value);
	$self->call_back('sendValue', $nodeid, $sensor, $type, $value);
}

sub sendTime {
	my ($self,$nodeid,$sensor) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor");
	my $t = time;
	$self->send($nodeid,
			$sensor,
			MySensors::Const::MessageType('INTERNAL'),
			0,
			MySensors::Const::Internal('TIME'),
			$t);
	$self->call_back('sendTime', $nodeid, $t);
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
	$self->call_back('sendConfig', $dest, $self->{config});
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
	$self->call_back('saveProtocol', $nodeid, $protocol);
	if($self->{backend}->can("saveProtocol")) {
		return $self->{backend}->saveProtocol($nodeid,$protocol);
	}
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type");
	$self->call_back('saveSensor', $nodeid, $sensor, $type);
	if($self->{backend}->can("saveSensor")) {
		return $self->{backend}->saveSensor($nodeid,$sensor,$type);
	}
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$self->{log}->debug("NodeID: $nodeid sensor: $sensor type: $type value: $value");
	$self->call_back('saveValue', $nodeid, $sensor, $type, $value);
	if($self->{backend}->can("saveValue")) {
		return $self->{backend}->saveValue($nodeid,$sensor,$type,$value);
	}

}

sub saveBatteryLevel {
	my($self,$nodeid,$batteryLevel) = @_;
	$self->{log}->debug("NodeID: $nodeid batteryLevel $batteryLevel");
	$self->call_back('saveBatteryLevel', $nodeid, $batteryLevel);
	if($self->{backend}->can("saveBatteryLevel")) {
		return $self->{backend}->saveBatteryLevel($nodeid,$batteryLevel);
	}
}

sub saveSketchName {
	my($self,$nodeid,$name) = @_;
	$self->{log}->debug("NodeID: $nodeid name: $name");
	$self->call_back('saveSketchName', $nodeid, $name);
	if($self->{backend}->can("saveSketchName")) {
		return $self->{backend}->saveSketchName($nodeid,$name);
	}
}

sub saveSketchVersion {
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("NodeID: $nodeid version: $version");
	$self->call_back('saveSketchVersion', $nodeid, $version);
	if($self->{backend}->can("saveSketchVersion")) {
		return $self->{backend}->saveSketchVersion($nodeid,$version);
	}
}

sub saveVersion {
	my($self,$nodeid,$version) = @_;
	$self->{log}->debug("Got version: Node=$nodeid Version=$version");
	if($nodeid == 0) {
		$self->{version} = $version;
		$self->call_back('saveVersion', $nodeid, $version);
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
	$typeStr = MySensors::Const::PresentationToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('PRESENTATION');
	$typeStr = MySensors::Const::SetReqToStr($type) . "($type)" if $command eq MySensors::Const::MessageType('REQ') or 
												                 $command eq MySensors::Const::MessageType('SET');
	$typeStr = MySensors::Const::InternalToStr($type)  . "($type)" if $command eq MySensors::Const::MessageType('INTERNAL');
	$payload = "" unless defined $payload;
	return join(" ; ","NodeID:$nodeid","Sensor:$sensor",$commandStr,$acknowledgeStr,$typeStr,$payload);
}

# This is called by other thread(s)
sub shutdown {
	my($self) = @_;
	$self->receive({ type => "SHUTDOWN" });
}

# This is called by other thread(s)
sub receive {
	my($self,$msg) = @_;
	$self->{inqueue}->enqueue($msg);
}

sub run {
	my($self,$timeout) = @_;
	if($self->{inqueue}->can("dequeue_timed")) {
		while (defined(my $msg = $self->{inqueue}->dequeue_timed($timeout))) {
			last if !defined $msg;
			last if $msg->{type} eq 'SHUTDOWN';
			if($msg->{type} eq 'PACKET') {
				$self->process($msg);
			}
		}
	} else {
		my $t = $timeout;
		while (defined $self->{inqueue}->pending() && $timeout > 0) {
			if ($self->{inqueue}->pending() <= 0) {
				$timeout--;
				sleep 1;
				next;
			}
			my $msg = $self->{inqueue}->dequeue_nb();
			last if !defined $msg;
			last if $msg->{type} eq 'SHUTDOWN';
			if($msg->{type} eq 'PACKET') {
				$self->process($msg);
			}
			$t = $timeout;
		}
	}
}

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
	$self->call_back('process',$data,$nodeid,$sensor,$command,$acknowledge,$type,$payload);

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
			$self->saveSensor($nodeid,$sensor,$type);
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
