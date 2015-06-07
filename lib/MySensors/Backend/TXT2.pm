#
# Simple backend using flat files.
#

package MySensors::Backend::TXT2;

use strict;
use warnings;

use threads::shared;

use JSON;

sub new {
	my($class) = shift;
	my($opts) = shift // {};

	my $self  = {
		'controller' => undef,
		'datadir' => $opts->{'datadir'},
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
		'nodes' => undef,
		'values' => undef,
	};
	
	$self->{datadir} .= "/" unless $self->{datadir} =~ m{/$};
	bless ($self, $class);
	return $self;
}

sub init {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	if(!-d $self->{datadir}) {
		$self->{log}->error("'" . $self->{datadir} . "' does not exist");
		return undef;
	}
	if(!$self->_load()) {
		$self->{log}->error("TXT Backend initialization failed");
		return undef;
	}
	$self->{log}->debug("TXT Backend initialized, storing data in ".$self->{datadir});
	return $self;
}

sub getNodes {
	my($self) = @_;
	return $self->{nodes};
}

sub getValues {
	my($self) = @_;
	return $self->{values};
}

sub clone {
	my($self) = @_;
	return $self;
}

sub _load {
	my($self) = @_;
	my %nodes;
	my %values;
	opendir(my $dir,$self->{datadir}) || return undef;
	foreach my $node (readdir($dir)) {
		next unless $node =~ /^\d+$/;
		my $cfg;
		# nodes
		if(!open($cfg,"<", $self->{datadir} . "$node/node.json")) {
			$self->{log}->error("Failed to open: " . $self->{datadir} . "$node/node.json: $!");
			return undef;
		}
		my $json = join("",<$cfg>);
		close($cfg);
		if(!eval { $nodes{$node} = from_json($json); }) {
			$self->{log}->error("Failed to parse: " . $self->{datadir} . "$node/node.json: $!");
			return undef;
		}
		# values
		if(!open($cfg,"<", $self->{datadir} . "$node/values.json")) {
			$self->{log}->error("Failed to open: " . $self->{datadir} . "$node/values.json: $!");
			return undef;
		}
		$json = join("",<$cfg>);
		close($cfg);
		if(!eval { $values{$node} = from_json($json); }) {
			$self->{log}->error("Failed to parse: " . $self->{datadir} . "$node/values.json: $!");
			return undef;
		}
	}
	closedir($dir);
	$self->{nodes}  = shared_clone(\%nodes);
	$self->{values} = shared_clone(\%values);
	$self->{controller}->receive({type => 'CONFIG'});
	return $self;
}

sub _save {
	my($self,$node) = @_;
	if(!defined $self->{nodes}->{$node}) {
			$self->{log}->error("Trying to save undefined node :-/");
			return undef;
	}
	if(!-d $self->{datadir} . "$node") {
		if(!mkdir($self->{datadir} . "$node")) {
			$self->{log}->error("Failed to mkdir: " . $self->{datadir} . "$node");
			return undef;
		}
	}
	my $cfg;
	# nodes
	if(!open($cfg,">",$self->{datadir} . "$node/node.json.new")) {
			$self->{log}->error("Failed to open (for writing): " . $self->{datadir} . "$node/node.json.new");
			return undef;
	}
	print $cfg to_json($self->{nodes}->{$node},{pretty => 1, canonical => 1});
	if(!close($cfg)) {
			$self->{log}->error("Failed to close (for writing): " . $self->{datadir} . "$node/node.json.new");
			return undef;
	}
	if(!rename($self->{datadir} . "$node/node.json.new",$self->{datadir} . "$node/node.json")) {
			$self->{log}->error("Failed to rename: " . $self->{datadir} . "$node/node.json.new to " . $self->{datadir} . "$node/node.json");
			unlink($self->{datadir} . "$node/node.json.new"); # || ignore :-/
			return undef;
	}
	$self->{controller}->receive({type => 'CONFIG'});
	return $self->_saveValues($node);
}

