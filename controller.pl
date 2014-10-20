#!/usr/bin/perl
#
# TODO:
#		arguments...
#		...
#

use strict;
use warnings;

use Carp;

use IO::Socket::INET;

use lib 'lib';

use MySensors::Controller;
use MySensors::Backend::TXT;

# auto-flush on socket
local $| = 1;

my $timeout = 15; # half of timeout in controller...

# create a connecting socket
my $socket = IO::Socket::INET->new (
  PeerHost => '192.168.2.10',
  PeerPort => '5003',
  Proto => 'tcp',
  Timeout => $timeout,
);

if(!defined $socket) {
	croak "cannot connect to the server $!\n";
}

print "connected to the server\n";

my $backend = MySensors::Backend::TXT->new() || croak "Can't init Backend";
my $controller = MySensors::Controller->new($backend,$socket) || croak "Can't init Controller";

# receive a response of up to 1024 characters from server
my $msg = "";
while(1) {
	my $response = "";

    # Message timeout.
	eval {
		local $SIG{ALRM} = sub { }; # do nothing but interrupt the syscall.
		alarm($timeout);
		$socket->recv($response, 1024);
		alarm(0);
	};
	alarm(0); # race cond.

	# if no message received do version check.
	if($response eq "") {
        # Send version request (~gateway ping).
		$controller->versionCheck();
        # Check if no message received in timeout s.
		last unless $controller->timeoutCheck();
		next;
	}

	my @msgs;
	if($response =~ /\n/x && $response =~ /\n$/x) {
		push @msgs,split(/\n/x,$msg.$response);
		$msg = "";
	} elsif($response =~ /\n/x) {
		push @msgs,split(/\n/x,$msg.$response);
		$msg = pop @msgs;
	} else {
		$msg .= $response;
	}
	for ( grep { length } @msgs ) { 
		$controller->process($_); 
	}
}
$socket->close();
