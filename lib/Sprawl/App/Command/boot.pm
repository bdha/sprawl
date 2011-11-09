package Sprawl::App::Command::boot;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;

=head1 NAME

Sprawl::App::Command::boot - boot a node

=cut

sub command_names { qw(boot) }

sub usage_desc { '%c boot <UUID>' }

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

  my $response = HTTP::Tiny->new->put("http://$endpoint/boot/$uuid");
  die $response->{content} unless $response->{success};

  my $json = JSON->new;
  $json->pretty(1);

  my $out = $json->decode($response->{content});
  print $json->encode($out);
}

1;
