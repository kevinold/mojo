# Copyright (C) 2008-2009, Sebastian Riedel.

package MojoX::Renderer;

use strict;
use warnings;

use base 'Mojo::Base';

use File::Spec;
use MojoX::Types;

__PACKAGE__->attr([qw/default_handler precedence/]);
__PACKAGE__->attr('handler', default => sub { {} });
__PACKAGE__->attr('types',   default => sub { MojoX::Types->new });
__PACKAGE__->attr('root',    default => '/');

# This is not how Xmas is supposed to be.
# In my day Xmas was about bringing people together, not blowing them apart.
sub add_handler {
    my $self = shift;

    # Merge
    my $handler = ref $_[0] ? $_[0] : {@_};
    $handler = {%{$self->handler}, %$handler};
    $self->handler($handler);

    return $self;
}

sub render {
    my ($self, $c) = @_;

    # We got called
    $c->stash->{rendered} = 1;

    # Partial?
    my $partial = delete $c->stash->{partial};

    my ($output, $template);

    # Text
    if (my $text = delete $c->stash->{text}) {
        $output = $text;
        $template =
          $self->_fix_template($c, delete $c->stash->{template} || '');
        $c->stash->{inner_template} = $output if $c->stash->{layout};
    }

    # Template
    elsif ($template = delete $c->stash->{template}) {

        # Fix
        return unless $template = $self->_fix_template($c, $template);

        # Render
        if ($self->_render_template($c, $template, \$output)) {
            $c->stash->{inner_template} = $output if $c->stash->{layout};
        }
    }

    # Layout
    if (my $layout = delete $c->stash->{layout}) {

        # Fix
        $template = File::Spec->catfile('layouts', $layout);
        return unless $template = $self->_fix_template($c, $template);

        # Render
        $self->_render_template($c, $template, \$output);
    }

    # Partial
    return $output if $partial;

    # Response
    my $res = $c->res;
    $res->code(200) unless $res->code;
    $res->body($output) unless $res->body;

    # Extract format
    $template =~ /\.(\w+)(?:\.\w+)?$/;
    my $format = $1;

    # Type
    my $type = $self->types->type($format) || 'text/plain';
    $res->headers->content_type($type) unless $res->headers->content_type;

    # Success!
    return 1;
}

sub _detect_default_handler {
    my $self = shift;
    return 1
      if $self->default_handler && -f File::Spec->catfile($self->root, shift);
}

sub _fix_format {
    my ($self, $c, $template) = @_;

    # Format ok
    return $template if $template =~ /\.\w+(?:\.\w+)?$/;

    my $format = $c->stash->{format};

    # Append format
    if ($format) { $template .= ".$format" }

    # Missing format
    else {
        $c->app->log->debug('Template format missing.');
        return;
    }

    return $template;
}

sub _fix_handler {
    my ($self, $c, $template) = @_;

    # Handler ok
    return $template if $template =~ /\.\w+\.\w+$/;

    my $handler = $c->stash->{handler};

    # Append handler
    if ($handler) { $template .= ".$handler" }

    # Detect
    elsif (!$self->_detect_default_handler($template)) {
        for my $ext (@{$self->precedence}) {

            # Try
            my $t = "$template.$ext";
            if (-r File::Spec->catfile($self->root, $t)) {
                $c->app->log->debug(qq/Template found "$t"./);
                return $t;
            }
        }

        # Try the default handler if nothing else matches
        my $default = $self->default_handler;
        return "$template.$default" if $default;

        # Nothing found
        $c->app->log->debug(qq/Template not found "$template.*"./);
        return;
    }

    return $template;
}

sub _fix_template {
    my ($self, $c, $template) = @_;

    # Handler precedence
    $self->precedence([sort keys %{$self->handler}])
      unless $self->precedence;

    # Make sure we are portable
    $template = File::Spec->catfile(split '/', $template) if $template;

    # Format
    return unless $template = $self->_fix_format($c, $template);

    # Handler
    return unless $template = $self->_fix_handler($c, $template);

    return $template;
}

sub _render_template {
    my ($self, $c, $template, $output) = @_;

    # Nothing to do
    return unless $template;

    # Extract handler
    $template =~ /\.\w+\.(\w+)$/;
    my $handler = $c->stash->{handler} || $1 || $self->default_handler;

    # Renderer
    my $r = $self->handler->{$handler};

    # No handler
    unless ($r) {
        $c->app->log->error(qq/No handler for "$handler" available./);
        return;
    }

    # Render
    local $c->stash->{template} = $template;
    return unless $r->($self, $c, $output);

    # Success!
    return 1;
}

1;
__END__

=head1 NAME

MojoX::Renderer - Renderer

=head1 SYNOPSIS

    use MojoX::Renderer;

    my $renderer = MojoX::Renderer->new;

=head1 DESCRIPTION

L<MojoX::Renderer> is a MIME type based renderer.

=head2 ATTRIBUTES

=head2 C<default_handler>

    my $default = $renderer->default_handler;
    $renderer   = $renderer->default_handler('epl');

=head2 C<handler>

    my $handler = $renderer->handler;
    $renderer   = $renderer->handler({epl => sub { ... }});

=head2 C<precedence>

    my $precedence = $renderer->precedence;
    $renderer      = $renderer->precedence(qw/epl tt mason/);

=head2 C<types>

    my $types = $renderer->types;
    $renderer = $renderer->types(MojoX::Types->new);

=head2 C<root>

   my $root  = $renderer->root;
   $renderer = $renderer->root('/foo/bar/templates');

=head1 METHODS

L<MojoX::Types> inherits all methods from L<Mojo::Base> and implements the
follwing the ones.

=head2 C<add_handler>

    $renderer = $renderer->add_handler(epl => sub { ... });

=head2 C<render>

    my $success  = $renderer->render($c);

    $c->stash->{partial} = 1;
    my $output = $renderer->render($c);

=cut
