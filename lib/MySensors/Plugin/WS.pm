#
# WS Plugin 
#

package MySensors::Plugin::WS;

use strict;
use warnings;

use base 'MySensors::Plugin';

use HTTP::Daemon;
use HTTP::Status qw(:constants);
use CGI;
use MySensors::Const;
use IO::Select;

use JSON;

sub new {
	my($class,$opts) = @_;
	$opts //= {};
	$opts->{name} = __PACKAGE__;
	my $self = $class->SUPER::new($opts);
	$self->{port} = $opts->{port} // 9998;
	$self->{select} = IO::Select->new();
	return $self;
}

sub init {
	my($self) = @_;
	$self->{data} = {};
	$self->{daemon} = HTTP::Daemon->new(LocalAddr => '0.0.0.0',
										  LocalPort => $self->{port},
										  Listen => 20,
										  ReuseAddr => 1);

	$self->{select}->add($self->{mmq}->getSocket());
	$self->{select}->add($self->{daemon});

	$self->{log}->info(__PACKAGE__ . " initialized");
}

sub saveNodes {
	my($self,$nodes) = @_;
	$self->{log}->info("Got nodes :-) $nodes");
	$self->{data}->{nodes} = $nodes;
}

sub saveValues {
	my($self,$values) = @_;
	$self->{log}->info("Got values :-) $values");
	$self->{data}->{values} = $values;
}

sub run {
	my($self) = @_;

	# Get :shared pointer to Node config and current Values.
	#$self->{data}->{nodes}  = $self->getNodes();
	#$self->{data}->{values} = $self->getValues();

	$SIG{CHLD} = 'IGNORE';
	$SIG{PIPE} = 'IGNORE';

	$self->{log}->info(sprintf("WS Init complete. Adress: http://%s:%d/",$self->{daemon}->sockhost(),$self->{daemon}->sockport()));
	#$self->{mmq}->{mmq}->{debug} = 1;
	while(1) {
		foreach my $s ($self->{select}->can_read(1)) {
			# handle request
			if($s eq $self->{daemon}) {
				if (my $c = $self->{daemon}->accept) {
					$self->saveNodes($self->getNodes()) unless defined ($self->{data}->{nodes});
					$self->saveValues($self->getValues()) unless defined ($self->{data}->{values});
					my $pid = fork();
					if(defined $pid && $pid == 0) {
						$SIG{'ALRM'} = sub { exit; };
						alarm(5);
						$self->process_one_req($c);
						exit(0);
					}
					$c->close();
				}
			}
		}
		# look at the queue
		$self->{mmq}->once(0.01);
	}
	return $self;
}

