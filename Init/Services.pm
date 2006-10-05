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

my $SERVICE_START = 0;
my $SERVICE_STOP  = 1;

use Init::ServicesList;

sub get_runlevels
{
  my (%dist_map, %runlevels);
  my ($desc, $distro);

  %dist_map =
    (
     "redhat-6.2"       => "redhat-6.2",
     "redhat-7.0"       => "redhat-6.2",
     "redhat-7.1"       => "redhat-6.2",
     "redhat-7.2"       => "redhat-6.2",
     "redhat-7.3"       => "redhat-6.2",
     "redhat-8.0"       => "redhat-6.2",
     "mandrake-9.0"     => "redhat-6.2",
     "conectiva-9"      => "redhat-6.2",
     "debian-3.0"       => "redhat-6.2",
     "suse-9.0"         => "redhat-6.2",
     "pld-1.0"          => "redhat-6.2",
     "vine-3.0"         => "redhat-6.2",
     "slackware-9.1.0"  => "slackware-9.1.0",
     "gentoo"           => "gentoo",
     "freebsd-5"        => "slackware-9.1.0",
     "solaris-2.11"     => "freebsd-5",
    );

  %runlevels=
    (
     "redhat-6.2"      => [ "0", "1", "2", "3", "4", "5", "6" ],
     "gentoo"          => [ "boot", "default", "nonetwork" ],
     "freebsd-5"       => [ "default" ],
    );

  $distro = $dist_map{$Utils::Backend::tool{"platform"}};
  $desc = $runlevels{$distro};

  return $desc;
}

# This function gets the runlevel that is in use
sub get_sysv_default_runlevel
{
	my (@arr);
	@arr = split / /, `/sbin/runlevel` ;
  chomp $arr[1];

	return $arr[1];
}

sub get_default_runlevel
{
  my $type = &get_init_type ();

  return "default" if ($type eq "gentoo" || $type eq "rcng" || $type eq "bsd" || $type eq "smf");
  return &get_sysv_default_runlevel ();
}

sub get_sysv_paths
{
  my %dist_map =
    (
     # gst_dist => [rc.X dirs location, init.d scripts location, relative path location]
     "redhat-6.2"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.0"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.1"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.2"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.3"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-8.0"     => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-9.0"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "yoper-2.2"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "conectiva-9"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "debian-3.0"     => ["$gst_prefix/etc",      "$gst_prefix/etc/init.d",      "../init.d"],
     "suse-9.0"       => ["$gst_prefix/etc/init.d", "$gst_prefix/etc/init.d",    "../"],
     "pld-1.0"        => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "vine-3.0"       => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "ark"            => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "solaris-2.11"   => ["$gst_prefix/etc",      "$gst_prefix/etc/init.d",      "../init.d"],
     );
  my $res;

  $res = $dist_map{$Utils::Backend::tool{"platform"}};
  &Utils::Report::do_report ("service_sysv_unsupported", $Utils::Backend::tool{"platform"}) if ($res eq undef);
  return @$res;
}

# we are going to extract the name of the script
sub get_sysv_service_name
{
	my ($service) = @_;
	
	$service =~ s/$initd_path\///;
  
	return $service;
}

# This function gets the state of the service along the runlevels,
# it also returns the average priority
sub get_sysv_runlevels_status
{
	my ($service) = @_;
	my ($link);
	my ($runlevel, $action, $priority);
	my (@arr, @ret);
	
	foreach $link (<$rcd_path/rc[0-6].d/[SK][0-9][0-9]$service>)
	{
		$link =~ s/$rcd_path\///;
		$link =~ /rc([0-6])\.d\/([SK])([0-9][0-9]).*/;
		($runlevel,$action,$priority)=($1,$2,$3);

    if ($action eq "S")
		{
      push @arr, [ $runlevel, $SERVICE_START, $priority ];
    }
		elsif ($action eq "K")
		{
      push @arr, [ $runlevel, $SERVICE_STOP, $priority ];
		}
	}
	
	return \@arr;
}

