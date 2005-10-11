#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# Time/Date Configuration handling
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>
#          Carlos Garnacho     <carlosg@gnome.org>
#          Grzegorz Golawski <grzegol@pld-linux.org> (PLD Support)
#          James Ogley <james@usr-local-bin.org> (SuSE 9.0 support)
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

package Time::TimeDate;

sub get_local_time
{
  my (%h, $trash);

  ($h{"second"}, $h{"minute"}, $h{"hour"}, $h{"monthday"}, $h{"month"}, $h{"year"},
   $trash, $trash, $trash) = localtime (time);

  $h{"month"}++;
  $h{"year"} += 1900;

  return \%h;
}

sub get_timezone
{
  my ($local_time_file, $zoneinfo_dir) = @_;
  local *TZLIST;
  my $zone;
  my $size_search;
  my $size_test;

  *TZLIST = &Utils::File::open_read_from_names($zoneinfo_dir . "/zone.tab");
  if (not *TZLIST) { return; }

  &Utils::Report::do_report ("time_timezone_scan");

  # Get the filesize for /etc/localtime so that we don't have to execute
  # a diff for every file, only for file with the correct size. This speeds
  # up loading 
  $size_search = (stat ($local_time_file))[7];

  while (<TZLIST>)
  {
    if (/^\#/) { next; }                   # Skip comments.
    ($d, $d, $zone) = split /[\t ]+/, $_;  # Get 3rd column.
    chomp $zone;                           # Remove linefeeds.


    # See if this zone file matches the installed one.
    &Utils::Report::do_report ("time_timezone_cmp", $zone);
    $size_test = (stat("$zoneinfo_dir/$zone"))[7];
    if ($size_test eq $size_search)
    {
      if (!&Utils::File::run ("diff $zoneinfo_dir/$zone $local_time_file"))
      {
        # Found a match.
        last;
      }
    }
    
    $zone = "";
  }
  
  return $zone;
  close (TZLIST);
}

sub conf_get_parse_table
{
  my %dist_map =
  (
   "redhat-6.0"      => "redhat-6.2",
   "redhat-6.1"      => "redhat-6.2",
   "redhat-6.2"      => "redhat-6.2",

   "redhat-7.0"      => "redhat-7.0",
   "redhat-7.1"      => "redhat-7.0",
   "redhat-7.2"      => "redhat-7.0",
   "redhat-7.3"      => "redhat-7.0",
   "redhat-8.0"      => "redhat-7.0",
   "redhat-9"        => "redhat-7.0",
   "openna-1.0"      => "redhat-7.0",

   "mandrake-7.1"    => "redhat-7.0",
   "mandrake-7.2"    => "redhat-7.0",
   "mandrake-9.0"    => "redhat-7.0",
   "mandrake-9.1"    => "redhat-7.0",
   "mandrake-9.2"    => "redhat-7.0",
   "mandrake-10.0"   => "redhat-7.0",
   "mandrake-10.1"   => "redhat-7.0",

   "debian-2.2"      => "debian-2.2",
   "debian-3.0"      => "debian-3.0",
   "debian-sarge"    => "debian-3.0",

   "suse-7.0"        => "suse-7.0",
   "suse-9.0"        => "suse-9.0",
   "suse-9.1"        => "suse-9.0",

   "turbolinux-7.0"  => "redhat-7.0",
   
   "slackware-8.0.0" => "debian-2.2",
   "slackware-8.1"   => "debian-2.2",
   "slackware-9.0.0" => "debian-2.2",
   "slackware-9.1.0" => "debian-2.2",
   "slackware-10.0.0" => "debian-2.2",
   "slackware-10.1.0" => "debian-2.2",

   "gentoo"          => "gentoo",

   "pld-1.0"         => "pld-1.0",
   "pld-1.1"         => "pld-1.0",
   "pld-1.99"        => "pld-1.0",
   "fedora-1"        => "redhat-7.0",
   "fedora-2"        => "redhat-7.0",
   "fedora-3"        => "redhat-7.0",
   
   "specifix"        => "redhat-7.0",

   "vine-3.0"        => "redhat-7.0",
   "vine-3.1"        => "redhat-7.0",

   "freebsd-5"       => "freebsd-5",
   "freebsd-6"       => "freebsd-5",
   );

  my %dist_tables =
  (
   "redhat-6.2" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       STEP_TICKERS => "/etc/ntp/step-tickers",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_sysv_get_status, "xntpd" ],
#      [ "ntpinstalled", \&gst_service_sysv_installed, "xntpd" ],
     ]
   },

   "redhat-7.0" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_sysv_get_status, "ntpd" ],
#      [ "ntpinstalled", \&gst_service_sysv_installed, "ntpd" ],
     ]
   },

   "debian-2.2" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_first_array_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_sysv_get_status, "ntpd" ],
#      [ "ntpinstalled", \&gst_service_sysv_installed, "ntp" ],
     ]
   },

   "debian-3.0" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_sysv_get_status, "ntpd" ],
#      [ "ntpinstalled", \&gst_service_sysv_installed, "ntp-server" ],
     ]
   },

   "suse-7.0" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_sysv_get_status, "xntpd" ],
#      [ "ntpinstalled", \&gst_service_sysv_installed, "xntpd" ],
     ]
   },

   "suse-9.0" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_get_status, "xntpd" ],
#      [ "ntpinstalled", \&gst_service_installed,  "xntpd" ],
     ]
   },

   "pld-1.0" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME   => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_sysv_get_status, "ntpd" ],
#      [ "ntpinstalled", \&gst_service_sysv_installed, "ntpd" ],
     ]
   },

   "gentoo" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_gentoo_get_status, "ntpd" ],
#      [ "ntpinstalled", \&gst_service_list_any_installed, [ "ntpd", "openntpd" ]],
     ]
   },

   "freebsd-5" =>
   {
     fn =>
     {
       NTP_CONF     => "/etc/ntp.conf",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_local_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
#      [ "sync",         \&Utils::Parse::split_all_array_with_pos, NTP_CONF, "server", 0, "[ \t]+", "[ \t]+" ],
#      [ "sync_active",  \&gst_service_rcng_get_status, "ntpd" ],
#      [ "ntpinstalled", \&gst_service_installed, "ntpd" ],
     ]
   },
  );

  my $dist = $dist_map {$Utils::Backend::tool{"platform"}};
  return %{$dist_tables{$dist}} if $dist;

  &Utils::Report::do_report ("platform_no_table", $$tool{"platform"});
  return undef;
}

sub get
{
  my %dist_attrib;
  my $hash;

  %dist_attrib = &conf_get_parse_table ();

  $hash = &Utils::Parse::get_from_table ($dist_attrib{"fn"},
                                 $dist_attrib{"table"});
  $h = $$hash {"local_time"};

  return ($$h {"year"}, $$h {"month"},  $$h {"monthday"},
          $$h {"hour"}, $$h {"minute"}, $$h {"second"},
          $$hash{"timezone"});
}

1;
