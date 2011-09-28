package SVN::PropBug;

use strict;
use warnings;

use base 'Exporter';
our $VERSION = 0.01;
our @EXPORT_OK = qw(diff_contains_real_change);

our $ver = 0;


# For bypasing bug [perl #49788].

# TODO - better parsing

# for full parsing use Text::Diff::Parser
sub diff_contains_real_change {
    my ( $diff ) = @_;

    return 1 unless $diff;

    my @lines = split( /\n/, $diff );

    my $num_to_skip = 4; # skip first 4 lines
    my $pn = 'diff'; # part name

    my $prev_minus_line = undef;
    my $real_change = 0;

    foreach my $ln ( 0..$#lines ) {
        my $line = $lines[ $ln ];
        if ( $ver > 4 ) {
            printf("%3d:",$ln);
            print $line . " - ";
            ( defined $prev_minus_line ) ? print "PM" : print "..";
            print " - ";
        }

        # skip line
        if ( $num_to_skip > 0 ) {
            $num_to_skip--;
            print "skipped, to_skip=$num_to_skip\n" if $ver > 4;
            next;
        }

        # head
        if ( $pn eq 'head' ) {
            $num_to_skip = 2;
            print "$pn\n" if $ver > 4;
            $pn = 'diff';

            $real_change = 1 if defined $prev_minus_line;
            $prev_minus_line = undef;
            next;
        }

        # diff
        if ( $pn eq 'diff' ) {
            my $first_char = substr( $line, 0, 1 );
            print "$pn - first char '$first_char'\n" if $ver > 4;

            if ( $first_char eq '+' ) {
                if ( defined $prev_minus_line ) {
                    # $Id:$ -> $Id$, $Author:$ -> $Author$
                    my $fixed_prev_line = $prev_minus_line;
                    $fixed_prev_line =~ s{\$(id|author):\s*[^\$]*\$}{\$$1\$}ig;
                    #print "----> ". $fixed_prev_line;
                    if ( substr($fixed_prev_line,1) ne substr($line,1) ) {
                        $real_change = 1;
                        print "<<REAL CHANGE FOUND>>\n" if $ver > 4;
                    }
                }
                $prev_minus_line = undef;
                next;
            }

            $real_change = 1 if defined $prev_minus_line;
            $prev_minus_line = undef;

            if ( $first_char eq '-' ) {
                $prev_minus_line = $line;
                next;
            }

            if ( $line =~ /^Index:/ ) {
                $pn = 'head';
                next;
            }

            if ( $first_char eq '@' ) {
                if ( $line !~ /^\@\@\s+\-(\d+),(\d+)\s+\+(\d+),(\d+)\s+\@\@\s*$/ ) {
                    $@ = "Begin of section 'line_nums' not found on line $ln.";
                    return undef;
                }

                #              0   1   2   3
                my @diff_poss = ( $1, $2, $3, $4 );
                next;
            }

            if ( $first_char eq '\\' ) {
                next;
            }

            if ( $first_char eq ' ' ) {
                next;
            }

            $@ = "Unknown diff first char, line $ln.";
            next;
        }

        $@ = "Unknown part found, line $ln.";
        return undef;
    }

    $real_change = 1 if defined $prev_minus_line;

    return $real_change;
}


1;
