#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# Functions for manipulating system services, like daemons and network.
#
# Copyright (C) 2002 Ximian, Inc.
#
# Authors: Carlos Garnacho Parro <garparr@teleline.es>,
#          Hans Petter Jansson <hpj@ximian.com>,
#          Arturo Espinosa <arturo@ximian.com>
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

package Init::Services;

use Utils::Report;
use Utils::File;

$rcd_path;
$initd_path;
$relative_path;

$SCRIPTSDIR = "@scriptsdir@";
$FILESDIR = "@filesdir@";
if ($SCRIPTSDIR =~ /^@scriptsdir[@]/)
{
    $FILESDIR = "files";
    $SCRIPTSDIR = ".";
    $DOTIN = ".in";
}

use File::Copy;

require "$SCRIPTSDIR/service-list.pl$DOTIN";

# Where is the SysV subsystem installed?
sub gst_service_sysv_get_paths
{
  my %dist_map =
      (
       # dist => [rc.X dirs location, init.d scripts location, relative path location]
       "redhat-5.2"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-6.0"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-6.1"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-6.2"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-7.0"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-7.1"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-7.2"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-7.3"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-8.0"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "redhat-9"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "openna-1.0"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "mandrake-7.1" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "mandrake-7.2" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "mandrake-9.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "mandrake-9.1" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "mandrake-9.2" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "mandrake-10.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "mandrake-10.1" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "blackpanther-4.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "conectiva-9"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "conectiva-10" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "debian-2.2"   => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
       "debian-3.0"   => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
       "debian-sarge" => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],

       "suse-7.0"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d", "../"],
       "suse-9.0"     => ["$gst_prefix/etc/init.d", "$gst_prefix/etc/init.d", "../"],
       "suse-9.1"     => ["$gst_prefix/etc/init.d", "$gst_prefix/etc/init.d", "../"],

       "turbolinux-7.0"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "pld-1.0"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "pld-1.1"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "pld-1.99"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "fedora-1"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "fedora-2"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "fedora-3"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "specifix"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

       "vine-3.0"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       "vine-3.1"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
       );
  my $res;

  $res = $dist_map{$Utils::Backend::tool{"platform"}};
  &Utils::Report::do_report ("service_sysv_unsupported", $Utils::Backend::tool{"platform"}) if ($res eq undef);
  return @$res;
}

# Those runlevels that are usually used. Maybe we should add
# the current running runlevel, using the "runlevel" command.
sub gst_service_sysv_get_runlevels
{
  my %dist_map =
      (
       "redhat-5.2"     => [3, 5],
       "redhat-6.0"     => [3, 5],
       "redhat-6.1"     => [3, 5],
       "redhat-6.2"     => [3, 5],
       "redhat-7.0"     => [3, 5],
       "redhat-7.1"     => [3, 5],
       "redhat-7.2"     => [3, 5],
       "redhat-7.3"     => [3, 5],
       "redhat-8.0"     => [3, 5],
       "redhat-9"       => [3, 5],
       "openna-1.0"     => [3, 5],

       "mandrake-7.1"   => [3, 5],
       "mandrake-7.2"   => [3, 5],
       "mandrake-9.0"   => [3, 5],
       "mandrake-9.1"   => [3, 5],
       "mandrake-9.2"   => [3, 5],
       "mandrake-10.0"  => [3, 5],
       "mandrake-10.1"  => [3, 5],

       "blackpanther-4.0" => [3, 5],

       "conectiva-9"    => [3, 5],
       "conectiva-10"   => [3, 5],

       "debian-2.2"     => [2, 3],
       "debian-3.0"     => [2, 3],
       "debian-sarge"   => [2, 3],

       "suse-7.0"       => [3, 5],
       "suse-9.0"       => [3, 5],
       "suse-9.1"       => [3, 5],

       "turbolinux-7.0" => [3, 5],

       "pld-1.0"        => [3, 5],
       "pld-1.1"        => [3, 5],
       "pld-1.99"       => [3, 5],

       "fedora-1"       => [3, 5],
       "fedora-2"       => [3, 5],
       "fedora-3"       => [3, 5],

       "specifix"       => [3, 5],
       
       "vine-3.0"       => [3, 5],
       "vine-3.1"       => [3, 5],
       );
  my $res;

  $res = $dist_map{$Utils::Backend::tool{"platform"}};
  &Utils::Report::do_report ("service_sysv_unsupported", $Utils::Backend::tool{"platform"}) if ($res eq undef);
  return @$res;
}

sub gst_service_get_verbose_runlevels
{
  my (%dist_map, %runlevels, $desc, $distro);
  %dist_map =
    (
     "redhat-5.2"     => "redhat-5.2",
     "redhat-6.0"     => "redhat-5.2",
     "redhat-6.1"     => "redhat-5.2",
     "redhat-6.2"     => "redhat-5.2",
     "redhat-7.0"     => "redhat-5.2",
     "redhat-7.1"     => "redhat-5.2",
     "redhat-7.2"     => "redhat-5.2",
     "redhat-7.3"     => "redhat-5.2",
     "redhat-8.0"     => "redhat-5.2",
     "redhat-9"       => "redhat-5.2",
     "openna-1.0"     => "redhat-5.2",
     
     "mandrake-7.1"   => "redhat-5.2",
     "mandrake-7.2"   => "redhat-5.2",
     "mandrake-9.0"   => "redhat-5.2",
     "mandrake-9.1"   => "redhat-5.2",
     "mandrake-9.2"   => "redhat-5.2",
     "mandrake-10.0"  => "redhat-5.2",
     "mandrake-10.1"  => "redhat-5.2",
     
     "blackpanther-4.0" => "redhat-5.2",

     "conectiva-9"    => "redhat-5.2",
     "conectiva-10"   => "redhat-5.2",
     
     "debian-2.2"     => "debian-2.2",
     "debian-3.0"     => "debian-2.2",
     "debian-sarge"   => "debian-2.2",
     
     "suse-7.0"       => "redhat-5.2",
     "suse-9.0"       => "redhat-5.2",
     "suse-9.1"       => "redhat-5.2",
     
     "turbolinux-7.0" => "redhat-5.2",
     "pld-1.0"        => "redhat-5.2",
     "pld-1.1"        => "redhat-5.2",
     "pld-1.99"       => "redhat-5.2",
     "fedora-1"       => "redhat-5.2",
     "fedora-2"       => "redhat-5.2",
     "fedora-3"       => "redhat-5.2",

     "specifix"       => "redhat-5.2",

     "vine-3.0"       => "redhat-5.2",
     "vine-3.1"       => "redhat-5.2",

     "slackware-9.1.0" => "slackware-9.1.0",
     "slackware-10.0.0" => "slackware-9.1.0",
     "slackware-10.1.0" => "slackware-9.1.0",

     "gentoo"         => "gentoo",

     "freebsd-5"      => "freebsd-5",
     "freebsd-6"      => "freebsd-5",
    );

  %runlevels=
    (
     "redhat-5.2" => {"0" => _("Halting the system"),
                      "3" => _("Text mode"),
                      "5" => _("Graphical mode"),
                      "6" => _("Rebooting the system")
                     },
     "debian-2.2" => {"0" => _("Halting the system"),
                      "2" => _("Graphical mode"),
                      "3" => _("Text mode"),
                      "6" => _("Rebooting the system")
                     },
     "gentoo"     => {"boot"      => _("Starts all system neccesary services"),
                      "default"   => _("Default runlevel"),
                      "nonetwork" => _("Networkless runlevel")
                     },
     "freebsd-5"  => {"rc" => "dude, FreeBSD has no runlevels" },
     "slackware-9.1.0" => {"4" => _("Graphical mode") }
    );

  $distro = $dist_map{$Utils::Backend::tool{"platform"}};
  $desc = $runlevels{$distro};

  return $runlevels{$distro};
}

