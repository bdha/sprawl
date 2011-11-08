package Sprawl::App::Command::info;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;

=head1 NAME

Sprawl::App::Command::info - info on a node

=cut

sub command_names { qw(info i) }

sub usage_desc { '%c info <UUID>' }

sub opt_spec {
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->assert_args_count(1, $args);
}

sub execute {
  my ($self, $opt, $args) = @_;

  my $endpoint = $self->get_config->{endpoint};

  my $uuid = $args->[0];

  my $response = HTTP::Tiny->new->get("http://$endpoint/node/$uuid");
  die $response->{content} unless $response->{success};

  my $json = JSON->new;
  $json->pretty(1);

  my $out = $json->decode($response->{content});
  print $json->encode($out);
}

1;
