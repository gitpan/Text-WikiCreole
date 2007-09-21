#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Text::WikiCreole' );
}

diag( "Testing Text::WikiCreole $Text::WikiCreole::VERSION, Perl $], $^X" );
