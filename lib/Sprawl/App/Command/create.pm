package Sprawl::App::Command::create;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;

=head1 NAME

Sprawl::App::Command::create - create a new node

=cut

sub command_names { qw(create cr) }

sub usage_desc { '%c create %o' }

sub opt_spec {
  return (
    [ 'size|s=s'      => 'size', { required => 1 } ],
    [ 'template|t=s'  => 'template', { required => 1 } ],
    [ 'hostname|h=s'  => 'hostname', { required => 1 } ],
    [ 'domain|d=s'    => 'domain name' ],
    [ 'sshkey|k=s'    => 'ssh key pair', { required => 1 } ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  $self->usage_error("No args allowed") if @$args;
}

sub execute {
  my ($self, $opt, $args) = @_;

  my $endpoint = $self->get_config->{endpoint};

  my $json = JSON->new;
  $json->pretty(1);

  my $node = ();

  $node->{size} = $opt->size;
  $node->{template} = $opt->template;
  $node->{hostname} = $opt->hostname;
  $node->{domain} = $opt->domain;
  $node->{sshkey} = $opt->sshkey;

  my $content = $json->encode($node);

  my $response = HTTP::Tiny->new->put(
    "http://$endpoint/node/create", {
      content =>  $content,
      headers =>  { 'content-type'  =>  'application/x-json' },
    }
  );

  die $response->{content} unless $response->{success};

  my $out = $json->decode($response->{content});
  print $json->encode($out);
}

1;
