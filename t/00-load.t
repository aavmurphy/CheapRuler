#!perl
use 5.006;
use strict;
use warnings;
use Test::More;

plan tests => 1;

BEGIN {
    use_ok( 'CheapRuler' ) || print "Bail out!\n";
}

diag( "Testing CheapRuler $CheapRuler::VERSION, Perl $], $^X" );
