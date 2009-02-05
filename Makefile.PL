use inc::Module::Install;

name     'REA';
all_from 'lib/REA.pm';
author   'Toby Corkindale <tjc@cpan.org>';

requires 'XML::LibXML';
requires 'LWP::UserAgent';
requires 'Class::Accessor';
requires 'parent';
requires 'DBIx::Class';

build_requires 'Test::More';

auto_install;

WriteAll;

