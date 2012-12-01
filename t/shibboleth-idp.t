#!/usr/bin/env perl
use warnings;
use strict;
use Test::Most;
use File::Slurp;
use YAML::XS;
use XML::Simple;
use XML::SemanticDiff;

BEGIN { use_ok('YAML::XMLConfig::Shibboleth::IDP') }

my $why;
sub because { chomp($why = join(' ', @_)); $why =~ s/\s*\n\s*/ /g }

=head1 NAME

YAML::XMLConfig::Shibboleth::IDP - Create Shib IPD attribute config XML files

=head1 SYNOPSIS

  use YAML::XMLConfig::Shibboleth::IDP;
  YAML::XMLConfig::Shibboleth::IDP->make_attribute_conf({
      config_dir => "/opt/shibboleth-idp",
  }

or

  YAML::XMLConfig::Shibboleth::IDP->make_attribute_conf({
      config_dir => "/opt/shibboleth-idp",
      defaults => "idp-defaults.yaml",
      filter_yaml => "filter.yaml",
      filter_xml => "attribute-filter.xml",
      resolver_yaml => "resolver.yaml",
      resolver_xml => "attribute-resolver.xml",
  });

(The second version gives the default values.)

=cut

=head1 METHODS

=head2 make_attribute_conf

Creates C<attribute-filter.xml> and C<attribute-resolver.xml>.

Dies if the generated C<attribute-filter.xml> would try to grant an attribute
not defined in the generated C<attribute-resolver.xml>.

Details: for each C<attributeID> value of an C<AttributeRule> in the filter
XML, the resolver XML must containt a C<resolver:AttributeDefinition> whose
C<id> attribute has that value.

When using the supplied macro file, neither the C<attributeID> and C<id> names
need not be explicitly mentioned in the YAML, which will probably look like
this for the filter:

  - PolicyRequirementRule: https://service1.internet2.edu/shibboleth
    AttributeRule:
    - eduPersonAffiliation
    - eduPersonEntitlement
    - eduPersonTargetedID

or if there is only a single C<AttributeRule>, like this:

  - PolicyRequirementRule: https://service1.internet2.edu/shibboleth
    AttributeRule: eduPersonAffiliation

while the resolver YAML for the C<eduPersonAffiliation> attribute looks like:

  resolver:AttributeDefinition:
  ... lots of other AttributeDefinitions...
  - $: eduPersonAffiliation
    xsi:type: Simple
    resolver:AttributeEncoder:
    - name: urn:mace:dir:attribute-def:eduPersonAffiliation
      xsi:type: SAML1String
    - friendlyName: eduPersonAffiliation
      name: urn:oid:1.3.6.1.4.1.5923.1.1.1.1
      xsi:type: SAML2String

=cut

because <<'/';
make_attribute_conf creates attribute-filter.xml and attribute-resolver.xml
/

my $ok = YAML::XMLConfig::Shibboleth::IDP->make_attribute_conf({
    config_dir => "t/data",
});
ok($ok, $why);

my $diff = XML::SemanticDiff->new();
sub compare {
  my ($type) = @_;
  my @files = map { "t/data/${_}attribute-$type.xml"} ("expected-", "");
  return [$diff->compare(@files)];
}

eq_or_diff(compare("filter"), [], "attribute-filter");
eq_or_diff(compare("resolver"), [], "attribute-resolver");

because <<'/';
make_attribute_conf dies if the filter YAML grants an attribute not defined
in the resolver YAML
/
eval {
  YAML::XMLConfig::Shibboleth::IDP->make_attribute_conf({
    config_dir => "t/data",
    filter_yaml => "filter-extra.yaml"
  });
};
like($@, qr/eduPersonBwaHaHa/, $why);
eq_or_diff(compare("filter"), [], "...and doesn't write the XML files");

done_testing;
write_file("lib/YAML/XMLConfig/Shibboleth/IDP.pod", read_file($0))
  if Test::Builder::Module->builder->is_passing;
