package YAML::XMLConfig;
use warnings;
use strict;
# ABSTRACT: Use tweaked YAML to create Java and other XML config files

use File::Slurp;
use YAML::XS;
use XML::Simple qw(:strict);
use Carp;

sub weaver {
  my ($class, $macros) = @_;
  $macros = ref $macros ? {%$macros} : $class->load_yaml($macros);
  my $element_order = delete $$macros{'$ELEMENT_ORDER'} || {};
  my $cdata = delete $$macros{'$CDATA'} || [];
  bless {
    xml_out => YAML::XMLConfig::out->new($element_order, $cdata),
    macros => {map { ($_=>$class->macro($$macros{$_})) } keys %$macros},
  }, $class;
}

sub macros { $_[0]->{macros} }
sub xml_out { $_[0]->{xml_out} }

sub load_yaml {
  my ($class, $path) = @_;
  return Load scalar read_file $path;
}

sub read_config {
  my ($weaver, $path, $opt) = @_;
  my $xml;
  if ($opt) {
    ref $opt eq "HASH"
      or croak "Second argument must be a HASH reference if given";
    $xml = lc($opt->{as}||"") eq "xml";
  }
  my $result = $weaver->weave($weaver->load_yaml($path));
  return $xml ? $weaver->xml($result) : $result;
}

sub xml {
  my ($weaver, $object) = @_;
  return $weaver->xml_out->out($object);
}

sub weave {
  my ($weaver, $item, $key) = @_;
  defined($key) or $key = "";

  if (ref $item eq "ARRAY") {
    return [map { $weaver->weave($_, $key) } @$item];
  }

  my $default;
  my $macro = $weaver->macro_for($key);
  ($default, $item) = $macro->default_for($item);

  ref $item or return $item;

  ref $item eq "HASH" or confess <<"/";
Can't weave expanded item
  Problem: expanded type is not HASH
  Item: @{[Dump($item)]}
/
  $item = {map { $_ => $weaver->weave($$item{$_}, $_) } keys %$item};
  $weaver->fill_defaults($item, $default);
  return $item;
}

sub macro_for {
  my ($weaver, $key) = @_;
  return $$weaver{macros}{$key} || YAML::XMLConfig::IdentityMacro->new;
}
package YAML::XMLConfig::IdentityMacro;
  my $identity_macro;
  sub new { $identity_macro ||= {}; bless $identity_macro, $_[0] }
  sub default_for { return ({}, $_[1]) }
package YAML::XMLConfig;

sub macro {
  my ($class, $item_hash) = @_;
  $class = ref $class if ref $class;

  ref $item_hash eq "HASH" or croak "Argument must be a HASH reference";
  my ($params, $item) = $class->extract($item_hash);

  croak "Value of '\$' must be an ARRAY reference or a scalar"
    unless ref $params eq "ARRAY";
  croak "Every name in the parameter list must be a string"
    if grep { ref $_} @$params;
  my $bad = __badlist(grep { ! /^\$[_:\w]+$/ } @$params);
  croak <<"/" if $bad;
Every name in the parameter list must start with a dollar sign (\$)
and be followed by one or more alphanumerics, underscores, or colons.
Offending names:
$bad
/
  my %count;
  $count{$_}++ for @$params;
  $bad = __badlist(grep { $count{$_} != 1 } @$params);
  croak "Repeating parameter names:\n$bad" if $bad;

  bless {params => $params, yaml => Dump($item)}, $class;
}

sub __badlist { join("", map { "   $_\n" } @_) }
sub yaml { $_[0]->{yaml} }
sub params {
  my ($macro) = @_;
  return @{$macro->{params} || confess "I have no parameter list"};
}

sub default_for {
  my ($macro, $item) = @_;
  my ($arguments, $trimmed_item) = $macro->extract($item);
  defined(my $default = eval { $macro->expand($arguments) })
    or die "Can't weave item\n  Problem: $@\n  Item: " . Dump($item);
  return ($default, $trimmed_item);
}

sub extract {
  my ($class, $item) = @_;

  ref $item or return ([$item], {});
  ref $item eq "HASH"
    or croak "Argument must be a scalar or a HASH reference";
  $item = {%$item};

  my $params = delete $$item{'$'};
  defined($params) or $params = [];
  ref $params or $params = [$params];

  return ($params, $item);
}

sub expand {
  my ($macro, $args) = @_;
  ref $args eq "ARRAY" or croak "Expected an ARRAY reference";
  my $size = $macro->params;
  return {} if @$args == 0 and $size > 0;

  my $cmp = @$args < $size ? "few"
          : @$args > $size ? "many"
                            :  "";
  croak "Too $cmp arguments -- expected $size"
    if $cmp;

  my @params = $macro->params;
  my @args = @$args;
  my $yaml = $macro->yaml;
  while (my $param = shift @params) {
    my $arg = shift @args;
    $yaml =~ s/\Q$param\E\b/$arg/g;
  }
  return Load($yaml);
}

sub fill_defaults {
  my ($class, $contents, $default) = @_;
  while (my ($key, $value) = each %$default) {
    for my $item ($$contents{$key}) {
      if (! defined $item) {
        $item = $value;
      }
      elsif (ref $item eq "HASH" and ref $value eq "HASH") {
        $class->fill_defaults($item, $value);
      }
    }
  }
  return;
}

package YAML::XMLConfig::out;
use base qw(XML::Simple);
use YAML::XS;
use Carp;

sub new {
  my ($class, $element_order, $cdata) = @_;
  my $xml_out = $class->SUPER::new(
    keeproot => 1,
    keyattr => [],
    attrindent => 1,
    noescape => 1,
    xmldecl => '<?xml version="1.0" encoding="UTF-8"?>',
  );
  $$xml_out{element_order} = $element_order;
  $$xml_out{cdata} = {map { $_ => 1 } @$cdata};
  return $xml_out;
}

sub out {
  my ($self, $obj) = @_;
  $self->XMLout($self->escape($obj, ""));
}

sub escape {
  my ($self, $obj, $key) = @_;

  return [map { $self->escape($_, $key) } @$obj]
    if ref $obj eq "ARRAY";

  return { map { ($_ => $self->escape($$obj{$_}, $_)) } keys %$obj }
    if ref $obj eq "HASH";

  croak "Reference is not ARRAY or HASH: ", Dump($obj)
    if ref $obj;

  if ($$self{cdata}{$key}) {
    return "<![CDATA[$obj]]>";
  }
  else {
    return $self->escape_value($obj);
  }
}

sub sorted_keys {
  my ($self, $name, $ref) = @_;
  my $order = $$self{element_order}{$name} or return sort keys %$ref;
  my %hash = %$ref;
  my @ordered_keys;
  foreach my $key (@$order) {
    push @ordered_keys, $key if delete $hash{$key};
  }
  return (@ordered_keys, sort keys %hash);
}

1;