sub _saveValues {
	my($self,$node) = @_;
	if(!defined $self->{values}->{$node}) {
			$self->{log}->error("Trying to save undefined node :-/");
			return undef;
	}
	if(!-d $self->{datadir} . "$node") {
		if(!mkdir($self->{datadir} . "$node")) {
			$self->{log}->error("Failed to mkdir: " . $self->{datadir} . "$node");
			return undef;
		}
	}
	my $cfg;
	# values
	if(!open($cfg,">",$self->{datadir} . "$node/values.json.new")) {
			$self->{log}->error("Failed to open (for writing): " . $self->{datadir} . "$node/values.json.new");
			return undef;
	}
	print $cfg to_json($self->{values}->{$node},{pretty => 1, canonical => 1});
	if(!close($cfg)) {
			$self->{log}->error("Failed to close (for writing): " . $self->{datadir} . "$node/values.json.new");
			return undef;
	}
	if(!rename($self->{datadir} . "$node/values.json.new",$self->{datadir} . "$node/values.json")) {
			$self->{log}->error("Failed to rename: " . $self->{datadir} . "$node/values.json.new to " . $self->{datadir} . "$node/values.json");
			unlink($self->{datadir} . "$node/values.json.new"); # || ignore :-/
			return undef;
	}
}

sub _initNode {
	my($self,$nodeid) = @_;
	if(!defined $self->{nodes}->{$nodeid}) {
		my %nodes :shared = (
			'protocol'      => undef,
			'version'       => undef,
			'sketchversion' => undef,
			'sketchname'    => undef,
			'savelog'       => 'yes',
		);
		$self->{nodes}->{$nodeid} = \%nodes;
		# Just create $nodeid hash to have it :-)
		my %values :shared;
		$self->{values}->{$nodeid} //= \%values;
		$self->_save($nodeid);
		return $self;
	}
	return;
}

sub _initSensor {
	my($self,$nodeid,$sensor) = @_;
	$self->_initNode($nodeid);
	if(!defined $self->{nodes}->{$nodeid}->{$sensor}) {
		my %sensor :shared = (
			'type'          => undef,
			'description'   => ($nodeid == 255?'Node':undef),
			'savelog'       => 'parent',
		);
		$self->{nodes}->{$nodeid}->{$sensor} //= \%sensor;
		# Just create $nodeid hash to have it :-)
		my %values :shared;
		$self->{values}->{$nodeid}->{$sensor} //= \%values;
		$self->_save($nodeid);
	}
}

sub _setNodeItem {
	my($self,$nodeid,$key,$value) = @_;
	$self->_initNode($nodeid);

	my $noupdate = {
		'sketchname' => 1
	};
	$self->lastseen($nodeid);

	# only set "default" keys if ! defined.
	return $self if exists $noupdate->{$key} && defined $self->{nodes}->{$nodeid}->{$key};
	return $self if defined $self->{nodes}->{$nodeid}->{$key} && $self->{nodes}->{$nodeid}->{$key} eq $value;

	$self->{nodes}->{$nodeid}->{$key} = $value;
	$self->_save($nodeid) || return undef;

	return $self;
}

sub _setSensorItem {
	my($self,$nodeid,$sensorid,$key,$value,$nosave) = @_;
	$self->_initSensor($nodeid,$sensorid);
	my $noupdate = {
		'description' => 1
	};
	$self->lastseen($nodeid,$sensorid);
	return $self if exists $noupdate->{$key} && defined $self->{nodes}->{$nodeid}->{$sensorid}->{$key};
	return $self if defined $self->{nodes}->{$nodeid}->{$sensorid}->{$key} && $self->{nodes}->{$nodeid}->{$sensorid}->{$key} eq $value;

	$self->{nodes}->{$nodeid}->{$sensorid}->{$key} = $value;
	#unless($nosave // 0) { # ignore :-)
		$self->_save($nodeid) || return undef;
	#}
	return $self;
}

