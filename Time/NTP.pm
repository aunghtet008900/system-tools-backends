#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# NTP Configuration handling
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

package Time::NTP;

sub get_config_file ()
{
  my %dist_map =
  (
    "redhat-6.0"      => "redhat-6.2",
    "redhat-6.1"      => "redhat-6.2",
    "redhat-6.2"      => "redhat-6.2",

    "redhat-7.0"      => "redhat-6.2",
    "redhat-7.1"      => "redhat-6.2",
    "redhat-7.2"      => "redhat-6.2",
    "redhat-7.3"      => "redhat-6.2",
    "redhat-8.0"      => "redhat-6.2",
    "redhat-9"        => "redhat-6.2",
    "openna-1.0"      => "redhat-6.2",

    "mandrake-7.1"    => "redhat-6.2",
    "mandrake-7.2"    => "redhat-6.2",
    "mandrake-9.0"    => "redhat-6.2",
    "mandrake-9.1"    => "redhat-6.2",
    "mandrake-9.2"    => "redhat-6.2",
    "mandrake-10.0"   => "redhat-6.2",
    "mandrake-10.1"   => "redhat-6.2",

    "debian-2.2"      => "redhat-6.2",
    "debian-3.0"      => "redhat-6.2",
    "debian-sarge"    => "redhat-6.2",

    "suse-7.0"        => "redhat-6.2",
    "suse-9.0"        => "redhat-6.2",
    "suse-9.1"        => "redhat-6.2",

    "turbolinux-7.0"  => "redhat-6.2",
    
    "slackware-8.0.0" => "redhat-6.2",
    "slackware-8.1"   => "redhat-6.2",
    "slackware-9.0.0" => "redhat-6.2",
    "slackware-9.1.0" => "redhat-6.2",
    "slackware-10.0.0" => "redhat-6.2",
    "slackware-10.1.0" => "redhat-6.2",

    "gentoo"          => "redhat-6.2",

    "pld-1.0"         => "pld-1.0",
    "pld-1.1"         => "pld-1.0",
    "pld-1.99"        => "pld-1.0",
    "fedora-1"        => "redhat-6.2",
    "fedora-2"        => "redhat-6.2",
    "fedora-3"        => "redhat-6.2",
    
    "specifix"        => "redhat-6.2",

    "vine-3.0"        => "redhat-6.2",
    "vine-3.1"        => "redhat-6.2",

    "freebsd-5"       => "redhat-6.2",
    "freebsd-6"       => "redhat-6.2",
  );

  my %dist_table =
  (
    "redhat-6.2" => "/etc/ntp.conf",
    "pld-1.0"    => "/etc/ntp/ntp.conf"
  );

  my $dist = $dist_map{$Utils::Backend::tool{"platform"}};
  return $dist_table{$dist} if $dist;

  &Utils::Report::do_report ("platform_no_table", $$tool{"platform"});
  return undef;
}

sub get_ntp_servers
{
  $ntp_conf = &get_config_file ();

  return &Utils::Parse::split_all_array_with_pos ($ntp_conf, "server", 0, "[ \t]+", "[ \t]+");
}

sub get
{
  return &get_ntp_servers ();
}

1;
