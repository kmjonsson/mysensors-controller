
package MySensors::MMQ;

=head1 MySensors::MMQ

MMQ Server Module

=head2 AUTHOR

Magnus Jonsson <fot@fot.nu>

=head2 CONTRIBUTOR


=head2 LICENSE

GNU GENERAL PUBLIC LICENSE Version 2 

(See LICENSE file)

=head2 Methods

=cut

use strict;
use warnings;

use MMQ::Server;
use MMQ::Client;
use Data::Dumper;

sub new {
	my($class) = shift;
	my($opts)  = shift // {};

	my $self  = {
		'addr'    => $opts->{addr} // '127.0.0.1',
		'port'    => $opts->{port} // 4343,
		'key'     => $opts->{key} // 'MySensors',
		'callbacks' => {},
		'cfg'     => $opts->{cfg},
		'log'     => $opts->{log},
		'server'  => $opts->{server} // 0,
	};
	bless ($self, $class);
	if($self->{server}) {
		$self->{mmq} = MMQ::Server->new({addr => $self->{addr}, port => $self->{port}, key => $self->{key}, debug => 0});
	} else {
		$self->{mmq} = MMQ::Client->new({addr => $self->{addr}, port => $self->{port}, key => $self->{key}, debug => 0, noconnect => 1});
	}
	return unless defined $self->{mmq};
	$self->{log}->info("MMQ initialized $opts->{server}");
	return $self;
}

sub send {
	my($self,$data,$queue) = @_;
	return $self->{mmq}->send($data,$queue);
}

sub getSocket {
	my($self) = @_;
	return $self->{mmq}->getSocket();
}

sub clone {
	my($self) = @_;
	return MySensors::MMQ->new(
		{
			addr   => $self->{addr},
			port   => $self->{port},
			key    => $self->{key},
			cfg    => $self->{cfg},
			log    => $self->{log},
			server => $self->{server},
		}
	);
}

sub connect {
	my($self) = @_;
	return $self->{mmq}->connect();
}

sub run {
	my($self) = @_;
	$self->{mmq}->run();
}

sub once {
	my($self,@args) = @_;
	if(!defined $self->{mmq}->{client}) { 
		my($package, $filename, $line) = caller; 
		die "DIEx: $package, $filename, $line ..."; 
	}
	return $self->{mmq}->once(@args);
}

sub rpc {
	my($self,$rpc,$arg) = @_;
	return $self->{mmq}->rpc($rpc,$arg);
}

sub subscribe {
	my($self,$queue,$callback,$subSelf) = @_;
	if(!defined $self->{mmq}->{client}) {
		 my($package, $filename, $line) = caller;
		 die "subs: $package, $filename, $line ...";
	}
	return $self->{mmq}->subscribe($queue, $callback, $subSelf);
}

sub rpc_subscribe {
	my($self,$rpc,$callback,$rpcSelf) = @_;
	$self->{mmq}->rpc_subscribe($rpc,$callback,$rpcSelf // $self);
}

sub id {
	my($self) = @_;
	return $self->{mmq}->id();
}

1;
