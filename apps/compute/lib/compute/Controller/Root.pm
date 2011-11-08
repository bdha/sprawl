package compute::Controller::Root;
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

sub index :Path :Args(0) {
  my ( $self, $c ) = @_;
  $c->response->body( $c->welcome_message );
}

sub default :Path {
  my ( $self, $c ) = @_;
  $c->response->body( 'Page not found' );
  $c->response->status(404);
}

sub sizes : Local : ActionClass('REST') { } 

sub sizes_GET {
  my ( $self, $c ) = @_;

  $self->status_ok(
    $c,
    entity => { %{$c->config->{node_sizes}} }
  );
}

=head1 AUTHOR

Super-User

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
