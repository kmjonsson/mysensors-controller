#
# Simple backend using flat files.
#

package MySensors::Backend::TXT2;

use strict;
use warnings;

use JSON;

use base 'MySensors::Backend';

use MySensors::Const;

sub new {
        my($class) = shift;
        my($opts) = shift // {};

		$opts->{name} = __PACKAGE__;
        my $self = $class->SUPER::new($opts);
        $self->{log} = Log::Log4perl->get_logger(__PACKAGE__);
        # Options
        $self->{'nodes'}                   = undef;
        $self->{'values'}                  = undef;
        $self->{'datadir'}                 = $opts->{datadir};
		$self->{datadir} .= "/" unless $self->{datadir} =~ m{/$};
        $self->{log}->info(__PACKAGE__ . " initialized");
        return $self;
}

sub init {
	my($self) = @_;
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

# remove?
sub getNodes {
	my($self) = @_;
	return $self->{nodes};
}

# remove?
sub getValues {
	my($self) = @_;
	return $self->{values};
}

# remove?
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
		if(!open($cfg,"<", $self->{datadir} . "/$node/node.json")) {
			$self->{log}->error("Failed to open: " . $self->{datadir} . "/$node/node.json: $!");
			return undef;
		}
		my $json = join("",<$cfg>);
		close($cfg);
		if(!eval { $nodes{$node} = from_json($json); }) {
			$self->{log}->error("Failed to parse: " . $self->{datadir} . "/$node/node.json: $!");
			return undef;
		}
		# values
		if(!open($cfg,"<", $self->{datadir} . "$node/values.json")) {
			$self->{log}->error("Failed to open: " . $self->{datadir} . "/$node/values.json: $!");
			return undef;
		}
		$json = join("",<$cfg>);
		close($cfg);
		if(!eval { $values{$node} = from_json($json); }) {
			$self->{log}->error("Failed to parse: " . $self->{datadir} . "/$node/values.json: $!");
			return undef;
		}
	}
	closedir($dir);
	for my $val (keys %values) { # upgrade check
		if (!defined $values{$val}->{lastseenvia}) {
			$self->{log}->debug("Upgrading node $val to contain lastseenvia");
			$values{$val}->{lastseenvia} = {};
		}
	}
	$self->{nodes}  = \%nodes;
	$self->{values} = \%values;
	# send data to MySensors::Backend::Nodes and/or Values
	$self->sendNodes($self->getNodes());
	$self->sendValues($self->getValues());
	return $self;
}

sub _save {
	my($self,$node) = @_;
	if(!defined $self->{nodes}->{$node}) {
			$self->{log}->error("Trying to save undefined node :-/");
			return undef;
	}
	if(!-d $self->{datadir} . "/$node") {
		if(!mkdir($self->{datadir} . "/$node")) {
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
	# send data to MySensors::Backend::Nodes and/or Values
	$self->sendNodes($self->getNodes());
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
	$self->sendValues($self->getValues());
}

sub _initNode {
	my($self,$nodeid) = @_;
	if(!defined $self->{nodes}->{$nodeid}) {
		my %nodes = (
			'protocol'      => undef,
			'version'       => undef,
			'sketchversion' => undef,
			'sketchname'    => undef,
			'savelog'       => 'yes',
			'sensors'	    => {},
			'lastseenvia'   => {},
		);
		$self->{nodes}->{$nodeid} = \%nodes;
		$self->lastseen($nodeid);
		$self->_save($nodeid);
		return $self;
	}
	$self->lastseen($nodeid);
	return;
}

sub _initSensor {
	my($self,$nodeid,$sensor) = @_;
	$self->_initNode($nodeid);
	if(!defined $self->{nodes}->{$nodeid}->{sensors}->{$sensor}) {
		my %sensor = (
			'type'          => undef,
			'types'         => {},
			'description'   => ($nodeid == 255?'Node':undef),
			'savelog'       => 'parent',
		);
		$self->{nodes}->{$nodeid}->{sensors}->{$sensor} //= \%sensor;
		$self->lastseen($nodeid,$sensor);
		$self->_save($nodeid);
	}
	$self->lastseen($nodeid,$sensor);
	return;
}

sub _initType {
	my($self,$nodeid,$sensor,$type) = @_;
	$self->_initSensor($nodeid,$sensor);
	if(!defined $self->{nodes}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type}) {
		my %type = (
			'description'   => MySensors::Const::SetReqToStr($type),
		);
		$self->{nodes}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type} //= \%type;
		$self->lastseen($nodeid,$sensor,$type);
		$self->_save($nodeid);
	}
	$self->lastseen($nodeid,$sensor,$type);
	return;
}

sub _setNodeItem {
	my($self,$nodeid,$key,$value) = @_;
	$self->_initNode($nodeid);
	my $noupdate = {
		'sketchname' => 1
	};
	# only set "default" keys if ! defined.
	return $self if exists $noupdate->{$key} 
	             && defined $self->{nodes}->{$nodeid}->{$key};
	return $self if defined $self->{nodes}->{$nodeid}->{$key} 
	                     && $self->{nodes}->{$nodeid}->{$key} eq $value;

	$self->{nodes}->{$nodeid}->{$key} = $value;
	$self->_save($nodeid) || return undef;
	return $self;
}

