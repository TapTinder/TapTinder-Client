package TapTinder::Client::RepManager;

use strict;
use warnings;
use Carp qw(carp croak verbose);

our $VERSION = '0.10';

use File::Spec::Functions;
use File::Copy::Recursive qw(dircopy);
use File::Path;
use File::Copy;

use GitShell;


=head1 NAME

TapTinder::Client::RepManager - TapTinder client manager of repositories local copies

=head1 SYNOPSIS

See L<TapTinder::Client>

=head1 DESCRIPTION

TapTinder client ...

=head2 new

Create RepManager object.

=cut

sub new {
    my ( $class, $dir, $keypress_obj, $ver, $debug ) = @_;

    croak "Directory '$dir' not found.\n" unless -d $dir;

    my $self  = {};
    $self->{dir} = $dir;
    $self->{keypress} = $keypress_obj;

    $ver = 2 unless defined $ver;
    $debug = 0 unless defined $debug;
    $self->{ver} = $ver;
    $self->{debug} = $debug;

    # TODO - separate by PID, many clients
    $self->{watchdog_dir} = $self->{dir};

    bless ($self, $class);
    return $self;
}


=head2 get_base_dir_name

Return dir name for $rp_dir_base_name and $suffix.

=cut

sub get_base_dir_name {
    my ( $self, $rp_dir_base_name, $suffix ) = @_;

    my $rp_dir_name = $rp_dir_base_name . '-' . $suffix;
    return $rp_dir_name;
}


=head2 get_dir_path

Return dir_path for $rp_dir_base_name and $suffix.

=cut

sub get_dir_path {
    my ( $self, $rp_dir_base_name, $suffix ) = @_;

    my $rp_dir_name = $self->get_base_dir_name( $rp_dir_base_name, $suffix );
    my $dir_path = catdir( $self->{dir}, $rp_dir_name );
    return $dir_path;
}


=head2 prepare_repo_dirs

Will create all directories for give repository testing.

=cut

sub prepare_repo_dirs {
    my ( $self, $rp_dir_base_name ) = @_;

    #my @suffixes = ( 'src', 'temp', 'results' );
    my @suffixes = ( 'temp', 'results' );
    foreach my $suffix ( @suffixes ) {
        my $dir_path = $self->get_dir_path( $rp_dir_base_name, $suffix );
        unless ( -d $dir_path ) {
            mkdir( $dir_path ) or croak "Can't create directory '$dir_path':\n  " . $!;
        }
    }

    return 1;
}


=head2 get_repo_dir_base_name

Returns filesystem valid directory base name for $project_name, $rep_name combination.

=cut

sub get_repo_dir_base_name {
    my ( $self, $project_name, $repo_name ) = @_;

    my $fs_valid_project_name = $project_name;
    $fs_valid_project_name =~ s{[^a-zA-Z0-9\-]}{}g;
    $fs_valid_project_name =~ s{^\-+}{};

    my $fs_valid_repo_name = $repo_name;
    $fs_valid_repo_name =~ s{[^a-zA-Z0-9\-_]}{}g;

    my $rp_dir_base_name = $fs_valid_project_name;
    $rp_dir_base_name .= '-' . $fs_valid_repo_name if $fs_valid_repo_name;
    return $rp_dir_base_name;
}


=head2 dir_is_empty

Return 1 if directory is empty.

=cut

sub dir_is_empty {
    my ( $self, $src_dir_path ) = @_;

    my $dir_handle;
    opendir( $dir_handle, $src_dir_path ) or croak "Cannot open the directory '$src_dir_path': $!";
    my @files = grep {$_ ne '.' and $_ ne '..'} readdir( $dir_handle );
    closedir( $dir_handle ) or croak "Cannot close the directory '$src_dir_path': $!";

    # dir is not empty, svn co not needed
    return 0 if @files;
    return 1;
}


=head2 git_cmd_error

Print error and retur undef.

=cut

sub git_cmd_error {
    my ( $self, $rc, $cmd_name, $o_log ) = @_;
    
    print "RepManager command '$cmd_name' error.\n" if $self->{ver} >= 1;
    print "RepManager cmd log: '$o_log'\n" if $self->{ver} >= 3;
    return undef;
}


=head2 remove_dir_loop

Will try to recursive remove directory. Will sleep for 5 seconds if directory can't be removed and then try
to remove it again.

=cut


sub remove_dir_loop {
    my ( $self, $dir_path ) = @_;

    print "Removing dir '$dir_path' ...\n" if $self->{ver} >= 2;
    if ( -d $dir_path ) {
        rmtree( $dir_path ) or croak $!;
        while ( -d $dir_path ) {
            print "Remove temp dir '$dir_path' failed.\n" if $self->{ver} >= 2;
            my $wait_time = 5;
            print "Waiting for ${wait_time}s.\n" if $self->{ver} >= 2;
            $self->{keypress}->sleep_and_process_keypress( $wait_time );
            rmtree( $dir_path ) or croak $!;
        }
        print "Dir '$dir_path' removed.\n" if $self->{ver} >= 2;
    } else {
        print "Dir '$dir_path' not found.\n" if $self->{ver} >= 2;
    }
    return 1;
}


=head2 prepare_temp_from_src

Create temp_dir as copy of src_dir.

=cut

