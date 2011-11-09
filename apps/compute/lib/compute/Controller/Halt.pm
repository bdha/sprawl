package compute::Controller::Halt;
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

sub halt : Local : ActionClass('REST') : Args(1) { }

sub halt_PUT {
  my ( $self, $c, $uuid ) = @_;

  $c->log->info("Calling halt: $uuid");

  my $zone_state = qx( /usr/sbin/zoneadm -z $uuid list -p | awk -F: '{print \$3}' );
  chomp $zone_state;

  my $zone_brand = qx( /usr/sbin/zonecfg -z $uuid info brand | awk '{print \$2}');
  chomp $zone_brand;

  my %status;
  $status{uuid} = $uuid;

  if ( $zone_state eq "running" ) {
    $c->log->info("Halting $uuid");
    if ( $zone_brand eq "kvm" ) {
      my $halt = qx( /usr/sbin/vmadm halt $uuid 30 );
    }
    else {
      my $halt = qx( /usr/sbin/zoneadm -z $uuid halt );
    }

    $c->log->info("Halted: $uuid");
    $status{state}   = "halted";
    $status{message} = "$uuid halted";

    $self->status_ok(
      $c,
      entity => { %status },
    );
  }
}

=head1 AUTHOR

Bryan Horstmann-Allen <bda@mirrorshades.net>

=cut

__PACKAGE__->meta->make_immutable;

1;
