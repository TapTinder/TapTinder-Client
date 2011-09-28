package TapTinder::Client;

use strict;
use warnings;
use Carp qw(carp croak verbose);

our $VERSION = '0.21';

use Data::Dumper;
use File::Spec::Functions;
use Cwd;
use File::Copy;

use Watchdog qw(sys sys_for_watchdog);
use TapTinder::Client::KeyPress;
use TapTinder::Client::WebAgent;
use TapTinder::Client::RepManager;

=head1 NAME

TapTinder::Client - Client for TapTinder software development tool.

=head1 DESCRIPTION

TapTinder is software development tool (continuous integration, test
harness, collect and analyse test results, create reports and diffs).

=head2 $ver

Verbosity level.

* >0 .. print errors only
* >1 .. print base run info
* >2 .. all run info (default)
* >3 .. major debug info
* >4 .. major and minor debug info
* >5 .. all debug info

=cut

our $ver = 0;

our $debug = 0;


=head2 new

Create Client object.

=cut

sub new {
    my ( $class, $client_conf, $base_dir, $params ) = @_;

    $ver = $params->{ver};
    $debug = $params->{debug};

    my $self = {};
    $self->{client_conf} = $client_conf;
    $self->{src_add_dir} = catdir( $base_dir, 'client-src-add' );
    $self->{data_dir} = catdir( $base_dir, 'client-data' );

    $self->{agent} = undef;
    $self->{msession_id} = undef;
    $self->{msproc_id} = undef;
    $self->{msjobp_cmd_id} = undef;

    $self->{params} = $params;

    $self->{do_stop} = 0;
    $self->{do_client_restart} = 0;
    $self->{do_client_upgrade} = 0;

    # current work directory on start
    $self->{orginal_cwd} = Cwd::getcwd;

    bless ($self, $class);

    # Must be first, because used in agent and repmanager.
    $self->init_keypress();

    $self->init_agent();
    $self->init_repmanager();

    return $self;
}


=head2 init_agent

Initialize KeyPress object.

=cut

sub init_keypress {
    my ( $self ) = @_;

    my $keypress = TapTinder::Client::KeyPress->new(
        $ver,
        $debug
    );

    # Closure - take $self.
    my $before_exit_sub = sub {
        chdir( $self->{orginal_cwd} );
        if ( $self->{msession_id} ) {
            $self->{agent}->msdestroy( $self->{msession_id} );
        }
    };
    $keypress->set_before_exit_sub( $before_exit_sub );

    my $pause_begin_sub = sub {
        if ( $self->{msession_id} ) {
            $self->{agent}->mevent( $self->{msession_id}, $self->{msjobp_cmd_id}, 'pause' );
        }
    };
    $keypress->set_pause_begin_sub( $pause_begin_sub );

    my $pause_refresh_sub = sub {
        if ( $self->{msession_id} ) {
            $self->{agent}->mevent( $self->{msession_id}, $self->{msjobp_cmd_id}, 'pause refresh' );
        }
    };
    $keypress->set_pause_refresh_sub( $pause_refresh_sub );
    $keypress->set_pause_refresh_rate( 60*60 );

    my $pause_end_sub = sub {
        if ( $self->{msession_id} ) {
            $self->{agent}->mevent( $self->{msession_id}, $self->{msjobp_cmd_id}, 'continue' );
        }
    };
    $keypress->set_pause_end_sub( $pause_end_sub );

    $self->{keypress} = $keypress;
    return 1;
}


=head2 init_agent

Initialize WebAgent object.

=cut

sub init_agent {
    my ( $self ) = @_;

    print "Starting WebAgent.\n" if $ver >= 3;
    my $agent = TapTinder::Client::WebAgent->new(
        $self->{client_conf}->{taptinderserv},
        $self->{client_conf}->{machine_id},
        $self->{client_conf}->{machine_passwd},
        $self->{keypress},
        $ver,
        $debug
    );

    $self->{agent} = $agent;
    return 1;
}


=head2 process_agent_errors_get_err_num

Process data from server response for errors.

Croak if error is fatal or unknown.
Return ag_err number if found and set $self->{do_stop} to 1 if run loop should exit.
Return error number if not fatal error found.
Return 0 unless error found.

