
package MMQ::Client;

use warnings;
use strict;

use IO::Socket;
use IO::Select;
use MIME::Base64 qw(encode_base64 decode_base64);
use Encode qw(encode decode);
use JSON;
use Data::Dumper;

my $key = shift @ARGV // 'password';

my $client = IO::Socket::INET->new( Proto     => 'tcp',
									PeerHost => 'localhost',
									PeerPort => 4344,
									) || die;

print $client "snoop $key\r\n";
while(<$client>) {
	s,[\r\n]+,,mg;
	print "$_\n";
	if(/SNOOP To: \[(\d+)\] (.*)$/) {
		my($msg) = decode_json(decode("UTF-8",decode_base64($2)));
		print "To[$1]: ".Dumper($msg);
	}
}

__DATA__

	foreach my $m (@rows) {
		print "R: $m\n" if $self->{debug};
		my($msg) = decode_json(decode("UTF-8",decode_base64($m)));
		return if(!defined $msg);
		return if(ref($msg) ne 'HASH');
		return if(!defined $msg->{id});
		return if(!defined $msg->{type});

		print Dumper($msg) if $self->{debug};
		print Dumper($msg) if $self->{x_debug};

		# status..
		if($msg->{type} eq 'STATUS') {
			return unless defined $msg->{status};
			return unless $msg->{status} eq 'OK';
			$msg->{_timestamp_} = time;
			$self->{status}->{$msg->{id}} = $msg;
			next;
		}

		# need auth
		if(!$self->{auth}) {
			next;
		}

		# RPC
		if($msg->{type} eq 'RPC') {
			return unless defined $msg->{rpc};
			return unless defined $msg->{client};
			if(defined $self->{rpc}->{$msg->{rpc}}) {
				my $rpc = $self->{rpc}->{$msg->{rpc}};
				my $result = eval { &{$rpc->{rpc}}($rpc->{self},$msg->{data}) };
				if(!defined $result && length $@) {
					$self->{log}->error(sprintf("Callback error (rpc):  %d %s %s - %s",$self->{id},$msg->{rpc},$msg->{data},$@));
				}
				$self->sendMsg({
					type => 'RPR',
					client => $msg->{client},
					client_id => $msg->{id},
					data => $result,
				});
			}
			next;
		}

		# packet
		if($msg->{type} eq 'PACKET') {
			return unless defined $msg->{queue};
			return unless defined $msg->{data};
			my $callback = $self->{queues}->{$msg->{queue}};
			printf("G: %d %s %s ($callback)\n",$self->{id},$msg->{queue},$msg->{data}) if $self->{debug};
			next unless defined $callback;
			my $result = eval { &{$callback->{callback}}($callback->{self},$msg->{data},$msg->{queue}) };
			if(!defined $result && length $@) {
				$self->{log}->error(sprintf("Callback error:  %d %s %s - %s",$self->{id},$msg->{queue},$msg->{data},$@));
			}
			next;
		}

		die "End: $m\n" . Dumper($msg);
	}
	return 1;
}

1;