# --- Plain process utilities --- #

# Get owners list (login) of named process.
sub gst_service_proc_get_owners
{
  my ($service) = @_;
  my ($user, $pid, $command);
  my ($fd);
  my (@arr);

  &Utils::Report::enter ();

  $fd = Utils::File::run_pipe_read ("ps acx -o user,pid,command");

  while (<$fd>)
  {
    /(.*)[ \t]+(.*)[ \t]+(.*)/;
    $user    = $1;
    $pid     = $2;
    $command = $3;

    push @arr, $user if ($command eq $service);
  }

  &Utils::Report::leave ();
  return \@arr;
}

# Stops all instances of a process
sub gst_service_proc_stop_all
{
  my ($service) = @_;

  return &Utils::File::run ("killall $service");
}

# Starts instances of a process for a given list of users
sub gst_service_proc_start_all
{
  my ($cmd, $users) = @_;
  my ($fqcmd, $fqsu);

  $fqcmd = &Utils::File::get_cmd_path ($cmd);
  $fqsu  = &Utils::File::locate_tool  ("su");

  foreach $user (@$users)
  {
    # Can't use gst_file_run_bg here, since it clobbers the quotes.
    system ("$fqsu $user -c \"$fqcmd &\" >/dev/null 2>/dev/null");
  }
}

sub gst_service_sysv_list_dir
{
    my ($path) = @_;
    my ($service, @services);

    foreach $service (<$path/*>)
    {
        if (-x $service)
        {
            $service =~ s/.*\///;
            push @services, $service;
        }
    }

    return \@services;
}

sub gst_service_sysv_list_available
{
    my ($rcd_path, $initd_path);
    
    ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

    return &gst_service_sysv_list_dir ($initd_path);
}

# Return 1 or 0: is the service running?
# Depends on the rc script to support the "status" arg.
# Maybe we should do something more portable.
sub gst_service_sysv_get_status
{
  my ($service) = @_;
  my ($rc_path, $initd_path, $res);
  my ($pid);

  &Utils::Report::enter ();

  # Stolen from RedHat's /etc/rc.d/init.d/functions:status
  # FIXME: portable to other UNIXES?
  $pid = &Utils::File::run_backtick ("pidof -o %PPID -x $service");
  chomp $pid;

  if ($pid)
  {
    $res = 1;
    &Utils::Report::do_report ("service_status_running", $service);
  }
  else
  {
    $res = 0;
    &Utils::Report::do_report ("service_status_stopped", $service);
  }
    
#  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();
#  $res = 0;
#  
#  if (-f "$initd_path/$service")
#  {
#    $res = &Utils::File::run ("$initd_path/$service status")? 0 : 1;
#    &Utils::Report::do_report ("service_status_running", $service) if $res;
#    &Utils::Report::do_report ("service_status_stopped", $service) if !$res;
#  }

  &Utils::Report::leave ();
  return $res;
}

# If any of the passed services is running, return true.
sub gst_service_sysv_get_status_any
{
  my (@services) = @_;
  my $i;

  foreach $i (@services)
  {
    return 1 if &gst_service_sysv_get_status ($i);
  }

  return 0;
}

# Set start links and remove stop links at the usual runlevels.
# Old start link is removed, in case the priority is different from $pri.
sub gst_service_sysv_set_links_active
{
  my ($pri, $service) = @_;

  foreach $runlevel (&gst_service_sysv_get_runlevels ())
  {
    &gst_service_sysv_remove_link ($runlevel, $service);
    &gst_service_sysv_add_link ($runlevel, "S", $pri, $service);
  }
}

# Set stop links and remove start links at the usual runlevels.
sub gst_service_sysv_set_links_inactive
{
  my ($pri, $service) = @_;

  foreach $runlevel (&gst_service_sysv_get_runlevels ())
  {
    &gst_service_sysv_remove_link ($runlevel, "$service");
    &gst_service_sysv_add_link ($runlevel, "K", $pri, $service);
  }
}

# Set links for active/inactive service at the given priority.
sub gst_service_sysv_set_links
{
  my ($pri, $service, $active) = @_;

  if ($active)
  {
    &gst_service_sysv_set_links_active ($pri, $service);
  }
  else
  {
    &gst_service_sysv_set_links_inactive (100 - $pri, $service);
  }
}



# Start or stop the service, depending on $active. Set
# links accordingly.  $force makes this function use
# start/stop only, without considerations for restart.
# Not to be called from parse/replace tables, due to last $force
# param: use the following two functions instead.
sub gst_service_sysv_set_status_do
{
  my ($priority, $service, $active, $force) = @_;
  my ($arg, $status);

  &gst_service_sysv_set_links ($priority, $service, $active);
  
  $status = &gst_service_sysv_get_status ($service);
  if ($status && !$force)
  {
    # if it's already active and you want it active, restart.
    $arg = $active? "restart" : "stop";
  }
  else
  {
    # normal operation.
    $arg = $active? "start" : "stop";
  }

  return &gst_service_sysv_run_initd_script ($service, $arg);
}

sub gst_service_sysv_set_status
{
  my ($priority, $service, $active) = @_;

  return &gst_service_sysv_set_status_do ($priority, $service, $active, 0);
}

sub gst_service_sysv_force_status
{
  my ($priority, $service, $active) = @_;

  return &gst_service_sysv_set_status_do ($priority, $service, $active, 1);
}

sub gst_service_sysv_install_script
{
  my ($service, $file) = @_;
  my ($res, $rcd_path, $initd_path);

  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

  if (!copy ("$FILESDIR/$file", "$initd_path/$service"))
  {
      &Utils::Report::do_report ("file_copy_failed", "$FILESDIR/$file", "$initd_path/$service");
      return -1;
  }

  chmod (0755, "$initd_path/$service");

  return 0;
}

# THESE ARE THE FUNCTIONS WHICH EXTRACT THE CONFIGURATION FROM THE COMPUTER

# we are going to extract the name of the script
sub gst_service_sysv_get_service_name
{
	my ($service) = @_;
	
	$service =~ s/$initd_path\///;
  
	return $service;
}

# This function gets the state of the service along the runlevels,
# it also returns the average priority
sub gst_service_sysv_get_runlevels_status
{
	my ($service) = @_;
	my ($link);
	my ($runlevel, $action, $priority);
	my (@arr, @ret);
	my ($sum, $count);
	
	$sum = $count = 0;
	
	foreach $link (<$rcd_path/rc[0-6].d/[SK][0-9][0-9]$service>)
	{
		$link =~ s/$rcd_path\///;
		$link =~ /rc([0-6])\.d\/([SK])([0-9][0-9]).*/;
		($runlevel,$action,$priority)=($1,$2,$3);
		if ($action eq "S")
		{
			push @arr, { "number" => $runlevel,
				         "action" => "start" };
			$sum += $priority;
		}
		elsif ($action eq "K")
		{
			push @arr, { "number" => $runlevel,
			             "action" => "stop" };
			$sum += (100 -$priority);
		}
		$count++;
	}
	
	return (undef,99) if (scalar(@arr) eq 0);
	push @ret, { "runlevel" => \@arr };
	return (\@ret, int ($sum / $count));
}

