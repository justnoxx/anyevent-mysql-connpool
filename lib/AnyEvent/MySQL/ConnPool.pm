=head1 NAME

AnyEvent::MySQL::ConnPool

=head1 DESCRIPTION

Adds additional method "pool_connect" to L<AnyEvent::MySQL> package.

=head1 SYNOPSIS

Similar to AnyEvent::MySQL->connect();

    use AnyEvent;
    use AnyEvent::MySQL;
    use AnyEvent::MySQL::ConnPool;

    my $connpool = AnyEvent::MySQL->connect_pool(
        "DBI:mysql:database=test;host=127.0.0.1;port=3306",
        "ptest",
        "pass", {
            PrintError      =>  1,
            PoolSize        =>  10,
            CheckInterval   =>  5,
        }, 
        sub {
            my($dbh) = @_;
            if( $dbh ) {
                warn "Connect success!";
                $dbh->pre_do("set names latin1");
                $dbh->pre_do("set names utf8");
            }
            else {
                warn "Connect fail: $AnyEvent::MySQL::errstr ($AnyEvent::MySQL::err)";
                $end->send;
            }
        }
    );
    
    # if you need only connection methods, you can use dispatcher object as regular AnyEvent::MySQL connection  object.
    # the difference is: dispatcher applies connection pool functional to your connection object.
    my $dispatcher = $connpool->dispatcher();
    $dispatcher->selectall_hashref('SELECT * FROM `table1`', {}, sub {
        ...;
    });

=head1 METHODS

=over

=item B<connect_pool>

Returns connected L<AnyEvent::ConnPool> object. 
All options for connect_pool are similar to the AnyEvent::MySQL->connect method.
But pool accepts additional options in parameters hashref(4th parameter).

    AnyEvent::MySQL->connect_pool($dsn, $user, $password, {PoolSize => 5, CheckInterval => 10}, $callback);

PoolSize    =>  how many connections should be created. 5 connections by default.

CheckInterval   =>  Interval for ping connections. 10 seconds by default.

=back

=cut

package AnyEvent::MySQL::ConnPool;
use strict;
use warnings;

use Carp;
use AnyEvent::MySQL;
use AnyEvent::ConnPool;

our $VERSION = 0.07;

sub import {
    *{AnyEvent::MySQL::connect_pool} = sub {
        my ($caller, $dsn, $user, $password, $params, $cb) = @_;

        my @conn_args = @_;
        shift @conn_args;

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
                return AnyEvent::MySQL->connect(@conn_args);
            },
        );
    };
}


sub new {
    my ($class, %params) = @_;
    
    if (!$params{CheckInterval}) {
        $params{CheckInterval} = 10;
    }
    if (!$params{PoolSize}) {
        $params{PoolSize} = 5;
    }
    if (!$params{Dispatcher}) {
        $params{Dispatcher} = 0;
    }

}


sub _connpool {
    my ($self, %params) = @_;

    my ($pool_size, $check_interval, $dispatcher) = ($params{PoolSize}, $params{CheckInterval}, $params{Dispatcher});
    $pool_size ||= 5;
    $check_interval ||= 10;
    $dispatcher = 0 unless $dispatcher;

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
            return AnyEvent::MySQL->connect(...);
        },
    );
}

1;

__END__

