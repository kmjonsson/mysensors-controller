
package MySensors::Radio::Dummy;

use strict;
use warnings;

use threads;
use Thread::Queue;

sub new {
	my($class) = shift;
	my($opts) = shift // {};
	my $self  = {
		'log' 			=> Log::Log4perl->get_logger(__PACKAGE__),
		# Options
		'infile'		=> $opts->{'infile'}  // "/tmp/mys.in",
		'outfile'		=> $opts->{'outfile'} // "/tmp/mys.out",
		# vars
		'serial'		=> undef,
		'controller'	=> undef,
		'id'			=> undef,
		'inqueue'       => undef,
	};
	bless ($self, $class);
	return $self;
}

sub id {
	my($self) = @_;
	return $self->{id};
}

sub init {
	my($self,$controller,$id) = @_;

	$self->{controller} = $controller;
	$self->{id} = $id;

	$self->start();

	return $self;
}

sub start {
	my($self) = @_;

	# inqueue
	$self->{inqueue} = Thread::Queue->new();

	# Start receive thread
	$self->{'recvthr'} = threads->create(
		 sub { $self->receive_thr(); }
	);
	# Start send thread
	$self->{'sendthr'} = threads->create(
		 sub { $self->send_thr(); }
	);

	$self->{log}->info("Started");
	return $self;
}

sub status {
	my($self) = @_;
	return 1 unless defined $self->{'sendthr'};
	return 1 unless defined $self->{'recvthr'};
	my $status = 0;
	if($self->{'sendthr'}->is_joinable()) {
		$self->{'sendthr'}->join();
		$self->{'sendthr'} = undef;
		$status = 1;
	}
	if($self->{'recvthr'}->is_joinable()) {
		$self->{'recvthr'}->join();
		$self->{'recvthr'} = undef;
		$status = 1;
	}
	return $status;
}

sub send {
	my($self,$msg) = @_;
	if(defined $self->{inqueue}) {
		$self->{inqueue}->enqueue($msg);
	}
	return $self;
}

sub shutdown {
	my($self) = @_;
	if(defined $self->{inqueue}) {
		$self->{'inqueue'}->enqueue({ type => "SHUTDOWN"}); 
	}
}

sub send_thr {
	my($self) = @_;
	while (defined(my $msg = $self->{inqueue}->dequeue())) {
		last if $msg->{type} eq 'SHUTDOWN';
		if($msg->{type} eq 'RADIO') {
			my $data = $msg->{data};
			$self->{log}->debug("Sending: $data");
			if(open(my $out,">>",$self->{outfile})) {
				print $out "$data\n";
				close($out);
			}
		}
	}
	$self->{log}->warn("Exit...");
}

sub restart {
	my($self) = @_;
	$self->{log}->info("Restarting..");
	return $self;
}

sub receive_thr {
	my($self) = @_;
	return unless defined $self->{'controller'};

	# receive a response of up to 256 characters from server
	my $msg = "";
	while(sleep(1)) {
		next unless -f $self->{infile};

		my $in;
		if(!open($in,"<",$self->{infile})) {
			$self->shutdown(); 
			$self->{'controller'}->shutdown(); 
			$self->{log}->warn("Exit...");
			last;
		}
		my $response = join("\n",<$in>);
		close($in);

		if(!unlink($self->{infile})) {
			$self->shutdown(); 
			$self->{'controller'}->shutdown(); 
			$self->{log}->warn("Exit...");
			last;
		}

		# Split messages up based on '\n'. Only process messages
		# that are longer then 8 chars.
		my @msgs;
		if($response =~ /[\n\r]+/x && $response =~ /[\r\n]+$/x) {
			push @msgs,split(/[\n\r]+/x,$msg.$response);
			$msg = "";
		} elsif($response =~ /[\n\r]+/x) {
			push @msgs,split(/[\n\r]+/x,$msg.$response);
			$msg = pop @msgs;
		} else {
			$msg .= $response;
		}
		for ( grep { length > 8 && !/^#/ } @msgs ) { 
			#next if /^0;0;/;
			$self->{log}->debug("received: '$_'");
			$self->{'controller'}->receive({ type => "RADIO", data => $_ }); 
		}
	}
	$self->{'serial'}->close();
	$self->{'serial'} = undef;
}

1;
