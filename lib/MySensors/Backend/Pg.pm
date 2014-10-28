#
# Simple backend using flat files.
#

package MySensors::Backend::Pg;

use strict;
use warnings;

use Data::Dumper;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		'dsn' => $opts->{'dsn'} // "",
		'user' => $opts->{'user'} // "",
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{dbh} = DBI->connect($self->{dsn}, $self->{user}, $opts->{password} // "", 
			{ RaiseError => 1, 'pg_enable_utf8' => 1 });
	$self->{dbh}->do("SET CLIENT_ENCODING='UTF8';");
	$self->{log}->debug("Backend initialized");
	return $self;
}

sub _query {
        my($self,$sql,@args) = @_;
        my $sth = $self->{dbh}->prepare($sql);
        if($sth->execute(@args)) {
		return;
        }
        my @result;
        while(1) {
                my(@data) = $sth->fetchrow_array();
                last unless defined $data[0];
                push @result,\@data;
        }
        return \@result;
}

sub _call {
	my($self,$func,@args) = @_;
	my $sql = "select $func(" . join(",",map { "?" } 1 .. (scalar @args)) . ")";
	#printf("%s(%s)\n",$sql,join(" , ",@args));
	my $result = $self->_query($sql,@args);
	return unless defined $result;
	return @{$result->[0]};
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	return $self->_call('save_protocol',$nodeid,$protocol);
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	return $self->_call('save_sensor',$nodeid,$sensor,$type);
}

sub getNextAvailableNodeId {
	my($self) = @_;
	return $self->_call('get_next_available_nodeid');
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	return $self->_call('save_value',$nodeid,$sensor,$type,$value);
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	return $self->_call('get_value',$nodeid,$sensor,$type);
}

sub saveBatteryLevel {
	my ($self,$nodeid,$batteryLevel) = @_;
	return $self->_call('save_batterylevel',$nodeid,$batteryLevel);
}

sub saveSketchName {
	my ($self,$nodeid,$name) = @_;
	return $self->_call('save_sketch_name',$nodeid,$name);
}

sub saveSketchVersion {
	my ($self,$nodeid,$version) = @_;
	return $self->_call('save_sketch_version',$nodeid,$version);
}

sub saveVersion {
	my ($self,$nodeid,$version) = @_;
	return $self->_call('save_version',$nodeid,$version);
}

1;