sub _getSaveLog {
	my($self,$nodeid,$sensor) = @_;
    if(defined $self->{nodes}->{$nodeid} &&
       defined $self->{nodes}->{$nodeid}->{$sensor}) {
		my $val = $self->{nodes}->{$nodeid}->{$sensor}->{"savelog"};
		if(defined $val && $val eq 'parent') {
			my $nval = $self->{nodes}->{$nodeid}->{"savelog"};
			return ($nval // "yes") eq 'yes';
		}
		return ($val // "yes") eq 'yes';
	}
	return 'yes';
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	return $self->_setNodeItem($nodeid,'protocol',$protocol);
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type) = @_;
	return $self->_setSensorItem($nodeid,$sensor,'type',$type);
}

sub getNextAvailableNodeId {
	my($self) = @_;
	for my $nodeid (1..254) {
		if(!defined $self->{nodes}->{$nodeid}) {
			return $nodeid if $self->_initNode($nodeid);
		}
	}
	return;
}

sub lastseen {
	my($self,$nodeid,$sensorid,$type) = @_;
	my %node :shared;
	$self->{values}->{$nodeid} //= \%node if defined $nodeid;
	if(defined $nodeid && defined $self->{values}->{$nodeid}) {
		$self->{values}->{$nodeid}->{lastseen} = time;
		my %sensor :shared;
		$self->{values}->{$nodeid}->{$sensorid} //= \%sensor if defined $sensorid;
		if(defined $sensorid && defined $self->{values}->{$nodeid}->{$sensorid}) {
			$self->{values}->{$nodeid}->{$sensorid}->{lastseen} = time;
			my %type :shared;
			$self->{values}->{$nodeid}->{$sensorid}->{$type} //= \%type if defined $type;
			if(defined $type && defined $self->{values}->{$nodeid}->{$sensorid}->{$type}) {
				$self->{values}->{$nodeid}->{$sensorid}->{$type}->{lastseen} = time;
			}
		}
	}
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;
	$value =~ s,[\r\n],<NL>,g;

	$self->_initSensor($nodeid,$sensor);

	$self->lastseen($nodeid,$sensor,$type);
	$self->{values}->{$nodeid}->{$sensor}->{$type}->{value} = $value;
	$self->_saveValues($nodeid);

	if(0) {
		if($self->_getSaveLog($nodeid,$sensor)) {
			open(my $fh,">>",$self->{datadir}."${nodeid}/${sensor}.${type}.log") || die;
			printf $fh "%d;%s\n",time,$value;
			close($fh);
		}

		open(my $fh,">",$self->{datadir}."${nodeid}/${sensor}.${type}.json") || die;
		printf $fh to_json({
			timestamp => time,
			value     => $value,
			type      => $type,
			typeStr   => MySensors::Const::SetReqToStr($type),
		});
		close($fh);
	}
	return;
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	if(defined $self->{values}->{$nodeid} &&
	   defined $self->{values}->{$nodeid}->{$sensor} &&
	   defined $self->{values}->{$nodeid}->{$sensor}->{$type}) {
		return $self->{values}->{$nodeid}->{$sensor}->{$type}->{value};
	}
	return;
}

sub getValueLastSeen {
	my ($self,$nodeid,$sensor,$type) = @_;
	if(defined $self->{values}->{$nodeid} &&
	   defined $self->{values}->{$nodeid}->{$sensor} &&
	   defined $self->{values}->{$nodeid}->{$sensor}->{$type}) {
		return $self->{values}->{$nodeid}->{$sensor}->{$type}->{lastseen};
	}
	return;
}

sub saveSketchName {
	my($self,$nodeid,$sketchname) = @_;
	return $self->_setNodeItem($nodeid,'sketchname',$sketchname);
}

sub saveSketchVersion {
	my ($self,$nodeid,$sketchversion) = @_;
	return $self->_setNodeItem($nodeid,'sketchversion',$sketchversion);
}

sub saveBatteryLevel {
	my ($self,$nodeid,$level) = @_;
	$self->saveValue($nodeid,255,MySensors::Const::SetReq('VOLTAGE'),$level);
	return;
}
sub saveVersion {
	my ($self,$nodeid,$version) = @_;
	return $self->_setNodeItem($nodeid,'version',$version);
	return;
}

1;

