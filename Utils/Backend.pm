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
use Utils::Platform;

our $DBUS_PREFIX = "org.freedesktop.SystemToolsBackends";
our $DBUS_PATH   = "/org/freedesktop/SystemToolsBackends";
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

$gst_prefix = "";
$gst_do_verbose = 0;
$gst_do_report = 0;

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
       -i --interface Shows the available backend directives for interactive mode,
                      in XML format.

                      Interactive mode is set when no -g, -s or -f arguments are
                      given.

       -d --directive <directive> Takes a \'name::arg1::arg2...::argN\' directive
                      value as comming from standard input in interactive mode.

       -h --help      Prints this page to standard error.

          --version   Prints version information to standard output.

       Modifiers (specify any combination of these):

          --platform  <name-ver>  Overrides the detection of your platform\'s
                      name and version, e.g. redhat-6.2. Use with care. See the
                      documentation for a full list of supported platforms.

          --disable-immediate  With --set, prevents the configurator from
                      running any commands that make immediate changes to
                      the system configuration. Use with --prefix to make a
                      dry run that won\'t affect your configuration.

                      With --get, suppresses running of non-vital external
                      programs that might take a long time to finish.

       -p --prefix <location>  Specifies a directory prefix where the
                      configuration is looked for or stored. When storing
                      (with --set), directories and files may be created.

          --report    Prints machine-readable diagnostic messages to standard
                      output, before any XML. Each message has a unique
                      three-digit ID. The report ends in a blank line.

       -v --verbose   Prints human-readable diagnostic messages to standard
                      error.
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

  print "$$tool{name} $$tool{version}\n";

  exit $exit_code if $exit_code ne undef;
}

# --- Initialization and finalization --- #


sub set_operation
{
  my ($tool, $operation) = @_;

  if ($tool{"operation"} ne "")
  {
    print STDERR "Error: You may specify only one major operation.\n\n";
    &print_usage ($tool, 1);
    exit (1);
  }

  $$tool{"operation"} = $operation;
}

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

sub set_op_directive
{
  my ($tool, $directive) = @_;

  &set_with_param ($tool, "directive", $directive);
  &set_operation ($tool, "directive");
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
  $gst_dist = $dist;
}

sub merge_std_directives
{
  my ($tool) = @_;
  my ($directives, $i);
  my %std_directives =
      (
# platforms directive to do later.       
       "platforms"    => [ \&Utils::Platform::list, [],
                           "Print XML showing platforms supported by backend." ],
       "platform_set" => [ \&Utils::Platform::set_platform,    ["platform"],
                           "Force the selected platform. platform arg must be one of the listed in the" .
                           "reports." ],
       "interface"    => [ \&print_interface_directive, [],
                           "Print XML showing backend capabilities." ],
       "end"          => [ \&end_directive,   [],
                           "Finish gracefuly and exit with success." ]
       );

  $directives = $$tool{"directives"};
  # Standard directives may be overriden.
  foreach $i (keys %std_directives)
  {
    $$directives{$i} = $std_directives{$i} if !exists $$directives{$i};
  }
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

  # print a CR for synchronysm with the frontend
  print "\n";

  # Set the output autoflush.
  $old_fh = select (STDOUT); $| = 1; select ($old_fh);
  $old_fh = select (STDERR); $| = 1; select ($old_fh);

  $tool{"is_tool"} = 1;

  # Set backend descriptors.

  $tool{"name"} = $gst_name = $name;
  $tool{"version"} = $version;
  $tool{"description"} = $description;
  $tool{"directives"} = $directives;
  
  &merge_std_directives (\%tool);

  # Parse arguments.
  
  while ($arg = shift (@args))
  {
    if    ($arg eq "--get"       || $arg eq "-g") { &set_operation (\%tool, "get"); }
    elsif ($arg eq "--set"       || $arg eq "-s") { &set_operation (\%tool, "set"); }
    elsif ($arg eq "--filter"    || $arg eq "-f") { &set_operation (\%tool, "filter"); }
    elsif ($arg eq "--directive" || $arg eq "-d") { &set_op_directive (\%tool, shift @args); }
    elsif ($arg eq "--interface" || $arg eq "-i") { &print_interface  (\%tool, 0); }
    elsif ($arg eq "--help"      || $arg eq "-h") { &print_usage   (\%tool, 0); }
    elsif ($arg eq "--version")                   { &print_version (\%tool, 0); }
    elsif ($arg eq "--prefix"    || $arg eq "-p") { &set_prefix    (\%tool, shift @args); }
    elsif ($arg eq "--platform")                  { &set_dist      (\%tool, shift @args); }
    elsif ($arg eq "--verbose"   || $arg eq "-v")
    {
      $tool{"do_verbose"} = $gst_do_verbose = 1;
      &Utils::Report::set_threshold (99);
    }
    elsif ($arg eq "--report")
    {
      $tool{"do_report"} = $gst_do_report = 1;
      &Utils::Report::set_threshold (99);
    }
    else
    {
      print STDERR "Error: Unrecognized option '$arg'.\n\n";
      &print_usage (\%tool, 1);
    }
  }
  
  # Set up subsystems.

  &Utils::Platform::get_system (\%tool);
  &Utils::Platform::guess (\%tool) if !$tool{"platform"};
  &Utils::Report::begin ();

  return \%tool;
}