sub res {
	my($status,$content,$ct) = @_;
	return HTTP::Response->new(
		$status, OK => [ 'Content-Type' => ($ct // 'text/plain') ], ($content // "")
	);
}

sub OK {
	my($content,$ct) = @_;
	return res(HTTP_OK,$content,$ct);
}

sub notFound {
	my($content) = @_;
	return res(HTTP_NOT_FOUND,$content // "Not Found");
}

sub getJSON {
	my($cgi,$data) = @_;

	my $jsoncallback    = $cgi->url_param('jsoncallback');
	my $jsoncallbackend = '';
	$jsoncallbackend    = ')' if defined $jsoncallback;
	$jsoncallback      .= '(' if defined $jsoncallback;
	$jsoncallback       = ''   unless defined $jsoncallback;

	return OK($jsoncallback . to_json($data,{ canonical => 1, pretty => 1}) . $jsoncallbackend,"text/plain");
}

sub printTree {
	my($cgi,$data) = @_;
	my $res = "";
	$res .= $cgi->a({href=>"/get/dump"}, "Raw dump of all").$cgi->br."\n";
	$res .= $cgi->a({href=>"/get/nodes"}, "Raw dump of all nodes").$cgi->br."\n";
	$res .= $cgi->a({href=>"/get/values"}, "Raw dump of all values").$cgi->br."\n";
	for my $node (sort {$a <=> $b} keys %{$data->{nodes}}) {
		$res .= $cgi->a({href=>"/get/$node"},"Node $node").$cgi->br."\n";
		$res .= "<ul>\n";
		for my $val (sort { $a <=> $b } keys %{$data->{nodes}->{$node}->{sensors}}) {
			for my $type (sort {$a <=> $b} keys %{$data->{values}->{$node}->{sensors}->{$val}->{types}}) {
				$res .= $cgi->li.$cgi->a({href=>"/get/$node/$val/$type"},"Sensor $node-$val-$type").$cgi->br."\n";
			}
		}
		$res .= "</ul>\n";
	}
	return OK($res,'text/html');
}

sub process_one_req {
	my($self,$client) = @_;
	while(my $request = $client->get_request) {
		if ($request->method eq "GET") {
			$client->send_response($self->process_req($request));
		} else {
			$client->send_response(res(HTTP_METHOD_NOT_ALLOWED,"Method Not Allowed"));
		}
	}
	$client->close;
}

sub process_req {
	my($self,$request) = @_;
	my $pi = $request->url->path();
	my $cgi = CGI->new( $request->uri->query );

	if($pi =~ m,^/get/dump(|.json)$,) { # Dump
		return getJSON($cgi, $self->{data});
	} elsif($pi =~ m,^/get/nodes(|.json)$,) { # Nodes
		my($node) = ($1);
		my($n) = $self->{data}->{nodes};
		if(!defined $n) { return notFound(); }
		return getJSON($cgi,{
			nodes => $n,
		});
	} elsif($pi =~ m,^/get/values(|.json)$,) { # values
		my($node) = ($1);
		my($n) = $self->{data}->{values};
		if(!defined $n) { return notFound(); }
		return getJSON($cgi,{
			values => $n,
		});
	} elsif($pi =~ m,^/reboot/(\d+)$,) { # Reboot
		my($node) = ($1);
		$self->{controller}->receive({ type => "REBOOT", nodeid => $node });
		return getJSON($cgi,{
			status => 'OK',
		});
	} elsif($pi =~ m,^/get/(\d+)(|.json)$,) { # Node
		my($node) = ($1);
		my($n) = $self->{data}->{nodes}->{$node};
		if(!defined $n) { return notFound(); }
		my($ls) = $self->{data}->{values}->{$node}->{lastseen};
		my($lsv) = $self->{data}->{values}->{$node}->{lastseenvia};
		return getJSON($cgi,{
			nodeid => $node,
			node => $n,
			lastseen => $ls,
			lastseenvia => $lsv
		});
	} elsif($pi =~ m,^/list(|.json)$,) { # List nodes
		return getJSON($cgi,{
			nodes => [sort { $a <=> $b } keys %{ $self->{data}->{nodes} } ],
		});
	} elsif($pi =~ m,^/list/(\d+)(|.json)$,) { # List sensors
		my($node) = ($1);
		my($n) = $self->{data}->{nodes}->{$node};
		if(!defined $n) { return notFound(); }
		return getJSON($cgi,{
			nodeid => $node,
			sensors => [sort { $a <=> $b } keys %{ $n->{sensors} } ],
		});
	} elsif($pi =~ m,^/list/(\d+)/(\d+)(|.json)$,) { # List types
		my($node,$sensor) = ($1,$2);
		my($n) = $self->{data}->{nodes}->{$node};
		if(!defined $n) { return notFound(); }
		my($s) = $n->{sensors}->{$sensor};
		if(!defined $s) { return notFound(); }
		return getJSON($cgi,{
			nodeid => $node,
			sensor => $sensor,
			types => [sort { $a <=> $b } keys %{ $s->{types} } ],
		});
	} elsif($pi =~ m,^/get/(\d+)/(\d+)/(\d+)(|.json)$,) { # Sensor Value
		my($node,$sensor,$type) = ($1,$2,$3);
		if(!defined $self->{data}->{values}->{$node}) { return notFound(); }
		if(!defined $self->{data}->{values}->{$node}->{sensors}->{$sensor}) { return notFound(); }
		if(!defined $self->{data}->{values}->{$node}->{sensors}->{$sensor}->{types}->{$type}) { return notFound(); }
		my($v) = $self->{data}->{values}->{$node}->{sensors}->{$sensor}->{types}->{$type}->{value};
		my($t) = $self->{data}->{values}->{$node}->{sensors}->{$sensor}->{types}->{$type}->{lastseen};
		return getJSON($cgi,{
			nodeid => $node,
			sensorid => $sensor,
			type => $type,
			typeStr => MySensors::Const::SetReqToStr($type),
			value => $v,
			lastseen => $t,
		});
	} elsif ($pi eq "/") {
		return printTree($cgi,$self->{data});
	} 
	return notFound();
}

1;
