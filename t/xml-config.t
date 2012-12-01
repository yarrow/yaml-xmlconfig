#!/usr/bin/env perl
use warnings;
use strict;
use Test::Most;
use File::Slurp;
use YAML::XS;
use XML::Simple;

BEGIN { use_ok('YAML::XMLConfig') }

my $why;
sub because { chomp($why = join(' ', @_)); $why =~ s/\s*\n\s*/ /g }

# File paths used for testing
#
my $yaml_config = "t/config.yaml";
my $weaver_path = "t/weaver.yaml";
END { unlink $yaml_config, $weaver_path if $yaml_config }

# A config weaver used in examples, and something for it to act on.
#
my $weaver_hash = {
  a => {'$' => '$x', num => 42, b => '&buzz$x'},
  b => {hive => "yes"},
};
my $weaver = YAML::XMLConfig->weaver($weaver_hash);
my $fancy_weaver = YAML::XMLConfig->weaver(
  {%$weaver_hash,
    '$ELEMENT_ORDER' => {stuff => [qw(b a)]},
    '$CDATA' => [qw(ant)],
  }
);
my $config_hash = {
  stuff => {
    a => {'$' => ["ing bees"], num => 0, ant => ["hill"]},
    b => [ {direction => "North"}, {direction => "South"}],
  },
};

=head1 NAME

YAML::XMLConfig - Use tweaked YAML to create Java and other XML config files