# We are going to extract the information of the service
sub gst_service_sysv_get_service_info
{
	my ($service) = @_;
	my ($script, $name, $description, @actions, @runlevels);
	my %hash;

	# Return if it's a directory
	return undef if (-d $service);
	
	# We have to check if the service is executable	
	return undef unless (-x $service);

	$script = &gst_service_sysv_get_service_name ($service);
		
	# We have to check out if the service is in the "forbidden" list
	return undef if (&gst_service_list_service_is_forbidden ($script));

	($name, $description) = &gst_service_list_get_info ($script);
	($runlevels, $priority) = &gst_service_sysv_get_runlevels_status($script);

	$hash{"script"} = $script;
	$hash{"name"} = $name unless ($name eq undef);
	$hash{"description"} = $description unless ($description eq undef);
#	$hash{"runlevels"} = $runlevels unless ($runlevels eq undef);
	$hash{"priority"} = $priority;

	return \%hash;
}

# This function gets an ordered array of the available services from a SysV system
sub gst_service_sysv_get_services
{
	my ($service);
	my (@arr, %ret);
	
	($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

	foreach $service (<$initd_path/*>)
	{
		my (%hash);
		$hash = &gst_service_sysv_get_service_info ($service);

		if ($hash ne undef)
		{
      $ret{$service} = $hash;
		}
	}

	return \%ret;
}

# This functions get an ordered array of the available services from a file-rc system
sub gst_service_filerc_get_runlevels_status
{
  my ($start_service, $stop_service, @arr) = @_;
  my (@ret);

  # we start with the runlevels in which the service starts
  if ($start_service !~ /-/) {
    my (@runlevels);

    @runlevels = split /,/, $start_service;

    foreach $runlevel (@runlevels)
    {
      push @arr, { "number" => $runlevel,
                   "action" => "start" };
    }
  }

  # now let's go with the runlevels in which the service stops
  if ($stop_service !~ /-/) {
    my (@runlevels);

    @runlevels = split /,/, $stop_service;

    foreach $runlevel (@runlevels)
    {
      push @arr, { "number" => $runlevel,
                   "action" => "stop" };
    }
  }

  push @ret, {"runlevel" => \@arr};
  return \@ret;
}

sub gst_service_filerc_get_service_info
{
  my ($line, %ret) = @_;
  my %hash;
  my @runlevels;

  if ($line =~ /^([0-9][0-9])[\t ]+([0-9\-S,]+)[\t ]+([0-9\-S,]+)[\t ]+\/etc\/init\.d\/(.*)/)
  {
    $priority = $1;
    $stop_service = $2;
    $start_service = $3;
    $script = $4;

    return undef if (&gst_service_list_service_is_forbidden ($script));

    $hash{"script"} = $script;

    $hash{"runlevels"} = &gst_service_filerc_get_runlevels_status ($start_service, $stop_service);

    if ($start_service eq "-")
    {
      $hash{"priority"} = 100 - $priority;
      $priority = 100 - $priority;
    }
    else
    {
      $hash{"priority"} = $priority;
    }

    return (\%hash);
  }

  return undef;
}

sub gst_service_filerc_get_services
{
	my ($script);
  my %ret;
	
  open FILE, "$gst_prefix/etc/runlevel.conf" or return undef;
  while ($line = <FILE>)
  {
    if ($line !~ /^#.*/)
    {
      my (%hash);
      my ($start_service, $stop_service);
      $hash = &gst_service_filerc_get_service_info ($line);

      if ($hash ne undef)
      {
        $script = $$hash{"script"};

        if ($ret{$script} eq undef)
        {
          ($name, $description) = &gst_service_list_get_info ($script);
          $$hash{"name"} = $name unless ($name eq undef);
          $$hash{"description"} = $description unless ($description eq undef);
          $$hash{"count"} = 1;

          $ret{$script} = $hash;
        }
        else
        {
            my (@runlevels);

            # We need to mix the runlevels
            @runlevels = $$hash{"runlevels"}[0]{"runlevel"};
            foreach $runlevel (@runlevels)
            {
                push @{$ret{$script}{"runlevels"}[0]{"runlevel"}}, $runlevel;
            }
            
            $ret{$script}{"priority"} += $$hash{"priority"};

            $ret{$script}{"count"}++;
        }
      }
    }
  }

  # we have to return the average priority
  foreach $i (sort keys %ret)
  {
      $ret{$i}{"priority"} = int ($ret{$i}{"priority"} / $ret{$i}{"count"});
      delete $ret{$i}{"count"};
  }

  return \%ret;
}

