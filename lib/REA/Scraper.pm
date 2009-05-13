package REA::Scraper;
use warnings;
use strict;
use feature ':5.10';
use HTML::TreeBuilder::XPath;
use LWP::UserAgent;
use File::Slurp qw(slurp);
use Carp qw(croak carp);
use Encode;
use base 'Class::Accessor';
__PACKAGE__->mk_accessors(qw(storage _response));

use constant BASE_URL => 'http://www.realestate.com.au/cgi-bin/rsearch';

=head1 NAME

REA::Scraper

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

REA::Scraper will go to the realestate.com.au website and find properties
matching your request, and then store them locally.

    use REA::Scraper;
    use REA::Storage;

    my $storage = REA::Storage->new;

    my $scraper = REA::Scraper->new(
        storage => $storage
    );
    $scraper->postcode(3071);
    $scraper->price_max(400000);
    $scraper->price_min(250000);
    $scraper->scrape;

    $scraper->postcode(5063);
    $scraper->scrape;

=head1 FUNCTIONS

=head2 new

The constructor. Takes a hash of arguments:
 * storage - mandatory, the ORM. REA::Storage or a superclass of it.

=cut

sub new {
    my ($class, %args) = @_;
    croak("Storage is mandatory!") unless $args{storage};

    my $self = bless {}, $class;
    $self->storage($args{storage});

    # Set default parameters to call out to rsearch with:
    $self->{_params} = {
        a => 'qfp', # Indicates quick search
        cu => 'fn-rea', # realestate.com.au site, not partner
        t => 'res', # Residential homes for sale
        q => 'Go',  # Indicates quick-search
        o => 'd',   # Order by newest first
        p =>  100,   # Number of items per page
    };
    $self->{_globals} = {
        proptype => 'residential',
    };

    return $self;
}

=head2 limit

Set the maximum number of properties to fetch.

=cut

sub limit {
    my ($self, $n) = @_;
    $self->{_params}->{p} = $n;
}

=head2 postcode

Sets the postcode of the area to search. Mutually exclusive with suburb().

=cut

sub postcode {
    my ($self, $code) = @_;
    die("Invalid postcode: $code") unless $code =~ /^(\d+)$/;
    $self->{_params}->{id} = $1;
    $self->{_globals}->{postcode} = $1;
}

=head2 suburb

Sets the suburb of the area to search. Mutually exclusive with postcode().

=cut

sub suburb {
    my ($self, $burb) = @_;
    die("Invalid suburb: $burb") unless $burb =~ /^([\w ]+)$/;
    warn("Sorry, suburb searches don't appear to be working yet..\n");

    $self->{_params}->{id} = uc($1);
    $self->{_globals}->{suburb} = uc($1);
}

=head2 proptype

Sets the property type - 'residential' or 'rental' are current valid options.

=cut

{
    my %proptype_to_param = (
        'residential' => 'res',
        'rental' => 'ren',
    );

    sub proptype {
        my ($self, $proptype) = @_;
        unless (exists $proptype_to_param{$proptype}) {
            die("Invalid property type: $proptype");
        }

        $self->{_params}->{t} = $proptype_to_param{$proptype};
        $self->{_globals}->{proptype} = $proptype;
    }
}

=head2 price_min

Set minimum price, in whole dollars.

=cut

sub price_min {
    my ($self, $price) = @_;
    die("price_min() not yet supported.");
}


=head2 price_max

Set maximum price, in whole dollars.

=cut

sub price_max {
    my ($self, $price) = @_;
    die("price_max() not yet supported.");
}



=head2 scrape

Goes off and does the scraping!

You can call this again and again after changing the other parameters, and
it'll go off and get the new data.

=cut

sub scrape {
    my $self = shift;
    $self->_response('');

    my $url = $self->_make_search_url;
    warn "Scraping from $url\n";
    $self->_get_content($url);
    my $results = $self->_parse_html;

    $self->storage->update_results($self->{_globals}, $results);

    return scalar(@$results);
}

=head1 INTERNAL FUNCTIONS

The following functions are for internal use only!

=cut

=head2 _parse_html

Parse the returned HTML and then scrape results from it..

=cut

sub _parse_html {
    my ($self) = @_;

    my $doc = HTML::TreeBuilder::XPath->new;
    eval {
        $doc->parse_content( $self->_response );
    };
    if ($@) {
        die "Failed to parse HTML, errors were: $@\n";
    }

    my $results = $self->_locate_results($doc);
    $doc->delete; # Apparently important to call for HTML::TreeBuilder
    return $results;
}

=head2 _locate_results

Locate the properties within the returned XHTML.

=cut

sub _locate_results {
    my ($self, $root) = @_;
    my @results;
    my @nodes = $root->findnodes(
        '//div[@class="propOverview"]'
        . ' | '
        . '//div[@class="propOverview featureProperty"]'
    );
    foreach my $node (@nodes) {
        my %data;
        $data{suburb} = $node->findvalue('div[@class="header"]/h2');
        $data{price} = $node->findvalue('div[@class="header"]/h3');
        $data{title} = $node->findvalue('div[@class="content"]/h4/a');
        $data{address} = $node->findvalue('div[@class="content"]/h5');
        $data{description} = $node->findvalue('div[@class="content"]/p');
        $data{photo} = $node->findvalue('div[@class="content"]/a[@class="photo"]/img/@src');
        $data{url} = $node->findvalue('div[@class="content"]/a[@class="moreInfo"]/@href');
        # Figure out the rea id:
        ($data{id}) = $data{url} =~ /[^a-zA-Z0-9]id=(\d+)/;

        for my $key (qw(suburb price title address description)) {
            $data{$key} =~ s/[\n\r]+/ /g;
            $data{$key} =~ s/\s{2,}/ /g;
            $data{$key} =~ s/^\s+//;
            $data{$key} =~ s/\s+$//;
        }
        push @results, \%data;
    }
    return \@results;
}


=head2 _get_content

Retrieves the HTML from the realestate.com.au server.

TODO: Implement local caching?

=cut

sub _get_content {
    my ($self, $url) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30);
    $ua->env_proxy;
    $ua->agent('Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10.5; en-US; rv:1.9.0.5) Gecko/2008120121 Firefox/3.0.5');

    my $response = $ua->get($url);
    if (not $response->is_success) {
        die("Failed to get REA content: " . $response->status_line . "\n");
    }
    warn "Response size: " . length($response->content) . "\n";
    my $content = decode('UTF-8', $response->content, Encode::FB_XMLCREF);
    $self->_response($content);
}

=head2 _make_search_url

Builds the appropriate GET URL up from the current settings.

TODO: Should really replace this with HTTP::Request!

=cut

sub _make_search_url {
    my $self = shift;

    my @params;
    while (my ($key, $val) = each %{$self->{_params}}) {
        push(@params, "$key=$val");
    }
    return BASE_URL . '?' . join(';', @params);
}


=head1 AUTHOR

Toby Corkindale, C<< <tjc at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-rea at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=REA>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc REA

You can also look for information at: http://dryft.net/rea/

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=REA>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/REA>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/REA>

=item * Search CPAN

L<http://search.cpan.org/dist/REA>

=back

=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2009 Toby Corkindale, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1;
