#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# DBus object for the Shares list
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

package SharesList;

use base qw(Net::DBus::Object);
use Shares::Exports;

my $OBJECT_NAME = "SharesList";
my $SHARES_PATH = $Utils::Backend::DBUS_PATH . "/" . $OBJECT_NAME;

sub new
{
  my $class  = shift;
  my $self   = $class->SUPER::new ($SHARES_PATH,
                                   ["get"],
                                   @_);
  bless $self, $class;
#  share::monitor_share_files ($self, $OBJECT_NAME, "changed");

  return $self;
}

sub get
{
  my ($self) = @_;
  my ($smb_exports, $nfs_exports);

  ($smb_exports, $nfs_exports) = Shares::Exports::get_list ();

  return Net::DBus::dstruct ($smb_exports);
}

1;
