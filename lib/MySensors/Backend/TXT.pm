#
# Simple backend using flat files.
#

package MySensors::Backend::TXT;

use strict;
use warnings;

sub new {
	my($class) = shift;

	my $self  = {
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{log}->debug("Backend initialized");
	mkdir "id" unless (-d "id");
	return $self;
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	open(my $fh,">","id/${nodeid}.version") || die;
	print $fh $protocol;
	close($fh);
	return;
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	open(my $fh,">","id/${nodeid}.${sensor}.type") || die;
	print $fh $type;
	close($fh);
	return;
}

sub getNextAvailableNodeId {
	my($self) = @_;
	for my $id (1..254) {
		next if(-f "id/$id");
		open(my $fh,">","id/$id") || die;
		close($fh) || die;
		return $id;
	}
	return;
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$value =~ s,[\r\n],<NL>,g;
	open(my $fh,">>","id/${nodeid}.${sensor}.${type}.set") || die;
	printf $fh "%d;%s\n",time,$value;
	close($fh);
	open($fh,">","id/${nodeid}.${sensor}.${type}.latest") || die;
	printf $fh "%d;%s\n",time,$value;
	close($fh);
	return;
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	open(my $fh,"<","id/${nodeid}.${sensor}.${type}.latest") || die;
	my($data) = <$fh>;
	close($fh);
	if($data =~ /^(\d+);(.*)$/) {
		return $2;
	}
	return;
}


sub saveSketchName {
	my($self,$nodeid,$name) = @_;
	open(my $fh,">","id/${nodeid}.sketchname") || die;
	print $fh $name;
	close($fh);
	return;
}

sub saveSketchVersion {
	my ($self,$nodeid,$version) = @_;
	open(my $fh,">","id/${nodeid}.sketchversion") || die;
	print $fh $version;
	close($fh);
	return;
}
sub saveBatteryLevel {
	my ($self,$nodeid,$level) = @_;
	$level =~ s,[\r\n],<NL>,g;
	open(my $fh,">>","id/${nodeid}.batterylevel") || die;
	printf $fh "%d;%s\n",time,$level;
	close($fh);
	open($fh,">","id/${nodeid}.batterylevel.latest") || die;
	printf $fh "%d;%s\n",time,$level;
	close($fh);
	return;
}
sub saveVersion {
	my ($self,$nodeid,$version) = @_;
	open(my $fh,">","id/${nodeid}.fooversion") || die;
	print $fh $version;
	close($fh);
	return;
}

1;

