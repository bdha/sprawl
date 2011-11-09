package compute::Controller::Templates;
use Moose;
use namespace::autoclean;
use JSON;
use XML::Simple;
use Data::Dumper::Simple;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default   => 'application/json',
  namespace   => '',
);

sub templates : Local : ActionClass('REST') { }

sub templates_GET {
  my ( $self, $c ) = @_;

  my %templates;

  my @templates = qx( /sbin/zfs list -Ho name -r zones/templates | grep -v "zones/templates\$" );
  foreach my $template ( @templates ) {
    chomp $template;
    foreach my $property ( qw/ volsize used / ) {
      my $value = qx( /sbin/zfs get -Ho value $property $template );
      chomp $value;
      $templates{templates}{$template}->{$property} = $value;
    }
  }

  $self->status_ok(
    $c,
    entity => { %templates }
  );
}

=head1 AUTHOR

Bryan Horstmann-Allen <bda@mirrorshades.net>

=cut

__PACKAGE__->meta->make_immutable;

1;
