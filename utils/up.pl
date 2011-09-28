#!perl

use strict;
use warnings;

use Carp qw(carp croak verbose);
use FindBin qw($RealBin);

use File::Spec::Functions;

my $is_win32 = ( $^O eq 'MSWin32' );

if ( ! $is_win32  ) {
    $ENV{PERL5LIB} = '/home2/scripts/mj41/taptinder/libcpan';
}

my $dh;
opendir( $dh, './' ) || die $!;
while ( my $dir = readdir($dh) ) {
    next if $dir eq '.' || $dir eq '..';
    next unless -d $dir;
    print "dir: $dir\n";
    my $res_fp = catfile( $dir,  'taptinder-results.yml' );

    my $base_cmd;
    if ( $is_win32 ) {
        $base_cmd = 'perl';
    } else {
        $base_cmd = '/usr/bin/perl';
    }

    my $cmd =
        $base_cmd
        . ' ' . catfile( $RealBin, '..', '..', 'client', 'upload.pl' )
        . ' ' . 'parrot'
        . ' ' . $res_fp
        . ' ' . catfile( $RealBin, '..', '..', 'client-conf', 'client-conf.yml' )
    ;
    system( $cmd );
    #exit; # debug
}

close( $dh );
