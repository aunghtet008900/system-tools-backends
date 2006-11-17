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
use Utils::XML;

our $DBUS_PREFIX = "org.freedesktop.SystemToolsBackends";
our $DBUS_PATH   = "/org/freedesktop/SystemToolsBackends";
our $localstatedir;
our $tool;

eval "use Locale::gettext";
$eval_gettext = $@;
eval "use POSIX";
$eval_posix = $@;
eval "use Encode";
$eval_encode = $@;

$has_i18n = (($eval_gettext eq "") && ($eval_posix eq "") && ($eval_encode eq ""));

if ($has_i18n)
{
  # set up i18n stuff
  &setlocale (LC_MESSAGES, "");
  &bindtextdomain ("@GETTEXT_PACKAGE@", "@localedir@");

  # Big stupid hack, but it's the best I can do until
  # distros switch to perl's gettext 1.04...
  eval "&bind_textdomain_codeset (\"@GETTEXT_PACKAGE@\", \"UTF-8\")";
  &textdomain ("@GETTEXT_PACKAGE@");

  eval "sub _ { return gettext (shift); }";
}
else
{
  # fake the gettext calls
  eval "sub _ { return shift; }";
}

# --- Operation modifying variables --- #


# Variables are set to their default value, which may be overridden by user. Note
# that a $prefix of "" will cause the configurator to use '/' as the base path,
# and disables creation of directories and writing of previously non-existent
# files.

# We should get rid of all these globals.

our $no_daemon = 0;
our $prefix = "";
our $do_verbose = 0;
our $do_report = 0;
our $session_bus = 0;

sub print_usage_synopsis
{
  my ($tool) = @_;
  my ($ops_syn, $i);
  my @ops = qw (get set filter);

  foreach $i (@ops)
  {
    $ops_syn .= "--$i | " if exists $ {$$tool{"directives"}}{$i};
  }
  
  print STDERR "Usage: $$tool{name}-conf <${ops_syn}--interface | --directive | --help | --version>\n";

  print STDERR " " x length $$tool{"name"};
  print STDERR "             [--disable-immediate] [--prefix <location>]\n";

  print STDERR " " x length $$tool{"name"};
  print STDERR "             [--report] [--verbose]\n\n";
}

sub print_usage_generic
{
  my ($tool) = @_;
  my (%usage, $i);
  my @ops = qw (get set filter);

  my $usage_generic_head =<< "end_of_usage_generic;";
       Major operations (specify one of these):

end_of_usage_generic;

  my $usage_generic_tail =<< "end_of_usage_generic;";
           -h --help  Prints this page to standard error.

           --version  Prints version information to standard output.

       Modifiers (specify any combination of these):

          -no-daemon  Does not daemonize the backend

          --platform  <name-ver>  Overrides the detection of your platform\'s
                      name and version, e.g. redhat-6.2. Use with care. See the
                      documentation for a full list of supported platforms.

       -p --prefix <location>  Specifies a directory prefix where the
                      configuration is looked for or stored. When storing
                      (with --set), directories and files may be created.

          --report    Prints machine-readable diagnostic messages to standard
                      output, before any XML. Each message has a unique
                      three-digit ID. The report ends in a blank line.

       -v --verbose   Prints human-readable diagnostic messages to standard
                      error.

      --session-bus   Makes the backends to use the session bus.

end_of_usage_generic;

  $usage{"get"} =<< "end_of_usage_generic;";
       -g --get       Prints the current configuration to standard output, as
                      a standalone XML document. The configuration is read from
                      the host\'s system config files.

end_of_usage_generic;
  $usage{"set"} =<< "end_of_usage_generic;";
       -s --set       Updates the current configuration from a standalone XML
                      document read from standard input. The format is the same 
                      as for the document generated with --get.

end_of_usage_generic;
  $usage{"filter"} =<< "end_of_usage_generic;";
       -f --filter    Reads XML configuration from standard input, parses it,
                      and writes the configurator\'s impression of it back to
                      standard output. Good for debugging and parsing tests.

end_of_usage_generic;

  print STDERR $usage_generic_head;

  foreach $i (@ops)
  {
    print STDERR $usage{$i} if exists $ {$$tool{"directives"}}{$i};
  }

  print STDERR $usage_generic_tail;
}