sub _setSensorItem {
	my($self,$nodeid,$sensorid,$key,$value) = @_;
	$self->_initSensor($nodeid,$sensorid);
	my $noupdate = {
		'description' => 1
	};

	# only set "default" keys if ! defined.
	return $self if exists $noupdate->{$key} 
	             && defined $self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{$key};
	return $self if defined $self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{$key} 
	                     && $self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{$key} eq $value;

	$self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{$key} = $value;
	$self->_save($nodeid) || return undef;
	return $self;
}

sub _setTypeItem {
	my($self,$nodeid,$sensorid,$type,$key,$value) = @_;
	$self->_initType($nodeid,$sensorid,$type);
	my $noupdate = {
		'description' => 1
	};

	# only set "default" keys if ! defined.
	return $self if exists $noupdate->{$key} && 
	                defined $self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$type}->{$key};
	return $self if defined $self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$type}->{$key} && 
                            $self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$type}->{$key} eq $value;

	$self->{nodes}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$type}->{$key} = $value;
	$self->_save($nodeid) || return undef;
	return $self;
}

sub _processLog {
	my ($self,$nodeid,$payload) = @_;
	if ($payload =~ /read: (\d+)-(\d+)-(\d+)/) {
		if ($1 != 255) {
		    $self->lastseen($1);
		    $self->lastseen($2);
		    $self->lastseenvia($1,$2)
		}
	}
	return;
}

sub saveProtocol {
	my($self,$nodeid,$protocol) = @_;
	return $self->_setNodeItem($nodeid,'protocol',$protocol);
}

sub saveSensor {
	my($self,$nodeid,$sensor,$type,$description) = @_;
	my $x = $self->_setSensorItem($nodeid,$sensor,'type',$type);
	return unless defined $x;
	return $self->_setSensorItem($nodeid,$sensor,'description',$description);
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

sub nodeexists {
	my($self,$nodeid) = @_;
	if (defined $self->{nodes}->{$nodeid}) {
		return 1;
	}
	return 0;
}

sub lastseen {
	my($self,$nodeid,$sensorid,$type) = @_;
	if(defined $nodeid) {
		$self->{values}->{$nodeid} //= { sensors => {} };
		$self->{values}->{$nodeid}->{lastseen} = time;
		if(defined $sensorid) {
			$self->{values}->{$nodeid}->{sensors}->{$sensorid} //= { types => {} };
			$self->{values}->{$nodeid}->{sensors}->{$sensorid}->{lastseen} = time;
			if(defined $type) {
				$self->{values}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$type} //= {} if defined $type;
				$self->{values}->{$nodeid}->{sensors}->{$sensorid}->{types}->{$type}->{lastseen} = time;
			}
		}
	}
}
sub lastseenvia {
	my($self,$nodeid,$vianode) = @_;
	$self->{log}->debug("lastseenvia($nodeid,$vianode)");
	if (!$self->nodeexists($nodeid)) {
		$self->{log}->error("lastseenvia failing, $nodeid does not exist");
		return;
	}
	if (!$self->nodeexists($vianode)) {
		$self->{log}->error("lastseenvia failing, $vianode does not exist");
		return;
	}
	if(defined $nodeid && defined $vianode) {
		$self->{values}->{$nodeid} //= { lastseenvia => {} };
		$self->{values}->{$nodeid}->{lastseenvia} //= {};
		$self->{values}->{$nodeid}->{lastseenvia}->{$vianode} = time;
		$self->{log}->debug("updated lastseenvia");
	}
}

sub saveValue {
	my ($self,$nodeid,$sensor,$type,$value) = @_;

	$self->{log}->info("saveValue: node=$nodeid,sensor=$sensor,type=$type,value=$value");

	$value =~ s,[\r\n],<NL>,g;

	$self->_initType($nodeid,$sensor,$type);
	$self->{values}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type}->{value} = $value;
	$self->_saveValues($nodeid);
	return;
}

sub getValue {
	my ($self,$nodeid,$sensor,$type) = @_;
	if(defined $self->{values}->{$nodeid} &&
	   defined $self->{values}->{$nodeid}->{sensors}->{$sensor} &&
	   defined $self->{values}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type}) {
		return $self->{values}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type}->{value};
	}
	return;
}

sub getValueLastSeen {
	my ($self,$nodeid,$sensor,$type) = @_;
	if(defined $self->{values}->{$nodeid} &&
	   defined $self->{values}->{$nodeid}->{sensors}->{$sensor} &&
	   defined $self->{values}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type}) {
		return $self->{values}->{$nodeid}->{sensors}->{$sensor}->{types}->{$type}->{lastseen};
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
	$self->{log}->info("Save battery Level: $nodeid = $level");
	$self->saveValue($nodeid,255,MySensors::Const::SetReq('VOLTAGE'),$level);
	return;
}
sub saveVersion {
	my ($self,$nodeid,$version) = @_;
	return $self->_setNodeItem($nodeid,'version',$version);
}
sub processLog {
	my($self,$nodeid,$payload) = @_;
	$self->_processLog($nodeid,$payload);
	return;
}


1;