# this functions get a list of the services that run on a bsd init
sub gst_service_bsd_get_service_info
{
  my ($service) = @_;
  my ($script, $name, $description);
  my (%hash);
	my (@arr, @rl);

  $script = $service;
  $script =~ s/^.*\///;
  $script =~ s/^rc\.//;

  return undef if (! Utils::File::exists ($service));

  return undef if (&gst_service_list_service_is_forbidden ($script));

  ($name, $description) = &gst_service_list_get_info ($script);

  $hash {"script"} = $service;
  $hash{"name"} = $name unless ($name eq undef);
  $hash{"description"} = $description unless ($description eq undef);

  # we hardcode the fourth runlevel, it's the graphical one
  if ( -x $service)
  {
    push @arr, { "number" => 4,
                 "action" => "start" };
  }
  else
  {
      push @arr, { "number" => 4,
                   "action" => "stop" };
  }

	push @rl, { "runlevel" => \@arr };
  
	$hash{"runlevels"} = \@rl;
  
  return \%hash;
}

sub gst_service_bsd_get_services
{
  my (%ret);
  my ($files) = [ "rc.M", "rc.inet2", "rc.4" ];
  my ($file);

  foreach $i (@$files)
  {
    $file = "/etc/rc.d/" . $i;
    $fd = &Utils::File::open_read_from_names ($file);

    if (!$fd) {
      &Utils::Report::do_report ("rc_file_read_failed", $file);
      return undef;
    }

    while (<$fd>)
    {
      $line = $_;

      if ($line =~ /^if[ \t]+\[[ \t]+\-x[ \t]([0-9a-zA-Z\/\.\-_]+) .*\]/)
      {
        my (%hash);
        $service = $1;

        $hash = &gst_service_bsd_get_service_info ($service);

        if ($hash ne undef)
        {
          $ret{$service} = $hash;
        }
      }
    }

    Utils::File::close_file ($fd);
  }

  return \%ret;
}

# these functions get a list of the services that run on a gentoo init
sub gst_service_gentoo_get_service_status
{
  my ($script, $runlevel) = @_;
  my ($services) = &gst_service_gentoo_get_services_by_runlevel ($runlevel);

  foreach $i (@$services)
  {
    return 1 if ($i eq $script);
  }

  return 0;
}

sub gst_service_gentoo_get_runlevels
{
  my($raw_output) = Utils::File::run_backtick("rc-status -l");
  my(@runlevels) = split(/\n/,$raw_output);
    
  return @runlevels;
}

sub gst_service_gentoo_get_services_by_runlevel
{
  my($runlevel) = @_;
  my($raw_output) = Utils::File::run_backtick("rc-status $runlevel");
  my(@raw_lines) = split(/\n/,$raw_output);
  my(@services);
  my($line);

  foreach $line (@raw_lines)
  {
    if ($line !~ /^Runlevel/)
    {
      $line=(split(" ",$line))[0];
	    push(@services,$line);
	  }
  }

  return \@services
}

sub gst_service_gentoo_get_services_list
{
  return &gst_service_sysv_list_dir ("/etc/init.d/");
}

sub gst_service_gentoo_service_exist
{
  my($service) = @_;
  my($services) = &gst_service_gentoo_get_services_list();

  foreach $i (@$services)
  {
    return 1 if ($i =~ /$service/);
  }

  return 0;
}

sub gst_service_gentoo_get_runlevels_by_service
{
  my ($service) = @_;
  my(@runlevels,@services_in_runlevel,@contain_runlevels, $runlevel);
  my ($elem);

  # let's do some caching to improve performance
  if ($gentoo_services_hash eq undef)
  {
    @runlevels = &gst_service_gentoo_get_runlevels ();

    foreach $runlevel (@runlevels)
    {
      $$gentoo_services_hash{$runlevel} = &gst_service_gentoo_get_services_by_runlevel ($runlevel);
    }
  }

  if (&gst_service_gentoo_service_exist($service))
  {
    foreach $runlevel (keys %$gentoo_services_hash)
    {
      $services_in_runlevel = $$gentoo_services_hash {$runlevel};

      foreach $elem (@$services_in_runlevel)
      {
        push (@contain_runlevels, $runlevel) if ($elem eq $service);
      }
    }
  }

  return @contain_runlevels;
}

sub gst_service_gentoo_runlevel_status_by_service
{
  my ($service) = @_;
  my (@arr, @ret);
  my (@runlevels) = &gst_service_gentoo_get_runlevels();
  my (@started) = &gst_service_gentoo_get_runlevels_by_service($service);
  my (%start_runlevels) = map { $started[$_], 1 } 0 .. $#started;

  foreach $runlevel (@runlevels)
  {
    if (defined $start_runlevels{$runlevel})
    {
      push @arr, { "number" => $runlevel,
                   "action" => "start" };
    }
    else
    {
      push @arr, { "number" => $runlevel,
                   "action" => "stop" };
    }
  }

  push @ret, { "runlevel" => \@arr };
  return @ret;
}

sub gst_service_gentoo_get_service_info
{
	my ($service) = @_;
	my ($script, $name, $description, @actions, @runlevels);
	my %hash;
	
	# We have to check out if the service is in the "forbidden" list
	return undef if (&gst_service_list_service_is_forbidden ($service));

	($name, $description) = &gst_service_list_get_info ($service);

	my($runlevels) = &gst_service_gentoo_runlevel_status_by_service ($service);

	$hash{"script"} = $service;
	$hash{"name"} = $name unless ($name eq undef);
	$hash{"description"} = $description unless ($description eq undef);
	$hash{"runlevels"} = $runlevels unless ($runlevels eq undef);

	return \%hash;
}

sub gst_service_gentoo_get_services
{
  my ($service);
  my (%ret);
  my ($service_list) = &gst_service_gentoo_get_services_list ();

  foreach $service (@$service_list)
  {
    my (%hash);
    $hash = &gst_service_gentoo_get_service_info ($service);

    $ret{$service} = $hash if ($hash ne undef);
  }

  return \%ret;
}

