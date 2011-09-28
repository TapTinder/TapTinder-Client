package GitShell;

use strict;
use warnings;

use base 'Exporter';
our $VERSION = 0.01;
our @EXPORT_OK = qw(set_git_cmd_prefix git_clone git_status git_checkout);

use Cwd;

# TODO - escapeshellarg


my $git_cmd_prefix = '';

sub set_git_cmd_prefix {
    my ( $dir ) = @_;
    $git_cmd_prefix = $dir;
}


sub git_clone {
    my ( $base_dir, $repo_dir_name, $repo_url ) = @_;
    my $act_dir = getcwd;

    chdir $base_dir || return ( 0, "Command chdir to '$base_dir' failed: $!" );
    my $gitclone_cmd =  $git_cmd_prefix . "git clone $repo_url $repo_dir_name" . ' 2>&1 |';
    unless ( open( GITCLONE, $gitclone_cmd ) ) {
        chdir $act_dir;
        return ( undef, $! );
    }
    my $gitclone_log = '';
    {
        local $/ = undef;
        $gitclone_log = <GITCLONE>;
    }
    close GITCLONE;

    chdir $act_dir;
    return (1, $gitclone_log );
}


sub git_status {
    my ( $dir ) = @_;
    my $act_dir = getcwd;

    chdir $dir || return( 0, "Command chdir to '$dir' failed: $!" );
    my $gitin_cmd =  $git_cmd_prefix . 'git info ' . $dir . ' 2>&1 |';
    unless ( open( GITINFO, $gitin_cmd ) ) {
        chdir $act_dir || return ( 0, $! );
        return ( undef, $! );
    }
    my $gitin_log = '';
    {
        local $/ = undef;
        $gitin_log = <GITINFO>;
    }
    close GITINFO;

    my ( $actual_rev ) = $gitin_log =~ /Revision:\s*(\d+(?:\:\d+)?M?)\s*/msi;
    chdir $act_dir || return ( 0, $! );
    return ( $actual_rev, $gitin_log );
}


sub git_checkout {
    my ( $dir, $commit_sha ) = @_;
    my $act_dir = getcwd;

    chdir $dir || return ( 0, "Command chdir to '$dir' failed: $!" );
    my $git_checkout_cmd =
        $git_cmd_prefix . 'git checkout ' 
        . $commit_sha
        . ' 2>&1 |'
    ;
    if ( open( GITCHECKOUT, $git_checkout_cmd ) ) {
        my $gitcheckout_log = '';
        while ( my $line = <GITCHECKOUT> ) { $gitcheckout_log .= $line; }
        close GITCHECKOUT;
        chdir $act_dir || return ( 0, "Command chdir back to '$act_dir' failed: $!" );
        return ( 1, $gitcheckout_log );
    }
    chdir $act_dir || return ( 0, "Command chdir back to '$act_dir' failed: $!" );
    return ( 0, $! );
}



sub git_fetch {
    my ( $dir ) = @_;
    my $act_dir = getcwd;

    chdir $dir || return ( 0, "Command chdir to '$dir' failed: $!" );
    my $git_cmd =
        $git_cmd_prefix . 'git fetch ' 
        . ' 2>&1 |'
    ;
    if ( open( GITFETCH, $git_cmd ) ) {
        my $git_log = '';
        while ( my $line = <GITFETCH> ) { $git_log .= $line; }
        close GITFETCH;
        chdir $act_dir || return ( 0, "Command chdir back to '$act_dir' failed: $!" );
        return ( 1, $git_log );
    }
    chdir $act_dir || return ( 0, "Command chdir back to '$act_dir' failed: $!" );
    return ( 0, $! );
}



=head2 check_not_modified

Check if directory is in clean (not modified) state.

=cut

sub check_not_modified {
    my ( $dir ) = @_;

    # ToDo
    return 1;
}


1;

