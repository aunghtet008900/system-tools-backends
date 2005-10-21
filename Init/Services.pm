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

use Init::ServicesList;

sub get_runlevel_roles
{
  my (%dist_map, %runlevels);
  my ($desc, $distro);

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
     "ubuntu-5.04"    => "debian-2.2",     
          
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

     "slackware-9.1.0"  => "slackware-9.1.0",
     "slackware-10.0.0" => "slackware-9.1.0",
     "slackware-10.1.0" => "slackware-9.1.0",

     "gentoo"         => "gentoo",
     "vlos-1.2"       => "gentoo",

     "freebsd-5"      => "freebsd-5",
     "freebsd-6"      => "freebsd-5",
    );

  %runlevels=
    (
     "redhat-5.2"      => [["0",         "HALT"      ],
                           ["1",         "RECOVER"   ],
                           ["2",         "NONE"      ],
                           ["3",         "TEXT"      ],
                           ["4",         "NONE"      ],
                           ["5",         "GRAPHICAL" ],
                           ["6",         "REBOOT"    ]],

     "debian-2.2"      => [["0",         "HALT"      ],
                           ["1",         "RECOVER"   ],
                           ["2",         "NONE"      ],
                           ["3",         "NONE"      ],
                           ["4",         "NONE"      ],
                           ["5",         "NONE"      ],
                           ["6",         "REBOOT"    ]],

     "gentoo"          => [["boot",      "BOOT"      ],
                           ["default",   "GRAPHICAL" ],
                           ["nonetwork", "RECOVER"   ]],

     "freebsd-5"       => [["default",   "GRAPHICAL" ]],

     "slackware-9.1.0" => [["default",   "GRAPHICAL" ]]
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

  return "default" if ($type eq "gentoo" || $type eq "rcng" || $type eq "bsd");
  return &get_sysv_default_runlevel ();
}

sub get_sysv_paths
{
  my %dist_map =
    (
     # gst_dist => [rc.X dirs location, init.d scripts location, relative path location]
     "redhat-5.2"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-6.0"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-6.1"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-6.2"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.0"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.1"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.2"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-7.3"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-8.0"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "redhat-9"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "openna-1.0"    => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "mandrake-7.1"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-7.2"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-9.0"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-9.1"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-9.2"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-10.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandrake-10.1" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "blackpanther-4.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "conectiva-9"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "conectiva-10"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "debian-2.2"    => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
     "debian-3.0"    => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
     "debian-sarge"  => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],

     "ubuntu-5.04"   => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],       
       
     "suse-7.0"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d", "../"],
     "suse-9.0"      => ["$gst_prefix/etc/init.d", "$gst_prefix/etc/init.d", "../"],
     "suse-9.1"      => ["$gst_prefix/etc/init.d", "$gst_prefix/etc/init.d", "../"],

     "turbolinux-7.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "pld-1.0"       => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "pld-1.1"       => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "pld-1.99"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "fedora-1"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "fedora-2"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "fedora-3"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "specifix"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "vine-3.0"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "vine-3.1"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
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
      push @arr, [ $runlevel, "start", $priority ];
    }
		elsif ($action eq "K")
		{
      push @arr, [ $runlevel, "stop", $priority ];
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
		
	# We have to check out if the service is in the "forbidden" list
	return if (&Init::ServicesList::is_forbidden ($script));

	$runlevels = &get_sysv_runlevels_status($script);
  $role = &Init::ServicesList::get_role ($script);

  return ($script, $role, $runlevels);
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

# This functions get an ordered array of the available services from a file-rc system
sub get_filerc_runlevels_status
{
  my ($start_service, $stop_service, $priority) = @_;
  my (@arr, @ret);

  # we start with the runlevels in which the service starts
  if ($start_service !~ /-/) {
    my (@runlevels);

    @runlevels = split /,/, $start_service;

    foreach $runlevel (@runlevels)
    {
      push @arr, { "name"     => $runlevel,
                   "action"   => "start",
                   "priority" => $priority};
    }
  }

  # now let's go with the runlevels in which the service stops
  if ($stop_service !~ /-/) {
    my (@runlevels);

    @runlevels = split /,/, $stop_service;

    foreach $runlevel (@runlevels)
    {
      push @arr, { "name"     => $runlevel,
                   "action"   => "stop",
                   "priority" => $priority};
    }
  }

  push @ret, {"runlevel" => \@arr};
  return \@ret;
}

sub get_filerc_service_info
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

    return undef if (&Init::ServicesList::is_forbidden ($script));

    $hash{"script"} = $script;

    $hash{"runlevels"} = &get_filerc_runlevels_status ($start_service, $stop_service, $priority);
    $hash{"role"} = &Init::ServicesList::get_role ($script);

    return (\%hash);
  }

  return undef;
}

