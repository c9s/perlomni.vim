#!/usr/bin/env perl
use warnings;
use strict;
use PPI;

# parse from util/moose-type-constraints script
my @types = qw(Item Undef Defined Bool Value Ref Str Num Int ScalarRef CodeRef RegexpRef GlobRef FileHandle Object Role ClassName RoleName);

# XXX:
#  should skip basic data types: Str , Int , Hash ... etc

my $file = shift;
my $d = PPI::Document->new( $file );

my $sts = $d->find( sub { 
    $_[1]->isa('PPI::Statement') and $_[1]->child;
});

if( $sts ) {
    for my $st ( @$sts ) {
        if( $st->isa('PPI::Statement') and $st->child(0)->content eq 'has' ) {
            my $key = $st->child(2)->content;
            my $list = $st->find( sub {
                $_[1]->isa('PPI::Structure::List')
            });
            my %hash = eval $list->[0];
            print join(' ',$key,$hash{isa} ) . "\n" if defined $hash{isa};
        }
    }
}
