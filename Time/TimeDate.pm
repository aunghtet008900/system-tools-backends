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

use File::Copy;

sub get_utc_time
{
  my (%h, $trash);

  ($h{"second"}, $h{"minute"}, $h{"hour"}, $h{"monthday"}, $h{"month"}, $h{"year"},
   $trash, $trash, $trash) = gmtime (time);

  $h{"year"} += 1900;

  return \%h;
}

# This function will force date format when setting time
sub change_timedate
{
  my ($time) = @_;
  my ($command);

  my $system_table = {
    "Linux"   => "date -u %02d%02d%02d%02d%04d.%02d",
    "FreeBSD" => "date -u -f %%m%%d%%H%%M%%Y.%%S  %02d%02d%02d%02d%04d.%02d"
  };

  $command = sprintf ($$system_table {$Utils::Backend::tool{"system"}},
                      $$time{"month"} + 1, $$time{"monthday"},
                      $$time{"hour"},  $$time{"minute"}, 
                      $$time{"year"},  $$time{"second"});

  &Utils::Report::do_report ("time_localtime_set", $command);
  return &Utils::File::run ($command);
}

sub set_utc_time
{
  my ($time) = @_;
  my ($res, $xscreensaver_owners);

  &Utils::Report::enter ();

  # FIXME: restore this, take into account other screensavers
  # Kill screensaver, so it doesn't confuse the users.
#  $xscreensaver_owners = &gst_service_proc_get_owners ("xscreensaver");
#  &gst_service_proc_stop_all  ("xscreensaver");

  $res = &change_timedate ($time);

  # Restart screensaver.
#  &gst_service_proc_start_all ("xscreensaver -no-splash", $xscreensaver_owners);

  &Utils::Report::leave ();
  return -1 if $res;
  return 0;
}

sub time_sync_hw_from_sys
{
  &Utils::File::run ("hwclock --systohc");
  return 0;
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

sub set_timezone
{
  my ($localtime, $zonebase, $timezone) = @_;

  &Utils::Report::enter ();
  &Utils::Report::do_report ("time_timezone_set", $timezone);

  $tz = "$zonebase/$timezone";

  if (stat($tz) ne "")
  {
    unlink $localtime;  # Important, since it might be a symlink.
    
    &Utils::Report::enter ();
    $res = copy ($tz, $localtime);
    &Utils::Report::leave ();
    return -1 unless $res;
    return 0;
  }

  &Utils::Report::leave ();
  return -1;
}

sub conf_get_parse_table
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
   "debian-3.0"      => "debian-3.0",
   "debian-sarge"    => "debian-3.0",

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
   "slackware-10.2.0" => "redhat-6.2",

   "gentoo"          => "redhat-6.2",
   "vlos-1.2"        => "redhat-6.2",

   "archlinux"       => "archlinux",

   "pld-1.0"         => "redhat-6.2",
   "pld-1.1"         => "redhat-6.2",
   "pld-1.99"        => "redhat-6.2",
   "fedora-1"        => "redhat-6.2",
   "fedora-2"        => "redhat-6.2",
   "fedora-3"        => "redhat-6.2",
   "rpath"           => "redhat-6.2",

   "vine-3.0"        => "redhat-6.2",
   "vine-3.1"        => "redhat-6.2",

   "freebsd-5"       => "redhat-6.2",
   "freebsd-6"       => "redhat-6.2",
   );

  my %dist_tables =
  (
   "redhat-6.2" =>
   {
     fn =>
     {
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME   => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_utc_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
     ]
   },

   "debian-3.0" =>
   {
     fn =>
     {
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME   => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_utc_time ],
      [ "timezone",     \&get_timezone, [LOCAL_TIME, ZONEINFO] ],
     ]
   },

   "archlinux" =>
   {
     fn =>
     {
       RC_LOCAL     => "/etc/rc.local",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME   => "/etc/localtime"
     },
     table =>
     [
      [ "local_time",   \&get_utc_time ],
      [ "timezone",     \&Utils::Parse::get_sh, RC_LOCAL, TIMEZONE ],
     ]
   },
  );

  my $dist = $dist_map {$Utils::Backend::tool{"platform"}};
  return %{$dist_tables{$dist}} if $dist;

  &Utils::Report::do_report ("platform_no_table", $Utils::backend::tool{"platform"});
  return undef;
}

sub conf_get_replace_table
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
   "debian-3.0"      => "debian-3.0",
   "debian-sarge"    => "debian-3.0",

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
   "slackware-10.2.0" => "redhat-6.2",

   "gentoo"          => "redhat-6.2",
   "vlos-1.2"        => "redhat-6.2",

   "archlinux"       => "archlinux",

   "pld-1.0"         => "redhat-6.2",
   "pld-1.1"         => "redhat-6.2",
   "pld-1.99"        => "redhat-6.2",
   "fedora-1"        => "redhat-6.2",
   "fedora-2"        => "redhat-6.2",
   "fedora-3"        => "redhat-6.2",
   "rpath"           => "redhat-6.2",

   "vine-3.0"        => "redhat-6.2",
   "vine-3.1"        => "redhat-6.2",

   "freebsd-5"       => "redhat-6.2",
   "freebsd-6"       => "redhat-6.2",
   );

  my %dist_tables =
  (
   "redhat-6.2" =>
   {
     fn =>
     {
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME    => "/etc/localtime"
     },
     table =>
     [
      [ "timezone",    \&set_timezone, [LOCAL_TIME, ZONEINFO] ],
      [ "local_time",  \&set_utc_time ],
     ]
   },
       
   "debian-3.0" =>
   {
     fn =>
     {
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME   => "/etc/localtime",
       TIMEZONE     => "/etc/timezone"
     },
     table =>
     [
      [ "timezone",    \&set_timezone, [LOCAL_TIME, ZONEINFO] ],
      [ "timezone",    \&Utils::Replace::set_first_line, TIMEZONE ],
      [ "local_time",  \&set_utc_time ],
     ]
   },

   "archlinux" =>
   {
     fn =>
     {
       RC_LOCAL     => "/etc/rc.local",
       ZONEINFO     => "/usr/share/zoneinfo",
       LOCAL_TIME   => "/etc/localtime",
     },
     table =>
     [
      [ "timezone",    \&Utils::Replace::set_sh, RC_LOCAL, TIMEZONE ],
      [ "timezone",    \&set_timezone, [LOCAL_TIME, ZONEINFO] ],
      [ "local_time",  \&set_utc_time ],
     ]
   },
  );

  my $dist = $dist_map {$Utils::Backend::tool{"platform"}};
  return %{$dist_tables{$dist}} if $dist;

  &Utils::Report::do_report ("platform_no_table", $Utils::Backend::tool{"platform"});
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

sub set
{
  my (@config) = @_;
  my ($hash, %localtime);

  %localtime = (
    "year"     => $config[0],
    "month"    => $config[1],
    "monthday" => $config[2],
    "hour"     => $config[3],
    "minute"   => $config[4],
    "second"   => $config[5]
  );

  $$hash{"local_time"} = \%localtime;
  $$hash{"timezone"}   = $config[6];

  %dist_attrib = &conf_get_replace_table ();

  $res = &Utils::Replace::set_from_table ($dist_attrib{"fn"}, $dist_attrib{"table"}, $hash);
  &time_sync_hw_from_sys ();

  return $res;
}

1;
