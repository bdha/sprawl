package compute::Controller::Status;
use Moose;
use namespace::autoclean;
use JSON;
use XML::Simple;
use Sys::Hostname;
use Data::Dumper::Simple;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default   => 'application/json',
  namespace   => '',
);

sub status : Local : ActionClass('REST') { }

sub status_GET {
  my ( $self, $c ) = @_;

  my %status;

  $status{state} = "ok";

  $status{hostname} = hostname;

  my $os_version = qx( /bin/uname -v );
  chomp $os_version;
  $status{os_version} = $os_version;

  my $chassis = qx(/usr/sbin/prtdiag | head -1 | sed -e 's/^.*: //' );
  chomp $chassis;
  $status{chassis} = $chassis;

  my $cpu_idle = qx( /bin/mpstat -a 1 2 | /bin/tail -1 | /bin/awk '{print \$16'} );
  chomp $cpu_idle;

  my $cpu_model = qx( /usr/sbin/prtdiag | grep CPU | head -1 );
  chomp $cpu_model;

  my $cpu_num = qx( /usr/sbin/psrinfo -p );
  chomp $cpu_num;
  
  $status{resources}{cpu}->{idle}   = $cpu_idle;
  $status{resources}{cpu}->{model}  = $cpu_model;
  $status{resources}{cpu}->{num}    = $cpu_num;

  $status{resources}{cpu}->{state} = "ok";
  my $cpu_bad_state = qx( /usr/sbin/psrinfo | grep -v on-line );
  if ( $cpu_bad_state ) {
    $status{resources}{cpu}->{state} = "nok";
    $status{state} = "nok";
  } 

  my $total_memory = qx( prtconf | head | grep Memory | awk '{print \$3}' );
  chomp $total_memory;
  $status{resources}{memory}->{total} = $total_memory;

  my $swap = qx( /usr/sbin/swap -sh );
  chomp $swap;

  # XXX STATUS: The smart way to do this. But I am not smart.
  #my $size = qr{(?: [0-9]+ )(?: \.[0-9]+ ).}x;
  #my ($swap_alloc, $swap_reserved, $swap_used, $swap_avail) = $swap =~ m{($size) allocated \+ ($size) reserved = ($size) used, ($size) available};

  my @swap = split(/\s/,$swap);

  # total: 14G allocated + 4.1G reserved = 18G used, 75G available
  $status{resources}{memory}{swap}->{alloc}    = $swap[1];
  $status{resources}{memory}{swap}->{used}     = $swap[7];
  $status{resources}{memory}{swap}->{avail}    = $swap[9];
  $status{resources}{memory}{swap}->{reserved} = $swap[4];

  # XXX STATUS: If we are low on swap, set state to nok.

  my $zfs_usage = qx( echo ::memstat | mdb -k | grep ZFS | awk '{print \$5,\$6}');
  chomp $zfs_usage;
  my ( $zfs_used_mb, $zfs_percent ) = split(/ /, $zfs_usage );

  $status{resources}{memory}{zfs}->{used}          = $zfs_used_mb;
  $status{resources}{memory}{zfs}->{percent}       = $zfs_percent;

  my $zfs_arc_max_bytes = qx( grep "^set zfs:zfs_arc_max" /etc/system | sed -e 's/^.*=//' );
  if ( $zfs_arc_max_bytes ) { 
   chomp $zfs_arc_max_bytes;
   my $zfs_arc_max_mb = $zfs_arc_max_bytes / 1024 / 1024;
   $status{resources}{memory}{zfs}->{zfs_arc_max}   = $zfs_arc_max_mb;
  }

  my $kernel_usage = qx( echo ::memstat | mdb -k | grep Kernel | awk '{print \$3,\$4}');
  chomp $kernel_usage;
  my ( $kernel_used_mb, $kernel_percent ) = split(/ /, $kernel_usage );

  $status{resources}{memory}{kernel}->{used}          = $kernel_used_mb;
  $status{resources}{memory}{kernel}->{percent}       = $kernel_percent;

  my @pools = qx( /sbin/zpool list -Ho name );
  chomp @pools;

  foreach my $pool ( @pools ) {
    my $pool_usage = qx( /sbin/zfs list -Ho used,avail $pool );
    chomp $pool_usage;
    my ( $used, $avail ) = split(/\t/, $pool_usage );
    my $health = qx( /sbin/zpool list -Ho health $pool );
    chomp $health;
 
    $status{storage}{zfs}{$pool}->{used}   = $used;
    $status{storage}{zfs}{$pool}->{avail}  = $avail;
    $status{storage}{zfs}{$pool}->{health} = $health;

    if ( $health ne "ONLINE" ) {
      $status{state} = "nok";
    }
  }

  my $zones = qx( /usr/sbin/zoneadm list -p | grep -v global | grep joyent | wc -l | awk '{print \$1}' );
  chomp $zones;

  my $kvm   = qx( /usr/sbin/zoneadm list -p | grep -v global | grep kvm | wc -l | awk '{print \$1}'); 
  chomp $kvm;

  $status{guests}->{zones} = $zones;
  $status{guests}->{kvm} = $kvm;

  # XXX STATUS: If a zone is wedged, set state to nok.

  foreach my $nic ( qx( grep _nic /usbkey/config ) ) {
    my ( $name, $mac ) = split( /=/,$nic );
    chomp $name;
    chomp $mac;
    $name =~ s/_nic//;

    my $phys = qx( /sbin/dladm show-phys -m | grep -v LINK | grep $mac );
    chomp $phys;

    my ( $link, $slot, $address, $inuse, $client ) = split(/\s+/, $phys );

    $status{network}{$name}->{macaddr} = $mac;
    $status{network}{$name}->{link}    = $link;
  }

  # XXX STATUS: Return capacity info.
  #   - empty
  #   - moderate
  #   - max
  #$status{capacity} = "?";

  # XXX STATUS: Return system faults.
  #status{faults} = "?";

  $self->status_ok(
    $c,
    entity => { %status }
  );
}

=head1 AUTHOR

Bryan Horstmann-Allen <bda@mirrorshades.net>

=cut

__PACKAGE__->meta->make_immutable;

1;
