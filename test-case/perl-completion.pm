package App::SD::Replica::rt::PullEncoder;
use Any::Moose; use strict;
extends 'App::SD::ForeignReplica::PullEncoder';
use strict;
use warnings;

## should complete package name and show 'strict' and 'warnings'
# use 

# (blank) should complete 
#   * package name 
#   * subroutine in current file
#   * perl built-in function
#   * constant
#   * moose subroutines if use Moose found.
#       * has 
#       * extends 
#       * after
#       * before 

# capitalize word should be completed with package names
## MyApp
## AnyEvent::

has sync_source => 
    ( isa => 'App::SD::Replica::rt',
      is => 'rw');

sub ticket_id {
    my $self = shift;
    $ticket->{id};
}

sub translate_ticket_state {
    my $self   = shift;
    my $ticket = shift;
    my $transactions = shift;

    # Ctrl-x Ctrl-
    $self->_recode_attachment_create
    $self->
    $class->translate_ticket_state()
    $ticket->
    Jifty::DBI::Record->


    # Ctrl-x Ctrl-m
    App::CLI::Command->

    # undefine empty fields, we'll delete after cleaning
    $ticket->{$_} = undef for
        grep defined $ticket->{$_} && $ticket->{$_} eq '',
        keys %$ticket;

    $ticket->{'id'} =~ s/^ticket\///g;

    $ticket->{ $self->sync_source->uuid . '-' . lc($_) } = delete $ticket->{$_}
        for qw(Queue id);

    delete $ticket->{'Owner'} if lc($ticket->{'Owner'}) eq 'nobody';
    $ticket->{'Owner'} = $self->resolve_user_id_to( email_address => $ticket->{'Owner'} )
        if $ticket->{'Owner'};

    # normalize names of watchers to variant with suffix 's'
    foreach my $field (qw(Requestor Cc AdminCc)) {
        if ( defined $ticket->{$field} && defined $ticket->{$field .'s'} ) {
            die "It's impossible! Ticket has '$field' and '${field}s'";
        } elsif ( defined $ticket->{$field} ) {
            $ticket->{$field .'s'} = delete $ticket->{$field};
        }
    }

    for my $date (grep defined $ticket->{$_}, qw(Created Resolved Told LastUpdated Due Starts Started)) {
        my $dt = App::SD::Util::string_to_datetime($ticket->{$date});
        if ($dt) {
            $ticket->{$date} =  $dt->ymd('-')." ".$dt->hms(":");
        } else {
            delete $ticket->{$date}
        }
    }

    $ticket->{$_} =~ s/ minutes$//
        for grep defined $ticket->{$_}, qw(TimeWorked TimeLeft TimeEstimated);

    $ticket->{'Status'} =~ $self->translate_status($ticket->{'Status'});

    # delete undefined and empty fields
    delete $ticket->{$_} for
        grep !defined $ticket->{$_} || $ticket->{$_} eq '',
        keys %$ticket;

    return $ticket, {%$ticket};
}

=head2 find_matching_tickets query => QUERY

Returns an RT::Client ticket collection for all tickets found matching your QUERY string.

=cut

sub find_matching_tickets {
    my $self = shift;
    my %args = validate(@_,{query => 1});
    my $query = $args{query};
    # If we've ever synced, we can limit our search to only newer things
    if ( my $before = $self->_only_pull_tickets_modified_after ) {
       $query = "($query) AND LastUpdated >= '" . $before->ymd('-') . " " . $before->hms(':') . "'";
        $self->sync_source->log( "Skipping all tickets not updated since " . $before->iso8601 );
    }
    return [map {
        my $hash = $self->sync_source->rt->show( type => 'ticket', id => $_ );
        $hash->{id} =~ s|^ticket/||g;
        $hash
    } $self->sync_source->rt->search( type => 'ticket', query => $query )];
}


=head2 find_matching_transactions { ticket => $id, starting_transaction => $num }

Returns a reference to an array of all transactions (as hashes) on ticket $id after transaction $num.

=cut

