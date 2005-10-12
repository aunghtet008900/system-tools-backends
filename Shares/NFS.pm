#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>
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

package Shares::NFS;

use Utils::Parse;

sub get_distro_nfs_file
{
  # This is quite generic
  return "/etc/exports";
}

sub get_share_client_info
{
  my ($client) = @_;
  my ($pattern, $options_str, @options, $option);
  my ($rw);

  $client =~ /^([a-zA-Z0-9.-_*?@\/]+)/;
  $pattern = $1;
  $pattern = "0.0.0.0/0" if $pattern eq "";

  if ($client =~ /\((.+)\)/)
  {
    $option_str = $1;
    @options = ($option_str =~ /([a-zA-Z0-9_=-]+),?/mg);

    for $option (@options)
    {
      if ($option eq "rw") { $rw = 1; }
      # Add supported NFS export options here. Some might have to be split on '='.
    }
  }

  return [ $pattern, $rw ];
}

sub get_share_info
{
  my ($clients) = @_;
  my (@share_info, $client);

  foreach $client (@$clients)
  {
    push @share_info, &get_share_client_info ($client);
  }

  return \@share_info;
}

sub get
{
  my ($nfs_exports_name);
  my (@sections, @table, $entries);
  my $point, $share_info;

  $nfs_exports_name = &get_distro_nfs_file ();

  $entries = &Utils::Parse::split_hash_with_continuation ($nfs_exports_name, "[ \t]+", "[ \t]+");

  foreach $point (keys %$entries)
  {
    my $clients = $$entries{$point};

    $share_info = &get_share_info ($clients);
    push @table, [ $point, $share_info ];
  }

  return \@table;
}

1;