# We are going to extract the information of the service
sub get_sysv_service_info
{
	my ($service) = @_;
	my ($script, @actions, @runlevels, $role);

	# Return if it's a directory
	return if (-d $service);
	
	# We have to check if the service is executable	
	return unless (-x $service);

	$script = &get_sysv_service_name ($service);
	$runlevels = &get_sysv_runlevels_status($script);

  return ($script, $runlevels);
}

# This function gets an ordered array of the available services from a SysV system
sub get_sysv_services
{
	my ($service);
	my (@arr);

	($rcd_path, $initd_path) = &get_sysv_paths ();

  return undef unless ($rcd_path && $initd_path);

	foreach $service (<$initd_path/*>)
	{
		my (@info);

		@info = &get_sysv_service_info ($service);
    push @arr, \@info  if (scalar (@info));
	}

	return \@arr;
}

# These are the functions for storing the service settings in SysV
sub remove_sysv_link
{
  my ($rcd_path, $runlevel, $script) = @_;
	
  foreach $link (<$rcd_path/rc$runlevel.d/[SK][0-9][0-9]$script>)
  {
    &Utils::Report::enter ();
    &Utils::Report::do_report ("service_sysv_remove_link", "$link");
    unlink ($link);
    &Utils::Report::leave ();
  }
}

sub add_sysv_link
{
  my ($rcd_path, $relative_path, $runlevel, $action, $priority, $service) = @_;
  my ($prio) = sprintf ("%0.2d",$priority);

  symlink ("$relative_path/$service", "$rcd_path/rc$runlevel.d/$action$prio$service");

  &Utils::Report::enter ();
  &Utils::Report::do_report ("service_sysv_add_link", "$rcd_path/rc$runlevel.d/$action$prio$service");
  &Utils::Report::leave ();
}

sub run_sysv_initd_script
{
  my ($service, $arg) = @_;
  my ($rc_path, $initd_path);
  my $str;

  &Utils::Report::enter ();
  
  ($rcd_path, $initd_path) = &get_sysv_paths ();

  if (-f "$initd_path/$service")
  {
    if (&Utils::File::run ("$initd_path/$service $arg") == 0)
    {
      &Utils::Report::do_report ("service_sysv_op_success", $service, $arg);
      &Utils::Report::leave ();
      return 0;
    }
  }
  
  &Utils::Report::do_report ("service_sysv_op_failed", $service, $arg);
  &Utils::Report::leave ();
  return -1;
}

sub set_sysv_service
{
  my ($service) = @_;
  my ($script, $priority, $runlevels, $default_runlevel);
  my ($runlevel, $action, %configured_runlevels);

  ($rcd_path, $initd_path, $relative_path) = &get_sysv_paths ();

  $script = $$service[0];
  $runlevels = $$service[1];
  $default_runlevel = &get_sysv_default_runlevel ();

  foreach $r (@$runlevels)
  {
    $runlevel = $$r[0];
    $action   = ($$r[1] == $SERVICE_START) ? "S" : "K";
    $priority = sprintf ("%0.2d", $$r[2]);

    $configured_runlevels{$runlevel} = 1;

    if (!-f "$rcd_path/rc$runlevel.d/$action$priority$script")
    {
      &remove_sysv_link ($rcd_path, $runlevel, $script);
      &add_sysv_link ($rcd_path, $relative_path, $runlevel, $action, $priority, $script);

      if ($runlevel eq $default_runlevel)
      {
        &run_sysv_initd_script ($script, ($$r[1] == $SERVICE_START) ? "start" : "stop");
      }
    }
  }

  # remove unneeded links
  foreach $link (<$rcd_path/rc[0-6].d/[SK][0-9][0-9]$script>)
	{
    $link =~ /rc([0-6])\.d/;
    $runlevel = $1;

    if (!exists $configured_runlevels{$runlevel})
    {
      &remove_sysv_link ($rcd_path, $runlevel, $script);

      if ($runlevel eq $default_runlevel)
      {
        &run_sysv_initd_script ($script, "stop");
      }
    }
  }
}

sub set_sysv_services
{
	my ($services) = @_;

	foreach $i (@$services)
	{
		&set_sysv_service($i);
	}
}

# This functions get an ordered array of the available services from a file-rc system
sub get_filerc_runlevels_status
{
  my ($start_service, $stop_service, $priority) = @_;
  my (@arr);

  # we start with the runlevels in which the service starts
  if ($start_service !~ /-/) {
    my (@runlevels);

    @runlevels = split /,/, $start_service;

    foreach $runlevel (@runlevels)
    {
      push @arr, [ $runlevel, $SERVICE_START, $priority ];
    }
  }

  # now let's go with the runlevels in which the service stops
  if ($stop_service !~ /-/) {
    my (@runlevels);

    @runlevels = split /,/, $stop_service;

    foreach $runlevel (@runlevels)
    {
      push @arr, [ $runlevel, $SERVICE_STOP, $priority ];
    }
  }

  return \@arr;
}

sub get_filerc_service_info
{
  my ($line, %ret) = @_;
  my (@runlevels, $role);

  if ($line =~ /^([0-9][0-9])[\t ]+([0-9\-S,]+)[\t ]+([0-9\-S,]+)[\t ]+\/etc\/init\.d\/(.*)/)
  {
    $priority = $1;
    $stop_service = $2;
    $start_service = $3;
    $script = $4;

    $runlevels = &get_filerc_runlevels_status ($start_service, $stop_service, $priority);

    return ($script, $runlevels);
  }

  return;
}

sub get_filerc_services
{
	my ($script);
  my ($script, @arr, %hash);

  open FILE, "$gst_prefix/etc/runlevel.conf" or return undef;
  while ($line = <FILE>)
  {
    next if ($line =~ /^\#.*/);

    my (@info);
    my ($start_service, $stop_service);

    @info = &get_filerc_service_info ($line);
    next if (!scalar (@info));

    $script = $info[0];

    if (!$hash{$script})
    {
      $hash{$script} = \@info;
    }
    else
    {
      # We need to mix the runlevels
      foreach $runlevel (@{$info[2]})
      {
        push @{$hash{$script}[2]}, $runlevel;
      }
    }
  }

  foreach $key (keys %hash)
  {
    push @arr, $hash{$key};
  }

  return \@arr;
}

