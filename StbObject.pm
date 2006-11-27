#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
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

package StbObject;

use base qw(Net::DBus::Object);
use Net::DBus::Exporter ($Utils::Backend::DBUS_PREFIX);

sub new
{
  my $class   = shift;
  my $path    = shift;
  my $name    = shift;

  my $bus = &Utils::Backend::get_bus ();
  my $service = $bus->export_service ($Utils::Backend::DBUS_PREFIX . ".$name");
  my $self = $class->SUPER::new ($service, $path);

  bless $self, $class;
  &Utils::Backend::ensure_platform ();

  return $self;
}

sub reset_counter
{
  &Utils::Backend::initialize_timer (\%Utils::Backend::tool);
}

1;
