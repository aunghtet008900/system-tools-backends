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

     "rpath"          => "redhat-5.2",

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
     "mandrake-10.2" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandriva-2006.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "mandriva-2006.1" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "yoper-2.2" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "blackpanther-4.0" => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "conectiva-9"   => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "conectiva-10"  => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "debian-2.2"    => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
     "debian-3.0"    => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
     "debian-sarge"  => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
     "ubuntu-5.04"   => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],       
     "ubuntu-5.10"   => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],
     "ubuntu-6.04"   => ["$gst_prefix/etc", "$gst_prefix/etc/init.d", "../init.d"],

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
     "fedora-4"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "rpath"         => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],

     "vine-3.0"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "vine-3.1"      => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
     "ark"           => ["$gst_prefix/etc/rc.d", "$gst_prefix/etc/rc.d/init.d", "../init.d"],
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

sub set_sysv_service
{
  my ($service) = @_;
  my ($script, $priority, $runlevels);
  my ($action);

  ($rcd_path, $initd_path, $relative_path) = &get_sysv_paths ();

  $script = $$service[0];
  $runlevels = $$service[2];

  foreach $r (@$runlevels)
  {
    $runlevel = $$r[0];
    $action   = ($$r[1] eq "start") ? "S" : "K";
    $priority = $$r[2];

    if (!-f "$rcd_path/rc$runlevel.d/$action$priority$script")
    {
      &remove_sysv_link ($rcd_path, $runlevel, $script);
      &add_sysv_link ($rcd_path, $relative_path, $runlevel, $action, $priority, $script);
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

sub get_filerc_services
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

  $runlevels = $$service[2];

  foreach $i (@$runlevels)
  {
    $priority = 0 + $$i[2];
    $priority = 50 if ($priority == 0); #very rough guess

    if ($$i[1] eq "start")
    {
      $hash{$priority}{"start"} = [] if (!$hash{$priority}{"start"});
      push @{$hash{$priority}{"start"}}, $$i[0];
    }
    else
    {
      $hash{$priority}{"stop"} = [] if (!$hash{$priority}{"stop"});
      push @{$hash{$priority}{"stop"}}, $$i[0];
    }
  }

  foreach $priority (keys %hash)
  {
    $line  = sprintf ("%0.2d", $priority) . "\t";
    $line .= &concat_filerc_runlevels (@{$hash{$priority}{"stop"}}) . "\t";
    $line .= &concat_filerc_runlevels (@{$hash{$priority}{"start"}}) . "\t";
    $line .= $initd_path . "/" . $$service{"script"} . "\n";

    push @$buff, $line;
  }
}

sub set_filerc_services
{
  my ($services) = @_;
  my ($buff, $lineno, $line, $file);
  my ($rcd_path, $initd_path, $relative_path) = &sysv_get_paths ();

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
sub get_bsd_service_info
{
  my ($service) = @_;
  my ($script);
  my (%hash);
	my (@arr, @rl);

  $script = $service;
  $script =~ s/^.*\///;
  $script =~ s/^rc\.//;

  return undef if (! Utils::File::exists ($service));

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

        $hash = &get_bsd_service_info ($service);

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

# This function stores the configuration in a bsd init
sub set_bsd_services
{
  my ($services) = @_;
  my ($script, $runlevels);

	foreach $service (@$services)
	{
    $script = $$service[0];
    $runlevels = $$service[2];
    $runlevel  = $$runlevels[0];

    $action = $$runlevel[1];

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

sub set_gentoo_service_status
{
  my ($script, $rl, $action) = @_;

  if ($action eq "start")
  {
    &Utils::File::run ("rc-update add $script $rl");
  }
  elsif ($action eq "stop")
  {
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
    $arr = $$service[2];

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

    Utils::File::close_file ($fd);
    return $active;
  }
}

sub get_rcng_service_info
{
  my ($service) = @_;
  my ($script, @actions, @runlevels);
  my (%hash, @arr, @rl);

  # We have to check if the service is in the "forbidden" list
  return undef if (&Init::ServicesList::is_forbidden ($service));

  $hash{"script"} = $service;

  if (get_rcng_status_by_service ($service))
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
    $runlevels = $$service[2];
    $runlevel  = $$runlevels[0];
    $action    = ($$runlevel[1] eq "start")? 1 : 0;

    &$func ($script, $action);
  }
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

  ($rcd_path, $initd_path) = &get_sysv_paths ();

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

# This function stores the configuration in suse init
sub set_suse_services
{
  my ($services) = @_;
  my ($action, $runlevels, $script, $rllist);

  foreach $service (@$services)
  {
    $script = $$service[0];
    $runlevels = $$service[2];
    $rllist = "";

    &Utils::File::run ("insserv -r $script");

    foreach $rl (@$runlevels)
    {
      if ($$rl[1] eq "start")
      {
        $rllist .= $$rl[0] . ",";
      }
    }

    if ($rllist ne "")
    {
      $rllist =~ s/,$//;

      &Utils::File::run ("insserv $script,start=$rllist");
    }
  }
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
  else
  {
    return "sysv";
  }
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
}

1;