# These are the functions for storing the service settings in file-rc
sub concat_filerc_runlevels
{
  my (@runlevels) = @_;

  $str = join (",", sort (@runlevels));
  return ($str) ? $str : "-";
}

sub set_filerc_service
{
  my ($buff, $initd_path, $service) = @_;
  my (%hash, $priority, $line, $str);
  my ($script, $default_runlevel, %configured_runlevels);

  $script = $$service[0];
  $runlevels = $$service[1];
  $default_runlevel = &get_sysv_default_runlevel ();

  foreach $i (@$runlevels)
  {
    $priority = 0 + $$i[2];
    $priority = 50 if ($priority == 0); #very rough guess
    $configured_runlevels {$$i[0]} = 1;

    if ($$i[1] == $SERVICE_START)
    {
      $hash{$priority}{$SERVICE_START} = [] if (!$hash{$priority}{$SERVICE_START});
      push @{$hash{$priority}{$SERVICE_START}}, $$i[0];
    }
    else
    {
      $hash{$priority}{$SERVICE_STOP} = [] if (!$hash{$priority}{$SERVICE_STOP});
      push @{$hash{$priority}{$SERVICE_STOP}}, $$i[0];
    }

    if ($$i[0] eq $default_runlevel)
    {
      &run_sysv_initd_script ($script, ($$i[1] == $SERVICE_START) ? "start" : "stop");
    }
  }

  foreach $priority (keys %hash)
  {
    $line  = sprintf ("%0.2d", $priority) . "\t";
    $line .= &concat_filerc_runlevels (@{$hash{$priority}{$SERVICE_STOP}}) . "\t";
    $line .= &concat_filerc_runlevels (@{$hash{$priority}{$SERVICE_START}}) . "\t";
    $line .= $initd_path . "/" . $script . "\n";

    push @$buff, $line;
  }

  # stop the service if it's not configured
  if (!$configured_runlevels {$default_runlevel})
  {
    &run_sysv_initd_script ($script, "stop");
  }
}

