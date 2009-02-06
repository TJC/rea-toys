#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use feature ':5.10';
use lib "$FindBin::Bin/../lib";
use REA::Storage;
use REA::Searcher;
use Getopt::Long;
use Pod::Usage;

my ($dbname);
$dbname = 'rea'; # Default DB name.
GetOptions(
    'db=s' => \$dbname,
);
my $query = join(' ', @ARGV);
warn "Searching for: $query\n";

my $storage = REA::Storage->connect("dbi:Pg:dbname=$dbname") or die;

my $searcher = REA::Searcher->new;
my $results = $searcher->find( query => $query );

for my $hit (@$results) {
    my $prop = $storage->resultset('Properties')->find($hit->{id});

    say "Property: " . $hit->{id};
    say "Title: " . $prop->title;
    say "Address: " . $prop->address . ' ' . $prop->suburb;
    say "Desc: " . $hit->{excerpt};
    print "\n\n";
}


1;

__END__

=head1 NAME

rea_search

=head1 USAGE

rea_search.pl --db=rea "miller street"

This does a basic search for properties matching the search query.

=cut

