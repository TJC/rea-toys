#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use REA::Storage;
use REA::Scraper;
use Getopt::Long;
use Pod::Usage;

my ($postcode, $suburb, $price_min, $price_max, $proptype, $dbname);
$dbname = 'rea'; # Default DB name.
GetOptions(
    'postcode=i' => \$postcode,
    'suburb=s' => \$suburb,
    'price_min=i' => \$price_min,
    'price_max=i' => \$price_max,
    'proptype=s' => \$proptype,
    'db=s' => \$dbname,
);
pod2usage({ verbose => 2}) unless ($postcode or $suburb);

my $storage = REA::Storage->connect("dbi:Pg:dbname=$dbname") or die;

my $scraper = REA::Scraper->new( storage => $storage );

if ($postcode) {
    $scraper->postcode($postcode);
} elsif ($suburb) {
    $scraper->suburb($suburb);
}

# rest aren't supported yet..
my $c = $scraper->scrape;
print "Scraped $c properties..\n";

1;

__END__

=head1 NAME

rea_scraper

=head1 USAGE

rea_scraper.pl
    --postcode=3121 | --suburb=Richmond
    --price_min=250000
    --price_max=400000
    (--db=rea)

Should dump a lot of info into the database for those props..

=cut
