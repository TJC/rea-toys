package REA::Storage;
use strict;
use warnings;
use parent 'DBIx::Class::Schema';

__PACKAGE__->load_classes;

=head2 update_results

Accepts an array-ref of hashes, and stores them into the database.

  $storage->update_results(
    {
      type => 'residential',
      postcode => '3121'
    },
    [
      { .. },
      { .. },
    ]
  );

=cut

sub update_results {
    my ($self, $globals, $results) = @_;

    for my $prop (@$results) {
        my ($id) = $prop->{id} =~ /(\d+)/;
        next unless $id;
        $prop->{id} = $id; # cleanse that ID! ;)
        my $obj = $self->resultset('Properties')->update_or_create(
            {
                %$prop,
                %$globals
            }
        );
    }
}

1;
