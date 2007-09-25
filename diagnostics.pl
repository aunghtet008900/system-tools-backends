#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# diagnostics tool for the system tools backends.
#
# Copyright (C) 2007 Carlos Garnacho
#
# Authors: Carlos Garnacho  <carlosg@gnome.org>
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

use Utils::Backend;
use Init::Services;
use Network::Hosts;
use Network::Ifaces;
use Shares::NFS;
use Shares::SMB;
use Time::NTP;
use Time::TimeDate;
use Users::Groups;
use Users::Users;

sub print_tabified
{
  my ($tab, $str, $do_cr) = @_;

  print " " x $tab;
  print $str;
  print "\n" if ($do_cr);
}

sub print_recursive
{
  my ($obj, $tab) = @_;

  if (ref $obj eq "ARRAY")
  {
    print_tabified ($tab, "ARRAY = [", 1);

    foreach $elem (@{$obj})
    {
	 print_recursive ($elem, $tab + 2);
    }

    print_tabified ($tab, "]", 1);
  }
  elsif (ref $obj eq "HASH")
  {
    print_tabified ($tab, "HASH = {", 1);

    foreach $elem (keys %$obj)
    {
	 $sibling_ref = ref $$obj{$elem};

	 #print child arrays and hashes in a new line
      print_tabified ($tab + 2, "'$elem'\t=>" , ($sibling_ref eq "ARRAY" || $sibling_ref eq "HASH"));
      print_recursive ($$obj{$elem}, $tab + 4);
    }

    print_tabified ($tab, "}", 1);
  }
  else
  {
    print_tabified ($tab, $obj, 1);
  }
}

sub print_config
{
  my (@config) = @_;

  foreach $i (@config) {
    &print_recursive ($i, 0);
  }
}

&Utils::Backend::init (@ARGV);

if (!$Utils::Backend::tool{"platform"})
{
  print "No platform detected, try --platform <platform>\n";
  exit (-1);
}

print "GroupsConfig:\n\n";
&print_config (&Users::Groups::get ());

print "HostsConfig:\n\n";
&print_config (&Network::Hosts::get_hosts ());
&print_config (&Network::Hosts::get_dns ());
&print_config (&Network::Hosts::get_search_domains ());

print "IfacesConfig:\n\n";
&print_config (&Network::Ifaces::get ());

print "NFSConfig:\n\n";
&print_config (&Shares::NFS::get ());

print "NTPConfig:\n\n";
&print_config (&Time::NTP::get ());

print "ServicesConfig:\n\n";
&print_config (&Init::Services::get_runlevels ());
&print_config (&Init::Services::get ());

print "SMBConfig:\n\n";
&print_config (&Shares::SMB::get ());

print "TimeConfig:\n\n";
&print_config (&Time::TimeDate::get ());

print "UsersConfig:\n\n";
&print_config (&Users::Users::get ());

