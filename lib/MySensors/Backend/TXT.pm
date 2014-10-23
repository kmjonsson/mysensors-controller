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
	my($self,$sender,$payload) = @_;
	local *OUT;
	open(OUT,">id/${sender}.version") || die;
	print OUT $payload;
	close(OUT);
}

sub saveSensor {
	my($self,$sender,$sensor,$type) = @_;
	local *OUT;
	open(OUT,">id/${sender}.${sensor}.type") || die;
	print OUT $type;
	close(OUT);
}

sub getNextAvailableSensorId {
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
	my ($self,$sender,$sensor,$type,$payload) = @_;
	$payload =~ s,[\r\n],<NL>,g;
	local *OUT;
	open(OUT,">>id/${sender}.${sensor}.${type}.set") || die;
	printf OUT "%d;%s\n",time,$payload;
	close(OUT);
	open(OUT,">id/${sender}.${sensor}.${type}.latest") || die;
	printf OUT "%d;%s\n",time,$payload;
	close(OUT);
}

sub getValue {
	my ($self,$sender,$sensor,$type) = @_;
	local *IN;
	open(IN,"<id/${sender}.${sensor}.${type}.latest") || die;
	my($data) = <IN>;
	close(IN);
	if($data =~ /^(\d+);(.*)$/) {
		return $3;
	}
	return;
}

1;

