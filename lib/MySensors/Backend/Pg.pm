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
	$self->{log}->debug("Pg Backend initialized");
	return $self;
}

sub _query {
        my($self,$sql,@args) = @_;
        my $sth = $self->{dbh}->prepare($sql);
        if($sth->execute(@args) < 0) {
			$self->{log}->debug("Query failed: $sql = " . join(",",@args) . " - " . $DBI::errstr );
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
	my $sql = "select $func";
	#printf("%s <- (%s)\n",$sql,join(" , ",@args));
	my $result = $self->_query($sql,@args);
	return unless defined $result;
	return unless defined $result->[0];
	#print "Result: " . Dumper($result) . "\n";
	#print "Result: " . Dumper(@{$result->[0]}) . "\n";
	return @{$result->[0]};
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	return $self->_call('save_protocol(?::integer,?::text)',$nodeid,$protocol);
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	return $self->_call('save_sensor(?::integer,?::integer,?::integer)',$nodeid,$sensor,$type);
}

sub getNextAvailableNodeId {
	my($self) = @_;
	return $self->_call('get_next_available_nodeid()');
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	return $self->_call('save_value(?::integer,?::integer,?::integer,?::text)',$nodeid,$sensor,$type,$value);
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	return $self->_call('get_value(?::integer,?::integer,?::integer)',$nodeid,$sensor,$type);
}

sub saveBatteryLevel {
	my ($self,$nodeid,$batteryLevel) = @_;
	return $self->_call('save_batterylevel(?::integer,?::integer)',$nodeid,$batteryLevel);
}

sub saveSketchName {
	my ($self,$nodeid,$name) = @_;
	return $self->_call('save_sketch_name(?::integer,?::text)',$nodeid,$name);
}

sub saveSketchVersion {
	my ($self,$nodeid,$version) = @_;
	return $self->_call('save_sketch_version(?::integer,?::text)',$nodeid,$version);
}

sub saveVersion {
	my ($self,$nodeid,$version) = @_;
	return $self->_call('save_version(?::integer,?::text)',$nodeid,$version);
}

1;

