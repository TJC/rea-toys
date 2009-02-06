package REA::Searcher;
use strict;
use warnings;
use KinoSearch::Searcher;
use KinoSearch::Analysis::PolyAnalyzer;
use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw(analyser searcher));

use constant INDEX_LOCATION => '/tmp/rea.index/';

=head1 NAME

REA::Searcher

=head1 SYNOPSIS

Provides support for full-text searching of the indexed properties.

  use REA::Searcher;
  my $index = REA::Searcher->new(
    location => /tmp/index/
  );
  my $hits = $index->find('cheap fitzroy house');
  ... TBD

=head1 FUNCTIONS

=head2 new

Creates a new searcher.

=cut

sub new {
    my ($class, %args) = @_;

    my $location = $args{location} || INDEX_LOCATION;

    my $self = bless {}, $class;

    # Note, this needs to be the same one as used in REA::Indexer
    $self->analyser(
        KinoSearch::Analysis::PolyAnalyzer->new( language => 'en' )
    );

    $self->searcher(
        KinoSearch::Searcher->new(
            analyzer => $self->analyser,
            invindex => $location,
        )
    );

    return $self;
}

=head2 find

Search for something

  my $hits = $index->find(
    query => 'cheap house in brunswick',
    offset => 0,
    rows => 10,
  );

The returned result is an arrayref, like:
  [
    {
      id => 123,
      score => 12.345,
      excerpt => q{blah blah <b>brunswick</b>..}
    },
    ...
  ]

=cut

sub find {
    my ($self, %args) = @_;
    my $offset = $args{offset} || 0;
    my $hits_per_page = $args{rows} || 25;

    my $hits = $self->searcher->search($args{query});
    my $highlighter = KinoSearch::Highlight::Highlighter->new(
        excerpt_field => 'description',
        excerpt_length => 200,
    );

    $hits->create_excerpts( highlighter => $highlighter );

    $hits->seek($offset, $hits_per_page);

    my @results;
    while (my $hit = $hits->fetch_hit_hashref) {
        my %result;
        $result{score} = sprintf('%0.3f', $hit->{score});
        $result{excerpt} = $hit->{excerpt};
        $result{id} = $hit->{id};
        push @results, \%result;
    }

    return \@results;
}


1;