sub set_filerc_services
{
  my ($services) = @_;
  my ($buff, $lineno, $line, $file);
  my ($rcd_path, $initd_path, $relative_path) = &get_sysv_paths ();

  $file = "/etc/runlevel.conf";

  $buff = &Utils::File::load_buffer ($file);
  &Utils::File::join_buffer_lines ($buff);

  $lineno = 0;

  # We prepare the file for storing the configuration, save the initial comments
  # and delete the rest
  while ($$buff[$lineno] =~ /^#.*/)
  {
    $lineno++;
  }

  for ($i = $lineno; $i < scalar (@$buff); $i++)
  {
    $$buff[$i] =~ /.*\/etc\/init\.d\/(.*)/;

    # we need to keep the forbidden services and the services that only start in rcS.d
    # FIXME: need to remove this call to is_forbidden
    if (!&Init::ServicesList::is_forbidden ($1))
    {
      delete $$buff[$i];
    }
  }

  # Now we append the services
  foreach $service (@$services)
  {
    &set_filerc_service ($buff, $initd_path, $service);
  }

  @$buff = sort @$buff;

  push @$buff, "\n";
  &Utils::File::clean_buffer ($buff);
  &Utils::File::save_buffer ($buff, $file);
}

# this functions get a list of the services that run on a bsd init
sub get_bsd_scripts_list
{
  my ($files) = [ "rc.M", "rc.inet2", "rc.4" ];
  my ($file, $i, @scripts);

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
        $service = $1;

        push @scripts, $service;
      }
    }

    &Utils::File::close_file ($fd);
  }

  return \@scripts;
}

sub get_bsd_service_info
{
  my ($service) = @_;
  my ($script, @runlevels);

  $script = $service;
  $script =~ s/^.*\///;
  $script =~ s/^rc\.//;

  return undef if (! Utils::File::exists ($service));

  # hardcode the fourth runlevel, it's the graphical one
  if ( -x $service)
  {
    push @runlevels, [ "4", $SERVICE_START, 0 ];
  }
  else
  {
    push @runlevels, [ "4", $SERVICE_STOP, 0 ];
  }

  # FIXME: $service contains full path, would
  # be nice to just show the $script name
  return ($service, $runlevels);
}

sub get_bsd_services
{
  my (@arr, @scripts, $script);

  $scripts = &get_bsd_scripts_list ();

  foreach $script (@scripts)
  {
    my (@info);

    @info = &get_bsd_service_info ($script);
    push @arr, \@info if (scalar (@info));
  }

  return \@arr;
}

sub run_bsd_script
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

# This function stores the configuration in a bsd init
sub get_bsd_service_path
{
  my ($script) = @_;
  my (@scripts, $elem, $i);

  $scripts = &get_bsd_scripts_list ();

  foreach $i (@scripts)
  {
    $elem = $i;
    $elem =~ s/^.*\///;
    $elem =~ s/^rc\.//;

    return $i if ($elem eq $script);
  }

  return undef;
}

sub set_bsd_services
{
  my ($services) = @_;
  my ($script, $runlevels, @scripts);

  foreach $service (@$services)
  {
    $script = &get_bsd_service_path ($$service[0]);
    $runlevels = $$service[1];
    $runlevel  = $$runlevels[0];

    next if ($script eq undef);

    $action = $$runlevel[1];

    if ($action == $SERVICE_START)
    {
      &Utils::File::run ("chmod ugo+x $script");
      &run_bsd_script ($script, "start");
    }
    else
    {
      &run_bsd_script ($script, "stop");
      &Utils::File::run ("chmod ugo-x $script");
    }
  }
}