101..999 are ag_err errors.
1001..9999 are normal errors.

=cut

sub process_agent_errors_get_err_num {
    my ( $self, $cmd_name, $data ) = @_;

    $self->my_croak( "Unknown error (no data found)." ) unless $data;
    if ( exists $data->{ag_err} && $data->{ag_err} ) {

        # No fatal errors:
        # * 101 msession_id not found, need to create new msession
        my $found_no_fatal = 0;
        if ( $data->{ag_err} == 101 ) {
            $self->{do_client_restart} = 1;
            $self->{do_stop} = 1;
            $found_no_fatal = 1;
        }
        # * 102 server demands client upgrade
        if ( $data->{ag_err} == 102 ) {
            $self->{do_client_upgrade} = 1;
            $self->{do_stop} = 1;
            $found_no_fatal = 1;
        }
        if ( $found_no_fatal ) {
            print $data->{ag_err_msg}."\n" if $ver >= 1;
            return $data->{ag_err};
        }

        $self->my_croak( $data->{ag_err_msg} );
    }

    if ( exists $data->{err} && $data->{err} ) {
        print $data->{err_msg}."\n" if $ver >= 1;
        return $data->{err} if $data->{err} == 1001; # cget, can't obtain lock
    }

    $self->my_croak( $data->{err_msg} ) if $data->{err};
    return 0; # error num = 0 -> no error found
}


=head2 init_agent

Initialize WebAgent object.

=cut

sub init_repmanager {
    my ( $self ) = @_;
    
    unless ( -d $self->{data_dir} ) {
        mkdir $self->{data_dir} or croak $!;
    }

    print "Starting RepManager.\n" if $ver >= 3;
    my $repman = TapTinder::Client::RepManager->new(
        $self->{data_dir},
        $self->{keypress},
        $ver,
        $debug
    );

    $self->{repman} = $repman;
    return 1;
}


=head2 my_croak

Cleanup and croak.

=cut

sub my_croak {
    my ( $self, $err_msg ) = @_;
    $self->{keypress}->cleanup_before_exit();
    croak $err_msg;
}


=head2 ccmd_get_src

Run get_src client command.

=cut

sub ccmd_get_src {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;

    my $data; # many different uses
    $data = $self->{agent}->rciget(
        $self->{msession_id}, $self->{msproc_id}, $cmd_env->{rcommit_id}
    );
    return 0 if $self->process_agent_errors_get_err_num( 'rciget', $data );

    my $rcommit_info = { %$data };
    $cmd_env->{project_name} = $data->{project_name};
    $cmd_env->{repo_name} = $data->{repo_name};
    $cmd_env->{repo_url} = $data->{repo_url};
    $cmd_env->{sha} = $data->{sha};

    print "Checkout $cmd_env->{project_name} $cmd_env->{sha}.\n" if $ver >= 2;

    $data = $self->{agent}->sset( $self->{msession_id}, $self->{msproc_id}, $self->{msjobp_cmd_id}, 2 ); # running, $cmd_status_id
    return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );

    my $dirs = $self->{repman}->prepare_temp_copy( $rcommit_info );
    unless ( $dirs ) {
        $data = $self->{agent}->sset( $self->{msession_id}, $self->{msproc_id}, $self->{msjobp_cmd_id}, 7 ); # error, $cmd_status_id
        return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );
        return 0;
    }
    $cmd_env->{temp_dir} = $dirs->{temp_dir};
    $cmd_env->{results_dir} = $dirs->{results_dir};

    $data = $self->{agent}->sset( $self->{msession_id}, $self->{msproc_id}, $self->{msjobp_cmd_id}, 4 ); # ok, $cmd_status_id
    return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );

    return 1;
}


=head2 ccmd_prepare

Run prepare client command. Prepare project dir for TapTinder run.

=cut

