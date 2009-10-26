#!/usr/bin/env perl
# get perl function list
my $pathes = join ' ',@INC;
# my $pod = qx( find $pathes -name );
# chomp $pod;

open(FH, '-|', qq|podselect -section 'DESCRIPTION/*' /opt/local/lib/perl5/5.10.1/pods/perlapi.pod| );
my @func ;
my $inline = 0;
while( <FH> )
{
    if( /^=over/ ) {
        $inlist++;
    }
    elsif( /^=back/ ) {
        $inlist--;
    }
    elsif( /^=item \w+/ ) {
        s/^=item //;
        chomp;
        push @func,$_ if $inlist == 1;
    }
}
close FH;

print $_ , "\n" for @func;