sub gst_service_filerc_get_services
{
	my ($script);
  my (%ret);
	
  open FILE, "$gst_prefix/etc/runlevel.conf" or return undef;
  while ($line = <FILE>)
  {
    if ($line !~ /^#.*/)
    {
      my (%hash);
      my ($start_service, $stop_service);
      $hash = &get_filerc_service_info ($line);

      if ($hash ne undef)
      {
        $script = $$hash{"script"};

        if ($ret{$script} eq undef)
        {
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
        }
      }
    }
  }

  return \%ret;
}

# this functions get a list of the services that run on a bsd init
sub get_bsd_service_info
{
  my ($service) = @_;
  my ($script);
  my (%hash);
	my (@arr, @rl);

  $script = $service;
  $script =~ s/^.*\///;
  $script =~ s/^rc\.//;

  return undef if (! gst_file_exists ($service));

  return undef if (&Init::ServicesList::is_forbidden ($script));

  $hash {"script"} = $service;

  # we hardcode the fourth runlevel, it's the graphical one
  if ( -x $service)
  {
    push @arr, { "name"   => 4,
                 "action" => "start" };
  }
  else
  {
    push @arr, { "name"   => 4,
                 "action" => "stop" };
  }

	push @rl, { "runlevel" => \@arr };
  
	$hash{"runlevels"} = \@rl;
  $hash{"role"} = &Init::ServicesList::get_role ($script);
  
  return \%hash;
}

sub get_bsd_services
{
  my (%ret);
  my ($files) = [ "rc.M", "rc.inet2", "rc.4" ];
  my ($file);

  foreach $i (@$files)
  {
    $file = "/etc/rc.d/" . $i;
    $fd = &gst_file_open_read_from_names ($file);

    if (!$fd) {
      &gst_report ("rc_file_read_failed", $file);
      return undef;
    }

    while (<$fd>)
    {
      $line = $_;

      if ($line =~ /^if[ \t]+\[[ \t]+\-x[ \t]([0-9a-zA-Z\/\.\-_]+) .*\]/)
      {
        my (%hash);
        $service = $1;

        $hash = &get_bsd_service_info ($service);

        if ($hash ne undef)
        {
          $ret{$service} = $hash;
        }
      }
    }

    gst_file_close ($fd);
  }

  return \%ret;
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
  my($raw_output) = gst_file_run_backtick("rc-status -l");
  my(@runlevels) = split(/\n/,$raw_output);
    
  return @runlevels;
}

sub get_gentoo_services_by_runlevel
{
  my($runlevel) = @_;
  my($raw_output) = gst_file_run_backtick("rc-status $runlevel");
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
  return &gst_service_sysv_list_dir ("/etc/init.d/");
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
      push @arr, { "name"   => $runlevel,
                   "action" => "start" };
    }
    else
    {
      push @arr, { "name"   => $runlevel,
                   "action" => "stop" };
    }
  }

  push @ret, { "runlevel" => \@arr };
  return @ret;
}

sub get_gentoo_service_info
{
	my ($service) = @_;
	my ($script, @actions, @runlevels);
	my %hash;
	
	# We have to check out if the service is in the "forbidden" list
	return undef if (&Init::ServicesList::is_forbidden ($service));

	my($runlevels) = &get_gentoo_runlevel_status_by_service ($service);

	$hash{"script"} = $service;
	$hash{"runlevels"} = $runlevels unless ($runlevels eq undef);
  $hash{"role"} = &Init::ServicesList::get_role ($service);

	return \%hash;
}

