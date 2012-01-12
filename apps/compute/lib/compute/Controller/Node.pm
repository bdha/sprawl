package compute::Controller::Node;
use Moose;
use namespace::autoclean;
use JSON;
use XML::Simple;
use String::Random;
use Data::Dumper::Simple;

BEGIN { extends 'Catalyst::Controller::REST' }

__PACKAGE__->config(
  default   => 'application/json',
  namespace   => '',
);

sub node : Local : ActionClass('REST') { }

sub node_POST {
  my ( $self, $c ) = @_;

  my $json = JSON->new;
  $json->pretty(1);

  my $node_req = $c->req->data;

  $c->log->info("Processing new create request");

  my $template_file;
  if ( $node_req->{template} eq "smartos64" ) {
    $template_file = "ZONE.json";
  }
  else {
    $template_file = "KVM.json";
  }

  my $json_in;
  {
    local $/; #enable slurp
    open my $fh, "<", "/zones/machines/$template_file";
    $json_in = <$fh>;
  } 

  chomp $json_in;

  my $new_node =  $json->decode($json_in);

  my $size = $node_req->{size};
  my $node_ram  = $c->config->{node_sizes}->{ $size }->{ram};
  
  # XXX zone type should support most of this a well.
  if ( $node_req->{template} ne "smartos64" ) {
    my $node_cpu  = $c->config->{node_sizes}->{ $size }->{cpu};
    my $node_data = $c->config->{node_sizes}->{ $size }->{data};

    $new_node->{vcpus}    = $node_cpu;
    $new_node->{ram}      = $node_ram;

    $new_node->{disks}[0]->{image_uuid} = "templates/" . $node_req->{template};
    $new_node->{disks}[0]->{image_name} = $node_req->{template};
    $new_node->{disks}[1]->{size}       = $node_data;
  }
  else {
    $new_node->{max_physical_memory}  = $node_ram;
    $new_node->{max_swap}             = $node_ram;
    $new_node->{max_locked_memory}    = $node_ram;
  }

  my $new_ip = allocate_ip();
  $new_node->{nics}[0]->{ip} = $new_ip;
  $c->log->info("Allocating $new_ip");

  $new_node->{hostname} = $node_req->{hostname};
  $new_node->{alias}    = $node_req->{hostname};

  my $strrnd = new String::Random;
  my $tmp_file = $strrnd->randpattern("CCcnCncn");

  my $json_out = $json->encode( $new_node );

  open (NODE_TEMP_CONFIG, ">/var/tmp/$tmp_file.json");
  print NODE_TEMP_CONFIG $json_out;
  close (NODE_TEMP_CONFIG);

  # XXX CREATE: Add timing check, so we can say "time to build, time to boot", etc.
  # 
  # Need to redirect output until this bug is fixed:
  # https://github.com/joyent/smartos-live/issues/36
  my $vmadm = qx( /usr/sbin/vmadm create < /var/tmp/$tmp_file.json 2>&1 );
  chomp $vmadm;

  $c->log->info("vmadm: $vmadm");

  my $error;
  my $uuid;

  if ( $? eq 1 ) { 
    $error = $vmadm;
  }
  else {
    my @vmadm = split(/ /,$vmadm);  
    $uuid = $vmadm[2];
  }

  if ( $error ) {
    return $self->status_bad_request(
      $c,
      message => $error,
    );
  }

  # XXX CREATE: Check: Is the VM booted?
  # XXX CREATE:   No? Why? Tail the log, and return the last line as an error message.

  my $node_out;
  $node_out->{uuid}     = $uuid;
  $node_out->{ipaddr}   = $new_node->{nics}[0]->{ip};
  $node_out->{size}     = $size;
  $node_out->{template} = $node_req->{template};
  $node_out->{status}   = "success";
  $node_out->{action}   = "create";

  $c->log->info("Created: $uuid");

  $self->status_created(
    $c,
    # XXX CREATE: Fix location return to $uri/node/<UUID>
    location => $c->req->uri->as_string,
    entity   => $node_out,
  );
}

