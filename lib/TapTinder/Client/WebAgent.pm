package TapTinder::Client::WebAgent;

use strict;
use warnings;
use Carp qw(carp croak verbose);

use Data::Dumper;
use YAML;
use LWP::UserAgent;
use JSON;

our $VERSION = '0.21';
use constant REVISION => 344; # ToDo


=head1 NAME

TapTinder::Client::WebAgent - TapTinder client web interaction

=head1 SYNOPSIS

See L<TapTinder::Client>

=head1 DESCRIPTION

TapTinder client ...

=cut


sub new {
    my (
        $class, $taptinderserv, $machine_id, $machine_passwd, $keypress_obj,
        $ver, $debug
    ) = @_;

    my $self  = {};
    $self->{taptinderserv} = $taptinderserv;
    $self->{machine_id} = $machine_id;
    $self->{machine_passwd} = $machine_passwd;
    $self->{keypress} = $keypress_obj;

    $ver = 2 unless defined $ver;
    $debug = 0 unless defined $debug;
    $self->{ver} = $ver;
    $self->{debug} = $debug;

    $self->{ua} = undef;

    bless ($self, $class);
    $self->init_ua();

    return $self;
}


sub init_ua {
    my ( $self, $ua_conf ) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->agent( "TapTinder-client/" . REVISION );
    $ua->env_proxy;
    $self->{ua} = $ua;
    return 1;
}


sub run_action {
     my ( $self, $action, $request, $form_data ) = @_;

    if ( $self->{ver} >= 5 ) {
        print "action '$action' debug:\n";
        print Dumper( $request );
        print "\n";
    }

    my $taptinder_server_url = $self->{taptinderserv} . 'client/' . $action;
    my $resp;

    my $attempt_num = 0;
    do {
        $attempt_num++;
        if ( $attempt_num > 1 ) {
            my $sleep_time = 150; # maximum is 2.5 minutes
            $sleep_time = ($attempt_num-1)*($attempt_num-1) if $attempt_num <= 13; # 12*12 = 144 s
            print "Sleeping $sleep_time s before attempt number $attempt_num ...\n";
            $self->{keypress}->sleep_and_process_keypress( $sleep_time );
        }
        if ( $form_data ) {
            $resp = $self->{ua}->post( $taptinder_server_url, Content_Type => 'form-data', Content => $request );
        } else {
            $resp = $self->{ua}->post( $taptinder_server_url, $request );
        }
        if ( !$resp->is_success ) {
            print "WebAgent response error: '" . $resp->status_line . "'\n";
        }
    } while ( !$resp->is_success );
    return undef unless $resp->is_success;

    my $json_text = $resp->content;
    my $json = from_json( $json_text, {utf8 => 1} );

    if ( $self->{ver} >= 5 ) {
        print Dumper( $json );
        print "\n";
    }

    my $data = $json->{data};
    return $data;
}


sub mscreate {
    my ( $self ) = @_;

    my $action = 'mscreate';
    my $request = {
        ot => 'json',
        mid => $self->{machine_id},
        pass => $self->{machine_passwd},
        crev => REVISION,
        pid => $$,
    };
    my $data = $self->run_action( $action, $request );
    return $data;
}


sub msdestroy {
    my ( $self, $msession_id ) = @_;

    my $action = 'msdestroy';
    my $request = {
        ot => 'json',
        mid =>  $self->{machine_id},
        pass => $self->{machine_passwd},
        msid => $msession_id,
    };
    my $data = $self->run_action( $action, $request );
    return 0 unless defined $data;

    return 1;
}


sub mspcreate {
    my ( $self, $msession_id ) = @_;

    my $action = 'mspcreate';
    my $request = {
        ot => 'json',
        mid => $self->{machine_id},
        pass => $self->{machine_passwd},
        msid => $msession_id,
        pid => $$,
    };
    my $data = $self->run_action( $action, $request );
    return $data;
}


sub cget {
    my ( $self, $msession_id, $msproc_id, $attempt_number, $estimated_finish_time,
         $prev_msjobp_cmd_id ) = @_;

    my $action = 'cget';
    my $request = {
        ot =>   'json',
        mid =>  $self->{machine_id},
        pass => $self->{machine_passwd},
        msid => $msession_id,
        mspid => $msproc_id,
        an => $attempt_number,
        eftime => $estimated_finish_time,
        pmcid => $prev_msjobp_cmd_id,
    };
    my $data = $self->run_action( $action, $request );
    return $data;
}


sub sset {
    my ( $self, $msession_id, $msproc_id, $msjobp_cmd_id, $cmd_status_id,
         $end_time, $output_fpath, $outdata_fpath
    ) = @_;

    my $action = 'sset';
    my $request_upload = 0;
    my $request = {
        ot =>   'json',
        mid =>  $self->{machine_id},
        pass => $self->{machine_passwd},
        msid => $msession_id,
        mspid => $msproc_id,
        mcid => $msjobp_cmd_id,
        csid => $cmd_status_id,
    };
    if ( $end_time ) {
        $request_upload = 1;
        $request->{etime} = $end_time;
    }
    if ( $output_fpath ) {
        $request_upload = 1;
        $request->{output_file} = [ $output_fpath, 'output_file_name' ];
    }
    if ( $outdata_fpath ) {
        $request_upload = 1;
        $request->{outdata_file} = [ $outdata_fpath, 'outdata_file_name' ];
    }
    my $data = $self->run_action( $action, $request, $request_upload );
    return $data;
}


sub rciget {
    my ( $self, $msession_id, $msproc_id, $rcommit_id ) = @_;

    my $action = 'rciget';
    my $request = {
        ot =>   'json',
        mid =>  $self->{machine_id},
        pass => $self->{machine_passwd},
        msid => $msession_id,
        mspid => $msproc_id,
        rcid => $rcommit_id,
    };
    my $data = $self->run_action( $action, $request );
    return $data;
}


sub mevent {
    my ( $self, $msession_id, $msjobp_cmd_id, $event_name ) = @_;

    # TODO validate $event_name

    my $action = 'mevent';
    my $request = {
        ot   => 'json',
        mid  => $self->{machine_id},
        pass => $self->{machine_passwd},
        msid => $msession_id,
        mcid => $msjobp_cmd_id,
        en   => $event_name,
    };
    my $data = $self->run_action( $action, $request );
    return $data;
}


1;
