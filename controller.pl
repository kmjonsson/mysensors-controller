#!/usr/bin/perl
=head1 MySensor.org Controller

=head2 Author

Magnus Jonsson <fot@fot.nu>

=head2 Contributor

Tomas Forsman <>

=head2 LICENSE

GNU GENERAL PUBLIC LICENSE Version 2 

(See LICENSE file)

=head1 OPTIONS

=over 12

=item C<--config file>

Define config file to use

Default: C<$FindBin::bin/config.ini>

=item C<--daemon>

Send controller into background

=item C<--pidfile file>

Pid file to use

=back

=cut

use strict;
use warnings;

use Carp;
use Log::Log4perl;
use Config::IniFiles;

use Getopt::Long;

use FindBin;
use lib "$FindBin::Bin/lib";

use MySensors::Utils;

=head1 Basic flow

=over 12

=cut

my $configFile = "$FindBin::Bin/config.ini";
my $plugin     = undef;
GetOptions (
		"config=s" => \$configFile,    # numeric
		"plugin=s"   => \$plugin,      # string
	)
or die("Error in command line arguments\n");

=item C<Read config file>

=cut
my $cfg = Config::IniFiles->new(-file => $configFile) || croak "Can't load $configFile";

=item C<Init Log4Perl>

=cut
my $logconf = $cfg->val('MySensors::Controller','logconf') || croak "'logconf' missing from MySensors section in $configFile";
Log::Log4perl->init($logconf) || croak "Can't load $logconf";
my $log = Log::Log4perl->get_logger(__PACKAGE__) || croak "Can't init log";

$0 = 'MySensors';
my %children;
my $masterpid = $$;

$SIG{HUP} = $SIG{KILL} = sub {
	if($$ == $masterpid) {
		kill 'HUP', sort keys %children;
		exit(1);
	}
};

END {
	if($$ == $masterpid) {
		kill 'HUP', sort keys %children;
		exit(1);
	}
};

# Fork off MMQ-Server
my $mmqpid = fork();
if(!defined $mmqpid) {
	$log->error("Failed to fork()");
	exit(1);
}
my $mmq;
if(!$mmqpid) {
	setpgrp(0,getppid());
	$0 = 'MySensors::MMQ';
	$mmq = MySensors::Utils::loadPackage($log,$cfg,'MySensors::MMQ',{cfg => $cfg, log => $log, server => 1, key => 'MyS'}) || croak "Can't init MySensors::MMQ (server)";
	$mmq->run();
	exit;
} else {
	$mmq = MySensors::Utils::loadPackage($log,$cfg,'MySensors::MMQ',{cfg => $cfg, log => $log, server => 0, key => 'MyS'}) || croak "Can't init MySensors::MMQ (client)";
}
$log->info("MySensors::MMQ forked @ $mmqpid");
$children{$mmqpid} = 'MySensors::MMQ';

=item C<Load Controller>

=cut
my $controllerpid = fork();
if(!defined $controllerpid) {
	$log->error("Failed to fork() Controller");
	exit(1);
}
if(!$controllerpid) {
	setpgrp(0,getppid());
	$0 = 'MySensors::Controller';
	my $controller = MySensors::Utils::loadPackage($log,$cfg,'MySensors::Controller',{ cfg => $cfg, mmq => $mmq }) || croak "Can't init MySensors";
	$controller->start();
	exit;
}
$log->info("MySensors::Controller forked @ $controllerpid");
$children{$controllerpid} = 'MySensors::MMQ';

=item C<Load Module(s)>

=cut

my(@modules) = MySensors::Utils::listGroup($cfg,'Module');
if(scalar @modules == 0) {
	$log->error("No modules to init");
	kill 'HUP', sort keys %children;
	exit(1);
}

foreach my $module (sort @modules) {
	my $pid = fork();
	if(!defined $pid) {
		$log->error("Failed to fork :-(, aborting");
		kill 'HUP', sort keys %children;
		exit(1);
	}
	if($pid) {
		$children{$pid} = $module;
	} else {
		setpgrp(0,getppid());
		$0 = $module;
		my $mod = MySensors::Utils::loadPackage($log,$cfg,$module,{cfg => $cfg, log => $log, mmq => $mmq},"Module $module");
		if(!defined $mod) {
			$log->error("Failed to load $module");
			exit(1);
		}
		my $type = $mod->moduleType();
		$log->info("Loaded $mod ($type)");
		my $e = $mod->start();
		$log->info("Exited $mod ($type)");
		exit;
	}
}

sleep(2);

$mmq->connect() || die;

foreach my $module ('MySensors::Controller', sort @modules) {
	my $trycount = 5;
	while(!defined $mmq->rpc($module . '::ping')) {
		print "$trycount\n";
		if($trycount-- == 0) {
			kill 'HUP', sort keys %children;
			$log->error("$module failed to start");
			exit(1);
		}
	}
}
foreach my $module ('MySensors::Controller', sort @modules) {
	if(!defined $mmq->rpc($module . '::start')) {
			kill 'HUP', sort keys %children;
			$log->error("$module failed to start");
			exit(1);
	}
	$log->info("$module started");
}

my $pid = wait();
$log->error("$pid ($children{$pid}) died... exiting");
