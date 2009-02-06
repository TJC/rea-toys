package REA::Indexer;
use strict;
use warnings;
use KinoSearch::InvIndexer;
use KinoSearch::Analysis::PolyAnalyzer;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(analyser indexer));

use constant INDEX_LOCATION => '/tmp/rea.index/';

=head1 NAME

REA::Indexer

=head1 SYNOPSIS

Provides support for indexing and full-text searching of the stored properties.

  use REA::Indexer;
  my $index = REA::Indexer->new;
  for (my @props) {
      $index->add($_);
  }

=head1 FUNCTIONS

=head2 new

Creates a new index.

WARNING - Currently this will wipe out the existing index..

TODO: Need to put some logic in to not do this if it already exists?

=cut

sub new {
    my ($class, %args) = @_;

    my $location = $args{location} || INDEX_LOCATION;
    my $create = 0;

    if ($args{create}) {
        warn "Creating new index";
        mkdir($location) unless (-d $location);
        $create = 1;
    }

    my $self = bless {}, $class;

    $self->analyser(
        KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' )
    );

    $self->indexer(
        KinoSearch::InvIndexer->new(
            analyzer => $self->analyser,
            invindex => $location,
            create => $create,
        )
    );

    for my $name (qw(suburb postcode)) {
        $self->indexer->spec_field( name => $name, boost => 3 );
    }
    $self->indexer->spec_field( name => 'address', boost => 2 );
    for my $name (qw(price title description proptype)) {
        $self->indexer->spec_field( name => $name );
    }
    $self->indexer->spec_field( name => 'id', indexed => 0 );

    return $self;
}

=head2 add

Adds a new item to the index.

=cut

sub add {
    my ($self, $item) = @_;

    my $doc = $self->indexer->new_doc;

    for my $column (qw(
        id postcode suburb price title address description proptype
    )) {
        $doc->set_value( $column => $item->$column );
    }

    $self->indexer->add_doc($doc);
}

=head2 finalise

Finalises (optimises?) the index.

Must be called after you've added or updated items.

=cut

sub finalise {
    my $self = shift;
    $self->indexer->finish( optimize => 1 );
}

1;
