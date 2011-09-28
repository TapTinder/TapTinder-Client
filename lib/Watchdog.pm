package Watchdog;

use strict;
use warnings;

use base 'Exporter';
our $VERSION = 0.01;
our @EXPORT_OK = qw(sys sys_for_watchdog);

use Carp qw(carp croak);
use Storable;
use File::Spec::Functions;

sub sys {
    my ( $full_cmd, $temp_out_fn ) = @_;

    my $output;
    $temp_out_fn = '.out' unless $temp_out_fn;
    open my $oldout, ">&STDOUT"     or carp "Can't dup STDOUT: $!";
    open my $olderr, ">&", \*STDERR or carp "Can't dup STDERR: $!";

    open STDOUT, '>', $temp_out_fn or carp "Can't redirect STDOUT to '$temp_out_fn': $! $@";
    open STDERR, ">&STDOUT"     or carp "Can't dup STDOUT: $!";

    select STDERR; $| = 1;      # make unbuffered
    select STDOUT; $| = 1;      # make unbuffered

    my $status = system( $full_cmd );

    close STDOUT;
    close STDERR;

    open STDOUT, ">&", $oldout or carp "Can't dup \$oldout: $!";
    open STDERR, ">&", $olderr or carp "Can't dup \$olderr: $!";

    unless ( open( FH_STDOUT, "<$temp_out_fn") ) {
        carp("File $temp_out_fn not open!");
        unlink $temp_out_fn;
        next;
    }
    {
        local $/ = undef;
        $output = <FH_STDOUT>;
    }
    close FH_STDOUT;
    return ( $status, $output );
}


sub sys_for_watchdog {
    my ( $cmd, $cmd_params, $log_fn, $timeout, $sleep, $dir, $ver ) = @_;

    carp "cmd is mandatory" unless defined $cmd;
    $log_fn = $cmd . '.log' unless defined $log_fn;
    $timeout = 5*60 unless defined $timeout;

    my $ipc_fn = catfile( $dir, 'watchdog-setting.bin' );

    if ( -e $ipc_fn ) {
        print "found '$ipc_fn', probably already running\n";
#        exit 0;
    }
    my $full_cmd = $cmd;
    print "Running '$full_cmd' ...\n" if $ver;

    $full_cmd .= ' ' . $cmd_params if $cmd_params;
    my $info = {
        'log_fn'   => $log_fn,
        'pid'      => $$,
        'full_cmd' => $full_cmd,
        'timeout'  => $timeout,
    };
    $info->{'sleep'} = $sleep if defined $sleep;
    store( $info, $ipc_fn ) or carp "store failed\n$!\n$@";

=head todo
=pod
    sub catch_sig {
        my $signame = shift;
        print "captured $signame\n";
        unlink $ipc_fn;
        exit;
    }

    foreach my $sig ( qw/QUIT KILL CHILD/ ) {
        $SIG{$sig} = \&catch_sig;
    }
    #print dump( \%SIG );
=cut

    my ( $status, $output ) = sys( $full_cmd, $log_fn );

    unlink $ipc_fn;
    while ( -e $ipc_fn ) {
        print "Trying to unlink '$ipc_fn' again.\n" if $ver;
        sleep 1;
        unlink $ipc_fn;
    }
    if ( $ver ) {
        print ( ( $status ) ? "Finished, but exit code is $status\n" : "Finished ok\n" );
    }
    return ( $status, $output );
}

1;
