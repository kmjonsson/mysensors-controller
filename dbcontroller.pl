#!/usr/bin/perl

use strict;
use warnings;

use Carp;

use Log::Log4perl;

use DBI;

use lib 'lib';

use MySensors;
use MySensors::Backend::Pg;

# Init logger
Log::Log4perl->init("log.conf");

my $log = Log::Log4perl->get_logger(__PACKAGE__);

my $backend = MySensors::Backend::Pg->new({dsn => 'DBI:Pg:database=mysensors;host=localhost', 
											user => 'mysensors', 
											password => 'mysensors'}) || 
												croak "Can't init Backend";

my $mysensors = MySensors->new({ host => '192.168.2.10',
                                 backend => $backend,
				 debug => 1,
			   }) || croak "Can't init MySensors";

$mysensors->connect() || croak "Can't connect to server";

$log->info("Connected to the server");

$mysensors->run();