sub ccmd_prepare {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;

    my $data = $self->{agent}->sset( $self->{msession_id}, $self->{msproc_id}, $self->{msjobp_cmd_id}, 2 ); # running, $cmd_status_id
    return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );

    my $src_add_project_dir = catdir( $self->{src_add_dir}, $cmd_env->{project_name} );
    $self->{repman}->add_merge_copy( $src_add_project_dir, $cmd_env->{temp_dir} );

    $data = $self->{agent}->sset( $self->{msession_id}, $self->{msproc_id}, $self->{msjobp_cmd_id}, 4 ); # ok, $cmd_status_id
    return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );

    return 1;
}


=head2 ccmd_patch

Run patch client command.

=cut

sub ccmd_patch {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;
    print "Client command 'patch' not implemented yet.\n" if $ver >= 2;
    return 1;
}


=head2 run_cmd

Run command.

=cut

sub run_cmd {
    my (
        $self, $cmd_name, $cmd_env, $cmd, $cmd_params,
        $cmd_timeout, $outdata_file_full_path
    ) = @_;

    my $base_out_fname =
        $cmd_env->{msjob_id}
        . '-' . $cmd_env->{jobp_num}
        . '-' . $cmd_env->{jobp_cmd_num}
        . '-' . $cmd_name
    ;
    my $log_file_name =
        $base_out_fname
        . '.txt'
    ;
    my $cmd_log_fp = catfile( $cmd_env->{results_dir}, $log_file_name );

    my $data = $self->{agent}->sset(
        $self->{msession_id},
        $self->{msproc_id},
        $self->{msjobp_cmd_id}, # $msjobp_cmd_id
        2, # running
        undef, # $end_time
        undef  # $file_path
    );
    return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );


    my ( $cmd_rc, $out ) = sys_for_watchdog(
        $cmd,
        $cmd_params,
        $cmd_log_fp,
        $cmd_timeout,
        undef,
        $self->{data_dir}, # path to watchdog-setting.bin
        $ver # verbose or not
    );
    print "Command '$cmd_name' return $cmd_rc.\n" if $ver >= 5;

    my $status = 4; # 4 .. ok
    if ( $cmd_rc ) {
        $status = 7; # 7 .. error
    }

    # don't try to send outdata file if it doesn't exists
    if ( $outdata_file_full_path ) {
        if ( -f $outdata_file_full_path ) {
            # copy to results
            my $dest_outdata_fpath = catfile( $cmd_env->{results_dir}, $base_out_fname.'.tar.gz' );
            copy( $outdata_file_full_path, $dest_outdata_fpath )
                or carp "Copy '$outdata_file_full_path' to '$dest_outdata_fpath' failed.\n$!";
        } else {
            print "Trun outdata file '$outdata_file_full_path' not found.\n" if $ver >= 3;
            $outdata_file_full_path = undef;
        }
    }
    $data = $self->{agent}->sset(
        $self->{msession_id},
        $self->{msproc_id},
        $self->{msjobp_cmd_id}, # $msjobp_cmd_id
        $status,
        time(), # $end_time, TODO - is GMT?
        $cmd_log_fp,
        $outdata_file_full_path
    );
    return 0 if $self->process_agent_errors_get_err_num( 'sset', $data );

    return 1;
}


=head2 ccmd_perl_configure

Run perl_configure client command.

=cut

sub ccmd_perl_configure {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;

    my $cmd = 'perl Configure.pl';
    my $cmd_timeout = 5*60; # 5 min
    return $self->run_cmd( $cmd_name, $cmd_env, $cmd, $cmd_params, $cmd_timeout, undef );
}


=head2 ccmd_make

Run make client command.

=cut

sub ccmd_make {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;

    my $cmd = 'make';
    if ( $^O eq 'MSWin32' ) {
        my $rc = system( "mingw32-make --version > nul" );
        if ( $rc == 0 ) {
            $cmd = 'mingw32-make';
        } else {
            $cmd = 'nmake';
        }
    }

    my $cmd_timeout = 5*60; # 5 min
    return $self->run_cmd( $cmd_name, $cmd_env, $cmd, $cmd_params, $cmd_timeout, undef );
}


=head2 ccmd_trun

Run trun client command.

=cut

