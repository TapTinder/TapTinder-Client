#! perl

use strict;
use warnings;
use Carp qw(carp croak verbose);
use FindBin qw($RealBin);

use Data::Dumper;
use File::Spec::Functions;

use lib "$FindBin::Bin/../lib";
use TapTinder::Client::WebAgent;
use TapTinder::Client::Conf qw(load_client_conf);

my $project_name = $ARGV[0] || 'tt-test-proj';
my $conf_fpath = $ARGV[1] || catfile( $RealBin, '..', '..', 'client-conf', 'client-conf.yml' );
my $client_conf = load_client_conf( $conf_fpath, $project_name );

my $agent = TapTinder::Client::WebAgent->new(
    $client_conf->{taptinderserv},
    $client_conf->{machine_id},
    $client_conf->{machine_passwd},
);
my ( $login_rc, $msession_id ) = $agent->mscreate();

if ( ! $login_rc ) {
    croak "Login failed\n";
}

my $prev_msjobp_cmd_id = undef;
my $attempt_number = 1;
for my $num ( 1..2) {
    my $estimated_finish_time = undef;
    my $data = $agent->cget(
        $msession_id, $attempt_number, $estimated_finish_time,
        $prev_msjobp_cmd_id,
    );
    #print Dumper( $data );

    croak "cmd error\n" unless defined $data;
    if ( $data->{err} ) {
        croak $data->{err_msg};
    }
    if ( $data->{msjobp_cmd_id} ) {
        $prev_msjobp_cmd_id = $data->{msjobp_cmd_id};
        $attempt_number = 1;

        $data = $agent->sset(
            $msession_id,
            $prev_msjobp_cmd_id, # $msjobp_cmd_id
            2 # running, $cmd_status_id
        );
        if ( $data->{err} ) {
            croak $data->{err_msg};
        }

        # 3..ok, 4..stopped, 5..error
        my $status = 3 + ( ($num-1) % 3 );

        # ok
        if ( $status == 3 ) {
            my $output_file_path = catfile( $RealBin, '..', 'README' );
            $data = $agent->sset(
                $msession_id,
                $prev_msjobp_cmd_id, # $msjobp_cmd_id
                $status,
                time(), # $end_time, TODO - is GMT?
                $output_file_path
            );

        # not ok
        } else {
            $data = $agent->sset(
                $msession_id,
                $prev_msjobp_cmd_id, # $msjobp_cmd_id
                $status
            );
        }
        if ( $data->{err} ) {
            croak $data->{err_msg};
        }

    } else {
        carp "New msjobp_cmd_id not found.\n";
        $attempt_number++;
        $prev_msjobp_cmd_id = undef;
    }
}

$agent->msdestroy( $msession_id );
