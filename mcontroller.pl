#!/usr/bin/perl

use strict;
use warnings;

use Carp;

use Log::Log4perl;

use lib 'lib';

use MySensors;
use MySensors::Backend::TXT;
#use MySensors::Plugins::Example;
use MySensors::Plugins::Mattith;

my $host = shift @ARGV // '192.168.2.10';
my $datadir = shift @ARGV;
my $mattithhost = shift @ARGV // '192.168.0.1:2324';

# Init logger
Log::Log4perl->init("log.conf");

my $log = Log::Log4perl->get_logger(__PACKAGE__);

my $backend = MySensors::Backend::TXT->new({
				datadir=>$datadir,
			}) || croak "Can't init Backend";
my @plugins = (
                    MySensors::Plugins::Mattith->new({
						host => $mattithhost,
					}),
			);

my $mysensors = MySensors->new({ host => $host,
                                 backend => $backend,
                                 plugins => \@plugins,
				 debug => 1,
			   }) || croak "Can't init MySensors";

$mysensors->connect() || croak "Can't connect to server";

$log->info("Connected to the server");

$mysensors->run();