# these functions get a list of the services that run on a gentoo init
sub get_gentoo_service_status
{
  my ($script, $runlevel) = @_;
  my ($services) = &get_gentoo_services_by_runlevel ($runlevel);

  foreach $i (@$services)
  {
    return 1 if ($i eq $script);
  }

  return 0;
}

sub get_gentoo_runlevels
{
  my($raw_output) = Utils::File::run_backtick("rc-status -l");
  my(@runlevels) = split(/\n/,$raw_output);

  return @runlevels;
}

sub get_gentoo_services_by_runlevel
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

sub get_gentoo_services_list
{
  my ($service, @services);

  foreach $service (<$gst_prefix/etc/init.d/*>)
  {
    if (-x $service)
    {
      $service =~ s/.*\///;
      push @services, $service;
    }
  }

  return \@services;
}

sub gentoo_service_exists
{
  my($service) = @_;
  my($services) = &get_gentoo_services_list();

  foreach $i (@$services)
  {
    return 1 if ($i =~ /$service/);
  }

  return 0;
}

sub get_gentoo_runlevels_by_service
{
  my ($service) = @_;
  my(@runlevels,@services_in_runlevel,@contain_runlevels, $runlevel);
  my ($elem);

  # let's do some caching to improve performance
  if ($gentoo_services_hash eq undef)
  {
    @runlevels = &get_gentoo_runlevels ();

    foreach $runlevel (@runlevels)
    {
      $$gentoo_services_hash{$runlevel} = &get_gentoo_services_by_runlevel ($runlevel);
    }
  }

  if (&gentoo_service_exists($service))
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

sub get_gentoo_runlevel_status_by_service
{
  my ($service) = @_;
  my (@arr, @ret);
  my (@runlevels) = &get_gentoo_runlevels();
  my (@started) = &get_gentoo_runlevels_by_service($service);
  my (%start_runlevels) = map { $started[$_], 1 } 0 .. $#started;

  foreach $runlevel (@runlevels)
  {
    if (defined $start_runlevels{$runlevel})
    {
      push @arr, [ $runlevel, $SERVICE_START, 0 ];
    }
    else
    {
      push @arr, [ $runlevel, $SERVICE_STOP, 0 ];
    }
  }

  return \@arr;
}

sub get_gentoo_service_info
{
	my ($service) = @_;
	my ($script, @actions, @runlevels);
	my ($role);
	
  $runlevels = &get_gentoo_runlevel_status_by_service ($service);

  return ($service, $runlevels);
}

sub get_gentoo_services
{
  my ($service);
  my (@arr);
  my ($service_list) = &get_gentoo_services_list ();

  foreach $service (@$service_list)
  {
    my (@info);

    @info = &get_gentoo_service_info ($service);
    push @arr, \@info if scalar (@info);
  }

  return \@arr;
}

#FIXME: almost equal to the sysv equivalent
sub run_gentoo_script
{
  my ($service, $arg) = @_;

  &Utils::Report::enter ();

  if (&gentoo_service_exists ($service))
  {
    if (!&Utils::File::run ("/etc/init.d/$service $arg"))
    {
      &Utils::Report::do_report ("service_sysv_op_success", $service, $arg);
      &Utils::Report::leave ();
	    return 0;
	  }
  }

  &Utils::Report::do_report ("service_sysv_op_failed", $service, $arg);
  &Utils::Report::leave ();
  return -1;
}

sub set_gentoo_service_status
{
  my ($script, $rl, $action) = @_;

  if ($action == $SERVICE_START)
  {
    &Utils::File::run ("rc-update add $script $rl");
    &run_gentoo_script ($script, "start");
  }
  else
  {
    &run_gentoo_script ($script, "stop");
    &Utils::File::run ("rc-update del $script $rl");
  }
}

# This function stores the configuration in gentoo init
sub set_gentoo_services
{
  my ($services) = @_;
  my ($action, $rl, $script, $arr);

  foreach $service (@$services)
  {
    $script = $$service[0];
    $arr = $$service[1];

    foreach $i (@$arr)
    {
      $action = $$i[1];
      $rl = $$i[0];
      &set_gentoo_service_status ($script, $rl, $action);
    }
  }
}

# rcNG functions, mostly for FreeBSD
sub get_rcng_status_by_service
{
  my ($service) = @_;
  my ($fd, $line, $active);

  # This is the only difference between rcNG and archlinux
  if ($gst_dist eq "archlinux")
  {
      return &Utils::File::exists ("/var/run/daemons/$service");
  }
  else
  {
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

    &Utils::File::close_file ($fd);
    return $active;
  }
}

sub get_rcng_service_info
{
  my ($script) = @_;
  my (@runlevels);

  if (get_rcng_status_by_service ($script))
  {
    push @runlevels, [ "default", $SERVICE_START, 0 ];
  }
  else
  {
    push @runlevels, [ "default", $SERVICE_STOP, 0 ];
  }

  return ($script, $runlevels);
}

sub get_rcng_services
{
  my ($service);
  my (@arr);

  foreach $service (<$gst_prefix/etc/rc.d/*>)
  {
    my (@info);

    $service =~ s/.*\///;
    @info = &get_rcng_service_info ($service);
    push @arr, \@info if (scalar (@info));
  }

  return \@arr;
}

sub run_rcng_script
{
  my ($service, $arg) = @_;

  &Utils::Report::enter ();

  if (!&Utils::File::run ("/etc/rc.d/$service $arg"))
  {
    &Utils::File::do_report ("service_sysv_op_success", $service, $arg);
    &Utils::File::leave ();
    return 0;
  }

  &Utils::File::do_report ("service_sysv_op_failed", $service, $arg);
  &Utils::File::leave ();
  return -1;
}

# These functions store the configuration of a rcng init
sub set_rcng_service_status
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

        &run_rcng_script ($service, ($action) ? "forcestart" : "forcestop");
      }
    }

    &Utils::File::close_file ($fd);
  }
  elsif (&Utils::File::exists ("/usr/local/etc/rc.d/$service.sh"))
  {
    if ($action)
    {
      &Utils::File::copy_file ("/usr/local/etc/rc.d/$service.sh.sample",
                              "/usr/local/etc/rc.d/$service.sh");
      &run_rcng_script ($service, "forcestart");
    }
    else
    {
      &run_rcng_script ($service, "forcestop");
      Utils::File::remove ("/usr/local/etc/rc.d/$service.sh");
    }
  }
}

sub set_archlinux_service_status
{
  my ($script, $active) = @_;
  my $rcconf = '/etc/rc.conf';
  my ($daemons);

  $daemons = &Utils::Parse::get_sh ($rcconf, "DAEMONS");

  if (($daemons =~ m/$script/) && !$active)
  {
    $daemons =~ s/$script[ \t]*//;
  }
  elsif (($daemons !~ m/$script/) && $active)
  {
    $daemons =~ s/network/network $script/g;
  }

  &Utils::Replace::set_sh ($rcconf, "DAEMONS", $daemons);
  &run_rcng_script ($service, ($active) ? "start" : "stop");
}

