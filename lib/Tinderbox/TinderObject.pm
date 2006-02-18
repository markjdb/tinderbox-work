#-
# Copyright (c) 2004-2005 FreeBSD GNOME Team <freebsd-gnome@FreeBSD.org>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.
#
# $MCom: portstools/tinderbox/lib/Tinderbox/TinderObject.pm,v 1.15 2006/02/18 19:57:21 marcus Exp $
#

package Tinderbox::TinderObject;

use strict;
use vars qw(@ISA);
@ISA = qw(Exporter);

sub new {
        my ($that, @args) = @_;
        my $class = ref($that) || $that;

        my $attrs        = $args[1];
        my $_truth_array = {
                'f' => '0',
                't' => '1',
                '0' => '0',
                '1' => '1',
        };

        my $self = {
                _object_hash => $args[0],
                _id_field    => undef,
                _truth_array => $_truth_array,
        };
        foreach my $key (keys %{$attrs}) {
                $self->{$key} = $attrs->{$key}
                    if (defined($self->{'_object_hash'}->{$key}));
        }
        bless($self, $class);
        $self;
}

sub toHashRef {
        my $self    = shift;
        my $hashRef = {};

        foreach (keys %{$self->{'_object_hash'}}) {
                if (
                        defined($self->{$_})
                        && (
                                $_ ne $self->{'_id_field'}
                                || (       $_ eq $self->{'_id_field'}
                                        && $self->{$_} ne "")
                        )
                    )
                {
                        $hashRef->{$_} = $self->{$_};
                }
        }

        return $hashRef;
}

1;