# rcNG functions, mostly for FreeBSD

sub gst_service_rcng_status_by_service
{
  my ($service) = @_;
  my ($fd, $line, $active);

  $fd = &Utils::File::run_pipe_read ("/etc/rc.d/$service rcvar");

  while (<$fd>)
  {
    $line = $_;

    if ($line =~ /^\$.*=YES$/)
    {
      $active = 1;
      last;
    }
  }

  Utils::File::close_file ($fd);
  return $active;
}

sub gst_service_rcng_get_service_info
{
  my ($service) = @_;
  my ($script, $name, $description, @actions, @runlevels);
  my (%hash, @arr, @rl);

  # We have to check if the service is in the "forbidden" list
  return undef if (&gst_service_list_service_is_forbidden ($service));

  ($name, $description) = &gst_service_list_get_info ($service);

  $hash{"script"} = $service;
  $hash{"name"} = $name unless ($name eq undef);
  $hash{"description"} = $description unless ($description eq undef);

  if (gst_service_rcng_status_by_service ($service))
  {
    push @arr, { "number" => "rc",
                 "action" => "start" };
  }
  else
  {
    push @arr, { "number" => "rc",
                 "action" => "stop" };
  }

  push @rl,  { "runlevel", \@arr };

  $hash {"runlevels"} = \@rl;

  return \%hash;
}

sub gst_service_rcng_get_services
{
  my ($service);
  my (%ret);

  foreach $service (<$gst_prefix/etc/rc.d/*>)
  {
    my (%hash);
    
    $service =~ s/.*\///;
    $hash = &gst_service_rcng_get_service_info ($service);

    $ret{$service} = $hash if ($hash ne undef);
  }

  return \%ret;
}

# SuSE functions, quite similar to SysV, but not equal...
sub gst_service_suse_get_service_info ($service)
{
  my ($service) = @_;
  my ($name, $description);
  my (%hash, @arr, @ret);
                                                                                                                                                             
  # We have to check if the service is in the "forbidden" list
  return undef if (&gst_service_list_service_is_forbidden ($service));
                                                                                                                                                             
  ($name, $description) = &gst_service_list_get_info ($service);
                                                                                                                                                             
  $hash{"script"} = $service;
  $hash{"name"} = $name unless ($name eq undef);
  $hash{"description"} = $description unless ($description eq undef);

  foreach $link (<$rcd_path/rc[0-9S].d/S[0-9][0-9]$service>)
  {
    $link =~ s/$rcd_path\///;
    $link =~ /rc([0-6])\.d\/S[0-9][0-9].*/;
    $runlevel = $1;

    push @arr, { "number" => $runlevel,
                 "action" => "start" };
  }

  foreach $link (<$rcd_path/boot.d/S[0-9][0-9]$service>)
  {
    push @arr, {"number" => "B",
                "action" => "start" };
  }

  if (scalar @arr > 0)
  {
    push @ret, { "runlevel" => \@arr };
    $hash{"runlevels"} = \@ret;
  }

  return \%hash;
}