sub ccmd_trun {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;

    my $cmd;
    if ( $^O eq 'MSWin32' ) {
        $cmd = 'perl.exe t\harness --archive';
    } else {
        $cmd = 'perl t/harness --archive';
    }
    my $cmd_timeout = 15*60; # 15 min

    # TODO - Parrot file name
    my $outdata_file_full_path = catfile( $cmd_env->{temp_dir}, 'parrot_test_run.tar.gz' );
    return $self->run_cmd( $cmd_name, $cmd_env, $cmd, $cmd_params, $cmd_timeout, $outdata_file_full_path );
}


=head2 ccmd_test

Run test client command.

=cut

sub ccmd_test {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;

    my $cmd = 'make test';
    my $cmd_timeout = 5*60; # 5 min
    return $self->run_cmd( $cmd_name, $cmd_env, $cmd, $cmd_params, $cmd_timeout, undef );
}


=head2 ccmd_bench

Run bench client command.

=cut

sub ccmd_bench {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;
    print "Client command 'bench' not implemented yet.\n" if $ver >= 2;
    return 1;
}


=head2 ccmd_install

Run install client command.

=cut

sub ccmd_install {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;
    print "Client command 'install' not implemented yet.\n" if $ver >= 2;
    return 1;
}


=head2 ccmd_clean

Run clean client command.

=cut

sub ccmd_clean {
    my ( $self, $cmd_name, $cmd_env, $cmd_params ) = @_;
    print "Client command 'clean' not implemented yet.\n" if $ver >= 2;
    return 1;
}


=head2 do_client_upgrade

Return 1 if server demands client upgrade.

=cut

sub do_client_upgrade {
    my ( $self ) = @_;
    return $self->{do_client_upgrade};
}


=head2 do_client_restart

Return 1 if client demands restart.

=cut

sub do_client_restart {
    my ( $self ) = @_;
    return $self->{do_client_restart};
}


=head2 cleanup_and_return_zero

Do client run cleanup and return 0;

=cut

sub cleanup_and_return_zero {
    my ( $self ) = @_;
    $self->{keypress}->cleanup_before_exit();
    return 0;
}


=head2 run

Main run loop.

=cut