sub terminate
{
  &Utils::Report::set_threshold (-1);
  exit (0);
}

sub end_directive
{
  my ($tool) = @_;

  &Utils::Report::end ();
  &Utils::XML::print_request_end ();
  &terminate ();
}


sub print_interface_comment
{
  my ($name, $directive) = @_;
  my %std_comments =
      ("get" =>
       "Prints the current configuration to standard output, as " .
       "a standalone XML document. The configuration is read from " .
       "the host\'s system config files.",
       
       "set" =>
       "Updates the current configuration from a standalone XML " .
       "document read from standard input. The format is the same " .
       "as for the document generated with --get.",

       "filter" =>
       "Reads XML configuration from standard input, parses it, " .
       "and writes the configurator\'s impression of it back to " .
       "standard output. Good for debugging and parsing tests."
       );

  $comment = $$directive[2];
  $comment = $std_comments{$name} if (exists $std_comments{$name});

  if ($comment)
  {
    &Utils::XML::print_line ("<comment>");
    &Utils::XML::print_line ($comment);
    &Utils::XML::print_line ("</comment>");
  }
}

# if $exit_code is provided (ne undef), exit with that code at the end.
sub print_interface
{
  my ($tool, $exit_code) = @_;
  my ($directives, $key);

  $directives = $$tool{"directives"};

  &Utils::XML::print_begin ("interface");
  foreach $key (sort keys %$directives)
  {
    my $comment = $ {$$directives{$key}}[2];
    my @args = @{ $ {$$directives{$key}}[1]};
    my $arg;
    
    &Utils::XML::container_enter ("directive");
    &Utils::XML::print_line ("<name>$key</name>");
    &print_interface_comment ($key, $$directives{$key});

    while ($arg = shift (@args))
    {
      if ($arg =~ /\*$/)
      {
        my $tmp = $arg;

        &Utils::Report::do_report ("directive_invalid", $key) if ($#args != -1);
        chop $tmp;
        &Utils::XML::print_line ("<var-arguments>$tmp</var-arguments>");
      }
      else
      {
        &Utils::XML::print_line ("<argument>$arg</argument>");
      }
    }

    &Utils::XML::container_leave ();
  }
  &Utils::XML::print_end ("interface");

  exit $exit_code if $exit_code ne undef;
}


sub print_interface_directive
{
  my ($tool) = @_;

  &Utils::Report::end ();
  &print_interface ($tool);
}


sub directive_fail
{
  my (@report_args) = @_;
  
  &Utils::Report::do_report (@report_args);
  &Utils::Report::end ();
  &Utils::XML::print_request_end ();
}

# This sepparates a line in args by the directive line format,
# doing the necessary escape sequence manipulations.
sub directive_parse_line
{
  my ($line) = @_;
  my ($arg, @args);
  
  chomp $line;
  $line =~ s/\\\\/___escape\\___/g;
  $line =~ s/\\::/___escape2:___/g;
  @args = split ("::", $line);
  
  foreach $arg (@args)
  {
    $arg =~ s/___escape2:___/::/g;
    $arg =~ s/___escape\\___/\\/g;
  }

  return @args;
}

# Normal use for the direcives hash in the backends is:
#
# "name" => [ \&sub, [ "arg1", "arg2", "arg3",... "argN" ], "comment" ]
#
# name        name of the directive that will be used in interactive mode.
# sub         is the function that runs the directive.
# arg1...argN show the number of arguments that the function may use. The
#             name of the argument is used for documentation purposes for
#             the interfaces XML (dumped by the "interfaces" directive).
#             An argument ending with * means that 0 or more arguments
#             may be given.
# comment     documents the directive in a brief way, for the interface XML.
#
# Example:
#
# "install_font" => [ \&gst_font_install, [ "directory", "file", "morefiles*" ], "Installs fonts." ]
#
# This means that when an interactive mode directive is given, such as:
#
# install_font::/usr/share/fonts::/tmp/myfile::/tmp/myfile2
#
# the function gst_font_install will be called, with the tool structure, /usr/share/fonts,
# /tmp/myfile and /tmp/myfile2 as arguments. Directives with 1 or 0 arguments
# would be rejected, as we are requiring 2, and optionaly allowing more.
# Check enable_iface in network-conf.in for an example of a directive handler.
#
# The generated interface XML piece for this entry would be:
#
# <directive>
#  <name>gst_font_install</name>
#  <comment>
#  Installs fonts.
#  </comment>
#  <argument>directory</argument>
#  <argument>file</argument>
#  <var-arguments>morefiles</var-arguments>
# </directive>


sub directive_run
{
  my ($tool, $line) = @_;
  my ($key, @args, $directives, $proc, $reqargs, $i);

  ($key, @args) = &directive_parse_line ($line);
  $directives = $$tool{"directives"};

  &Utils::Report::begin ();

  if (!exists $$directives{$key})
  {
    &directive_fail ("directive_unsup", $key);
    return;
  }

  $reqargs = [];
  foreach $i (@{$ {$$directives{$key}}[1]})
  {
    push @$reqargs, $i if not ($i =~ /\*$/);
  }
  
  if (scalar @args < scalar @$reqargs)
  {
    &directive_fail ("directive_lowargs", $key, scalar (@$reqargs), join (',', $key, @args));
    return;
  }

  $reqargs = $ {$$directives{$key}}[1];
  if ((scalar @args != scalar @$reqargs) &&
      !($$reqargs[$#$reqargs] =~ /\*$/))
  {
    &directive_fail ("directive_badargs", $key, scalar (@$reqargs), join (',', $key, @args));
    return;
  }

  &Utils::Report::do_report ("directive_run", $key, join (',', @args));

  $proc = $ {$$directives{$key}}[0];
  &$proc ($tool, @args);

  &Utils::XML::print_request_end ();
}


sub run
{
  my ($tool) = @_;
  my ($line);

  if ($$tool{"operation"} ne "directive")
  {
    my @stdops = qw (get set filter);
    my ($op);

    foreach $op (@stdops)
    {
      if ($$tool{"operation"} eq $op)
      {
        $$tool{"operation"} = "directive";
        $$tool{"directive"} = $op;
      }
    }
  }

  &Utils::Report::end ();

  if ($$tool{"directive"})
  {
    &directive_run ($tool, $$tool{"directive"});
    &terminate ();
  }

  while ($line = <STDIN>)
  {
    &directive_run ($tool, $line);
  }
}

1;