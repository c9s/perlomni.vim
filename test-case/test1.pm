# SAMPLES {{{



# module compeltion
my $obj = new Jifty::Web;
$obj->callerujj

my $cgi = new CGI;
print $cgi->AUTOLOAD

# complete class methods
Jifty::DBI::Record->__create
Jifty->
Moose->

# complete built-in function
seekdir splice 


# $self completion
#   my $self
# to 
#   my $self = shift;
my $self

# complete current object methods
sub testtest { }
sub foo1 { }
sub foo2 { }


$self->url

\&fo

# smart object method completion
my $var = new Jifty;
$var->

# smart object method completion 2
my $var3 = Jifty::DBI::Record->new;
$var3->


my $mo = Moose->new;
$mo->


my %hash = ( );
my @array = ( );

%
@


# complete variable
$var1 $var2 $var3 $var_test $var__adfasdf
$var__adfasd  $var1  $var_
$test  $test  $zzz
$zzz

# moose complete

has url => (
    metaclass => 'Labeled',
    is => 'wo'
    label     => "The site's URL",
    isa => 'AFS::Object',
    reader => 'url
    writer => '
);

# role

with 'Restartable' => {
    -alias => {
        stop  => '_stop',
        start => '_start'
    },
    -excludes => [ 'stop', 'start' ],
};

# 'string' , 'string \' escpae'


:AcpEnable

# }}}
