#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# DBus object for the Services list
#
# Copyright (C) 2005 Carlos Garnacho
#
# Authors: Carlos Garnacho Parro  <carlosg@gnome.org>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU Library General Public License as published
# by the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Library General Public License for more details.
#
# You should have received a copy of the GNU Library General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.

package ServicesList;

use base qw(Net::DBus::Object);
use Init::Services;

my $OBJECT_NAME = "/ServicesList";

sub new
{
  my $class  = shift;
  my $self   = $class->SUPER::new ($OBJECT_NAME,
                                   {
                                     $OBJECT_NAME => {
                                       methods => {
                                         "get" => {
                                           params  => [],
                                           returns => [[ "dict", "string", [ "dict", "string", "string" ]]],
                                         },
                                       },
                                     },
                                   },
                                   @_);
  bless $self, $class;
  return $self;
}

sub get
{
  my ($self) = @_;
  my ($services);

  $services = Services::Services::gst_service_get_services ();
  return $services;
}

1;
