=head1 NAME

AnyEvent::MySQL::ConnPool

=head1 DESCRIPTION

Adds additional method "pool_connect" to AnyEvent::MySQL package.

=cut

package AnyEvent::MySQL::ConnPool;
use strict;
use warnings;

use AnyEvent::MySQL;
use AnyEvent::ConnPool;

our $VERSION = 0.02;

sub import {
    *{AnyEvent::MySQL::connect_pool} = sub {
        my ($dsn, $user, $password, $params, $cb) = @_;
        
        my $pool_size = delete $params->{PoolSize};
        my $check_interval = delete $params->{CheckInterval};

        $pool_size ||= 5;
        $check_interval ||= 10;

        my $connpool = AnyEvent::ConnPool->new(
            init    =>  1,
            size    =>  $pool_size,
            check   =>  {
                cb          =>  sub {
                    my $unit = shift;
                    $unit->conn()->ping();
                },
                interval    =>  $check_interval,
            },
            constructor     =>  sub {
                return AnyEvent::MySQL->connect(@_);
            },
        );
    };
}

1;

__END__
