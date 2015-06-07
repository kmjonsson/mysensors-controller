
package MySensors::Utils;

=head1 MySensors::Utils

Used for various functions that does not fit into any other place.

=head2 Author

Magnus Jonsson <fot@fot.nu>

=head2 Contributor

Tomas Forsman <>

=head2 LICENSE

GNU GENERAL PUBLIC LICENSE Version 2 

(See LICENSE file)

=head2 Methods

=over 12

=item loadPackage

Load a package with options from config file.

Used by controller.pl

=cut

sub loadPackage {
	my($log,$cfg,$package,$extra,$section) = @_;
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

=item loadGroup

Load modules based on Group with options from config file.

Used by controller.pl

=cut

sub loadGroup {
	my($log,$cfg,$group,$extra) = @_;
	my @result;
	foreach my $section ($cfg->GroupMembers($group)) {
		if($section !~ /^(\S+)\s+([^#]+)(#\d+|)$/) {
			$log->error("Bad section format '$section'. Expected: '$group <Module>' or '$group <Module>#<number>'");
			next;
		}
		my($grp,$package,$n) = ($1,$2,$3);
		my $p = loadPackage($log,$cfg,$package,$extra,$section);
		if(!defined $p) {
			$log->error("Can't init Plugin: $package$n, aborting");
			exit(1);
		}
		push @result,$p;
	}
	return \@result;
}

=back
=cut

1;