sub run {
    my ( $self ) = @_;

    print "Creating new machine session.\n" if $ver >= 3;
    my $data;
    do {
        return $self->cleanup_and_return_zero() if $self->{do_stop};
        $data = $self->{agent}->mscreate();
    } while ( $self->process_agent_errors_get_err_num( 'mscreate', $data ) );
    $self->{msession_id} = $data->{msid};
    
    $self->{keypress}->process_keypress();
    
    # ToDo - fork, errors
    my $proc_data = $self->{agent}->mspcreate( $self->{msession_id} );
    $self->process_agent_errors_get_err_num( 'mspcreate', $proc_data );
    $self->{msproc_id} = $proc_data->{mspid};

    # current (or last successful) ids
    my $msjob_id = undef;
    my $msjobp_id = undef;
    $self->{msjobp_cmd_id} = undef;

    # data shared between commands
    my $cmd_env = {};
    # Keys:
    # temp_dir - path to working copy (temp), created after ccmd_get_src
    # jobp_num, jobp_cmd_num - Number of job part in job and number of cmd in job_part.
    #                          Used as part of local client log file names.

    # number of job runs
    my $job_num = 0;
    # number of cget runs with "new cmd not found"
    my $no_job_num = 0;

    # Number of next attempt. Reseted to 1 after each successful cget.
    my $next_attempt_number = 1;
    my $estimated_finish_time = undef;

    my $ret_code; # last command return code

    while ( 1 ) {
        # to simplify code
        return $self->cleanup_and_return_zero() if $self->{do_stop};
        $self->{keypress}->process_keypress();

        # try to get command from server
        my $data = $self->{agent}->cget(
            $self->{msession_id},
            $self->{msproc_id},
            $next_attempt_number, # $attemnt_number
            $estimated_finish_time,
            $self->{msjobp_cmd_id} # use actual id to get new one
        );
        next if $self->process_agent_errors_get_err_num( 'cget', $data );

        # new cmd not found
        if ( ! $data->{msjobp_cmd_id} ) {
            $no_job_num++;
            $next_attempt_number++;

            print "New msjobp_cmd_id not found.\n";
            last if $self->{params}->{end_after_no_new_job};
            last if $debug; # debug - end forced by debug

            my $sleep_time = 15;
            print "Waiting for $sleep_time s ...\n" if $ver >= 1;
            $self->{keypress}->sleep_and_process_keypress( $sleep_time );

        # new cmd found
        } else {
            $next_attempt_number = 1;

            # new job
            if ( !defined($msjob_id) || ( exists($data->{msjob_id}) && $msjob_id != $data->{msjob_id}) ) {
                $job_num++;

                $cmd_env = {};
                $cmd_env->{jobp_num} = 0;
                $cmd_env->{jobp_cmd_num} = 0;
                $msjob_id = $data->{msjob_id};
                $cmd_env->{msjob_id} = $msjob_id;

                last if $debug && ($job_num > 1); # debug - end forced by debug
                if ( $ver >= 2 ) {
                    print "\n";
                    my @lt = localtime(time);
                    my $datetime_str = $lt[2].':'.$lt[1].':'.$lt[0].' '.$lt[3].'.'.($lt[4] + 1).'.'.($lt[5] + 1900);
                    print "Starting job number $job_num (id $data->{msjob_id}) at $datetime_str.\n";
                }
            }
            # new job part
            if ( !defined($msjobp_id) || ( exists($data->{msjobp_id}) && $msjobp_id != $data->{msjobp_id} ) ) {
                $cmd_env->{jobp_num}++;
                chdir( $self->{orginal_cwd} );
                $cmd_env->{temp_dir} = undef;
                $msjobp_id = $data->{msjobp_id};
            }
            # new command
            if ( !defined($self->{msjobp_cmd_id}) || ( exists($data->{msjobp_cmd_id}) && $self->{msjobp_cmd_id} != $data->{msjobp_cmd_id} ) ) {
                $cmd_env->{jobp_cmd_num}++;
                $self->{msjobp_cmd_id} = $data->{msjobp_cmd_id};
            } else {
                $self->my_croak("Error new msjobp_cmd_id=$data->{msjobp_cmd_id}.");
            }

            my $cmd_name = $data->{cmd_name};
            my $cmd_params = undef;
            $cmd_params = $data->{cmd_params} if exists $data->{cmd_params};
            if ( $cmd_name eq 'get_src' ) {
                $cmd_env->{rcommit_id} = $data->{rcommit_id};
                # will set another keys to $cmd_env
                $ret_code = $self->ccmd_get_src( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;
                
                # change current working directory (cwd, pwd)
                chdir( $cmd_env->{temp_dir} );

            } elsif ( $cmd_name eq 'prepare' ) {
                $ret_code = $self->ccmd_prepare( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'patch' ) {
                $ret_code = $self->ccmd_patch( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'perl_configure' ) {
                $ret_code = $self->ccmd_perl_configure( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'make' ) {
                $ret_code = $self->ccmd_make( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'trun' ) {
                $ret_code = $self->ccmd_trun( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'test' ) {
                $ret_code = $self->ccmd_test( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'bench' ) {
                $ret_code = $self->ccmd_bench( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'install' ) {
                $ret_code = $self->ccmd_install( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;

            } elsif ( $cmd_name eq 'clean' ) {
                $ret_code = $self->ccmd_clean( $cmd_name, $cmd_env, $cmd_params );
                return $self->cleanup_and_return_zero() unless $ret_code;
            }

            # debug sleep
            if ( 0 ) {
                my $sleep_time = 5;
                print "Debug sleep. Waiting for $sleep_time s ...\n" if $ver >= 1;
                $self->{keypress}->sleep_and_process_keypress( $sleep_time );
            }
        }
    } # while

    $self->{keypress}->cleanup_before_exit();
    return 1;
}


=head1 AUTHOR

Michal Jurosz <mj@mj41.cz>

=head1 COPYRIGHT

Copyright (c) 2007-2008 Michal Jurosz. All rights reserved.

=head1 TODO

Refactoring
* remove direct KeyPress method calls from RepManager
* ...

=head1 LICENSE

TapTinder is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

TapTinder is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

=head1 BUGS

L<http://dev.taptinder.org/>

=head1 SEE ALSO

L<TapTinder>, L<TapTinder::Web>

=cut

1;
