# Copyright (C) 2008-2009, Sebastian Riedel.

package Mojolicious::Lite;

use strict;
use warnings;

use base 'Mojolicious';

use File::Spec;
use FindBin;
use Mojolicious::Scripts;

# Singleton
my $APP;

# It's the future, my parents, my co-workers, my girlfriend,
# I'll never see any of them ever again... YAHOOO!
sub import {
    my $class = shift;

    # Lite apps are strict!
    strict->import;
    warnings->import;

    # Home
    $ENV{MOJO_HOME} ||= File::Spec->catdir(split '/', $FindBin::Bin);

    # Initialize app
    $APP = $class->new;

    # Renderer
    $APP->renderer->default_handler('eplite');

    # Route generator
    my $route = sub {
        my $methods = shift;

        my ($cb, $constraints, $defaults, $name, $pattern);

        # Route information
        for my $arg (@_) {

            # First scalar is the pattern
            if (!ref $arg && !$pattern) { $pattern = $arg }

            # Second scalar is the route name
            elsif (!ref $arg) { $name = $arg }

            # Callback
            elsif (ref $arg eq 'CODE') { $cb = $arg }

            # Constraints
            elsif (ref $arg eq 'ARRAY') { $constraints = $arg }

            # Defaults
            elsif (ref $arg eq 'HASH') { $defaults = $arg }
        }

        # Defaults
        $cb ||= sub {1};
        $constraints ||= [];

        # Merge
        $defaults ||= {};
        $defaults = {%$defaults, callback => $cb};

        # Create route
        $APP->routes->route($pattern, {@$constraints})->via($methods)
          ->to($defaults)->name($name);
    };

    # Prepare exports
    my $caller = caller;
    no strict 'refs';

    # Export
    *{"${caller}::app"}  = sub {$APP};
    *{"${caller}::any"}  = sub { $route->(ref $_[0] ? shift : [], @_) };
    *{"${caller}::get"}  = sub { $route->('get', @_) };
    *{"${caller}::post"} = sub { $route->('post', @_) };

    # Shagadelic!
    *{"${caller}::shagadelic"} = sub {

        # We are the app in a lite environment
        $ENV{MOJO_APP} = 'Mojolicious::Lite';

        # Start script system
        Mojolicious::Scripts->new->run(@_ ? @_ : @ARGV);
    };
}

# Steven Hawking, aren't you that guy who invented gravity?
# Sure, why not.
sub new { $APP || shift->SUPER::new(@_) }

1;
__END__

=head1 NAME

Mojolicious::Lite - Micro Web Framework

=head1 SYNOPSIS

    # Using Mojolicious::Lite will enable "strict" and "warnings"
    use Mojolicious::Lite;

    # Route with placeholder
    get '/:foo' => sub {
        my $self = shift;
        $self->render(text => 'Yea baby!');
    };

    # Start the Mojolicious script system
    shagadelic;

=head1 DESCRIPTION

L<Mojolicous::Lite> is a micro web framework built around L<Mojolicious>.

A minimal application looks like this.

    #!/usr/bin/env perl

    use Mojolicious::Lite;

    get '/' => sub {
        my $self = shift;
        $self->render(text => 'Yea baby!');
    };

    shagadelic;

There is also a helper script to generate a small example application.

    % mojolicious generate lite_app

All the normal L<Mojolicious> script options are available from the command
line.

    % ./myapp.pl daemon
    Server available at http://127.0.0.1:3000.

    % ./myapp.pl daemon 8080
    Server available at http://127.0.0.1:8080.

    % ./myapp.pl daemon_prefork
    Server available at http://127.0.0.1:3000.

    % ./myapp.pl cgi
    ...CGI output...

    % ./myapp.pl fastcgi
    ...Blocking FastCGI main loop...

The shagadelic call that starts the L<Mojolicious> script system can be
customized to override normal C<@ARGV> use.

    shagadelic('cgi');

Routes are basically just fancy paths that can contain different kinds of
placeholders.

    # /foo
    get '/foo' => sub {
        my $self = shift;
        $self->render(text => 'Yea baby!');
    };

All routes can have a name associated with them, this allows automatic
template detection and back referencing with C<url_for>.

    # /
    get '/' => 'index';

    # /foo
    get '/foo' => 'foo';

    __DATA__

    @@ index.html.eplite
    <a href="<%= shift->url_for('foo') %>">Foo</a>.

    @@ foo.html.eplite
    <a href="<%= shift->url_for('index') %>">Home</a>.

Templates can have layouts.

    # GET /with_layout
    get '/with_layout' => sub {
        my $self = shift;
        $self->render(template => 'with_layout', layout => 'green');
    };

    __DATA__

    @@ with_layout.html.eplite
    We've got content!

    @@ layouts/green.html.eplite
    <!html>
        <head><title>Green!</title></head>
        <body><%= shift->render_inner %></body>
    </html>

Route placeholders allow capturing parts of a request path until a C</> or
C<.> separator occurs, results will be stored by name in the C<stash>.

    # /foo/*
    get '/foo/:bar' => sub {
        my $self = shift;
        my $bar  = $self->stash('bar');
        $self->render(text => "Our :bar placeholder matched $bar");
    };

    # /*something/foo
    get '/(:bar)something/foo' => sub {
        my $self = shift;
        my $bar  = $self->stash('bar');
        $self->render(text => "Our :bar placeholder matched $bar");
    };