sub gst_service_suse_get_services
{
  my ($service, %ret);

  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

  foreach $service (<$gst_prefix/etc/init.d/*>)
  {
    my (%hash);

    next if (-d $service || ! -x $service);

    $service =~ s/.*\///;
    $hash = &gst_service_suse_get_service_info ($service);

    $ret{$service} = $hash if ($hash ne undef);
  }

  return \%ret;
}

# generic functions to get the available services
sub gst_get_init_type
{
  my $dist = $Utils::Backend::tool{"platform"};

  if (($dist =~ /debian/) && (stat ("$gst_prefix/etc/runlevel.conf")))
  {
    return "file-rc";
  }
  elsif ($dist =~ /slackware/)
  {
    return "bsd";
  }
  elsif ($dist =~ /freebsd/)
  {
    return "rcng";
  }
  elsif ($dist =~ /gentoo/)
  {
    return "gentoo";
  }
  elsif ($dist =~ /suse/)
  {
    return "suse";
  }
  else
  {
    return "sysv";
  }
}

sub gst_service_get_services
{
  $type = &gst_get_init_type ();

  return &gst_service_sysv_get_services ()   if ($type eq "sysv");
  return &gst_service_filerc_get_services () if ($type eq "file-rc");
  return &gst_service_bsd_get_services ()    if ($type eq "bsd");
  return &gst_service_gentoo_get_services () if ($type eq "gentoo");
  return &gst_service_rcng_get_services ()   if ($type eq "rcng");
  return &gst_service_suse_get_services ()   if ($type eq "suse");

  return undef;
}


# This function gets the runlevel that is in use
sub gst_service_sysv_get_default_runlevel
{
	my (@arr);
	
	@arr = split / /, `/sbin/runlevel` ;
	$arr[1] =~ s/\n//;
	
	return $arr[1];
}

sub gst_service_get_default_runlevel
{
    my ($type) = &gst_get_init_type ();

    return "default" if ($type eq "gentoo");
    return "rc"      if ($type eq "rcng");
    return &gst_service_sysv_get_default_runlevel ();
}


# THESE ARE THE FUNCTIONS WHICH APPLY THE CHANGES MADE TO THE CONFIGURATION OF THE COMPUTER

sub gst_service_sysv_add_link
{
  my ($runlevel, $action, $priority, $service) = @_;
  my ($prio) = sprintf ("%0.2d",$priority);

  symlink ("$relative_path/$service", "$rcd_path/rc$runlevel.d/$action$prio$service");
  
  &Utils::Report::enter ();
  &Utils::Report::do_report ("service_sysv_add_link", "$rcd_path/rc$runlevel.d/$action$prio$service");
  &Utils::Report::leave ();
}

sub gst_service_sysv_remove_link
{
  my ($runlevel, $script) = @_;
	
  foreach $link (<$rcd_path/rc$runlevel.d/[SK][0-9][0-9]$script>)
  {
    &Utils::Report::do_report ("service_sysv_remove_link", "$link");
    unlink ("$link");
    &Utils::Report::leave ();
  }
}


# These are the functions for storing the service settings from XML in SysV
sub gst_service_sysv_set_service
{
  my ($service) = @_;
  my ($script, $priority, $runlevels);
  my ($action);

  ($rcd_path, $initd_path, $relative_path) = &gst_service_sysv_get_paths ();

  $script = $$service{"script"};
  $priority = $$service{"priority"};
  $runlevels = $$service{"runlevels"}[0]{"runlevel"};

  # pass though all the runlevels checking if the service must be started, stopped or removed
  for ($i = 0; $i <= 6; $i++)
  {
    &gst_service_sysv_remove_link ($i, $script);

    $action = undef;
    foreach $j (@$runlevels)
    {
      if ($i == $$j{"number"})
      {
        $found = 1;
        $action = $$j{"action"};
      }
    }
    if ($action ne undef)
    {
      if ($action eq "start")
      {
        &gst_service_sysv_add_link ($i, "S", $priority, $script);
      }
      else
      {
        &gst_service_sysv_add_link ($i, "K", 100 - $priority, $script);
      }
    }
  }
}

sub gst_service_sysv_set_services
{
	my ($services, $runlevel) = @_;

	foreach $i (@$services)
	{
		&gst_service_sysv_set_service($i);
	}
}

# This is the function for storing the service settings from XML in file-rc
sub gst_service_filerc_set_services
{
  my ($services, $runlevel) = @_;
  my ($buff, $lineno, $line, $file);
  my ($rcd_path, $initd_path, $relative_path) = &gst_service_sysv_get_paths ();

  $file = "$gst_prefix/etc/runlevel.conf";

  $buff = &Utils::File::load_buffer ($file);
  &Utils::File::join_buffer_lines ($buff);

  $lineno = 0;

  # We prepare the file for storing the configuration, save the initial comments
  # and delete the rest
  do {
    $lineno++;
  } while ($$buff[$lineno] =~ /^#.*/);

  for ($i = $lineno; $i < scalar (@$buff); $i++)
  {
    $$buff[$i] =~ /.*\/etc\/init\.d\/(.*)/;

    # we need to keep the forbidden services and the services that only start in rcS.d
    if (!gst_service_list_service_is_forbidden ($1))
    {
      delete $$buff[$i];
    }
  }

  # Now we append the services
  foreach $service (@$services)
  {
    my (@start, @stop, @arr);

    $arr = $$service{"runlevels"}[0]{"runlevel"};

    # split the runlevels in two arrays
    foreach $i (@$arr)
    {
      if ($$i{"action"} eq "start")
      {
        push @start, $$i{"number"};
      }
      else
      {
        push @stop, $$i{"number"};
      }
    }

    if ((scalar (@start) eq 0) && (scalar (@stop) eq 0))
    {
      #print a empty line
      $line = sprintf ("%0.2d",$$service{"priority"}) . "\t";
      $line .= "-\t-";
      $line .= "\t\t". "/etc/init.d/" . $$service{"script"} . "\n";
      push @$buff, $line;
    }
    else
    {      
      if (scalar (@start) ne 0)
      {
        # print the line with the runlevels in which the service starts with priority = $priority
        $line = sprintf ("%0.2d",$$service{"priority"}) . "\t";
        $line .= "-" . "\t";
        $line .= join ",", sort @start;
        $line .= "\t\t". "/etc/init.d/" . $$service{"script"} . "\n";
        push @$buff, $line;
      }

      if (scalar (@stop) ne 0)
      {
        # print the line with the runlevels in which the service stops with priority = 100 - $priority
        $line = sprintf ("%0.2d", 100 - $$service{"priority"}) . "\t";
        $line .= join ",", sort @stop;
        $line .= "\t" . "-";
        $line .= "\t\t". "/etc/init.d/" . $$service{"script"} . "\n";
        push @$buff, $line;
      }
    }
  }

  @$buff = sort @$buff;

  push @$buff, "\n";
  &Utils::File::clean_buffer ($buff);
  &Utils::File::save_buffer ($buff, $file);
}

sub gst_service_bsd_set_services
{
  my ($services, $runlevel) = @_;
  my ($script, $runlevels);

	foreach $service (@$services)
	{
    $script = $$service{"script"};
    $runlevels = $$service{"runlevels"}[0]{"runlevel"}[0];

    $action = $$runlevels {"action"};

    if ($action eq "start")
    {
      &Utils::File::run ("chmod ugo+x $script");
    }
    else
    {
      &Utils::File::run ("chmod ugo-x $script");
    }
  }
}

sub gst_service_gentoo_set_services
{
  my ($services, $runlevel) = @_;
  my ($action);

  foreach $service (@$services)
  {
    $script = $$service{"script"};
    $arr = $$service{"runlevels"}[0]{"runlevel"};

    foreach $i (@$arr)
    {
      $action = $$i{"action"};
      $rl = $$i{"number"};

      if ( $action eq "start")
      {
        &Utils::File::run ("rc-update add $script $rl");
      }
      elsif ($action eq "stop")
      {
        &Utils::File::run ("rc-update del $script $rl");
      }
    }
  }
}

sub gst_service_rcng_set_status
{
  my ($service, $action) = @_;
  my ($fd, $key, $res);
  my ($default_rcconf) = "/etc/defaults/rc.conf";
  my ($rcconf) = "/etc/rc.conf";

  if (&Utils::File::exists ("/etc/rc.d/$service"))
  {
    $fd = &Utils::File::run_pipe_read ("/etc/rc.d/$service rcvar");

    while (<$fd>)
    {
      if (/^\$(.*)=.*$/)
      {
        # to avoid cluttering rc.conf with duplicated data,
        # we first look in the defaults/rc.conf for the key
        $key = $1;
        $res = &Utils::Parse::get_sh_bool ($default_rcconf, $key);

        if ($res == $action)
        {
          &Utils::Replace::set_sh ($rcconf, $key);
        }
        else
        {
          &Utils::Replace::set_sh_bool ($rcconf, $key, "YES", "NO", $action);
        }
      }
    }

    &Utils::File::close_file ($fd);
  }
  elsif (&Utils::File::exists ("/usr/local/etc/rc.d/$service.sh"))
  {
    if ($action)
    {
      Utils::File::copy_file ("/usr/local/etc/rc.d/$service.sh.sample",
                     "/usr/local/etc/rc.d/$service.sh");
    }
    else
    {
      Utils::File::remove ("/usr/local/etc/rc.d/$service.sh");
    }
  }
}

sub gst_service_rcng_set_services
{
  my ($services, $runlevel) = @_;
  my ($action, $runlevels, $script);

  foreach $service (@$services)
  {
    $script = $$service {"script"};
    $runlevels = $$service{"runlevels"}[0]{"runlevel"}[0];
    $action = ($$runlevels {"action"} eq "start")? 1 : 0;

    &gst_service_rcng_set_status ($script, $action);
  }
}

