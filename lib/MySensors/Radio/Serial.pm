
package MySensors::Radio::Serial;

use strict;
use warnings;

use base 'MySensors::Radio';

use IO::Select;
use Device::SerialPort qw( :PARAM :STAT 0.07 );

use Data::Dumper;

sub new {
	my($class) = shift;

	my($opts) = shift // {};

	$opts->{name} = __PACKAGE__;

	my $self = $class->SUPER::new($opts);
	$self->{log} = Log::Log4perl->get_logger(__PACKAGE__);

	# Options
	$self->{'timeout'}		= $opts->{'timeout'} // 300;
	$self->{'device'}       = $opts->{'device'} // "/dev/ttyUSB0";
	$self->{'baudrate'}     = $opts->{'baudrate'} // 115200;
	$self->{'parity'}		= $opts->{'parity'} // "none";
	$self->{'databits'}     = $opts->{'databits'} // 8;
	$self->{'stopbits'}     = $opts->{'stopbits'} // 1;
	$self->{'handshake'}    = $opts->{'handshake'} // "none";

	# Vars
	$self->{'id'}			= undef;
	$self->{'serial'}		= undef;
	$self->{select} 		= IO::Select->new();

	return $self;
}

sub id {
	my($self) = @_;
	return $self->{id};
}

sub init {
	my($self) = @_;
	$self->{id} = $self->{mmq}->id();

	# open..
	$self->{serial} = new Device::SerialPort($self->{device}); 
	if(!defined $self->{'serial'}) {
		$self->{log}->error("Failed to connect to server");
		return;
	}

	$self->{serial}->user_msg(1); 
	$self->{serial}->baudrate($self->{baudrate}); 
	$self->{serial}->parity($self->{parity}); 
	$self->{serial}->databits($self->{databits}); 
	$self->{serial}->stopbits($self->{stopbits}); 
	$self->{serial}->handshake($self->{handshake}); 
	$self->{serial}->write_settings;

	$self->{serial}->read_const_time(500);       # 500 milliseconds = 0.5 seconds
	$self->{serial}->read_char_time(5);          # avg time between read char
	$self->{serial}->purge_all();

	$self->{select}->add($self->{serial}->FILENO);
	$self->{select}->add($self->{mmq}->getSocket());

	$self->{log}->info(__PACKAGE__ . " initialized (" . $self->{id} . ")");
	return $self;
}

sub send {
	my($self,$msg) = @_;
	$self->{'serial'}->write("$msg\r\n");
	return $self;
}

sub run {
	my($self) = @_;
	my $msg = "";
	while(1) {
		my(@r) = $self->{select}->can_read(1);
		my $response = "";
		foreach my $fd (@r) {
			if($fd eq $self->{serial}->FILENO) {
				my $b = $self->{'serial'}->read(10);
				if(defined $b) {
					$response .= $b;
				}
			}
		}

		# Split messages up based on '\n'. Only process messages
		# that are longer then 8 chars.
		my @msgs;
		if($response =~ /[\n\r]+/x && $response =~ /[\r\n]+$/x) {
			push @msgs,split(/[\n\r]+/x,$msg.$response);
			$msg = "";
		} elsif($response =~ /[\n\r]+/x) {
			push @msgs,split(/[\n\r]+/x,$msg.$response);
			$msg = pop @msgs;
		} else {
			$msg .= $response;
		}
		for ( grep { length > 8 && !/^#/ } @msgs ) { 
			#print "Serial: '$_'\n";
			$self->{mmq}->send({ radio => $self->{mmq}->id(), data => $_ },'MySensors::Controller::receive');
		}

		# handle MMQ
		$self->{mmq}->once(0.01);
	}
}

1;
