#
# JSON Plugin 
#

package MySensors::Plugins::JSON;

use strict;
use warnings;

use Thread;

sub new {
	my($class,$opts) = @_;

	my $self  = {
		'controller' => undef,
		'port' => $opts->{port} // 9998,
		'log' => Log::Log4perl->get_logger(__PACKAGE__),
	};
	bless ($self, $class);
	$self->{log}->info(__PACKAGE__ . " initialized");
	return $self;
}

sub register {
	my($self,$controller) = @_;
	$self->{controller} = $controller;
	$controller->register('updatedConfig',$self);

	Thread->new( sub { $self->thread(); } );
	return $self;
}

sub updatedConfig {
	my($self,$config) = @_;
	return $self;
}

sub thread {
	my($self) = @_;
	my $backend = $self->{controller}->{backend}->clone();
	MySensors::Plugins::JSONWS->new($backend,$self->{port})->run();
}

package MySensors::Plugins::JSONWS;

use HTTP::Server::Simple::CGI;

use parent 'HTTP::Server::Simple::CGI';

use JSON;

sub new {
	my ($class, @args) = @_;

	my $backend = shift @args;

    # possibly call Parent->new(@args) first
	my $self = $class->SUPER::new(@args);

	$self->{_backend} = $backend;

	return $self;
}

sub handle_request {
	my($self,$cgi) = @_;
	my $pi = $cgi->path_info();

	if($pi =~ m,^/get/(\d+)/(\d+)/(\d+)(|.json)$,) {
		my($node,$sensor,$type) = ($1,$2,$3);
		my($v) = $self->{_backend}->getValue($node,$sensor,$type);
		print "HTTP/1.0 200 OK\r\n";
		print "Content-type: application/json\r\n\r\n";
		print to_json({
			node => $node,
			sensor => $sensor,
			type => $type,
			value => $v // "N/A",
		},{ canonical => 1});
	} else {
		print "HTTP/1.0 404 Not found\r\n";
		print $cgi->header,
			  $cgi->start_html('Not found'),
			  $cgi->h1('Not found'),
			  $cgi->end_html;
	}
}

1;