sub set_rcng_services
{
  my ($services) = @_;
  my ($action, $runlevels, $script, $func);

  # archlinux stores services differently
  if ($gst_dist eq "archlinux")
  {
    $func = \&set_archlinux_service_status;
  }
  else
  {
    $func = \&set_rcng_service_status;
  }

  foreach $service (@$services)
  {
    $script    = $$service[0];
    $runlevels = $$service[1];
    $runlevel  = $$runlevels[0];
    $action    = ($$runlevel[1] == $SERVICE_START)? 1 : 0;

    &$func ($script, $action);
  }
}

# SuSE functions, quite similar to SysV, but not equal...
sub get_suse_service_info ($service)
{
  my ($service) = @_;
  my (@runlevels, $link, $runlevel);
                                                                                                                                                             
  foreach $link (<$rcd_path/rc[0-9S].d/S[0-9][0-9]$service>)
  {
    $link =~ s/$rcd_path\///;
    $link =~ /rc([0-6])\.d\/S[0-9][0-9].*/;
    $runlevel = $1;

    push @runlevels, [ $runlevel, $SERVICE_START, 0 ];
  }

  foreach $link (<$rcd_path/boot.d/S[0-9][0-9]$service>)
  {
    push @runlevels, [ "B", $SERVICE_START, 0 ];
  }

  return ($service, $runlevels);
}