sub gst_service_suse_set_services
{
  my ($services, $runlevel) = @_;
  my ($action, $runlevels, $script, $rllist);

  foreach $service (@$services)
  {
    $script = $$service{"script"};
    $runlevels = $$service{"runlevels"}[0]{"runlevel"};
    $rllist = "";

    &Utils::File::run ("insserv -r $script");

    foreach $rl (@$runlevels)
    {
      if ($$rl{"action"} eq "start")
      {
        $rllist .= $$rl{"number"} . ",";
      }
    }

    if ($rllist ne "")
    {
      $rllist =~ s/,$//;

      &Utils::File::run ("insserv $script,start=$rllist");
    }
  }
}

sub gst_service_set_services
{
	my ($services, $runlevel) = @_;

  $type = &gst_get_init_type ();

  &gst_service_sysv_set_services   ($services, $runlevel) if ($type eq "sysv");
  &gst_service_filerc_set_services ($services, $runlevel) if ($type eq "file-rc");
  &gst_service_bsd_set_services    ($services, $runlevel) if ($type eq "bsd");
  &gst_service_gentoo_set_services ($services, $runlevel) if ($type eq "gentoo");
  &gst_service_rcng_set_services   ($services, $runlevel) if ($type eq "rcng");
  &gst_service_suse_set_services   ($services, $runlevel) if ($type eq "suse");
}

sub gst_service_set_conf
{
  my ($hash) = @_;
  my ($services, $runlevel);

  return unless $hash;
  $services = $$hash{"services"}[0]{"service"};
  return unless $services;
  $runlevel = $$hash{"runlevel"};
  return unless $runlevel;

  &gst_service_set_services($services, $runlevel);
}

# stuff for checking whether service is running
sub gst_service_debian_get_status
{
  my ($service) = @_;
  my ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();
  my ($output, $pidfile);

  $output = `grep "\/var\/run\/.*\.pid" $initd_path\/$service`;

  if ($output =~ /.*(\/var\/run\/.*\.pid).*/ )
  {
    $pidfile = $1;
    $pidval = `cat $pidfile`;

    return 0 if $pidval eq "";

    $pid = `ps h $pidval`;

    if ($pid eq "")
    {
      return 0;
    }
    else
    {
      return 1;
    }
  }

  return undef;
}

sub gst_service_redhat_get_status
{
  my ($service) = @_;
  my ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

  if (-f "/var/lock/subsys/$service")
  {
    return 1;
  }

  return 0;
}

sub gst_service_gentoo_get_status
{
  my ($service) = @_;

  $line = `/etc/init.d/$service status`;

  return 1 if ($line =~ /started/);
  return 0;
}

sub gst_service_rcng_get_status
{
  my ($service) = @_;

  $line = Utils::File::run_backtick ("/etc/rc.d/$service forcestatus");
  return 1 if ($line =~ /pid [0-9]*/);

  # hacky as hell, we need to check services in /usr/local/etc/rc.d
  # and there's no standard way to check they're running
  return 1 if (-f "/var/run/$service.pid");

  # we give up, the service isn't running
  return 0;
}

sub gst_service_suse_get_status
{
  my ($service) = @_;

  $line = Utils::File::run_backtick ("/etc/init.d/$service status");
  return 1 if ($line =~ /running/);
  return 0;
}

# returns true if the service is already running
sub gst_service_get_status
{
  my ($service) = @_;
  my %dist_map =
      (
       "debian-2.2"   => \&gst_service_debian_get_status,
       "debian-3.0"   => \&gst_service_debian_get_status,
       "debian-sarge" => \&gst_service_debian_get_status,
       
       "redhat-5.2"   => \&gst_service_redhat_get_status,
       "redhat-6.0"   => \&gst_service_redhat_get_status,
       "redhat-6.1"   => \&gst_service_redhat_get_status,
       "redhat-6.2"   => \&gst_service_redhat_get_status,
       "redhat-7.0"   => \&gst_service_redhat_get_status,
       "redhat-7.1"   => \&gst_service_redhat_get_status,
       "redhat-7.2"   => \&gst_service_redhat_get_status,
       "redhat-7.3"   => \&gst_service_redhat_get_status,
       "redhat-8.0"   => \&gst_service_redhat_get_status,
       "redhat-9"     => \&gst_service_redhat_get_status,
       "mandrake-7.2" => \&gst_service_redhat_get_status,
       "fedora-1"     => \&gst_service_redhat_get_status,
       "fedora-2"     => \&gst_service_redhat_get_status,
       "fedora-3"     => \&gst_service_redhat_get_status,
       "specifix"     => \&gst_service_redhat_get_status,

       "suse-9.0"     => \&gst_service_suse_get_status,
       "suse-9.1"     => \&gst_service_suse_get_status,

       "gentoo"       => \&gst_service_gentoo_get_status,

       "freebsd-5"    => \&gst_service_rcng_get_status,
       "freebsd-6"    => \&gst_service_rcng_get_status,
      );
  my $proc;

  $proc = $dist_map {$Utils::Backend::tool{"platform"}};

  return undef if ($proc eq undef);

  return &$proc ($service);
}

# Functions to run a service
sub gst_service_sysv_run_initd_script
{
  my ($service, $arg) = @_;
  my ($rc_path, $initd_path);
  my $str;
  my %map =
      ("restart" => "restarted",
       "stop" => "stopped",
       "start" => "started");

  &Utils::Report::enter ();
  
  if (!exists $map{$arg})
  {
    &Utils::Report::do_report ("service_sysv_op_unk", $arg);
    &Utils::Report::leave ();
    return -1;
  }

  $str = $map{$arg};

  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

  if (-f "$initd_path/$service")
  {
    if (!&Utils::File::run ("$initd_path/$service $arg"))
    {
      &Utils::Report::do_report ("service_sysv_op_success", $service, $str);
      &Utils::Report::leave ();
      return 0;
    }
  }
  
  &Utils::Report::do_report ("service_sysv_op_failed", $service, $str);
  &Utils::Report::leave ();
  return -1;
}

