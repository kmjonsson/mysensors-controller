#
# WS Plugin 
#

package MySensors::Plugins::WS;

use strict;
use warnings;

use threads;
use threads::shared;

use JSON;
use Data::Dumper;

sub new {
	my($class,$opts) = @_;
	
	my %data :shared;
	my $self = {
		'controller' => undef,
		'port' => $opts->{port} // 9998,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
		'data' => \%data,
	};
	bless ($self, $class);
	$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;

	# Get :shared pointer to Node config and current Values.
	$self->{data}->{nodes}  = $self->{controller}->{backend}->getConfig();
	$self->{data}->{values} = $self->{controller}->{backend}->getValues();

	threads->create( sub { $self->thread(); } );
	return $self;
}

sub thread {
	my($self) = @_;
	MySensors::Plugins::WS::Server->new($self,$self->{port})->run();
}

1;

package MySensors::Plugins::WS::Server;

use HTTP::Server::Simple::CGI;

use parent 'HTTP::Server::Simple::CGI';

use JSON;
use MySensors::Const;

sub new {
	my ($class, @args) = @_;

	my $parent = shift @args;

    # possibly call Parent->new(@args) first
	my $self = $class->SUPER::new(@args);

	$self->{_parent} = $parent;

	return $self;
}

sub notFound {
	print "HTTP/1.0 404 Not found\r\n\r\n";
	print "Not Found\r\n";
}

sub OK {
	my($ct) = @_;
	print "HTTP/1.0 200 OK\r\n";
	print "Content-type: $ct\r\n\r\n";
}

sub printJSON {
	my($cgi,$data) = @_;

	my $jsoncallback    = $cgi->url_param('jsoncallback');
	my $jsoncallbackend = '';
	$jsoncallbackend    = ')' if defined $jsoncallback;
	$jsoncallback      .= '(' if defined $jsoncallback;
	$jsoncallback       = ''   unless defined $jsoncallback;

	OK("text/plain");
	print $jsoncallback . to_json($data,{ canonical => 1, pretty => 1}) . $jsoncallbackend;
}

sub printTree {
	my($cgi,$data) = @_;
	OK("text/html");
	print $cgi->a({href=>"/get/dump"}, "Raw dump of all").$cgi->br."\n";
	for my $node (sort {$a <=> $b} keys %{$data->{nodes}}) {
		print $cgi->a({href=>"/get/$node"},"Node $node").$cgi->br."\n";
		my @lst;
		for my $val (keys %{$data->{nodes}->{$node}}) { # mixed num and alphanum, so <=> will bork. filter first.
			push @lst, $val if ($val =~ /^\d+$/);
		}
		for my $val (sort {$a <=> $b} @lst) {
			if (defined $data->{values}->{$node}->{$val}) {
				my @types;
				for my $type (keys %{$data->{values}->{$node}->{$val}}) {
					push @types, $type if ($type =~ /^\d+$/)
				}
				for my $type (sort {$a <=> $b} @types) {
					print $cgi->a({href=>"/get/$node/$val/$type"},"Sensor $node-$val-$type").$cgi->br."\n";
				}
			}
		}
	}
	
}

sub handle_request {
	my($self,$cgi) = @_;
	my $pi = $cgi->path_info();


	if($pi =~ m,^/get/dump(|.json)$,) { # Dump
		printJSON($cgi, $self->{_parent}->{data});
	} elsif($pi =~ m,^/get/nodes(|.json)$,) { # Nodes
		my($node) = ($1);
		my($n) = $self->{_parent}->{data}->{nodes};
		if(!defined $n) { notFound(); return; }
		printJSON($cgi,{
			nodes => $n,
		});
	} elsif($pi =~ m,^/reboot/(\d+)$,) { # Reboot
		my($node) = ($1);
		$self->{_parent}->{controller}->receive({ type => "REBOOT", nodeid => $node });
		printJSON($cgi,{
			status => 'OK',
		});
	} elsif($pi =~ m,^/get/(\d+)(|.json)$,) { # Node
		my($node) = ($1);
		my($n) = $self->{_parent}->{data}->{nodes}->{$node};
		my($ls) = $self->{_parent}->{data}->{values}->{$node}->{lastseen};
		if(!defined $n) { notFound(); return; }
		printJSON($cgi,{
			nodeid => $node,
			node => $n,
			lastseen => $ls
		});
	} elsif($pi =~ m,^/get/(\d+)/(\d+)/(\d+)(|.json)$,) { # Sensor Value
		my($node,$sensor,$type) = ($1,$2,$3);
		if(!defined $self->{_parent}->{data}->{values}->{$node}) { notFound(); return; }
		if(!defined $self->{_parent}->{data}->{values}->{$node}->{$sensor}) { notFound(); return; }
		if(!defined $self->{_parent}->{data}->{values}->{$node}->{$sensor}->{$type}) { notFound(); return; }
		my($v) = $self->{_parent}->{data}->{values}->{$node}->{$sensor}->{$type}->{value};
		my($t) = $self->{_parent}->{data}->{values}->{$node}->{$sensor}->{$type}->{lastseen};
		printJSON($cgi,{
			nodeid => $node,
			sensorid => $sensor,
			type => $type,
			typeStr => MySensors::Const::SetReqToStr($type),
			value => $v,
			lastseen => $t,
		});
	} else {
		printTree($cgi,$self->{_parent}->{data});
		#notFound();
	}
}

1;
