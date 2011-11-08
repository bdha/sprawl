package Sprawl::App::Command;
use base 'App::Cmd::Command';

use strict;
use warnings;

use YAML::XS qw'LoadFile';

my $config_file = $ENV{HOME} . "/.sprawl.yml";

sub get_config { 
  my $config = LoadFile($config_file);
  return $config;
}

sub assert_args_count {
  my ($self, $n, $args) = @_;
  if ($n == 0) {
    $self->usage_error('no arguments allowed') unless @$args == 0;
  } else {
    $self->usage_error('wrong number of args') unless @$args == $n;
  }
}

1;
