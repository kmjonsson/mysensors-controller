#!/usr/bin/perl

use strict;
use warnings;

use Carp;
use Log::Log4perl;
use Config::IniFiles;

use lib 'lib';

my $configFile = shift @ARGV // "config.ini";

my $cfg = Config::IniFiles->new(-file => $configFile) || croak "Can't load $configFile";

# Init logger
my $logconf = $cfg->val('MySensors','logconf') || croak "'logconf' missing from MySensors section in $configFile";
Log::Log4perl->init($logconf) || croak "Can't load $logconf";

my $log = Log::Log4perl->get_logger(__PACKAGE__) || croak "Can't init log";

my($backend) = loadGroup('Backend');
if(scalar @$backend == 0) {
	$log->error("Can't init Backend");
	exit(1);
}
if(scalar @$backend > 1) {
	$log->error("Multiple backend defined");
	exit(1);
}

my($plugins) = loadGroup("Plugin");

my $mysensors = loadPackage('MySensors',{ backend => $backend->[0], plugins => $plugins }) || croak "Can't init MySensors";
if(!defined $mysensors) {
	$log->error("Can't init MySensors");
	exit(1);
}

if(!$mysensors->connect()) {
 	$log->error("Can't connect to server");
	exit(1);
}

$log->info("Connected to the server");

$mysensors->run();

sub loadPackage {
	my($package,$extra,$section) = @_;
	$section //= $package;
	$log->info("Loading package $package");
	eval "use $package";
	if( $@ ) { 
		$log->error("Unable to load package $package");
		return undef;
	}
	my %opts;
	foreach my $k ($cfg->Parameters($section)) {
		$opts{$k} = $cfg->val($section,$k) unless $k eq 'package';
	}
	foreach my $k (keys %$extra) {
		$opts{$k} = $extra->{$k};
	}
	return $package->new(\%opts);
}

sub loadGroup {
	my($group,$extra) = @_;
	my @result;
	foreach my $section ($cfg->GroupMembers($group)) {
		my($grp,$package) = split(/\s+/,$section,2);
		my $p = loadPackage($package,$extra,$section);
		if(!defined $p) {
			$log->error("Can't init Plugin: $package");
			exit(1);
		}
		push @result,$p;
	}
	return \@result;
}
