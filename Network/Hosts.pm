#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# Hosts Configuration handling
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>
#          Carlos Garnacho     <carlosg@gnome.org>
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

package Network::Hosts;

sub get
{
  my ($statichosts, @arr);

  $statichosts = &Utils::Parse::split_hash ("/etc/hosts", "[ \t]+", "[ \t]+");

  foreach $i (sort keys %$statichosts)
  {
    push @arr, [$i, $$statichosts{$i}];
  }

  return \@arr;
}

sub get_dns
{
  my (@dns);

  @dns = &Utils::Parse::split_all_unique_hash_comment ("/etc/resolv.conf", "nameserver", "[ \t]+");

  return @dns;
}

sub get_search_domains
{
  my (@search_domains);

  @search_domains = &Utils::Parse::split_first_array_unique ("/etc/resolv.conf", "search", "[ \t]+", "[ \t]+");

  return @search_domains;
}

1;