sub get_suse_services
{
  my ($service, @arr);

  ($rcd_path, $initd_path) = &get_sysv_paths ();

  foreach $service (<$gst_prefix/etc/init.d/*>)
  {
    my (@info);

    next if (-d $service || ! -x $service);

    $service =~ s/.*\///;
    @info = &get_suse_service_info ($service);
    push @arr, \@info  if (scalar (@info));
  }

  return \@arr;
}

# This function stores the configuration in suse init
sub set_suse_services
{
  my ($services) = @_;
  my ($action, $runlevels, $script, $rllist);
  my (%configured_runlevels, $default_runlevel);

  $default_runlevel = &get_sysv_default_runlevel ();

  foreach $service (@$services)
  {
    $script = $$service[0];
    $runlevels = $$service[1];
    $rllist = "";
    %configured_runlevels = {};

    &Utils::File::run ("insserv -r $script");

    foreach $rl (@$runlevels)
    {
      $configured_runlevels{$$rl[0]} = 1;

      if ($$rl[1] == $SERVICE_START)
      {
        $rllist .= $$rl[0] . ",";
      }

      &run_sysv_initd_script ($script, ($$rl[1] == $SERVICE_START) ? "start" : "stop");
    }

    if ($rllist ne "")
    {
      $rllist =~ s/,$//;

      &Utils::File::run ("insserv $script,start=$rllist");
    }

    if (!$configured_runlevels{$default_runlevel})
    {
      &run_sysv_initd_script ($script, $$rl[1]);
    }
  }
}

# functions to get/set services info in smf
sub smf_service_exists
{
  my($service) = @_;
  my($services) = &get_smf_services_list ();

  foreach $i (@$services)
  {
    return 1 if ($i =~ /$service/);
  }

  return 0;
}

sub run_smf_svcadm
{
  my ($service, $arg) = @_;
  my ($option);

  my %op =
    ("stop" => "disable",
     "start" => "enable"
    );

  if (&smf_service_exists ($service))
  {
    if (!&Utils::File::run ("svcadm $op{$arg} $service"))
    {
      &Utils::Report::do_report ("service_sysv_op_success", $service, $arg);
      &Utils::Report::leave ();
      return 0;
    }
  }

  &Utils::Report::do_report ("service_sysv_op_failed", $service, $arg);
  &Utils::Report::leave ();
  return -1;
}

sub get_smf_runlevel_status_by_service
{
  my ($service, $status) = @_;
  my (@arr);

  if ($status)
  {
    push @arr, [ "default", $SERVICE_START, 0 ];
  }
  else
  {
    push @arr, [ "default", $SERVICE_STOP, 0 ];
  }

  return \@arr;
}

sub get_smf_service_info
{
  my ($service) = @_;
  my ($fd, @runlevels);
  my $status = 0;

  $fd = &Utils::File::run_pipe_read ("svcs -l $service");

  while (<$fd>)
  {
    $status = 1 if (/^state.*online/);
  }

  &Utils::File::close_file ($fd);

  $runlevels = &get_smf_runlevel_status_by_service ($service, $status);
  $service =~ m/.*\/(.*)$/;

  return ($service, $runlevels);
}

sub get_smf_services_list
{
  my ($fd, @list);

  $fd = &Utils::File::run_pipe_read ("svcs -H -a");

  while (<$fd>)
  {
    next if (/svc:\/milestone/);

    if (/^.*\s*.*\s*svc:\/(.*):.*/)
    {
      push @list, $1;
    }
  }

  &Utils::File::close_file ($fd);
  return \@list;
}