sub find_matching_transactions {
    my $self = shift;
    my %args = validate( @_, { ticket => 1, starting_transaction => 1 } );
    my @txns;

    my $rt_handle = $self->sync_source->rt;

    my $ticket_id = $self->ticket_id( $args{ticket} );

    my $latest = $self->sync_source->app_handle->handle->last_changeset_from_source(
        $self->sync_source->uuid_for_remote_id($ticket_id) ) || 0;

    for my $txn ( sort $rt_handle->get_transaction_ids( parent_id => $ticket_id ) ) {

        # Skip things calling code told us to skip
        next if $txn < $args{'starting_transaction'};

        # skip things we had on our last pull
        next if $txn <= $latest;

        # Skip things we've pushed
        next if $self->sync_source->foreign_transaction_originated_locally( $txn, $ticket_id );
        my $txn_hash = $rt_handle->get_transaction( parent_id => $ticket_id, id => $txn, type => 'ticket' );
        if ( my $attachments = delete $txn_hash->{'Attachments'} ) {
            for my $attach ( split( /\n/, $attachments ) ) {
                next unless ( $attach =~ /^(\d+):/ );
                my $id = $1;
                my $a = $rt_handle->get_attachment( parent_id => $ticket_id, id => $id );

                push( @{ $txn_hash->{_attachments} }, $a ) if ( $a->{Filename} );

            }

        }
        push @txns,
            {
            timestamp => App::SD::Util::string_to_datetime( $txn_hash->{Created} ),
            serial    => $txn_hash->{id},
            object    => $txn_hash
            };
    }
    return \@txns;
}

sub transcode_one_txn {
    my ($self, $txn_wrapper, $ticket_initial_state, $ticket) = (@_);
   
    my $txn = $txn_wrapper->{object};

    my $sub = $self->can( '_recode_txn_' . $txn->{'Type'} );
    unless ( $sub ) {
        die "Transaction type $txn->{Type} (for transaction $txn->{id}) not implemented yet";
    }
    my $changeset = Prophet::ChangeSet->new(
        {   original_source_uuid => $self->sync_source->uuid_for_remote_id( $ticket->{ $self->sync_source->uuid . '-id' } ),
            original_sequence_no => $txn->{'id'},
            created =>  $txn->{'Created'},
            creator => $self->resolve_user_id_to( email_address => $txn->{'Creator'} ),
        }
    );

    if ( $txn->{'Ticket'} ne $ticket->{$self->sync_source->uuid . '-id'}
        && $txn->{'Type'} !~ /^(?:Comment|Correspond)$/
    ) {
        warn "Skipping a data change from a merged ticket" . $txn->{'Ticket'} .' vs '. $ticket->{$self->sync_source->uuid . '-id'};
        next;
    }

    delete $txn->{'OldValue'} if ( $txn->{'OldValue'} eq '');
    delete $txn->{'NewValue'} if ( $txn->{'NewValue'} eq '');

    $sub->( $self, ticket => $ticket, txn          => $txn, changeset    => $changeset);
    $self->translate_prop_names($changeset);

    if (my $attachments = delete $txn->{'_attachments'}) {
       for my $attach (@$attachments) { 
            $self->_recode_attachment_create( ticket => $ticket, txn => $txn, changeset =>$changeset, attachment => $attach); 
       }
    }

    return $changeset;
}


{ # Recoding RT transactions

sub _recode_attachment_create {
    my $self   = shift;
    my %args   = validate( @_, { ticket => 1, txn => 1, changeset => 1, attachment => 1 } );
    my $change = Prophet::Change->new(
        {   record_type => 'attachment',
            record_uuid => $self->sync_source->uuid_for_url( $self->sync_source->remote_url . "/attachment/" . $args{'attachment'}->{'id'} ),
            change_type => 'add_file'
        }
    );
    $change->add_prop_change( name => 'content_type', old  => undef, new  => $args{'attachment'}->{'ContentType'});
    $change->add_prop_change( name => 'created', old  => undef, new  => $args{'txn'}->{'Created'} );
    $change->add_prop_change( name => 'creator', old  => undef, new  => $self->resolve_user_id_to( email_address => $args{'attachment'}->{'Creator'}));
    $change->add_prop_change( name => 'content', old  => undef, new  => $args{'attachment'}->{'Content'});
    $change->add_prop_change( name => 'name', old  => undef, new  => $args{'attachment'}->{'Filename'});
    $change->add_prop_change( name => 'ticket', old  => undef, new  => $self->sync_source->uuid_for_remote_id( $args{'ticket'}->{ $self->sync_source->uuid . '-id'} ));
    $args{'changeset'}->add_change( { change => $change } );
}

sub _recode_txn_Keyword {} # RT 2 - unused
sub _recode_txn_CommentEmailRecord { return; }

sub _recode_txn_EmailRecord     { return; }
sub _recode_txn_AddReminder     { return; }
sub _recode_txn_ResolveReminder { return; }
sub _recode_txn_DeleteLink      { }

sub _recode_txn_Status {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );

    $args{txn}->{'Type'} = 'Set';
    return $self->_recode_txn_Set(%args);
}

sub _recode_txn_Told {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );
    $args{txn}->{'Type'} = 'Set';
    return $self->_recode_txn_Set(%args);
}