=head1 SYNOPSIS

  use YAML::XMLConfig;
  my $weaver = YAML::XMLConfig->weaver("weaver.yaml");
  my $config_hash = $weaver->read_config("config.yaml");
                    # or #
  my $xml = $weaver->read_config("config.yaml", {as => "xml");

=head1 YAML EXTENSIONS

Yada yada yada....

=head1 METHODS

=head2 weaver

The C<weaver> method takes a hashref and returns an object with the same keys
as the original, but with each value turned into a macro.  (So the values must
all be themselves hashrefs.)

It can also take a string, the path of a YAML file.  In that case it uses the
C<load_yaml> routine to read a hashref from the file, and proceeds as if the
hashref had been passed in.

Exceptions: the '$ELEMENT_ORDER' and '$CDATA' sections don't become macros.
The '$ELEMENT_ORDER' section is used to control element order in XML output.

The '$CDATA' section controls which keys will have their string values output
as CDATA sections.

=cut

because <<'/';
C<weaver> can also that method take a string, the path of a YAML file.
/
write_file($weaver_path, Dump($weaver_hash));
eq_or_diff(
  YAML::XMLConfig->weaver($weaver_path),
  YAML::XMLConfig->weaver($weaver_hash),
  $why,
);

because <<'/';
Exceptions: the '$ELEMENT_ORDER' and '$CDATA' sections don't become macros.
/
eq_or_diff(
  $fancy_weaver->macros,
  $weaver->macros,
  $why,
);

because <<'/';
The '$ELEMENT_ORDER' section is used to control element order in XML output
/

=head2 load_yaml

The following are equivalent:

  $weaver->load_yaml($path)
  Load scalar read_file $path

(where C<Load> is the C<YAML::XS> routine and C<read_file> is the
C<File::Slurp> routine.
=cut

because <<'/';
C<< $weaver->load_yaml($path) >> is equivalent to C<Load scalar read_file $path>
/
write_file($yaml_config, Dump($config_hash));
eq_or_diff(
  $weaver->load_yaml($yaml_config),
  (Load scalar read_file $yaml_config),
  $why,
);

=head2 read_config

Reads in a YAML config file and weaves in the defaults, returning either an
object reference or XML text.  The following are equivalent:

  $weaver->read_config("config.yaml")
  $weaver->weave($weaver->load_yaml("config.yaml"))

as are these two:

  $weaver->read_config("config.yaml", {as => "xml"})
  $weaver->xml($weaver->read_config("config.yaml"))
=cut

because <<'/';
read_config($foo) is equivalent to weave("", $weaver->load_yaml($foo))
/
write_file($yaml_config, Dump($config_hash));
eq_or_diff(
  $weaver->read_config($yaml_config),
  $weaver->weave($weaver->load_yaml($yaml_config)),
  $why,
);

because <<'/';
read_config($foo, {as => "xml"}) uses C<xml>
/
write_file($yaml_config, Dump($config_hash));
eq_or_diff(
  $weaver->read_config($yaml_config, {as => "xml"}),
  $weaver->xml($weaver->read_config($yaml_config)),
  $why,
);

=head2 xml

Returns an XML string representation of the object, similar to

  XML::Simple::XMLout(
    $h,
    keeproot => 1,
    keyattr => [],
    attrindent => 1,
    xmldecl => '<?xml version="1.0" encoding="UTF-8"?>',
  )

-- but we subclass XML::Simple to use the C<element_order> method to control
the order of elements in the XML, and the C<cdata> method to choose which
values are printed as CDATA.
=cut

because <<'/';
C<xml> is a convenience abbreviation for XMLout
/
eq_or_diff(
  $weaver->xml($weaver->weave($config_hash)),
  XMLout(
    $weaver->weave($config_hash),
    keeproot => 1,
    keyattr => [],
    attrindent => 1,
    xmldecl => '<?xml version="1.0" encoding="UTF-8"?>',
  ),
  $why,
);

because <<'/';
We subclass XML::Simple to use the C<element_order> method to control
the order of elements in the XML, and the C<cdata> method to choose which
values are printed as CDATA.
/
eq_or_diff(
  $fancy_weaver->xml($fancy_weaver->weave($config_hash)),
  <<'/',
<?xml version="1.0" encoding="UTF-8"?>
<stuff>
  <b direction="North"
     hive="yes" />
  <b direction="South"
     hive="yes" />
  <a b="&amp;buzzing bees"
     num="0">
    <ant><![CDATA[hill]]></ant>
  </a>
</stuff>
/
#  XMLout(
#    $weaver->weave($config_hash),
#    keeproot => 1,
#    keyattr => [],
#    attrindent => 1,
#    xmldecl => '<?xml version="1.0" encoding="UTF-8"?>',
#  ),
  $why,
);

=head2 macro_for

The C<macro_for> method looks up a macro, given a key. The following statements
set $mac0 and $mac1 to identical macros:

  my $mac0 = YAML::XMLConfig->macro($foo);
  my $mac1 = YAML::XMLConfig->weaver({x => $foo})->macro_for("x");
=cut

because <<'/';
The POD statements set $mac0 and $mac1 to identical macros
/
{ my $foo = {bar => "baz"};
  eq_or_diff(
    YAML::XMLConfig->macro($foo),
    YAML::XMLConfig->weaver({x => $foo})->macro_for("x"),
    $why,
  );
}

=head2 weave

The C<weave> method takes two arguments, the I<item> and the I<key> (which
defaults to the empty string, i.e. to not using an macro. The key is used to
look up a macro.  The item is that to which the macro may be applied: either a
scalar, a hashref, or an arrayref.  If an arrayref, C<weave> returns an
arrayref calculated by calling itself recursively, with the same key, for each
element of the array, so the following two expressions are equivalent:

   $weaver->weave($a, $key)
   [map { $weaver->weave($_, $key) } @$a]

=cut

because <<'/';
Arrayref: call C<weave> recursively
/
eq_or_diff(
  $weaver->weave([{b => {ant => "hill"}}]),
  [{b => {hive => "yes", ant => "hill"}}],
  "$why (key miss, hit w/recursion)",
);

eq_or_diff(
  $weaver->weave([{ant => "hill"}]),
  [{ant => "hill"}],
  "$why (complete key miss)",
);

eq_or_diff(
  $weaver->weave([{'$' => "red"}, {'$' => "green", elf => "Santa's"}], "a"),
  [ {num => 42, b => "&buzzred"},
    {num => 42, b => "&buzzgreen", elf => "Santa's"},
  ],
  "$why (key hit)",
);

=pod

Otherwise, we check to see if there is a macro for the key.  If so, we use
it to calculate the hash of defaults.  If not, the default hash is empty.

If a macro is attached to the given key, and the item is scalar (say 'foo'),
the effect is the same as if the item were C<< {'$' => 'foo'} >> -- that is,
the macro is called with C<['foo']> as its argument list, and the default
hash is returned as the value of C<weave>.

=cut

because <<'/';
Scalar: if the key has a macro, it's applied
/
eq_or_diff(
  $weaver->weave("ing bees", "a"),
  {num => 42, b => "&buzzing bees"},
  $why,
);
because <<'/';
Scalar: and the result is the default hash
/
{ my ($default, undef) = $weaver->macro_for("a")->default_for("ing bees");
  eq_or_diff($weaver->weave("ing bees", "a"), $default, $why);
}

because <<'/';
Scalar: if the key has no  macro, return the scalar
/
eq_or_diff(
  $weaver->weave("ing bees", "nokey"),
  "ing bees",
  $why,
);

=pod

If the item is a hashref, then two things happen:

=over 4

=item *

A new item hashref is calculated, with the same keys as the old item.  For each
$key and $value of the old item, the new item has key $key and value
C<weave($key, $value)>.

=item *

The default values are filled in (using the C<fill_defaults> method): we set

   $$item{$key} = $$default{$key}

for each $key missing in $item but present in $default.

=back

=cut

because <<'/';
Hashref: if the key has a macro, it's applied
/
eq_or_diff(
  $weaver->weave({'$' => ["ing bees"], num => 0, ant => "hill"}, "a"),
  {num => 0, b => "&buzzing bees", ant => "hill"},
  $why,
);

because <<'/';
Hashref: if the key has no  macro, call C<weave> recursively
/
eq_or_diff(
  $weaver->weave({b => {ant => "hill"}}, "nokey"),
  {b => {hive => "yes", ant => "hill"}},
  $why,
);

=pod

There is one exception here: if the hashref has zero arguments (e.g., has no
'$' entry), and the macro requires one or more arguments, then the macro is
not called.

=cut

because <<'/';
When the hashref has zero arguments and the macro requires one, then the
macro isn't called.
/
eq_or_diff(
  $weaver->weave({num => 42, b => {ant => "bill"}}, "a"),
  {num => 42, b => {ant => "bill", hive => "yes"}},
  $why,
);

=head2 macro

Takes a hashref and returns a macro.  The macro's parameters are given by the
'$' value of the hash, usually an arrayref. (See below for exceptions.) The
macro's content is the remainder of the hashref -- that is, the content is
equivalent to the hashref passed in with the '$' key deleted.

Example: the call

  YAML::XMLConfig->macro({
    '$' => ['$a', '$b'],
    info => {
      description => '$a',
      code => 'V001',
    }
    price => '$b',
  });

returns a macro with two parameters, $a and $b.

The hash argument is not altered.
=cut

because <<'/';
The argument must be a hashref
/
eval { YAML::XMLConfig->macro('arf') };
like($@, qr/HASH reference/, $why);

because <<'/';
The macro's content is equivalent to the hashref passed in, but with the '$' key
deleted
/
my $hash_for_macro = {
  '$' => ['$a', '$b'],
  info => {
    description => '$a',
    code => 'V001',
  },
  price => '$b',
};
my $macro_content = {%$hash_for_macro};
delete $$macro_content{'$'};
my $macro = YAML::XMLConfig->macro({%$hash_for_macro});
eq_or_diff(
  {%$macro},
  {params => [qw($a $b)], yaml => YAML::XS::Dump($macro_content)},
  $why,
);

because <<'/';
The example returns a macro with two parameters, $a and $b.
/
eq_or_diff(
  [$macro->params],
  [qw($a $b)],
  $why,
);

because <<'/';
The hash argument is not altered
/
my $hash_victim = {%$hash_for_macro};
YAML::XMLConfig->macro($hash_victim);
eq_or_diff($hash_victim, $hash_for_macro, $why);

=head2 params

The C<params> method returns a list of the macro's parameters, taken from the
'$' value of the argument to C<macro>, which must be a scalar, an arrayref, or
undefined.

When the value of '$' is an arrayref, its contents become the macro's parameter
list.  When the '$' key is missing or its value is undefined, the parameter
list is empty.  When the '$' key's value is a scalar, that is equivalent to a
one-element arrayref: the parameter list has one element, the scalar.

Each element of the parameter list must be a string starting with a dollar sign
and followed by one or more alphanumerics, underscores, or colons.

No name may occur more than once in the parameter list.
=cut

because <<'/';
Value of '$' must be a scalar, an arrayref, or undefined.
/
eval { YAML::XMLConfig->macro({'$' => {a => 1}}) };
like($@, qr/ARRAY reference/, $why);

because <<'/';
When the '$' key is missing or its value is undefined, the parameter list is
empty.
/
eq_or_diff(
  [ [YAML::XMLConfig->macro({})->params],
    [YAML::XMLConfig->macro({'$' => undef})->params],
    [YAML::XMLConfig->macro({'$' => []})->params],
  ],
  [ [], [], [] ],
  $why
);

because <<'/';
A scalar value is equivalent to a one-element arrayref
/
eq_or_diff(
  YAML::XMLConfig->macro({'$' => '$q'}),
  YAML::XMLConfig->macro({'$' => ['$q']}),
  $why,
);

because <<'/';
Each element of the parameter list must be a string
/
eval { YAML::XMLConfig->macro({'$' => ['$a', {}]}) };
like($@, qr/must be a string/, $why);

because <<'/';
Each element of the parameter list must start with a dollar sign and be
followed by one or more alphanumerics, underscores, or colons
/
my @good = qw($a $: $_ $1 $_::arf1__whee);
my @bad = qw(b $ $' $$ :foo _foo foo);
my $has_bad = join(".*", map { "\Q$_\E" } @bad);
$has_bad = qr/$has_bad/s;
eval { YAML::XMLConfig->macro({'$' => [@good, @bad]}) };
like($@, qr/must.*$has_bad/s, $why);

because <<'/';
No name may occur more than once in the parameter list
/
eval { YAML::XMLConfig->macro({'$' => [qw($a $b $c $b $d)]}) };
like($@, qr/epeating.*\$b\b/s, $why);

=head2 default_for

The expression C<< $macro->default_for($item) >> returns a two-element list: a
default hashref, and a copy of $item with its '$' element (if any) deleted.
Example:

   my ($default, $new_item) = $macro->default_for($item);

This sets $default to an expanded copy of $macro's contents, with each
occurrence of a parameter name replaced by a value from $item's '$' value, and
sets $new_item to a copy of $item without its '$' element.

For instance, if we have:

  my $macro = YAML::XMLConfig->macro({
    '$' => ['$a', '$b'],
    info => {
      description => '$a',
      code => 'V001',
    },
    price => '$b',
    parts => 'few',
  });

  my $item = {
    '$' => ['Veeblefetzer', '42.00'],
    info => {precious => 'no'},
    parts => 'many',
  };

Then the statement

  my ($default, $new_item) = $macro->default_for($item);

is equivalent to:

  my $default = {
    info => {
      description => 'Veeblefetzer',
      code => 'V001',
    },
    price => '42.00',
    parts => 'few',
  };
  my $new_item = {
    info => {precious => 'no'},
    parts => 'many',
  };

=cut

because <<'/';
C<default_for> returns a defaults hashref and a trimmed item
/
$macro = macro_from_pod();
my $item = item_from_pod();
sub macro_from_pod {
  YAML::XMLConfig->macro({
    '$' => ['$a', '$b'],
    info => {
      description => '$a',
      code => 'V001',
    },
    price => '$b',
    parts => 'few',
  });
}
sub item_from_pod {
  {
    '$' => ['Veeblefetzer', '42.00'],
    info => {precious => 'no'},
    parts => 'many',
  };
}
eq_or_diff(
  [$macro->default_for($item)],
  [ { info => { description => 'Veeblefetzer', code => 'V001' },
      price => '42.00',
      parts => 'few',
    },
    { info => {precious => 'no'},
      parts => 'many',
    },
  ],
  $why
);

=head2 extract, expand

Internally, C<default_for> works in two stages.

=over 4

=item extract

First, we separate the item's arguments.  The call

  my ($arguments, $item_contents) = $macro->extract($item);

sets $argument to the value of $item's '$' entry (with undefined and scalar
values changed to empty and single-element arrayrefs as in the C<macro>
method), and $item_contents to a copy of $item with its '$' entry deleted.

$item itself is not changed.
=cut

because <<'/';
C<extract> returns the value of $item's '$' entry (with undefined and
scalar values changed as in the C<macro> method), followed by $item with its
'$' entry deleted.
/
$macro = YAML::XMLConfig->macro({'$' => ['$a']});
$item = {'$' => "x", rest => ["stuff"]};
my $original_item = {%$item};
eq_or_diff(
  [$macro->extract($item)],
  [["x"], {rest => ["stuff"]}],
  $why,
);
eq_or_diff($item, $original_item, '$item itself is not changed');

=pod

If $item is a scalar, C<extract($item)> returns the list C<([$item], {})>.
=cut

because <<'/';
If $item is a scalar, C<extract($item)> returns the list C<[$item], {}>.
/
eq_or_diff(
  [$macro->extract("foo")],
  [["foo"], {}],
  $why,
);

=item expand

Next, we use C<expand> to create a hashref corresponding to the contents of
$macro with each occurrence of a parameter name replaced by the corresponding
values in the $arguments extracted from $item:

  my $default = $macro->expand($arguments);

$arguments must be an arrayref, and must have the same size as
C<< $macro->params >>;
however, if $arguments has zero elements and C<< $macro->params >> has one or
more, we quietly return the empty hash.

=back

=cut

because <<'/';
$arguments must be an arrayref
/
eval { $macro->expand({}) };
like($@, qr/ARRAY reference/, $why);

because <<'/';
$arguments must have the same size as $macro->params
/
$macro = YAML::XMLConfig->macro({'$' => ['$a', '$b']});
my @death = (
  map { eval { $macro->expand($_) }; $@ } [], [qw(A)], [qw(A B)], [qw (A B C)]
);
like($death[1], qr/too few/i, "arrayref too small");
is($death[2], "", "arrayref just right");
like($death[3], qr/too many/i, "arrayref too large");

because <<'/';
however, if $arguments has zero elements and C<< $macro->params >> has one or
more, we quietly return the empty hash.
/
eq_or_diff([$death[0], eval { $macro->expand([]) }], ["", {}], $why);

because <<'/';
We use C<expand> to create a hashref corresponding to the contents of
$macro with each occurrence of a parameter name replaced by the corresponding
values in the $arguments extracted from $item:
/
$macro = macro_from_pod();

eq_or_diff(
  $macro->expand(['Veeblefetzer', '42.00']),
  { info => {
      description => 'Veeblefetzer',
      code => 'V001',
    },
    price => '42.00',
    parts => 'few',
  },
  $why
);

=head2 fill_defaults

The C<fill_defaults> method changes its first parameter by filling in the values
of keys present in its second parameter but not its first with values from the
second parameter.

  $macro->fill_defaults($item_contents, $default);

=cut

because <<'/';
fill_defaults modifies $item_contents by filling in missing keys from $default
/

my $item_contents = item_from_pod(); delete $$item_contents{'$'};

my $default = {
  info => {
    description => 'Veeblefetzer',
    code => 'V001',
  },
  price => '42.00',
  parts => 'few',
};
my $expected_contents = {
  info => {
    description => 'Veeblefetzer',
    code => 'V001',
    precious => 'no',
  },
  price => '42.00',
  parts => 'many',
};

$macro->fill_defaults($item_contents, $default);
eq_or_diff($item_contents, $expected_contents, $why);

done_testing;
write_file("lib/YAML/XMLConfig.pod", read_file($0))
  if Test::Builder::Module->builder->is_passing;
