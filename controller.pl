#!/usr/bin/perl

use strict;
use warnings;

use Carp;

use Log::Log4perl;

use lib 'lib';

use MySensors;
use MySensors::Backend::TXT;

# Init logger
Log::Log4perl->init("log.conf");

my $backend = MySensors::Backend::TXT->new() || croak "Can't init Backend";

my $mysensors = MySensors->new({ host => '192.168.2.10', 
                                 backend => $backend,
				 debug => 1,
			   }) || croak "Can't init MySensors";

$mysensors->connect() || croak "Can't connect to server";

print "connected to the server\n";

$mysensors->run();
