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

use FindBin;
use lib "$FindBin::Bin/lib";

use MySensors::Utils;

=head1 Basic flow

=over 12

=cut

# TODO: Use GetOpt...
my $configFile = shift @ARGV // "$FindBin::Bin/config.ini";

=item C<Read config file>

=cut
my $cfg = Config::IniFiles->new(-file => $configFile) || croak "Can't load $configFile";

=item C<Init Log4Perl>

=cut
my $logconf = $cfg->val('MySensors::Controller','logconf') || croak "'logconf' missing from MySensors section in $configFile";
Log::Log4perl->init($logconf) || croak "Can't load $logconf";
my $log = Log::Log4perl->get_logger(__PACKAGE__) || croak "Can't init log";

=item C<Load Radio Module(s)>

=cut
my($radio) = MySensors::Utils::loadGroup($log,$cfg,'Radio');
if(scalar @$radio == 0) {
	$log->error("Can't init Radio");
	exit(1);
}

=item C<Load Backend Module>

=cut
my($backend) = MySensors::Utils::loadGroup($log,$cfg,'Backend');
if(scalar @$backend == 0) {
	$log->error("Can't init Backend");
	exit(1);
}
if(scalar @$backend > 1) {
	$log->error("Multiple Backend defined");
	exit(1);
}

=item C<Load Plugin Module(s)>

=cut
my($plugins) = MySensors::Utils::loadGroup($log,$cfg,"Plugin");

=item C<Create MySensors object>

=cut
my $mysensors = MySensors::Utils::loadPackage($log,$cfg,'MySensors::Controller',{ radio => $radio, backend => $backend->[0], plugins => $plugins }) || croak "Can't init MySensors";
if(!defined $mysensors) {
	$log->error("Can't init MySensors");
	exit(1);
}

=item C<Run until done :-)>

=cut
$mysensors->run();

=back