sub gst_service_bsd_run_script
{
  my ($service, $arg) = @_;
  my ($chmod) = 0;

  return if (!&Utils::File::exists ($service));

  # if it's not executable then chmod it
  if (!((stat ($service))[2] & (S_IXUSR || S_IXGRP || S_IXOTH)))
  {
    $chmod = 1;
    &Utils::File::run ("chmod ugo+x $service");
  }
  
  &Utils::File::run ("$service $arg");

  # return it to it's normal state
  if ($chmod)
  {
    &Utils::File::run ("chmod ugo-x $service");
  }
}

sub gst_service_gentoo_run_script
{
  my ($service, $arg) = @_;
  my ($option);

  my %map =
    ("stop" => "stopped",
     "start" => "started"
    );

  &Utils::Report::enter ();

  if (!exists $map{$arg})
  {
    &Utils::Report::do_report ("service_sysv_op_unk", $arg);
    &Utils::Report::leave ();
    return -1;
  }

  if (&gst_service_gentoo_service_exist ($service))
  {
    if (!&Utils::File::run ("/etc/init.d/$service $arg"))
    {
      &Utils::Report::do_report ("service_sysv_op_success", $service, $str);
      &Utils::Report::leave ();
	    return 0;
	  }
  }

  &Utils::Report::do_report ("service_sysv_op_failed", $service, $str);
  &Utils::Report::leave ();
  return -1;
}

sub gst_service_rcng_run_script
{
  my ($service, $arg) = @_;
  my ($farg);

  my %map =
    ("stop"  => "forcestop",
     "start" => "forcestart"
    );

  &Utils::Report::enter ();

  if (!exists $map{$arg})
  {
    &Utils::Report::do_report ("service_sysv_op_unk", $arg);
    &Utils::Report::leave ();
    return -1;
  }

  $farg = $map {$arg};

  if (!&Utils::File::run ("/etc/rc.d/$service $farg"))
  {
    &Utils::Report::do_report ("service_sysv_op_success", $service, $str);
    &Utils::Report::leave ();
    return 0;
  }

  &Utils::Report::do_report ("service_sysv_op_failed", $service, $str);
  &Utils::Report::leave ();
  return -1;
}

sub gst_service_run_script
{
  my ($service, $arg) = @_;
  my ($proc, $type);
  my %map =
      (
       "sysv"   => \&gst_service_sysv_run_initd_script,
       "bsd"    => \&gst_service_bsd_run_script,
       "gentoo" => \&gst_service_gentoo_run_script,
       "rcng"   => \&gst_service_rcng_run_script,
       "suse"   => \&gst_service_sysv_run_initd_script,
      );

  $type = &gst_get_init_type ();

  $proc = $map {$type};

  &$proc ($service, $arg);
}

# functions to know if a service will be installed
sub gst_service_sysv_installed
{
  my ($service) = @_;
  my ($res, $rcd_path, $initd_path);

  &Utils::Report::enter ();
  
  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

  $res = 1;
  if (! -f "$initd_path/$service")
  {
    $res = 0;
    &Utils::Report::do_report ("service_sysv_not_found", $service);
  }

  &Utils::Report::leave ();
  return $res;
}

sub gst_service_bsd_installed
{
  my ($service) = @_;

  return 1 if ( -f "$service");
  return 0;
}

sub gst_service_gentoo_installed
{
  my ($service) = @_;

  return 1 if ( -f "/etc/init.d/$service");
  return 0;
}

sub gst_service_rcng_installed
{
  my ($service) = @_;

  return 1 if ( -f "/etc/rc.d/$service");
  return 1 if ( -f "/usr/local/etc/rc.d/$service.sh.sample");
  return 0;
}

sub gst_service_installed
{
  my ($service) = @_;
  my ($type);
  $type = &gst_get_init_type ();

  return &gst_service_sysv_installed ($service) if (($type eq "sysv") || ($type eq "file-rc") || ($type eq "suse"));
  return &gst_service_bsd_installed ($service) if ($type eq "bsd");
  return &gst_service_gentoo_installed ($service) if ($type eq "gentoo");
  return &gst_service_rcng_installed ($service) if ($type eq "rcng");

  return 0;
}

sub gst_service_list_any_installed
{
  my @service = @_;
  my $res;

  $res = 0;
  
  foreach $serv (@service)
  {
    if (gst_service_installed ($serv))
    {
      $res = 1;
    }
  }

  return $res;
}

sub gst_service_bsd_set_status
{
  my ($script, $active) = @_;
  my (@arr);

  if ($active)
  {
    &Utils::File::run ("chmod ugo+x $script");
    &gst_service_run_script ($script, "start");
  }
  else
  {
    &gst_service_run_script ($script, "stop");
    &Utils::File::run ("chmod ugo-x $script");
  }
}

sub gst_service_gentoo_set_status
{
  my ($script, $force_now, $active) = @_;
  my (@arr);

  if ($active)
  {
    &Utils::File::run ("rc-update add $script default");
    &Utils::File::run ("/etc/init.d/$script start") if ($force_now == 1);
  }
  else
  {
    &Utils::File::run ("rc-update del $script default");
    &Utils::File::run ("/etc/init.d/$script stop") if ($force_now == 1);
  }
}

sub gst_service_suse_set_status
{
  my ($script, $active) = @_;
  my (@runlevels, $rllist);
  my ($rcd_path, $initd_path);
  my ($rl);

  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();
  @runlevels = &gst_service_sysv_get_runlevels ();

  if ($active)
  {
    $rllist = join ",", @runlevels;
    &Utils::File::run ("insserv $script,start=$rllist");
    &gst_service_run_script ($script, "start");
  }
  else
  {
    # to remove a service from a few runlevels we need to run
    # insserv -r and then insserv blah,start=x,y,z
    foreach $link (<$rcd_path/rc[0-9S].d/S[0-9][0-9]$script>)
    {
      $link =~ s/$rcd_path\///;
      $link =~ /rc([0-9S])\.d\/S[0-9][0-9].*/;
      $rllist .= "$1,";
    }

    foreach $link (<$rcd_path/boot.d/S[0-9][0-9]$service>)
    {
      $rllist .= "B,";
    }

    # remove the default runlevels from the list
    foreach $runlevel (@runlevels)
    {
      $rllist =~ s/$runlevel,//;
    }

    $rllist =~ s/,$//;

    &Utils::File::run ("insserv -r $script");

    if ($rllist ne "")
    {
      &Utils::File::run ("insserv $script,start=$rllist");
    }

    &gst_service_run_script ($script, "stop");
  }
}