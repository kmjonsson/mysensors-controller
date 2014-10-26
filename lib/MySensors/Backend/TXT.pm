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
	return $self;
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	local *OUT;
	open(OUT,">id/${nodeid}.version") || die;
	print OUT $protocol;
	close(OUT);
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	local *OUT;
	open(OUT,">id/${nodeid}.${sensor}.type") || die;
	print OUT $type;
	close(OUT);
}

sub getNextAvailableNodeId {
	my($self) = @_;
	for my $id (1..254) {
		next if(-f "id/$id");
		local *OUT;
		open(OUT,">id/$id") || die;
		close(OUT) || die;
		return $id;
	}
	return;
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$value =~ s,[\r\n],<NL>,g;
	local *OUT;
	open(OUT,">>id/${nodeid}.${sensor}.${type}.set") || die;
	printf OUT "%d;%s\n",time,$value;
	close(OUT);
	open(OUT,">id/${nodeid}.${sensor}.${type}.latest") || die;
	printf OUT "%d;%s\n",time,$value;
	close(OUT);
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	local *IN;
	open(IN,"<id/${nodeid}.${sensor}.${type}.latest") || die;
	my($data) = <IN>;
	close(IN);
	if($data =~ /^(\d+);(.*)$/) {
		return $3;
	}
	return;
}

1;

