use strict;
use warnings;
use lib qw( lib . ../lib ../../lib );
use Test::More;

use TAPTinder::TestedRevs;

# project_name
my $pname = 'test-' . $$;

my $trevs = get_tested_revisions( $pname );

plan tests => 30;

is_deeply( $trevs, {}, 'empty' );

my $to_test;
$to_test = get_revision_to_test( $pname, 1 );
is( $to_test, 1, 'to test if actual is 1->1' );

$to_test = get_revision_to_test( $pname, 5 );
is( $to_test, 5, 'to test if actual is 5->5' );

revision_test_done( $pname, 5 );
$trevs = get_tested_revisions( $pname );
is_deeply( $trevs, { 5 => 1, }, 'contains 5' );

$to_test = get_revision_to_test( $pname, 5 );
is( $to_test, 4, 'to test if actual is 5->4' );

$to_test = get_revision_to_test( $pname, 4 );
is( $to_test, 4, 'to test if actual is 4->4' );

$to_test = get_revision_to_test( $pname, 10 );
is( $to_test, 10, 'to test is ok - 10->10' );

$to_test = get_revision_to_test( $pname, 2 );
is( $to_test, 4, 'to test is ok - 2->4' );


revision_test_done( $pname, 4 );
$trevs = get_tested_revisions( $pname );
is_deeply( $trevs, { 4 => 1, 5 => 1, }, 'contains 4 and 5' );

$to_test = get_revision_to_test( $pname, 5 );
is( $to_test, 3, 'to test if actual is 5->3' );

$to_test = get_revision_to_test( $pname, 4 );
is( $to_test, 3, 'to test if actual is 4->3' );

$to_test = get_revision_to_test( $pname, 10 );
is( $to_test, 10, 'to test is ok - 10->10' );

$to_test = get_revision_to_test( $pname, 3 );
is( $to_test, 3, 'to test is ok - 3->3' );

$to_test = get_revision_to_test( $pname, 2 );
is( $to_test, 3, 'to test is ok - 2->3' );


revision_test_done( $pname, 3 );
revision_test_done( $pname, 2 );
$trevs = get_tested_revisions( $pname );
is_deeply( $trevs, { 2 => 1, 3 => 1, 4 => 1, 5 => 1, }, 'contains 2..5' );

$to_test = get_revision_to_test( $pname, 10 );
is( $to_test, 10, 'to test is ok - 10->10' );

$to_test = get_revision_to_test( $pname, 5 );
is( $to_test, 1, 'to test is ok - 5->1' );


revision_test_done( $pname, 1 );
$to_test = get_revision_to_test( $pname, 1 );
is( $to_test, undef, 'to test is ok - 1->undef' );

$to_test = get_revision_to_test( $pname, 5 );
is( $to_test, undef, 'to test is ok - 5->undef' );


revision_test_done( $pname, 10 );
$trevs = get_tested_revisions( $pname );
is_deeply( $trevs, { 1 => 1, 2=>1, 3=>1, 4=>1, 5=>1, 10=>1, }, 'contains 1..5 and 10' );

$to_test = get_revision_to_test( $pname, 10 );
is( $to_test, 9, 'to test if actual is 10->9' );

$to_test = get_revision_to_test( $pname, 11 );
is( $to_test, 11, 'to test if actual is 11->11' );

$to_test = get_revision_to_test( $pname, 5 );
is( $to_test, 9, 'to test is ok - 5->9' );

$to_test = get_revision_to_test( $pname, 3 );
is( $to_test, 9, 'to test is ok - 3->9' );


revision_test_done( $pname, 9 );
revision_test_done( $pname, 11 );
$trevs = get_tested_revisions( $pname );
is_deeply( $trevs, { 1 => 1, 2=>1, 3=>1, 4=>1, 5=>1, 9=>1, 10=>1, 11=>1 }, 'contains 1..5 and 9..11' );

$to_test = get_revision_to_test( $pname, 20 );
is( $to_test, 20, 'to test if actual is 20->20' );

$to_test = get_revision_to_test( $pname, 10 );
is( $to_test, 8, 'to test if actual is 10->8' );

$to_test = get_revision_to_test( $pname, 6 );
is( $to_test, 8, 'to test if actual is 6->8' );

$to_test = get_revision_to_test( $pname, 2 );
is( $to_test, 8, 'to test if actual is 2->8' );


ok( unlink_state_file( $pname ), 'unlink ok' );
