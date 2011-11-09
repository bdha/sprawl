package compute::Controller::Boot;
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

sub boot : Local : ActionClass('REST') : Args(1) { }

sub boot_PUT {
  my ( $self, $c, $uuid ) = @_;

  $c->log->info("Calling boot: $uuid");

  my $zone_state = qx( /usr/sbin/zoneadm -z $uuid list -p | awk -F: '{print \$3}' );
  chomp $zone_state;

  my $zone_brand = qx( /usr/sbin/zonecfg -z $uuid info brand | awk '{print \$2}');
  chomp $zone_brand;

  my %status;
  $status{uuid} = $uuid;

  if ( $zone_state eq "installed" ) {
    $c->log->info("Booting $uuid");
    if ( $zone_brand eq "kvm" ) {
      my $boot = qx( /usr/sbin/vmadm boot $uuid );
    }
    else {
      my $boot = qx( /usr/sbin/zoneadm -z $uuid boot );
    }

    $c->log->info("Booted: $uuid");
    $status{state}   = "booted";
    $status{message} = "$uuid booted";

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
