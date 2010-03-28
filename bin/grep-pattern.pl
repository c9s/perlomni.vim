#!/usr/bin/env perl
my $file    = shift;
my $pattern = shift;
open FH, "<" , $file or die $!;
my @lines = <FH>;

my @vars = ();
for ( @lines ) {
    while ( /$pattern/og ) {
        push @vars,$1;
    }
}
close FH;
print $_  . "\n" for @vars;
