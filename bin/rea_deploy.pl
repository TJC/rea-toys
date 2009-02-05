#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use REA::Storage;

if (not @ARGV or $ARGV[0] =~ /help/i) {
    die("Deploys database manually.\nUsage: rea_deploy.pl dbname\n");
}

my $dbname = shift @ARGV;

system('createdb', '--encoding=utf8', $dbname);

my $schema = REA::Storage->connect("dbi:Pg:dbname=$dbname")
    or die;

$schema->deploy;

print "Successfully deployed to $dbname\n";

1;
