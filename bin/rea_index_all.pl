#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use REA::Storage;
use REA::Indexer;
use Getopt::Long;
use Pod::Usage;

my ($dbname);
$dbname = 'rea'; # Default DB name.
GetOptions(
    'db=s' => \$dbname,
);

my $storage = REA::Storage->connect(
    "dbi:Pg:dbname=$dbname", undef, undef,
    { pg_enable_utf8 => 1 }
) or die;

my $indexer = REA::Indexer->new( create => 1 );

my $rs = $storage->resultset('Properties')->search; # everything!
while (my $prop = $rs->next) {
    $indexer->add($prop);
}
$indexer->finalise;

1;

__END__

=head1 NAME

rea_index_all

=head1 USAGE

rea_index_all.pl --db=rea

This will index all properties currently in the DB.

=cut