sub node_DELETE {
  my ( $self, $c, $uuid ) = @_;

  $c->log->info("Destroying $uuid");

  my $error;

  my $brand = qx( /usr/sbin/zonecfg -z $uuid info brand | awk '{print \$2}' );
  chomp $brand;

  # XXX DESTROY: Error checking.
  if ( $brand eq "joyent" ) {
    $c->log->info("Halting: $uuid");
    my $halt_zone = qx( /usr/sbin/zoneadm -z $uuid halt );

    my $zone_timeout = 60;

    my $i = 0;
    my $zone_status;

    while ( $i <= 60 ) {
      $zone_status = qx( /usr/sbin/zoneadm -z $uuid list -p );

      if ( $zone_status =~ /running/ ) { $c->log->info("Halting: $uuid ($i)"); }

      if ( $zone_status =~ /shutting_down/ ) { $c->log->info("Shutting down: $uuid ($i)"); }

      if ( $zone_status =~ /installed/ ) {
        $c->log->info("Halted: $uuid ($i)");
        last;
      }

      $c->log->error("$uuid still running after $i seconds, sleeping.");
      sleep(1);
      $i++;
    }

    if ( $zone_status =~ /running/ ) {
      # XXX DELETE Do something drastic if we couldn't halt a zone after 60s.
      $c->log->error("$uuid still running after 60s; moving on");
    }

    $c->log->info("Uninstalling: $uuid");
    my $uninstall_zone = qx( /usr/sbin/zoneadm -z $uuid uninstall -F );

    $c->log->info("Deleting config: $uuid");
    my $delete_zone = qx( /usr/sbin/zonecfg -z $uuid delete -F );
  }
  else {
    my $destroy_kvm = qx( /usr/sbin/vmadm destroy $uuid 2>&1 );

    if ( $? eq 1 ) {
      chomp $destroy_kvm;
      return $self->status_bad_request(
        $c,
        message => $destroy_kvm,
      );
    }

    chomp $destroy_kvm;
    
    # XXX WORKAROUND for https://github.com/joyent/smartos-live/issues/39
    my $data_vol = qx( zfs list -H tank/data/$uuid-disk1 );
    if ( $? eq 0 ) {
      my $destroy_data_vol = qx( /usr/sbin/zfs destroy tank/data/$uuid-disk1 );
      my $delete_zonecfg = qx( /usr/sbin/zonecfg -z $uuid delete -F );
      $c->log->info("WORKAROUND: destroying tank/data/$uuid-tank1 $destroy_data_vol" );
      $c->log->info("WORKAROUND: deleting zonecfg for $uuid $delete_zonecfg" );
    }
  }

  $self->status_ok(
    $c,
    entity => {
      action  => "destroy",
      uuid    => $uuid,
      message => "destroyed $uuid",
      status  => "success"
    }
  );
}

