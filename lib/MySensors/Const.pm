package MySensors::Const;

use strict;
use warnings;

use Data::Dumper;

my %message_type = (
	'PRESENTATION' => 0,
	'SET' => 1,
	'REQ' => 2,
	'INTERNAL' => 3,
	'STREAM' => 4,
);

sub MessageType {
	return $message_type{$_[0]};
}

# my %v_const = (
my %setreq = (
	'TEMP' => 0,
	'HUM' => 1,
	'LIGHT' => 2,
	'DIMMER' => 3,
	'PRESSURE' => 4,
	'FORECAST' => 5,
	'RAIN' => 6,
	'RAINRATE' => 7,
	'WIND' => 8,
	'GUST' => 9,
	'DIRECTION' => 10,
	'UV' => 11,
	'WEIGHT' => 12,
	'DISTANCE' => 13,
	'IMPEDANCE' => 14,
	'ARMED' => 15,
	'TRIPPED' => 16,
	'WATT' => 17,
	'KWH' => 18,
	'SCENE_ON' => 19,
	'SCENE_OFF' => 20,
	'HEATER' => 21,
	'HEATER_SW' => 22,
	'LIGHT_LEVEL' => 23,
	'VAR1' => 24,
	'VAR2' => 25,
	'VAR3' => 26,
	'VAR4' => 27,
	'VAR5' => 28,
	'UP' => 29,
	'DOWN' => 30,
	'STOP' => 31,
	'IR_SEND' => 32,
	'IR_RECEIVE' => 33,
	'FLOW' => 34,
	'VOLUME' => 35,
	'LOCK_STATUS' => 36,
	'V_DUST_LEVEL' => 37,
	'V_VOLTAGE' => 38,
	'V_CURRENT' => 39,
);

sub SetReq {
	return $setreq{$_[0]};
}

#my %i_const = (
my %internal = (
	'BATTERY_LEVEL' => 0,
	'TIME' => 1,
	'VERSION' => 2,
	'ID_REQUEST' => 3,
	'ID_RESPONSE' => 4,
	'INCLUSION_MODE' => 5,
	'CONFIG' => 6,
	'PING' => 7,
	'PING_ACK' => 8,
	'LOG_MESSAGE' => 9,
	'CHILDREN' => 10,
	'SKETCH_NAME' => 11,
	'SKETCH_VERSION' => 12,
	'REBOOT' => 13,
	'GATEWAY_READY' => 14,
);

sub Internal {
	return $internal{$_[0]};
}

#my %s_const = (
my %presentation = (
	'DOOR' => 0,
	'MOTION' => 1,
	'SMOKE' => 2,
	'LIGHT' => 3,
	'DIMMER' => 4,
	'COVER' => 5,
	'TEMP' => 6,
	'HUM' => 7,
	'BARO' => 8,
	'WIND' => 9,
	'RAIN' => 10,
	'UV' => 11,
	'WEIGHT' => 12,
	'POWER' => 13,
	'HEATER' => 14,
	'DISTANCE' => 15,
	'LIGHT_LEVEL' => 16,
	'ARDUINO_NODE' => 17,
	'ARDUINO_REPEATER_NODE' => 18,
	'LOCK' => 19,
	'IR' => 20,
	'WATER' => 21,
	'AIR_QUALITY' => 22,
	'CUSTOM' => 23,
	'DUST' => 24,
	'SCENE_CONTROLLER' => 25,
);

sub Presentation {
	return $presentation{$_[0]};
}

#my %st_const = (
my %stream = (
	'FIRMWARE_CONFIG_REQUEST' => 0,
	'FIRMWARE_CONFIG_RESPONSE' => 1,
	'FIRMWARE_REQUEST' => 2,
	'FIRMWARE_RESPONSE' => 3,
	'SOUND' => 4,
	'IMAGE' => 5,
);

sub Stream {
	return $stream{$_[0]};
}

# my %p_const = (
my %type = (
	'STRING' => 0,
	'BYTE' => 1,
	'INT16' => 2,
	'UINT16' => 3,
	'LONG32' => 4,
	'ULONG32' => 5,
	'CUSTOM' => 6,
);

sub Type {
	return $type{$_[0]};
}

sub BroadcastAddress {
	return 255;
}

sub NodeSensorId {
	return 255;
}

1;
