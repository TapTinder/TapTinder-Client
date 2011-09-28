use strict;
use warnings;

use Data::Dumper;
use YAML qw(LoadFile);

my $conf_fname = 'taptinder-client.yml.example';
my ( $conf ) = LoadFile( $conf_fname );
print Dumper( $conf );
