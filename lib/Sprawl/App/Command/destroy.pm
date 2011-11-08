package Sprawl::App::Command::destroy;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;

=head1 NAME

Sprawl::App::Command::destroy - destroy a node

=cut

sub command_names { qw(destroy rm) }

sub usage_desc { '%c destroy <UUID>' }

sub opt_spec {
}

sub validate_args {
  my ($self, $opt, $args) = @_;

  $self->assert_args_count(1, $args);
}

sub execute {
  my ($self, $opt, $args) = @_;

  my $endpoint = $self->get_config->{endpoint};

  my $json = JSON->new;
  $json->pretty(1);

  my $uuid = $args->[0];

  my $response = HTTP::Tiny->new->delete(
    "http://$endpoint/node/$uuid", {
      headers =>  { 'content-type'  =>  'application/x-json' },
    }
  );

  die $response->{content} unless $response->{success};

  my $out = $json->decode($response->{content});
  print $json->encode($out);
}

1;
