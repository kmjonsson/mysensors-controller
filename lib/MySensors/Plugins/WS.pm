#
# WS Plugin 
#

package MySensors::Plugins::WS;

use strict;
use warnings;

use HTTP::Daemon;
use HTTP::Status;

use threads;
use threads::shared;
use Thread::Queue;

use JSON;
use Data::Dumper;

sub new {
	my($class,$opts) = @_;
	
	my %data :shared;
	my $self = {
		'controller' => undef,
		'port' => $opts->{port} // 9998,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
		'queue' => Thread::Queue->new(),
		'data' => \%data,
	};
	bless ($self, $class);
	$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('updatedConfig',$self);
	$controller->register('saveValue',$self);
	$controller->register('saveBatteryLevel',$self);

	my $config = $self->{controller}->{backend}->getConfig();
	$self->{data}->{nodes} = shared_clone($config);

	my $val = $self->{controller}->{backend}->getValues();
	#$self->{data}->{values} = shared_clone($val);

	threads->create( sub { $self->thread(); } );
	return $self;
}

sub updatedConfig {
	my($self) = @_;
	my $config = $self->{controller}->{backend}->getConfig();
	$self->{data}->{nodes} = shared_clone($config);
	return;
}

sub saveBatteryLevel {
	my($self,$node,$level) = @_;
	$self->saveValue($node,255,38,$level);
	return ($node,$level);
}

sub saveValue {
	my($self,$node,$sensor,$type,$value) = @_;
	if(!defined $self->{data}->{values}) {
		my %values :shared;
		$self->{data}->{values} = \%values;
	}
	if(!defined $self->{data}->{values}->{$node}) {
		my %node :shared;
		$self->{data}->{values}->{$node} = \%node;
	}
	if(!defined $self->{data}->{values}->{$node}->{$sensor}) {
		my %sensor :shared;
		$self->{data}->{values}->{$node}->{$sensor} = \%sensor;
	}
	if(!defined $self->{data}->{values}->{$node}->{$sensor}->{$type}) {
		my %type :shared;
		$self->{data}->{values}->{$node}->{$sensor}->{$type} = \%type;
	}
	$self->{data}->{values}->{$node}->{$sensor}->{$type}->{value} = $value;
	$self->{data}->{values}->{$node}->{lastseen} = time;
	$self->{data}->{values}->{$node}->{$sensor}->{lastseen} = time;
	$self->{data}->{values}->{$node}->{$sensor}->{$type}->{lastseen} = time;
	return ($node,$sensor,$type,$value);
}

sub thread {
	my($self) = @_;
	my $d = HTTP::Daemon->new(
		LocalAddr => '0.0.0.0',
		LocalPort => $self->{port},
		Timeout => 1,
	) || die;
	print "Please contact me at: <URL:", $d->url, ">\n";
	while (1) {
		my $c = $d->accept;
		next unless defined $c;
		while (my $r = $c->get_request) {
			if ($r->method eq 'GET' and $r->uri->path eq "/nodes") {
				# $c->send_file_response("/etc/passwd");
				my $r = HTTP::Response->new( 200 );
				$r->content(to_json($self->{data}->{nodes},{pretty => 1}));
				#$r->content(Dumper($self->{nodes}));
				$c->send_response($r);
			}
			elsif ($r->method eq 'GET' and $r->uri->path eq "/data") {
				# $c->send_file_response("/etc/passwd");
				my $r = HTTP::Response->new( 200 );
				$r->content(to_json($self->{data},{pretty => 1}));
				#$r->content(Dumper($self->{nodes}));
				$c->send_response($r);
			}
			elsif ($r->method eq 'GET' and $r->uri->path eq "/values") {
				# $c->send_file_response("/etc/passwd");
				my $r = HTTP::Response->new( 200 );
				$r->content(to_json($self->{data}->{values},{pretty => 1}));
				#$r->content(Dumper($self->{nodes}));
				$c->send_response($r);
			}
			else {
				$c->send_error(RC_FORBIDDEN)
			}
		}
		$c->close;
		undef($c);
	}
	print "End of thread... :(\n";
}

1;
