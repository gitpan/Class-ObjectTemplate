# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..14\n"; }
END {print "not ok 1\n" unless $loaded;}
# use blib;
use Class::ObjectTemplate;
$loaded = 1;
$i=1;
print "ok ", $i++, "\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

BEGIN {
  unshift (@INC, '.');
  open(F,">Foo.pm") or die "Couldn't write Foo.pm";

  print F <<'EOF';
package Foo;
use Class::ObjectTemplate;
@ISA = qw(Class::ObjectTemplate);
attributes(one, two, three);

1;
EOF
  close(F);
}
use lib '.';
require Foo;
my $f = new Foo(one=>23);

#
# test that a value defined at object creation is properly set
#
result($f->one() == 23);

#
# test that a value not defined at object creation is undefined
#
result(! defined $f->two());

#
# test that we can set and retrieve a value
#
$f->two(45);
result($f->two() == 45);

END { 1 while unlink 'Foo.pm'}

BEGIN {
  open(F,">Baz.pm") or die "Couldn't write Baz.pm";

  print F <<'EOF';
package Baz;
use Class::ObjectTemplate;
use subs qw(undefined);
@ISA = qw(Class::ObjectTemplate);
attributes('one', 'two');

package BazINC;
use Class::ObjectTemplate;
@ISA = qw(Baz);

1;
EOF
  close(F);
}

require Baz;
$baz = new Baz();
$baz->two(27);
result($baz->two() == 27);

#
# test that the data for attributes is being stored in the 'Baz::' namespace
# this is to monitor a bug that was storing lookup data in the 'main::'
# namespace
result(scalar @Baz::_two);

# test that @Baz::_ATTRIBUTES_ and is being properly set. This is to
# check a bug that overwrote it on each call to attributes()
result(scalar @Baz::_ATTRIBUTES_ == 2);

#
# Test an inherited class that defines no new attributes
#
$baz_inc = new BazINC();

# test that @Baz::_ATTRIBUTES_ is not being set. This is to check a
# bug where inherited classes didn't get their attributes properly
# initialized
result(scalar @BazINC::_ATTRIBUTES_ == 0);

$baz_inc->one(34);
result($baz_inc->one() == 34);

#
# !!!! WARNING ALL THESE TESTS SHOULD FAIL !!!!
#
# they are here to illustrate bugs in the original code, v0.1
#

#
# test that the data is being stored in the 'BazINC::' namespace
# this is to monitor a bug that was storing lookup data in the 'main::'
# namespace
result(scalar @BazINC::_one);

#
# test that Baz and BazINC not interfering with one another
# even though their attribute arrays are in Baz's namespace
$baz->one(45);
$baz_inc->one(56);
result($baz_inc->one() == $baz->one());

#
# test that $baz_inc->DESTROY properly modifies that @_free array in
# Baz and does not add one to BazINC
$old_free = scalar @Baz::_free;
$baz_inc->DESTROY();
result(! scalar @BazINC::_free);

result($old_free != scalar @Baz::_free);

END { 1 while unlink 'Foo.pm'; 1 while unlink 'Baz.pm'}

sub result {
  my $cond = shift;
  print STDERR "not " unless $cond;
  print STDERR "ok ", $i++, "\n";
}
