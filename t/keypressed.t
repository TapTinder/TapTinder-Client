use strict;
use warnings;
use lib qw( lib . ../lib ../../lib );

use TapTinder::Client::KeyPress;

Term::ReadKey::ReadMode('cbreak');

sub run_sleep {
    my ( $time, $msg ) = @_;

    print $msg if defined $msg;
    my $cmd = qq{ perl -e"select(STDOUT); \$| = 1; foreach (1..$time) { print '.'; sleep 1; }"};
    #print "cmd: '$cmd'\n";
    system($cmd);
    print "\n";
}

sub sig_handler() {
    my ( $signal ) = @_;
    print("Recieved signal: $signal\n");
    Term::ReadKey::ReadMode('normal');
    exit;
}

# debug
if ( 0 ) {
    foreach ( keys %SIG ) {
        next if $_ =~ /^(CHLD|CLD)$/;
        print "$_\n";
        $SIG{$_} = \&sig_handler;
    }
}

$SIG{'KILL'}  = \&sig_handler;
$SIG{'INT'}  = \&sig_handler;
$SIG{'QUIT'} = \&sig_handler;

my $keypress = TapTinder::Client::KeyPress->new( 10 );

print "Begin.\n";

run_sleep( 2, 'a1-2 ' );
$keypress->process_keypress();

run_sleep( 2, 'a2-2 ' );
$keypress->process_keypress();

print 'b1-3 ';
$keypress->sleep_and_process_keypress( 3 );

print 'b2-3 ';
$keypress->sleep_and_process_keypress( 3 );

print 'c2-35 ';
$keypress->sleep_and_process_keypress( 35 );

print "Normal end.\n";
