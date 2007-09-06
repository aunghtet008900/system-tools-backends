#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# Common stuff for the ximian-setup-tools backends.
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

package Utils::Backend;

use Utils::Report;

our $DBUS_PREFIX = "org.freedesktop.SystemToolsBackends";
our $DBUS_PATH   = "/org/freedesktop/SystemToolsBackends";
our $localstatedir;
our $tool;

# --- Operation modifying variables --- #

# if $exit_code is provided (ne undef), exit with that code at the end.
sub print_usage
{
  my ($tool, $exit_code) = @_;

  my $usage_text =<< "end_of_usage_text;";
        NOTE: You should not be running this directly, this is only
              recomended for debuggin purposes.

       Usage: SystemToolsBackends.pl options

     Options:

           -h --help  Show help options.

          --platform  <name-ver>  Overrides the detection of your platform\'s
                      name and version, e.g. redhat-6.2. Use with care.

            --module  <module> Defines the configuration module to load:
                      GroupsConfig, HostsConfig, IfacesConfig, NFSConfig,
                      NTPConfig, ServicesConfig, SMBConfig, TimeConfig
                      or UsersConfig.

        -v --verbose  Prints human-readable diagnostic messages to standard
                      error.

  --disable-shutdown  Disable default shutdown timeout of 180 seconds.

end_of_usage_text;

  print STDERR $usage_text;

  exit $exit_code if $exit_code ne undef;
}

# --- Initialization and finalization --- #

sub set_with_param
{
  my ($tool, $arg_name, $value) = @_;
  
  if ($$tool{$arg_name} ne "")
  {
    print STDERR "Error: You may specify --$arg_name only once.\n\n";
    &print_usage ($tool, 1);
  }
  
  if ($value eq "")
  {
    print STDERR "Error: You must specify an argument to the --$arg_name option.\n\n";
    &print_usage ($tool, 1);
  }
  
  $$tool{$arg_name} = $value;
}

sub set_disable_shutdown
{
  my ($tool) = @_;
  &set_with_param ($tool, "no-shutdown", 1);
}

sub set_module
{
  my ($tool, $module) = @_;
  &set_with_param ($tool, "module", "$module.pm");
}

sub set_prefix
{
  my ($tool, $prefix) = @_;
  
  &set_with_param ($tool, "prefix", $prefix);
  $gst_prefix = $prefix;
}

sub set_dist
{
  my ($tool, $dist) = @_;
  &set_with_param ($tool, "platform", $dist);
}

sub ensure_platform
{
  if (!$tool{"platform"})
  {
    my $bus = Net::DBus->system;
    my $service = $bus->get_service("org.freedesktop.SystemToolsBackends");
    my $obj = $service->get_object ("/org/freedesktop/SystemToolsBackends/Platform");
    my $platform = $obj->getPlatform ();

    &set_dist (\%tool, $platform) if ($platform);
  }
}

sub init
{
  my (@args) = @_;
  my ($arg);

  # Set the output autoflush.
  $old_fh = select (STDOUT); $| = 1; select ($old_fh);
  $old_fh = select (STDERR); $| = 1; select ($old_fh);

  # Parse arguments.
  while ($arg = shift (@args))
  {
    if    ($arg eq "--help"      || $arg eq "-h") { &print_usage   (\%tool, 0); }
    elsif ($arg eq "--module"    || $arg eq "-m") { &set_module    (\%tool, shift @args); }
    elsif ($arg eq "--platform")                  { &set_dist      (\%tool, shift @args); }
    elsif ($arg eq "--disable-shutdown")          { &set_disable_shutdown (\%tool); }
    elsif ($arg eq "--verbose"   || $arg eq "-v") { &set_with_param (\%$tool, "do_verbose", 1); }
    else
    {
      print STDERR "Error: Unrecognized option '$arg'.\n\n";
      &print_usage (\%tool, 1);
    }
  }

  if (!$tool{"module"})
  {
    print STDERR "Error: You must specify a module to load.\n\n";
    &print_usage ($tool, 1);
  }

  # Set up subsystems.
  &Utils::Report::begin ();
  &Utils::Platform::get_system ();
  &initialize_timer (\%tool);

  return \%tool;
}

sub get_bus
{
  return Net::DBus->session
}

sub run
{
  Net::DBus::Reactor->main->run ();
}

sub shutdown
{
  # exit the main loop
  Net::DBus::Reactor->main->shutdown ();
}

sub initialize_timer
{
  my ($tool) = @_;

  if (!$$tool{"no-shutdown"})
  {
    # remove previous timer
    Net::DBus::Reactor->main->remove_timeout ($$tool{"timer"}) if ($$tool {"timer"});

    #wait three minutes until shutdown
    $$tool{"timer"} = Net::DBus::Reactor->main->add_timeout (180000, Net::DBus::Callback->new(method => \&shutdown));
  }
}

1;
