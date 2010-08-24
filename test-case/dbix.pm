package DBIC::Result::User;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

DBIC::Result::User

=cut

__PACKAGE__->table("users");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 1
  size: 24

=head2 authtoken

  data_type: 'varchar'
  is_nullable: 1
  size: 64

=head2 email

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 address

  data_type: 'varchar'
  is_nullable: 1
  size: 128

=head2 firstname

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 lastname

  data_type: 'varchar'
  is_nullable: 1
  size: 32

=head2 role

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 1, size => 24 },
  "authtoken",
  { data_type => "varchar", is_nullable => 1, size => 64 },
  "email",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "address",
  { data_type => "varchar", is_nullable => 1, size => 128 },
  "firstname",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "lastname",
  { data_type => "varchar", is_nullable => 1, size => 32 },
  "role",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->add_unique_constraint("username", ["username"]);


# Created by DBIx::Class::Schema::Loader v0.07001 @ 2010-08-16 15:36:45
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Agox+3KY/uw2sJ6WnVbabQ

# You can replace this text with custom content, and it will be preserved on regeneration

__PACKAGE__->has_many( 'user_groups' => 'DBIC::Result::Usergroup' , 'userid' );   # accessor name , classs , 'self reference column':
                                                                                 #    use 'userid' to find group relation items in Usergroup class.
__PACKAGE__->many_to_many( 'groups' => 'user_groups' , 'groupid' );               # find 'groups' in 'usergroups' select groups by 'groupid'


# Make sure result class name will be completed.
# $schema->resultset("


# TODO: mark $rs as resultset class "User"
my $rs = $schema->resultset("User");

# TODO:
$schema->resultset("User")->...

# TODO: complete resultset class methods:
$rs->...


1;
