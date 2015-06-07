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

# Radio
my($radio) = loadGroup('Radio');
if(scalar @$radio == 0) {
	$log->error("Can't init Radio, aborting");
	exit(1);
}

# Backend
my($backend) = loadGroup('Backend');
if(scalar @$backend == 0) {
	$log->error("Can't init Backend, aborting");
	exit(1);
}
if(scalar @$backend > 1) {
	$log->error("Multiple Backend defined, aborting");
	exit(1);
}

# Plugins
my($plugins) = loadGroup("Plugin");

my $mysensors = loadPackage('MySensors',{ radio => $radio, backend => $backend->[0], plugins => $plugins }) || croak "Can't init MySensors";
if(!defined $mysensors) {
	$log->error("Can't init MySensors, aborting");
	exit(1);
}

$mysensors->run();

sub loadPackage {
	my($package,$extra,$section) = @_;
	$section //= $package;
	$log->info("Loading $section");
	eval "use $package";
	if( $@ ) { 
		$log->error("Unable to load $section: " . $@ );
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
		if($section !~ /^(\S+)\s+([^#]+)(#\d+|)$/) {
			$log->error("Bad section format '$section'. Expected: '$group <Module>' or '$group <Module>#<number>'");
			next;
		}
		my($grp,$package,$n) = ($1,$2,$3);
		my $p = loadPackage($package,$extra,$section);
		if(!defined $p) {
			$log->error("Can't init Plugin: $package$n, aborting");
			exit(1);
		}
		push @result,$p;
	}
	return \@result;
}
