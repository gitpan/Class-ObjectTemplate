package Class::ObjectTemplate;
require Exporter;

use vars qw(@ISA @EXPORT $VERSION $DEBUG);
use Carp;

@ISA = qw(Exporter);
@EXPORT = qw(attributes);
$VERSION = 0.4;

$DEBUG = 0; # assign 1 to it to see code generated on the fly 

# Create accessor functions, and new()
sub attributes {
  my ($pkg) = caller;
  croak "Error: attributes() invoked multiple times" 
    if scalar @{"${pkg}::_ATTRIBUTES_"};

  @{"${pkg}::_ATTRIBUTES_"} = @_;
  my $code = "";
  print STDERR "Creating methods for $pkg\n" if $DEBUG;
  foreach my $attr (@_) {
    print STDERR "  defining method $attr\n" if $DEBUG;
    # If a field name is "color", create a global list in the
    # calling package called @_color
    @{"${pkg}::_$attr"} = ();

    # If the accessor is already present, give a warning
    if (UNIVERSAL::can($pkg,"$attr")) {
      carp "$pkg already has method: $attr";
    }
    $code .= _define_accessor ($pkg, $attr, $lookup);
  }
  $code .= _define_constructor($pkg);
  eval $code;
  if ($@) {
    die  "ERROR defining constructor and attributes for '$pkg':"
       . "\n\t$@\n" 
       . "-----------------------------------------------------"
       . $code;
  }
}

# $obj->set_attributes (name => 'John', age => 23);     
# Or, $obj->set_attributes (['name', 'age'], ['John', 23]);
sub set_attributes {
  my $obj = shift;
  my $attr_name;
  if (ref($_[0])) {
    my ($attr_name_list, $attr_value_list) = @_;
    my $i = 0;
    foreach $attr_name (@$attr_name_list) {
      $obj->$attr_name($attr_value_list->[$i++]);
    }
  } else {
    my ($attr_name, $attr_value);
    while (@_) {
      $attr_name = shift;
      $attr_value = shift;
      $obj->$attr_name($attr_value);
    }
  }
}


# @attrs = $obj->get_attributes (qw(name age));
sub get_attributes {
  my $obj = shift;
  my (@retval);
  map {$obj->$_()} @_;
}

sub get_attribute_names {
  my $pkg = shift;
  $pkg = ref($pkg) if ref($pkg);
  my @result = @{"${pkg}::_ATTRIBUTES_"};
  if (defined (@{"${pkg}::ISA"})) {
    foreach my $base_pkg (@{"${pkg}::ISA"}) {
      push (@result, get_attribute_names($base_pkg));
    }
  }
  @result;
}

sub set_attribute {
  my ($obj, $attr_name, $attr_value) = @_;
  my ($pkg) = ref($obj);
  $ {"${pkg}::_$attr_name";}[$$obj] = $attr_value;
}

sub get_attribute {
  my ($obj, $attr_name, $attr_value) = @_;
  my ($pkg) = ref($obj);
  return $ {"${pkg}::_$attr_name";}[$$obj];
}

sub DESTROY {
    # release id back to free list
  my $obj = $_[0];
  my $pkg = ref($obj);
  my $inst_id = $$obj;
  # Release all the attributes in that row
  local (@attributes) = get_attribute_names($pkg);
  foreach my $attr (@attributes) {
    undef $ {"${pkg}::_$attr"}[$inst_id];
  }

  # JES -- need to deal with inheritance. The free list may be
  # maintained in a super class's namespace
  my $free;
  my $_pkg = find_free($pkg);
  croak "Couldn't find free list for $pkg" unless defined $_pkg;
  $free = \@{"${_pkg}::_free"};

  push(@{$free},$inst_id);
}

# JES -- needed to make the free list work with inheritance
# returns the pkg name if $_max_id is defined in this namespace
# if $_max_id is defined, so is @_free
sub find_free {
  my $pkg = shift;
  return $pkg if defined $ {"${pkg}::_max_id"};

  my $free_list;
  if (defined (@{"${pkg}::ISA"})) {
    foreach my $base_pkg (@{"${pkg}::ISA"}) {
      $free_list = find_free($base_pkg);
      last if defined $free_list;
    }
  }
  return $free_list;
}

sub initialize { }; # dummy method, if subclass doesn't define one.

#################################################################

sub _define_constructor {
  my $pkg = shift;
  my $free = "\@${pkg}::_free";
  my $code = qq {
    package $pkg;
    sub new {
      my \$class = shift;
      my \$inst_id;
      if (scalar $free) {
	\$inst_id = shift($free);
      } else {
	\$inst_id = \$_max_id++;
      }
      my \$obj = bless \\\$inst_id, \$class;
      \$obj->set_attributes(\@_) if \@_;
      my \$rc = \$obj->initialize;
      return undef if \$rc == -1;
      \$obj;
    }
  };
  $code;
}

sub _define_accessor {
  my ($pkg, $attr) = @_;

    # This code creates an accessor method for a given
    # attribute name. This method  returns the attribute value 
    # if given no args, and modifies it if given one arg.
    # Either way, it returns the latest value of that attribute


    # JES -- fixed bug so that inherited classes worked

    # JES -- simplified the free list to be a stack, and added a 
    # separate $_max_id variable

    # qq makes this block behave like a double-quoted string
  my $code = qq{
    package $pkg;
    sub $attr {                                      # Accessor ...
      my \$name = ref(\$_[0]) . "::_$attr";
         \@_ > 1 ? \$name->[\${\$_[0]}] = \$_[1]  # set
                 : \$name->[\${\$_[0]}];          # get
    }
  };
  $code .= qq{
    if (!defined \$max_id) {
      # Set up the free list, and the ID counter
      \@_free = ();
      \$_max_id = 0;
    };
  };
  $code;
}

1;
__END__
=head1 NAME

Class::ObjectTemplate - Perl extension for an optimized template
builder base class.

=head1 SYNOPSIS

  package Foo;
  use Class::ObjectTemplate;
  require Exporter;
  @ISA = qw(Class::ObjectTemplate Exporter);

  attributes('one', 'two', 'three');


=head1 DESCRIPTION

Class::ObjectTemplate is a utility class to assist in the building of
other Object Oriented Perl classes.

It was described in detail in the O\'Reilly book, "Advanced Perl
Programming" by Sriram Srinivasam. 

=head2 EXPORT

attributes()

=head1 AUTHOR

Original code by Sriram Srinivasam.

Fixes and CPAN module by Jason E. Stewart (jason@openinformatics.com)

=head1 SEE ALSO

http://www.oreilly.com/catalog/advperl/

perl(1).

=cut
