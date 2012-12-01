#!/usr/bin/env perl
use warnings;
use strict;
use YAML::XS;
use Test::Most;
use XML::Simple;

my $data = "t/data";
my $defaults = "$data/idp-defaults.yaml";
my $filter_yaml = "$data/filter.yaml";

my $filter = Load <<'/'; 
---
AttributeFilterPolicyGroup:
  AttributeFilterPolicy:
  - PolicyRequirementRule: https://service1.internet2.edu/shibboleth
    AttributeRule:
    - attributeID: eduPersonAffiliation
      PermitValueRule:
        xsi:type: basic:ANY
    - attributeID: eduPersonEntitlement
      PermitValueRule:
        xsi:type: basic:ANY
    - attributeID: eduPersonTargetedID
      PermitValueRule:
        xsi:type: basic:ANY
/

my $got = Foo->xml($filter);
$got =~ s/\n\n+/\n/g;
chomp($got); $got .= "\n";
my $expected =  xml_out($filter);
my $got_obj = read_xml($got);
my $expected_obj =  read_xml($expected);
is_deeply(
  $got_obj, $expected_obj,
  "Equivalent as unsorted XML"
);

my $n = 3;
eq_or_diff(
  $got, $expected
);

done_testing;

sub xml_out {
  my ($obj) = @_;
  return XMLout(
    $obj,
    keeproot => 1,
    keyattr => [],
    attrindent => 1,
    xmldecl => '<?xml version="1.0" encoding="UTF-8"?>',
  );
}

sub normalize {
  local ($_) = @_; 
  s/"\n/"/g;
  s/\n(?:\s*\n)+/\n/g;
  return $_;
}

sub read_xml {
  my ($xml) = @_;
  my $force = qr/^(?:\w+:)?[A-Z]/;
  return XMLin(
    $xml,
    keeproot => 1,
    forcearray => [$force],
    normalizespace => 2,
    keyattr => [],
  );
}

sub first {
  my ($n, $string) = @_;
  my @lines = split /\n/, $string;
  $n = @lines - 1 if $n >= @lines;
  return [map { "$_\n" } @lines[0..$n]];
}

package Foo;
use XML::Writer;
use Carp;

sub xml {
  my ($class, $obj) = @_;
  ref $obj eq "HASH"
    or croak "Expected a HASH reference";

  my $output;
  my $writer = XML::Writer->new(
    OUTPUT => \$output,
    DATA_MODE => 1,
    DATA_INDENT => "  ",
  );
  $writer->xmlDecl("UTF-8");
  
  $class->write_xml($writer, $_, $$obj{$_})
    for sort keys %$obj;
  
  return $output;
}

sub write_xml {
  my ($class, $writer, $key, $obj) = @_;
  if (ref $obj eq "ARRAY") {
    $class->write_xml($writer, $key, $_) for @$obj;
  }
  elsif (ref $obj eq "HASH") {
    $obj = {%$obj}; # Don't destroy our original
    my @attributes;
    foreach my $attr_key (sort keys %$obj) {
      my $value = $$obj{$attr_key};
      unless (ref $value) {
        push @attributes, $attr_key, delete $$obj{$attr_key};
      }
    }
    if (keys %$obj) {
      $writer->startTag($key, @attributes);
      $class->write_xml($writer, $_, $$obj{$_}) for sort keys %$obj;
      $writer->endTag($key);
    }
    else {
      $writer->emptyTag($key, @attributes);
    }
  }
  return;
}



