#
# Simple backend using flat files.
#

package MySensors::Backend::TXT;

use strict;
use warnings;

sub new {
	my($class) = shift;
	my($opts) = shift // {};

	my $self  = {
		'datadir' => $opts->{'datadir'} // "id",
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	$self->{datadir} .= "/" unless $self->{datadir} =~ m{/$};
	bless ($self, $class);
	$self->{log}->debug("TXT Backend initialized, storing data in ".$self->{datadir});
	mkdir $self->{datadir} unless (-d $self->{datadir});
	return $self;
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.version") || die;
	print $fh $protocol;
	close($fh);
	$self->lastseen($nodeid);
	return;
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.${sensor}.type") || die;
	print $fh $type;
	close($fh);
	$self->lastseen($nodeid);
	return;
}

sub getNextAvailableNodeId {
	my($self) = @_;
	for my $id (1..254) {
		next if(-f $self->{datadir}."$id");
		open(my $fh,">",$self->{datadir}."$id") || die;
		close($fh) || die;
		return $id;
	}
	return;
}
sub lastseen {
	my ($self,$nodeid) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.lastseen") || die;
	printf $fh "%d\n",time;
	close($fh);
	return;
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$value =~ s,[\r\n],<NL>,g;
	open(my $fh,">>",$self->{datadir}."${nodeid}.${sensor}.${type}.set") || die;
	printf $fh "%d;%s\n",time,$value;
	close($fh);
	open($fh,">",$self->{datadir}."${nodeid}.${sensor}.${type}.latest") || die;
	printf $fh "%d;%s\n",time,$value;
	close($fh);
	$self->lastseen($nodeid);
	return;
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	open(my $fh,"<",$self->{datadir}."${nodeid}.${sensor}.${type}.latest") || return;
	my($data) = <$fh>;
	close($fh);
	if($data =~ /^(\d+);(.*)$/) {
		return $2;
	}
	return;
}


sub saveSketchName {
	my($self,$nodeid,$name) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.sketchname") || die;
	print $fh $name;
	close($fh);
	$self->lastseen($nodeid);
	return;
}

sub saveSketchVersion {
	my ($self,$nodeid,$version) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.sketchversion") || die;
	print $fh $version;
	close($fh);
	$self->lastseen($nodeid);
	return;
}
sub saveBatteryLevel {
	my ($self,$nodeid,$level) = @_;
	$level =~ s,[\r\n],<NL>,g;
	open(my $fh,">>",$self->{datadir}."${nodeid}.batterylevel") || die;
	printf $fh "%d;%s\n",time,$level;
	close($fh);
	open($fh,">",$self->{datadir}."${nodeid}.batterylevel.latest") || die;
	printf $fh "%d;%s\n",time,$level;
	close($fh);
	$self->lastseen($nodeid);
	return;
}
sub saveVersion {
	my ($self,$nodeid,$version) = @_;
	open(my $fh,">",$self->{datadir}."${nodeid}.fooversion") || die;
	print $fh $version;
	close($fh);
	$self->lastseen($nodeid);
	return;
}

1;

