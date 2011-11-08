package Sprawl::App::Command::sizes;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;

=head1 NAME

Sprawl::App::Command::sizes - list node sizes

=cut

sub command_names { qw(sizes) }

sub usage_desc { '%c sizes' }

sub opt_spec {
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  $self->usage_error("No args allowed") if @$args;
}

sub execute {
  my ($self, $opt, $args) = @_;

  my $endpoint = $self->get_config->{endpoint};

  my $response = HTTP::Tiny->new->get("http://$endpoint/sizes");
  die $response->{content} unless $response->{success};

  my $json = JSON->new;
  $json->pretty(1);

  my $out = $json->decode($response->{content});
  print $json->encode($out);
}

1;
