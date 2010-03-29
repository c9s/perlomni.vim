#!/usr/bin/env perl
my $file = shift;
# looking for:
#    $var1 = new ClassName( );
# or 
#    $var2 = ClassName->new(  );

open FH, "<", $file;
my @lines = <FH>;
for ( @lines ) {
    if( /(\$\w+)\s*=\s*new\s+([A-Z][a-zA-Z0-9_:]+)/  ) {
        print $1 , "\t" , $2 , "\n";
    }
    elsif( /(\$\w+)\s*=\s*([A-Z][a-zA-Z0-9_:]+)->new/  ) {
        print $1 , "\t" , $2 , "\n";
    }
}
close FH;