sub prepare_temp_from_src {
    my ( $self, $temp_dir_path, $src_dir_path ) = @_;

    $self->remove_dir_loop( $temp_dir_path );
    mkdir( $temp_dir_path ) or croak "Can't mkdir '$temp_dir_path':\n  $!";
    $self->{keypress}->process_keypress();

    print "Copying src '$src_dir_path' to temp '$temp_dir_path' ...\n" if $self->{ver} >= 2;
    dircopy( $src_dir_path, $temp_dir_path ) or croak "Can't copy dir '$src_dir_path' to '$temp_dir_path' $!";
    print "Copy src dir to temp dir done.\n" if $self->{ver} >= 3;

    return 1;
}


=head2 prepare_temp_copy

Prepare temp direcotry with local copy of repository revision.

Required keys and example values:
'project_name' => 'tr1',
'rep_path' => 'http://dev.taptinder.org/svn/taptinder-tr1/',
'rep_path_path' => 'trunk/',
'rev_num' => '6'

=cut

sub prepare_temp_copy {
    my ( $self, $rr_info ) = @_;

    # use Data::Dumper; print Dumper( $rr_info ); exit;
    my $rp_dir_base_name = $self->get_repo_dir_base_name(
        $rr_info->{project_name}, $rr_info->{repo_name}
    );
    $self->prepare_repo_dirs( $rp_dir_base_name );

    my $src_dir_path = $self->get_dir_path( $rp_dir_base_name, 'src' );

    # update or checkout src dir
    #my $git_clone_needed = $self->dir_is_empty( $src_dir_path );
    my $git_clone_needed = ( ! -d $src_dir_path );
    my $results_dir_path = $self->get_dir_path( $rp_dir_base_name, 'results' );
    my $ret_code;
    
    my ( $rc, $o_log );
    
    # clone
    if ( $git_clone_needed ) {
        my $src_base_dir_name = $self->get_base_dir_name( $rp_dir_base_name, 'src' );
        print "Repository not found. Doing git clone to '$src_dir_path'.\n" if $self->{ver} >= 4;
        ( $rc, $o_log ) = GitShell::git_clone( $self->{dir}, $src_base_dir_name, $rr_info->{repo_url} );
        return $self->git_cmd_error( $rc, 'git_clone', $o_log ) unless $rc;
        print "Clone log: $o_log\n" if $self->{ver} >= 4;
    }

    # fetch
    print "Doing git fetch ('$src_dir_path').\n" if $self->{ver} >= 4;
    ( $rc, $o_log ) = GitShell::git_fetch( $src_dir_path );
    return $self->git_cmd_error( $rc, 'git_fetch', $o_log ) unless $rc;

    # checkout
    print "Doing git update ('$src_dir_path').\n" if $self->{ver} >= 4;
    ( $rc, $o_log ) = GitShell::git_checkout( $src_dir_path, $rr_info->{sha} );
    return $self->git_cmd_error( $rc, 'git_checkout', $o_log ) unless $rc;

    $self->{keypress}->process_keypress();

    # create temp dir from src dir
    my $temp_dir_path = $self->get_dir_path( $rp_dir_base_name, 'temp' );
    my $prep_rc = $self->prepare_temp_from_src( $temp_dir_path, $src_dir_path );
    return undef unless $prep_rc;

    # check_not_modified
    print "Doing check_not_modified ('$temp_dir_path').\n" if $self->{ver} >= 4;
    ( $rc, $o_log ) = GitShell::check_not_modified( $temp_dir_path );
    return $self->git_cmd_error( $rc, 'check_not_modified', $o_log ) unless $rc;

    return {
        results_dir => $results_dir_path,
        temp_dir => $temp_dir_path,
    };
}


=head2 add_merge_copy_recursion

Recursive part for add_merge_copy.

=cut


sub add_merge_copy_recursion {
    my ( $self, $src_dir, $dest_dir ) = @_;

    my $dir_handle;
    opendir( $dir_handle, $src_dir ) or croak "Cannot open the directory '$src_dir': $!";
    my @files_dirs = grep { $_ ne '.' and $_ ne '..' } readdir( $dir_handle );
    closedir( $dir_handle ) or croak "Cannot close the directory '$src_dir': $!";

    return 1 unless @files_dirs;

    foreach my $file_dir ( @files_dirs ) {

        # directory - recursive copy
        # TODO - catdir here?
        my $full_path = catdir( $src_dir, $file_dir );
        if ( -d $full_path ) {
            # Skip clien Subversion metadata
            next if $file_dir eq '.svn';
            next if $file_dir eq '_svn';

            my $new_src_dir = catdir( $src_dir, $file_dir );
            my $new_dest_dir = catdir( $dest_dir, $file_dir );
            unless ( -d $new_dest_dir ) {
                mkdir( $new_dest_dir ) or croak "Can't create directory '$new_dest_dir'.\n$!";
            }
            $self->add_merge_copy_recursion( $new_src_dir, $new_dest_dir );
            next;
        }

        # file
        my $src_fpath = catfile( $src_dir, $file_dir );
        my $dest_fpath = catfile( $dest_dir, $file_dir );
        copy( $src_fpath, $dest_fpath ) or croak "Can't copy '$src_fpath' to '$dest_fpath'.\n$!";
    }
    return 1;
}


=head2 add_merge_copy

Copy (add) all files from $src_dir to $dest_dir.

=cut

sub add_merge_copy {
    my ( $self, $src_dir, $dest_dir ) = @_;

    # add-src directory for this project doesn't exist
    return 1 unless -d $src_dir;
    return $self->add_merge_copy_recursion( $src_dir, $dest_dir );
}


=head1 TODO

Full client-data directory managment.
* quotas, cleanup
* ...

=cut

1;
