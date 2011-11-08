package Sprawl::App;
use base 'App::Cmd';

use strict;
use warnings;

our $version = '0.01';

sub _default_command_base {
  require Sprawl::App::Command;
  return 'Sprawl::App::Command';
}

sub plugin_search_path {
  my ($self) = @_;
  my $path = $self->SUPER::plugin_search_path;

  return [ 'Sprawl::App::Command' ];
}

1;