sub _recode_txn_Set {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );

    my $change = Prophet::Change->new(
        {   record_type => 'ticket',
            record_uuid => $self->sync_source->uuid_for_remote_id( $args{'ticket'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'update_file'
        }
    );

    my ($field, $old, $new) = @{ $args{txn} }{qw(Field OldValue NewValue)};

    if ( $field eq 'Queue' ) {
        my $current_queue = $args{'ticket'}->{$self->sync_source->uuid .'-queue'};
        my $user          = $args{txn}->{Creator};
        if ( $args{txn}->{Description} =~ /Queue changed from (.*) to $current_queue by $user/ ) {
            $old = $1;
            $new = $current_queue;
        }
    } elsif ( $field eq 'Status' ) {
        $new = $self->translate_status($new);
        $old = $self->translate_status($old); 

    } elsif ( $field eq 'Owner' ) {
        $new = $self->resolve_user_id_to( email_address => $new );
        $old = $self->resolve_user_id_to( email_address => $old );
    }

    $args{'changeset'}->add_change( { change => $change } );
    
    # XXX: This line is kind of magic
    # TODO: check if it's sill needed
    $args{'ticket'}->{ $field } = $old;

    $change->add_prop_change( name => $field, old => $old, new => $new );
}

*_recode_txn_Steal = \&_recode_txn_Set;
*_recode_txn_Take  = \&_recode_txn_Set;
*_recode_txn_Give  = \&_recode_txn_Set;

sub _recode_txn_Create {
    my $self = shift;
    my %args = validate( @_, {  txn => 1, ticket => 1, changeset => 1 } );

    my $change = Prophet::Change->new( {
        record_type => 'ticket',
        record_uuid => $self->sync_source->uuid_for_remote_id(
            $args{'ticket'}->{$self->sync_source->uuid . '-id'}
        ),
        change_type => 'add_file'
    } );

    $args{'changeset'}->add_change( { change => $change } );
    for my $name ( keys %{ $args{'ticket'} } ) {
        $change->add_prop_change(
            name => $name,
            old  => undef,
            new  => $args{'ticket'}->{$name},
        );
    }

    $self->_recode_content_update(%args);    # add the create content txn as a seperate change in this changeset
}

*_recode_txn_Link  = \&_recode_txn_AddLink;
sub _recode_txn_AddLink {
    # XXX, TODO: syncing links doesn't work
    return;

    my $self      = shift;
    my %args      = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );
    my $new_state = $args{'ticket'}->{ $args{'txn'}->{'Field'} };
    $args{'ticket'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'ticket'}->{ $args{'txn'}->{'Field'} },
        $args{'txn'}->{'NewValue'},
        $args{'txn'}->{'OldValue'}
    );

    my $change = Prophet::Change->new( {
        record_type => 'ticket',
        record_uuid => $self->sync_source->uuid_for_remote_id(
            $args{'ticket'}->{$self->sync_source->uuid . '-id'}
        ),
        change_type => 'update_file',
    } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'ticket'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );
    $args{'changeset'}->add_change( { change => $change } );
}

sub _recode_content_update {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );
    my $url = $self->sync_source->remote_url . "/transaction/" . $args{'txn'}->{'id'};
    my $change = Prophet::Change->new( {
        record_type => 'comment',
        record_uuid => $self->sync_source->uuid_for_url( $url ),
        change_type => 'add_file',
    } );

    $change->add_prop_change( name => 'created', new  => $args{'txn'}->{'Created'});
    $change->add_prop_change( name => 'type',    new  => $args{'txn'}->{'Type'});
    $change->add_prop_change( name => 'creator', new  => $self->resolve_user_id_to(
        email_address => $args{'txn'}->{'Creator'}
    ) );
    $change->add_prop_change( name => 'content', new  => $args{'txn'}->{'Content'});
    $change->add_prop_change( name => 'ticket',  new  => $self->sync_source->uuid_for_remote_id(
        $args{'ticket'}->{ $self->sync_source->uuid . '-id'}
    ) );
    $args{'changeset'}->add_change( { change => $change } );
}

*_recode_txn_Comment    = \&_recode_content_update;
*_recode_txn_Correspond = \&_recode_content_update;

sub _recode_txn_AddWatcher {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );

    my $type = $args{'txn'}->{'Field'};

    my $new_state = $args{'ticket'}->{ $type .'s' };
    $args{'ticket'}->{ $type .'s' } = $self->warp_list_to_old_value(
        $new_state,
        $self->resolve_user_id_to( email_address => $args{'txn'}->{'NewValue'} ),
        $self->resolve_user_id_to( email_address => $args{'txn'}->{'OldValue'} )
    );

    my $change = Prophet::Change->new({
        record_type   => 'ticket',
        record_uuid   => $self->sync_source->uuid_for_remote_id(
            $args{'ticket'}->{$self->sync_source->uuid . '-id'}
        ),
        change_type => 'update_file'
    } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'ticket'}->{ $args{'txn'}->{'Field'} .'s' },
        new  => $new_state
    );
    $args{'changeset'}->add_change( { change => $change } );
}

