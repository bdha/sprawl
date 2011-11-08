package Sprawl::App::Command::templates;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;

=head1 NAME

Sprawl::App::Command::templates - list operating system templates

=cut


sub command_names { qw(templates) }

sub usage_desc { '%c %o' }

sub opt_spec {
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  $self->usage_error("No args allowed") if @$args;
}

sub execute {
  my ($self, $opt, $args) = @_;

  my $endpoint = $self->get_config->{endpoint};

  my $response = HTTP::Tiny->new->get("http://$endpoint/templates");
  die $response->{content} unless $response->{success};

  my $json = JSON->new;
  $json->pretty(1);

  my $out = $json->decode($response->{content});
  print $json->encode($out);
}

1;
