package TapTinder::Client::Conf;

use strict;
use warnings;
use Carp qw(carp croak verbose);

use base 'Exporter';
our $VERSION = 0.01;
our @EXPORT = qw(load_client_conf);


sub load_client_conf {
    my ( $conf_fpath, $conf_section_name ) = @_;
    croak "Can't find client configuration file '$conf_fpath'.\n" unless -f $conf_fpath;
    my ( $client_conf) = YAML::LoadFile( $conf_fpath );
    return $client_conf;
}

1;