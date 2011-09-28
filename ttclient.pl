#!perl

use strict;
use warnings;

use Carp qw(carp croak verbose);
use FindBin qw($RealBin);
use Data::Dumper;
use File::Spec::Functions;

# CPAN libs and own libs
use lib "$FindBin::Bin/../libcpan";
use lib "$FindBin::Bin/lib";

use YAML;

use Getopt::Long;
use Pod::Usage;

use TapTinder::Client;
use TapTinder::Client::Conf qw(load_client_conf);

my $help = 0;
my $conf_section_name = 'dev';
my $conf_fpath = catfile( $RealBin, '..', 'client-conf', 'client-conf.yml' );
my $ver = 2; # verbosity level
my $debug = 0; # debug
my $end_after_no_new_job = 0;

my $options_ok = GetOptions(
    'help|h|?' => \$help,
    'config_section_name|csn=s' => \$conf_section_name,
    'conf_fpath|cfp=s' => \$conf_fpath,
    'verbose|v=i' => \$ver,
    'debug|d=i' => \$debug,
    'end_after_no_new_job' => \$end_after_no_new_job,
);
pod2usage(1) if $help || !$options_ok;

# TODO - Check parameters.
if ( $ver !~ /^\s*\d+\s*$/ || $ver < 0 || $ver > 5 ) {
    croak "Parameter error: ver is not 0-5.\n";
}

print "Verbose level: $ver\n" if $ver >= 3;
print "Working path: '" . $RealBin . "'\n" if $ver >= 4;

print "Loading config file section '$conf_section_name'.\n" if $ver >= 3;

my $client_conf = load_client_conf( $conf_fpath, $conf_section_name );

# debug, will also dump passwd on screen
# print Dumper( $client_conf ) if $ver >= 5;

print "Starting Client.\n" if $ver >= 3;

my $base_dir = catdir( $RealBin, '..' );

my $client = undef;
do {
    $client = TapTinder::Client->new(
        $client_conf,
        $base_dir,
        {
            ver => $ver,
            debug => $debug,
            end_after_no_new_job => $end_after_no_new_job,
        }
    );
    $client->run();
    if ( $client->do_client_restart() && $ver >= 1 ) {
        print "Doing client restart.\n\n";
    }
} while ( $client->do_client_restart() );


my $do_upgrade_sign_fpath = catfile( $RealBin, '.do_ttclient_upgrade' );
if ( $client->do_client_upgrade() ) {
    # Create new file with new timestamp.
    if ( -f $do_upgrade_sign_fpath ) {
        print "Previous upgrade attempt probably failed. Waiting 120 seconds ... ";
        sleep 120;

    } else {
        my $fh;
        open( $fh, '>', $do_upgrade_sign_fpath ) or croak $!;
        print $fh $$ . ' - ' . time() . "\n";
        close $fh;
    }

} elsif ( -f $do_upgrade_sign_fpath ) {
    unlink( $do_upgrade_sign_fpath ) or croak $!;
}

exit;

__END__

=head1 NAME

ttclient - TapTinder client.

=head1 SYNOPSIS

ttclient [options]

 Options:
   --help
   --conf_fpath ... Config file path.
   --ver ... Verbose level, 0-5, default 2.
   --end_after_no_new_job ... Will end if new job not found.
   --config_section_name ... Configuration section name. Default 'dev'.

=head1 DESCRIPTION

B<This program> will start TapTinder client.

=cut
