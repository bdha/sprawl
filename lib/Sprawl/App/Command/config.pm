package Sprawl::App::Command::config;
use Sprawl::App -command;
use YAML::XS;

=head1 NAME

Sprawl::App::Command::config - dump client config

=cut

sub command_names { qw(config conf) }

sub usage_desc { '%c config' }

sub opt_spec {
}

sub validate_args {
  my ($self, $opt, $args) = @_;
}

sub execute {
  my $config = Sprawl::App::Command::get_config();
  $config->{secret} = undef;
  print Dump $config;
}

1;
