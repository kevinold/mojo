# Copyright (C) 2008-2009, Sebastian Riedel.

package MojoliciousTestController;

use strict;
use warnings;

use base 'Mojolicious::Controller';

# My folks were always on me to groom myself and wear underpants.
# What am I, the pope?
sub index {
    my $self = shift;
    $self->res->headers->header('X-Bender', 'Kiss my shiny metal ass!');
    $self->render(text => "No class works!");
}

1;