# if $exit_code is provided (ne undef), exit with that code at the end.
sub print_usage
{
  my ($tool, $exit_code) = @_;

  &print_usage_synopsis ($tool);
  print STDERR $$tool{"description"} . "\n";
  &print_usage_generic ($tool);

  exit $exit_code if $exit_code ne undef;
}

sub print_version
{
  my ($tool, $exit_code) = @_;

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

sub set_no_daemon
{
  my ($tool) = @_;

  &set_with_param ($tool, "no-daemon", 1);
  $no_daemon = 1;
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

  &Utils::Platform::set_platform ($dist);
}

sub set_session_bus
{
  my ($tool) = @_;

  &set_with_param ($tool, "session-bus", 1);
  $session_bus = 1;
}

sub is_backend
{
  my ($tool) = @_;

  if ((ref $tool eq "HASH") &&
      (exists $$tool{"is_tool"}) &&
      ($$tool{"is_tool"} == 1))
  {
    return 1;
  }

  return 0;
}

sub init
{
  my ($name, $version, $description, $directives, @args) = @_;
  my ($arg);

  # Set the output autoflush.
  $old_fh = select (STDOUT); $| = 1; select ($old_fh);
  $old_fh = select (STDERR); $| = 1; select ($old_fh);

  $tool{"is_tool"} = 1;

  # Set backend descriptors.

  $tool{"name"} = $gst_name = $name;
  $tool{"version"} = $version;
  $tool{"description"} = $description;
  $tool{"directives"} = $directives;

  # Parse arguments.
  while ($arg = shift (@args))
  {
    if    ($arg eq "--help"      || $arg eq "-h") { &print_usage   (\%tool, 0); }
    elsif ($arg eq "--no-daemon" || $arg eq "-n") { &set_no_daemon (\%tool);    }
    elsif ($arg eq "--version")                   { &print_version (\%tool, 0); }
    elsif ($arg eq "--prefix"    || $arg eq "-p") { &set_prefix    (\%tool, shift @args); }
    elsif ($arg eq "--platform")                  { &set_dist      (\%tool, shift @args); }
    elsif ($arg eq "--session-bus")               { &set_session_bus (\%tool); }
    elsif ($arg eq "--verbose"   || $arg eq "-v")
    {
      $tool{"do_verbose"} = $do_verbose = 1;
      &Utils::Report::set_threshold (99);
    }
    elsif ($arg eq "--report")
    {
      $tool{"do_report"} = $do_report = 1;
      &Utils::Report::set_threshold (99);
    }
    else
    {
      print STDERR "Error: Unrecognized option '$arg'.\n\n";
      &print_usage (\%tool, 1);
    }
  }

  if (!$no_daemon)
  {
    &daemonize ();
  }

  # Set up subsystems.
  &Utils::Report::begin ();

  return \%tool;
}

sub daemonize
{
  chdir '/'                  or die "Can't chdir to /: $!";
  umask 0;
  open STDIN, '/dev/null'    or die "Can't read /dev/null: $!";
  open STDOUT, '>/dev/null'  or die "Can't write to /dev/null: $!";
  open STDERR, '>/dev/null'  or die "Can't write to /dev/null: $!";

  defined (my $pid = fork)   or die "Can't fork: $!";
  exit (0) if $pid;

  setsid                     or die "Can't start a new session: $!";

  # write pid file
  open (PIDFILE, ">$main::localstatedir/run/system-tools-backends.pid");
  print PIDFILE $$;
  close (PIDFILE);
}

sub get_bus
{
  return Net::DBus->session if ($session_bus);
  return Net::DBus->system;
}

1;