sub node_GET {
  my ( $self, $c, $uuid ) = @_;

  my @out;
  my @zones;
  my %zones;
  
  my $json = JSON->new->allow_nonref;
  $json->pretty(1);
  
  if ( $uuid ) { 
    @zones = qx( /usr/sbin/zoneadm -z $uuid list -p );
  }
  else {
    @zones = qx( /usr/sbin/zoneadm list -pc | grep -v global );
  }
  chomp @zones;
  
  foreach my $zone (@zones ) {
    my ( $zoneid, $zonename, $state, $zonepath, $uuid, $brand, $ip_type ) = split(/:/, $zone);

    my $cfg = XMLin( "/etc/zones/$uuid.xml" );

    my @nics;
    if ( ref $cfg->{network} eq "ARRAY" ) {
      @nics = @{$cfg->{network}};
    }
    else {
      push @nics,$cfg->{network};
    }

    foreach my $nic ( @nics ) {
      $zones{$zonename}{network}{ $nic->{physical} }->{index} = $nic->{'net-attr'}->{index}->{value};
      $zones{$zonename}{network}{ $nic->{physical} }->{ip}    = $nic->{'net-attr'}->{ip}->{value};
      $zones{$zonename}{network}{ $nic->{physical} }->{model} = $nic->{'net-attr'}->{model}->{value};

      $zones{$zonename}{network}{ $nic->{physical} }->{'global-nic'} = $nic->{'global-nic'};
    }

    if ( $cfg->{device} ) {
      my @devices;
      if ( ref $cfg->{device} eq "ARRAY" ) {
        @devices = @{$cfg->{device}};
      }
      else {
        push @devices,$cfg->{device};
      }

      foreach my $device ( @devices ) {
        if ( $device->{'net-attr'}->{'image-name'}->{value} ) {
          $zones{$zonename}{template} = $device->{'net-attr'}->{'image-name'}->{value};
        }
  
        if ( $device->{'match'} =~ /zvol/ ) {
          my $index = $device->{'net-attr'}->{index}->{value};
          my $size  = $device->{'net-attr'}->{size}->{value};
          my $boot  = $device->{'net-attr'}->{boot}->{value};
          my $volume = $device->{match};

          $volume =~ s#/dev/zvol/rdsk/##;
          populate_storage( \%zones, $zonename, $volume );

          $zones{$zonename}{storage}{ $volume }->{index} = $index;
          $zones{$zonename}{storage}{ $volume }->{boot}  = $boot;
          $zones{$zonename}{storage}{ $volume }->{size}  = $size;
        }
      }
    }

    if ( $cfg->{dataset} ) {
      my $zfshash;
      if ( $cfg->{dataset}->{name} ) {
        $zfshash->{ $cfg->{dataset}->{name} } = { };
      }
      else {
        $zfshash = $cfg->{dataset};
      }

      foreach my $dataset ( keys $zfshash ) {
        populate_storage( \%zones, $zonename, $dataset ); 
      }
    }

    if ( $brand eq "joyent" ) {
      my $zonepath = $cfg->{zonepath};
      my $zoneroot = qx( /sbin/zfs mount | /bin/grep "$zonepath\$" | /bin/awk '{print \$1}' );
      chomp $zoneroot;
      populate_storage( \%zones, $zonename, $zoneroot );

      $zones{$zonename}{storage}{ $zoneroot }->{boot} = "true";
    }

    $zones{$zonename}{state} = $state;
    $zones{$zonename}{brand} = $brand;
    $zones{$zonename}{hostname} = $cfg->{attr}->{hostname}->{value};

    if ( $brand eq "kvm" ) {
      # XXX This is a vmadm bug that should be fixed.
      # Sometimes vmadmd will get confused as to whether a VM is actually running
      # or not. It will say the VM is "off" but the zone will actually be
      # running. Restarting vmadmd is a crappy workaround.
      my $kvm_state = qx( /usr/sbin/vmadm list -v | grep $uuid | awk '{print \$4}' );
      chomp $kvm_state;
  
      if ( $kvm_state ne "running" && $state eq "running" ) {
        $c->log->error("KVM state for $uuid is $kvm_state, but the zone is $state! Please restart vmadmd!");
        #$c->log->error("Restarting vmadm to clear bad kvm/zone state for $uuid");
        #my $vmadmd_restart = qx( /usr/sbin/svcadm restart vmadmd );
      }

      # Grab some useful config information from kvm machines. vmadm dumps JSON,
      # so we need to decode it back to a Perl structure.
      if ( $kvm_state eq "running" ) { 
        my $kvm_json = qx( /usr/sbin/vmadm info $uuid );
        my $kvm = $json->decode ($kvm_json);

        $zones{$zonename}{vnc} = $kvm->{vnc};
        $zones{$zonename}{chardev} = $kvm->{chardev};
      }
    }
  }
  
  $self->status_ok(
    $c,
    entity => { %zones }
  );
}

sub populate_storage {
  my ( $zones, $zonename, $dataset ) = @_;

  my @children;

  # vzols cannot have child datasts, so we need to determine the dataset type
  # or the zfs list below fails.
  my $dataset_type = qx( /sbin/zfs get -Ho value type $dataset );
  chomp $dataset_type;

  if ( $dataset_type eq "volume" ) {
    push @children,$dataset;
  }
  else {
    @children = qx( /sbin/zfs list -o name -H -t filesystem -r $dataset );
    chomp @children;
  }

  # Here we loop through each zfs dataset and grab useful properties.
  foreach my $zfs ( @children ) {
    foreach my $property ( qw/ mountpoint quota used compressratio type/ ) {
      my $value = qx( /sbin/zfs get -Ho value $property $zfs );
      chomp $value;
      $zones->{$zonename}{storage}{ $zfs }->{$property} = $value;
     }

    if ( $zfs ne $dataset ) {
      $zones->{$zonename}{storage}{ $zfs }->{parent} = $dataset;
    }
  }
}

# XXX IP ALLOCATION: Gods below but this is bad.
sub allocate_ip {
  my $range   = 100;
  my $minimum = 100;
  my $host_octet = int(rand($range)) + $minimum;
  my $free_ip = qx( /usr/sbin/arp 10.21.200.$host_octet );
  if ( $? == 0 ) {
    allocate_ip();
  }

  return "10.21.200.$host_octet";
}

=head1 AUTHOR

Bryan Horstmann-Allen <bda@mirrorshades.net>

=cut

__PACKAGE__->meta->make_immutable;

1;
