package REA::Storage::Properties;
use strict;
use warnings;
use Carp qw(carp croak);
use parent 'DBIx::Class';

__PACKAGE__->load_components(qw(InflateColumn::DateTime Core));
__PACKAGE__->table("properties");
__PACKAGE__->add_columns(
    # Note that id is NOT auto incrementing..
    id => { data_type => "INTEGER", is_nullable => 0, is_auto_increment => 0 },
    postcode => { data_type => 'INTEGER', is_nullable => 1 },
    suburb => { data_type => 'VARCHAR', size => 64, is_nullable => 0 },
    price => { data_type => 'VARCHAR', size => 64, is_nullable => 1 },
    title => { data_type => 'VARCHAR', size => 128, is_nullable => 0 },
    address => { data_type => 'VARCHAR', size => 96, is_nullable => 1 },
    description => { data_type => 'TEXT', is_nullable => 1 },
    photo => { data_type => 'VARCHAR', size => 256, is_nullable => 1 },
    url => { data_type => 'VARCHAR', size => 256, is_nullable => 1 },
    proptype => { data_type => 'VARCHAR', size => 16, is_nullable => 0 },
    created => { data_type => 'TIMESTAMP', is_nullable => 0,
                     default_value => \'CURRENT_TIMESTAMP'
                   },
);

__PACKAGE__->set_primary_key("id");

sub sqlt_deploy_hook {
    my ($self, $table) = @_;
    $table->add_index(
        name => 'properties_postcode_idx',
        fields => ['postcode'],
    );
    $table->add_index(
        name => 'properties_suburb_idx',
        fields => ['suburb'],
    );
}

1;