*_recode_txn_DelWatcher = \&_recode_txn_AddWatcher;

sub _recode_txn_CustomField {
    my $self = shift;
    my %args = validate( @_, { txn => 1, ticket => 1, changeset => 1 } );

    my $new = $args{'txn'}->{'NewValue'};
    my $old = $args{'txn'}->{'OldValue'};
    my $name;
    if ( $args{'txn'}->{'Description'} =~ /^(.*) $new added by/ ) {
        $name = $1;
    }
    elsif ( $args{'txn'}->{'Description'} =~ /^(.*) changed to $new by/ ) {
        $name = $1;

    } elsif ( $args{'txn'}->{'Description'} =~ /^(.*) $old deleted by/ ) {
        $name = $1;
    } else {
        die "Unknown transaction description " . $args{'txn'}->{'Description'};
    }

    $args{'txn'}->{'Field'} = "CF-" . $name;

    my $new_state = $args{'ticket'}->{ $args{'txn'}->{'Field'} };
    $args{'ticket'}->{ $args{'txn'}->{'Field'} } = $self->warp_list_to_old_value(
        $args{'ticket'}->{ $args{'txn'}->{'Field'} },
        $args{'txn'}->{'NewValue'},
        $args{'txn'}->{'OldValue'}
    );

    my $change = Prophet::Change->new(
        {   record_type   => 'ticket',
            record_uuid   => $self->sync_source->uuid_for_remote_id( $args{'ticket'}->{$self->sync_source->uuid . '-id'} ),
            change_type => 'update_file'
        }
    );

    $args{'changeset'}->add_change( { change => $change } );
    $change->add_prop_change(
        name => $args{'txn'}->{'Field'},
        old  => $args{'ticket'}->{ $args{'txn'}->{'Field'} },
        new  => $new_state
    );
}

}


sub resolve_user_id_to {
    my $self = shift;
    my $attr = shift;
    my $id   = shift;
    return undef unless $id;

    local $@;
    my $user = eval { RT::Client::REST::User->new( rt => $self->sync_source->rt, id => $id )->retrieve};
    if ( my $err = $@ ) {
        warn $err;
        return $attr eq 'name' ? 'Unknown user' : 'unknown@localhost';
    }
    my $name = $user->name;
    if ( lc $name eq 'nobody' ) {
        return $attr eq 'name' ? 'nobody' : undef;
    }
    elsif ( lc $name eq 'RT_System' ) {
        return $attr eq 'name' ? 'system' : undef;
    } else {
        return $user->$attr();
    }
}

memoize 'resolve_user_id_to';

our %PROP_MAP = (
    subject         => 'summary',
    status          => 'status',
    owner           => 'owner',
    initialpriority => '_delete',
    finalpriority   => '_delete',
    told            => '_delete',
    requestor       => 'reporter',
    requestors      => 'reporter',
    cc              => 'cc',
    ccs             => 'cc',
    admincc         => 'admin_cc',
    adminccs        => 'admin_cc',
    refersto        => 'refers_to',
    referredtoby    => 'referred_to_by',
    dependson       => 'depends_on',
    dependedonby    => 'depended_on_by',
    hasmember       => 'members',
    memberof        => 'member_of',
    priority        => 'priority_integer',
    resolved        => 'completed',
    due             => 'due',
    creator         => 'creator',
    timeworked      => 'time_worked',
    timeleft        => 'time_left',
    timeestimated   => 'time_estimated',
    lastupdated     => '_delete',
    created         => 'created',
    queue           => 'queue',
    starts          => '_delete',
    started         => '_delete',
);

sub translate_status {
    my $self = shift;
    my $status = shift;

    $status =~ s/^resolved$/closed/;
    

    return $status;
}

sub translate_prop_names {
    my $self      = shift;
    my $changeset = shift;

    for my $change ( $changeset->changes ) {
        next unless $change->record_type eq 'ticket';

        my @new_props;
        for my $prop ( $change->prop_changes ) {
            next if ( ( $PROP_MAP{ lc( $prop->name ) } || '' ) eq '_delete' );
            $prop->name( $PROP_MAP{ lc( $prop->name ) } ) if $PROP_MAP{ lc( $prop->name ) };
            # Normalize away undef -> "" and vice-versa
            for (qw/new_value old_value/) {
                $prop->$_("") if !defined ($prop->$_());
                }
            next if ( $prop->old_value eq $prop->new_value);

            if ( $prop->name =~ /^cf-(.*)$/ ) {
                $prop->name( 'custom-' . $1 );
            }

            push @new_props, $prop;

        }
        $change->prop_changes( \@new_props );

    }
    return $changeset;
}

__PACKAGE__->meta->make_immutable;
no Any::Moose;
1;
