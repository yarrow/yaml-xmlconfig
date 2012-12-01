package YAML::XMLConfig::Shibboleth::IDP;
use warnings;
use strict;

use YAML::XMLConfig;
use File::Spec;
use File::Slurp;
use Carp;

my %default = (
  defaults => "idp-defaults.yaml",
  filter_yaml => "filter.yaml",
  filter_xml => "attribute-filter.xml",
  resolver_yaml => "resolver.yaml",
  resolver_xml => "attribute-resolver.xml",
);
sub make_attribute_conf {
  my ($classs, $opt) = @_;

  my %opt = %$opt;
  my $config_dir = delete $opt{config_dir}
    or croak "config_dir is a required option";
  YAML::XMLConfig->fill_defaults(\%opt, \%default);
  $_ = File::Spec->catfile($config_dir, $_) for values %opt;

  my $weaver = YAML::XMLConfig->weaver($opt{defaults});

  my $filter = $weaver->read_config($opt{filter_yaml});
  my $resolver = $weaver->read_config($opt{resolver_yaml});

  my %resolved = attributes($resolver, qw(resolver:AttributeDefinition id));
  my %filtered = attributes($filter, qw(AttributeRule attributeID));
  my @undefined = grep { ! $resolved{$_} } keys %filtered;
  if (@undefined) {
    my $s = @undefined == 1 ? "" : "s";
    die "Attribute$s used in $opt{filter_yaml} but not defined in $opt{resolver_yaml}: @undefined\n";
  }

  write_file($opt{filter_xml}, $weaver->xml($filter));
  write_file($opt{resolver_xml}, $weaver->xml($resolver));

  return 1;
}

my ($e, @elements);
sub attributes {
  my ($item, $element, $attribute) = @_;
  ($e, @elements) = ($element);
  find_elements($item);
  my %count;
  foreach (@elements) {
    ref $_ eq "HASH" or next;
    defined(my $attr = $$_{$attribute}) or next;
    $count{$attr}++;
  }
  return %count;
}
sub find_elements {
  my ($item) = @_;
  if (ref $item eq "ARRAY") {
    find_elements($_) for @$item;
  }
  elsif (ref $item eq "HASH") {
    my $elt = $$item{$e};
    if (ref $elt eq "HASH") { push @elements, $elt }
    elsif (ref $elt eq "ARRAY") { push @elements, @$elt }
    find_elements($_) for values %$item;
  }
  return;
}
1;