sub get_gentoo_services
{
  my ($service);
  my (%ret);
  my ($service_list) = &get_gentoo_services_list ();

  foreach $service (@$service_list)
  {
    my (%hash);

    $hash = &get_gentoo_service_info ($service);
    $ret{$service} = $hash if ($hash ne undef);
  }

  return \%ret;
}

# rcNG functions, mostly for FreeBSD

sub get_rcng_status_by_service
{
  my ($service) = @_;
  my ($fd, $line, $active);

  $fd = &gst_file_run_pipe_read ("/etc/rc.d/$service rcvar");

  while (<$fd>)
  {
    $line = $_;

    if ($line =~ /^\$.*=YES$/)
    {
      $active = 1;
      last;
    }
  }

  gst_file_close ($fd);
  return $active;
}

sub get_rcng_service_info
{
  my ($service) = @_;
  my ($script, @actions, @runlevels);
  my (%hash, @arr, @rl);

  # We have to check if the service is in the "forbidden" list
  return undef if (&Init::ServicesList::is_forbidden ($service));

  $hash{"script"} = $service;

  if (gst_service_rcng_status_by_service ($service))
  {
    push @arr, { "name"   => "default",
                 "action" => "start" };
  }
  else
  {
    push @arr, { "name"   => "default",
                 "action" => "stop" };
  }

  push @rl,  { "runlevel", \@arr };

  $hash {"runlevels"} = \@rl;
  $hash {"role"} = &Init::ServicesList::get_role ($service);

  return \%hash;
}

sub get_rcng_services
{
  my ($service);
  my (%ret);

  foreach $service (<$gst_prefix/etc/rc.d/*>)
  {
    my (%hash);
    
    $service =~ s/.*\///;
    $hash = &get_rcng_service_info ($service);

    $ret{$service} = $hash if ($hash ne undef);
  }

  return \%ret;
}

# SuSE functions, quite similar to SysV, but not equal...
sub get_suse_service_info ($service)
{
  my ($service) = @_;
  my (%hash, @arr, @ret);
                                                                                                                                                             
  # We have to check if the service is in the "forbidden" list
  return undef if (&Init::ServicesList::is_forbidden ($service));
                                                                                                                                                             
  $hash{"script"} = $service;

  foreach $link (<$rcd_path/rc[0-9S].d/S[0-9][0-9]$service>)
  {
    $link =~ s/$rcd_path\///;
    $link =~ /rc([0-6])\.d\/S[0-9][0-9].*/;
    $runlevel = $1;

    push @arr, { "name"   => $runlevel,
                 "action" => "start" };
  }

  foreach $link (<$rcd_path/boot.d/S[0-9][0-9]$service>)
  {
    push @arr, {"name"   => "B",
                "action" => "start" };
  }

  if (scalar @arr > 0)
  {
    push @ret, { "runlevel" => \@arr };
    $hash{"runlevels"} = \@ret;
    $hash{"role"} = &Init::ServicesList::get_role ($service);
  }

  return \%hash;
}

sub get_suse_services
{
  my ($service, %ret);

  ($rcd_path, $initd_path) = &gst_service_sysv_get_paths ();

  foreach $service (<$gst_prefix/etc/init.d/*>)
  {
    my (%hash);

    next if (-d $service || ! -x $service);

    $service =~ s/.*\///;
    $hash = &get_suse_service_info ($service);

    $ret{$service} = $hash if ($hash ne undef);
  }

  return \%ret;
}

# generic functions to get the available services
sub get_init_type
{
  if (($gst_dist =~ /debian/) && (Utils::File::exists ("/etc/runlevel.conf")))
  {
    return "file-rc";
  }
  elsif ($gst_dist =~ /slackware/)
  {
    return "bsd";
  }
  elsif ($gst_dist =~ /freebsd/)
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
  else
  {
    return "sysv";
  }
}

sub get
{
  $type = &get_init_type ();

  return &get_sysv_services ()   if ($type eq "sysv");
  return &gst_service_filerc_get_services () if ($type eq "file-rc");
  return &gst_service_bsd_get_services ()    if ($type eq "bsd");
  return &gst_service_gentoo_get_services () if ($type eq "gentoo");
  return &gst_service_rcng_get_services ()   if ($type eq "rcng");
  return &gst_service_suse_get_services ()   if ($type eq "suse");

  return undef;
}

1;
