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
# $MCom: portstools/tinderbox/lib/TBConfig.pm,v 1.3 2005/07/20 03:19:03 marcus Exp $
#

package TBConfig;

use strict;
use TinderObject;
use vars qw(@ISA);
@ISA = qw(TinderObject);

sub new {
        my $that        = shift;
        my $object_hash = {
                Config_Option_Name  => "",
                Config_Option_Value => "",
                Host_Id             => "",
        };

        my @args = ();
        push @args, $object_hash, @_;

        $that->SUPER::new(@args);
}

sub getOptionName {
        my $self = shift;

        return $self->{Config_Option_Name};
}

sub getOptionValue {
        my $self = shift;

        return $self->{Config_Option_Value};
}

sub getHostId {
        my $self = shift;

        return $self->{Host_Id};
}

sub setOptionName {
        my $self = shift;
        my $name = shift;

        $self->{Config_Option_Name} = $name;
}

sub setOptionValue {
        my $self  = shift;
        my $value = shift;

        $self->{Config_Option_Value} = $value;
}

sub setHostId {
        my $self   = shift;
        my $hostid = shift;

        $self->{Host_Id} = $hostid;
}

1;
