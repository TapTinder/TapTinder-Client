use strict;
use warnings;
use lib qw( lib . ../lib ../../lib );

use SVN::PropBug qw(diff_contains_real_change);
my $diff;

$SVN::PropBug::ver = 0;

if ( !$ARGV[0] ) {
    my $diff_fn;
    $diff_fn = ( defined $ARGV[1] ) ? $ARGV[1] : 't/svnbug-testdiff.txt';
    die $! unless open( SVNDIFF, '<', $diff_fn );
    {
        local $/ = undef;
        $diff = <SVNDIFF>;
    }
    close SVNDIFF;

} else {
    use SVNShell qw(svnversion svndiff);
    my $dir = '../client-data/parrot-temp/';
    print "INFO: Using real directory.\n";

    my $rev;
    my $err;

    ( $rev, $err ) = svnversion( $dir );
    print "ERROR: $err\n" unless defined $rev;

    if ( $rev ne '26769M' ) {
        print "WARNING: Directory revision = $rev.";
        print " Probably you need to update parrot-scr to r26769 and copy it to parrot-temp.\n";
    }

    ( $diff, $err ) = svndiff( $dir );
    print "ERROR: $err\n" unless defined $diff;
}


my $is_real = diff_contains_real_change( $diff );
unless ( defined $is_real ) {
    print "ERROR: $@\n";
    exit 1;
}

print "RESULT: diff_contains_real_change return $is_real.\n";
exit 0;