Relaxed placeholders allow matching of everything until a C</> occurs.

    # GET /hello/*
    get '/hello/(.you)' => sub {
        shift->render(template => 'groovy');
    };

    __DATA__

    @@ groovy.html.eplite
    Your name is <%= shift->stash('you') %>.

Wildcard placeholders allow matching absolutely everything, including
C</> and C<.>.

    # /hello/*
    get '/hello/(*you)' => sub {
        shift->render(template => 'groovy');
    };

    __DATA__

    @@ groovy.html.eplite
    Your name is <%= shift->stash('you') %>.

Routes can be restricted to specific request methods.

    # GET /bye
    get '/bye' => sub { shift->render(text => 'Bye!') };

    # POST /bye
    post '/bye' => sub { shift->render(text => 'Bye!') };

    # GET|POST|DELETE /bye
    any [qw/get post delete/] => '/bye' => sub {
        shift->render(text => 'Bye!');
    };

    # /baz
    any '/baz' => sub {
        my $self   = shift;
        my $method = $self->req->method;
        $self->render(text => "You called /baz with $method");
    };

All placeholders get compiled to a regex internally, with regex constraints
this process can be easily customized.

    # /*
    any '/:bar' => [bar => qr/\d+/] => sub {
        my $self = shift;
        my $bar  = $self->stash('bar');
        $self->render(text => "Our :bar placeholder matched $bar");
    };

Routes allow default values to make placeholders optional.

    # /hello/*
    get '/hello/:name' => {name => 'Sebastian'} => sub {
        my $self = shift;
        $self->render(template => 'groovy', format => 'txt');
    };

    __DATA__

    @@ groovy.txt.eplite
    % my $self = shift;
    My name is <%= $self->stash('name') %>.

All those features can be easily used together.

    # /everything/*?name=*
    get '/everything/:stuff' => [stuff => qr/\d+/] => {stuff => 23} => sub {
        shift->render(template => 'welcome');
    };

    __DATA__

    @@ welcome.html.eplite
    % my $self = shift;
    Stuff is <%= $self->stash('stuff') %>.
    Query param name is <%= $self->req->param('name') %>.

Here's a fully functional example for a html form handling application using
multiple features at once.

    #!/usr/bin/env perl

    use Mojolicious::Lite;

    get '/' => 'index';

    post '/form' => 'form' => sub {
        my $self = shift;

        my $groovy = $self->req->param('groovy') || 'Austin Powers';
        $groovy =~ s/[^\w\s]+//g;

        $self->render(
            template => 'welcome',
            layout   => 'funky',
            groovy   => $groovy
        );
    };

    shagadelic;
    __DATA__

    @@ index.html.eplite
    % my $self = shift;
    % $self->stash(layout => 'funky');
    Who is groovy?
    <form action="<%= $self->url_for('form') %>" method="POST">
        <input type="text" name="groovy" />
        <input type="submit" value="Woosh!">
    </form>

    @@ welcome.html.eplite
    % my $self = shift;
    <%= $self->stash('groovy') %> is groovy!
    <%= $self->render_partial(template => 'menu') %>

    @@ menu.html.eplite
    <a href="<%= shift->url_for('index') %>">Try again</a>

    @@ layouts/funky.html.eplite
    % my $self = shift;
    <!html>
        <head><title>Funky!</title></head>
        <body>
            <%= $self->render_inner %>
        </body>
    </html>

Formats can be automatically detected by looking at file extensions.

    # /detection.html
    # /detection.txt
    get '/detection' => sub {
        my $self = shift;
        $self->render(template => 'detected');
    };

    __DATA__

    @@ detected.html.eplite
    <!html>
        <head><title>Detected!</title></head>
        <body>HTML was detected.</body>
    </html>

    @@ detected.txt.eplite
    TXT was detected.

External templates will be searched by the renderer in a C<templates>
directory.

    # /external
    any '/external' => sub {
        my $self = shift;
        $self->render(template => 'foo/bar.html.epl');
    };

Static files will be automatically served from the C<public> directory if it
exists.

    % mkdir public
    % mv something.js public/something.js

To disable debug messages later in a production setup you can change the
L<Mojolicious> mode, default will be C<development>.

    % MOJO_MODE=production ./myapp.pl

Log messages will be automatically written to a C<log/$mode.log> file if a
C<log> directory exists.

    % mkdir log

For more control the L<Mojolicious> instance can be accessed directly.

    app->log->level('error');
    app->routes->route('/foo/:bar')->via('get')->to(callback => sub {
        my $self = shift;
        $self->render(text => 'Hello Mojo!');
    });

In case a lite app needs to grow, lite and real L<Mojolicous> applications
can be easily mixed to make the transition process very smooth.

    package MyApp::Foo;
    use base 'Mojolicious::Controller';

    sub index {
        shift->render(text => 'It works!');
    }

    package main;
    use Mojolicious::Lite;

    get '/bar' => sub { shift->render(text => 'This too!') };

    app->routes->namespace('MyApp');
    app->routes->route('/foo/:action')->via('get')
      ->to(controller => 'foo', action => index);

    shagadelic;

=head1 ATTRIBUTES

L<Mojolicious::Lite> inherits all attributes from L<Mojolicious>.

=head1 METHODS

L<Mojolicious::Lite> inherits all methods from L<Mojolicious> and implements
the following new ones.

=head2 C<new>

    my $mojo = Mojolicious::Lite->new;

=cut
