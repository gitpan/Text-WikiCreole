#!/usr/bin/perl

use lib 'lib';
use Text::WikiCreole;

creole_extend;
sub uppercase_plugin {
  my $text = shift; 
  $text =~ s/([a-z])/\u$1/gs;
  return "$text";
}
#creole_plugin \&uppercase_plugin;
#creole_link \&uppercase_plugin;

sub mylink {
      $_[0] =~ s|href=\"|href=\"http://my.comain/|;
      return $_[0];
}
creole_link \&mylink;



local $/; my $text = <DATA>;

print creole_parse($text);



__DATA__
test ** bold**