sub get_smf_services
{
  my ($service, @arr);
  my ($service_list) = &get_smf_services_list ();

  foreach $service (@$service_list)
  {
    my (@info);

    @info = &get_smf_service_info ($service);
    push @arr, \@info if scalar (@info);
  }

  return \@arr;
}

sub set_smf_service_status
{
  my ($service, $rl, $active) = @_;
  my ($info);

  $info = &get_smf_service_info ($service);

  #return if service has not changed
  return if ($active == @{@$info[0]}[1]);

  if ($active == $SERVICE_START)
  {
    &Utils::File::run ("svcadm enable -s $service");
  }
  else
  {
    &Utils::File::run ("svcadm disable -s $service");
  }
}

sub set_smf_services
{
  my ($services) = @_;
  my ($action, $rl, $script, $arr);

  foreach $service (@$services)
  {
    $script = $$service[0];
    $arr = $$service[1];

    foreach $i (@$arr)
    {
      $action = $$i[1];
      $rl = $$i[0];
      &set_smf_service_status ($script, $rl, $action);
    }
  }
}

# generic functions to get the available services
sub get_init_type
{
  my $gst_dist;

  $gst_dist = $Utils::Backend::tool{"platform"};

  if (($gst_dist =~ /debian/) && (Utils::File::exists ("/etc/runlevel.conf")))
  {
    return "file-rc";
  }
  elsif ($gst_dist =~ /slackware/)
  {
    return "bsd";
  }
  elsif (($gst_dist =~ /freebsd/) || ($gst_dist =~ /archlinux/))
  {
    return "rcng";
  }
  elsif (($gst_dist =~ /gentoo/) || ($gst_dist =~ /^vlos/))
  {
    return "gentoo";
  }
  elsif ($gst_dist =~ /suse/)
  {
    return "suse";
  }
  elsif ($gst_dist =~ /solaris/)
  {
    return "smf";
  }
  else
  {
    return "sysv";
  }
}

sub run_script
{
  my ($service, $arg) = @_;
  my ($proc, $type);
  my %map =
    (
     "sysv"    => \&run_sysv_initd_script,
     "file-rc" => \&run_sysv_initd_script,
     "bsd"     => \&run_bsd_script,
     "gentoo"  => \&run_gentoo_script,
     "rcng"    => \&run_rcng_script,
     "suse"    => \&run_sysv_initd_script,
     "smf"     => \&run_smf_svcadm,
    );

  $type = &get_init_type ();
  $proc = $map {$type};
  &$proc ($service, $arg);
}

sub get
{
  $type = &get_init_type ();

  return &get_sysv_services ()   if ($type eq "sysv");
  return &get_filerc_services () if ($type eq "file-rc");
  return &get_bsd_services ()    if ($type eq "bsd");
  return &get_gentoo_services () if ($type eq "gentoo");
  return &get_rcng_services ()   if ($type eq "rcng");
  return &get_suse_services ()   if ($type eq "suse");
  return &get_smf_services ()    if ($type eq "smf");

  return undef;
}

sub set
{
	my ($services) = @_;

  $type = &get_init_type ();

  &set_sysv_services   ($services) if ($type eq "sysv");
  &set_filerc_services ($services) if ($type eq "file-rc");
  &set_bsd_services    ($services) if ($type eq "bsd");
  &set_gentoo_services ($services) if ($type eq "gentoo");
  &set_rcng_services   ($services) if ($type eq "rcng");
  &set_suse_services   ($services) if ($type eq "suse");
  &set_smf_services    ($services) if ($type eq "smf");
}

1;
