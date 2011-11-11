package Sprawl::App::Command::list;
use Sprawl::App -command;
use HTTP::Tiny;
use JSON;
use Text::Table;

=head1 NAME

Sprawl::App::Command::list - list information on all nodes

=cut

sub command_names { qw(list li) }

sub usage_desc { '%c list' }

sub opt_spec {
  return (
    [ 'json|j' => 'print json' ],
  );
}

sub validate_args {
  my ($self, $opt, $args) = @_;
  $self->usage_error("No args allowed") if @$args;
}

sub execute {
  my ($self, $opt, $args) = @_;
  my $endpoint = $self->get_config->{endpoint};

  my $response = HTTP::Tiny->new->get("http://$endpoint/node");
  die $response->{content} unless $response->{success};

  my $json = JSON->new;
  $json->pretty(1);

  my $out = $json->decode($response->{content});

  unless ( $opt->json ) {
    my $tb = Text::Table->new( "UUID", "Hostname", "Brand", "Template", "IP", "VNC", "State" );
  
    foreach my $uuid ( sort keys %{$out} ) {
  
      my $vnc;
      if ( $out->{$uuid}->{vnc} ) {
        $vnc = $out->{$uuid}->{vnc}->{host} . ":" . $out->{$uuid}->{vnc}->{port};
      }
      else {
        $vnc = "~";
      }
  
      my $template;
      if ( $out->{$uuid}->{template} ) {
        $template = $out->{$uuid}->{template};
      }
      else {
        $template = "SmartOS";
      }
  
      $tb->add( $uuid, $out->{$uuid}->{hostname}, $out->{$uuid}->{brand}, $template, $out->{$uuid}->{network}->{net0}->{ip}, $vnc, $out->{$uuid}->{state} );
    }
  
    print $tb;
  }
  else {
    print $json->encode($out);
  }
}

1;
