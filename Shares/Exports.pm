#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# Common functions for exporting network shares (NFS or SMB).
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

package Shares::Exports;

use Utils::File;
use Utils::Replace;
use Utils::Parse;


$SCRIPTSDIR = "@scriptsdir@";
if ($SCRIPTSDIR =~ /^@scriptsdir[@]/)
{
    $SCRIPTSDIR = ".";
    $DOTIN = ".in";
}

require "$SCRIPTSDIR/network.pl$DOTIN";


# --- share_export_smb_info; information on a particular SMB export --- #

sub gst_share_smb_info_new
{
  my $info = {};
  return $info;
}

sub gst_share_smb_info_set
{
  my ($info, $key, $value) = @_;
  
  if ($value eq "")
  {
    delete $info->{$key};
  }
  else
  {
    $info->{$key} = $value;
  }
}

sub gst_share_smb_info_get_name
{
  return $_[0]->{'name'};
}

sub gst_share_smb_info_set_name
{
  &gst_share_smb_info_set ($_[0], 'name', $_[1]);
}

sub gst_share_smb_info_get_point
{
  return $_[0]->{'point'};
}

sub gst_share_smb_info_set_point
{
  &gst_share_smb_info_set ($_[0], 'point', $_[1]);
}

sub gst_share_smb_info_get_comment
{
  return $_[0]->{'comment'};
}

sub gst_share_smb_info_set_comment
{
  &gst_share_smb_info_set ($_[0], 'comment', $_[1]);
}

sub gst_share_smb_info_get_enabled
{
  return $_[0]->{'enabled'};
}

sub gst_share_smb_info_set_enabled
{
  &gst_share_smb_info_set ($_[0], 'enabled', $_[1]);
}

sub gst_share_smb_info_get_browse
{
  return $_[0]->{'browse'};
}

sub gst_share_smb_info_set_browse
{
  &gst_share_smb_info_set ($_[0], 'browse', $_[1]);
}

sub gst_share_smb_info_get_public
{
  return $_[0]->{'public'};
}

sub gst_share_smb_info_set_public
{
  &gst_share_smb_info_set ($_[0], 'public', $_[1]);
}

sub gst_share_smb_info_get_write
{
  return $_[0]->{'write'};
}

sub gst_share_smb_info_set_write
{
  &gst_share_smb_info_set ($_[0], 'write', $_[1]);
}

# --- share_smb_table; multiple instances of share_smb_info --- #

sub gst_share_smb_table_new
{
  my @array;
  return \@array;
}

sub gst_share_smb_table_add
{
  my ($table, $info) = @_;
  push @$table, $info;
}

sub gst_share_smb_table_find
{
  my ($table, $name) = @_;

  for $i (@$table)
  {
    if (&gst_share_smb_info_get_name ($i) eq $name)
    {
      return $i;
    }
  }

  return undef;
}

# --- share_export_nfs_info; information on a particular NFS export --- #

sub gst_share_nfs_info_new
{
  my $info = {};
  return $info;
}

sub gst_share_nfs_info_dup
{
  my ($orig) = @_;
  my $dup;

  $dup = { %$orig };
  &gst_share_nfs_info_set_client_table ($dup, &gst_share_nfs_client_table_dup (&gst_share_nfs_info_get_client_table ($orig)));
  return $dup;
}

sub gst_share_nfs_info_match_data
{
  my ($info_a, $info_b) = @_;

  if (&gst_share_nfs_info_get_point ($info_a) eq &gst_share_nfs_info_get_point ($info_b) &&
      &gst_share_nfs_info_print_clients ($info_a) eq &gst_share_nfs_info_print_clients ($info_b))
  {
    return 1;
  }

  return 0;
}

sub gst_share_nfs_info_set
{
  my ($info, $key, $value) = @_;
  
  if ($value eq "")
  {
    delete $info->{$key};
  }
  else
  {
    $info->{$key} = $value;
  }
}

sub gst_share_nfs_info_get_point
{
  return $_[0]->{'point'};
}

sub gst_share_nfs_info_set_point
{
  &gst_share_nfs_info_set ($_[0], 'point', $_[1]);
}

sub gst_share_nfs_info_get_client_table
{
  return $_[0]->{'clients'};
}

sub gst_share_nfs_info_set_client_table
{
  &gst_share_nfs_info_set ($_[0], 'clients', $_[1]);
}

# --- share_nfs_table; multiple instances of share_smb_info --- #

sub gst_share_nfs_table_new
{
  my @array;
  return \@array;
}

sub gst_share_nfs_table_add
{
  my ($table, $info) = @_;
  push @$table, $info;
}

sub gst_share_nfs_table_dup
{
  my ($orig) = @_;
  my $dup = &gst_share_nfs_table_new ();
  my $i;

  foreach $i (@$orig)
  {
    &gst_share_nfs_table_add ($dup, &gst_share_nfs_info_dup ($i));
  }

  return $dup;
}

sub gst_share_nfs_table_find
{
  my ($table, $point) = @_;
  my $i;

  for $i (@$table)
  {
    if (&gst_share_nfs_info_get_point ($i) eq $point)
    {
      return $i;
    }
  }

  return undef;
}

sub gst_share_nfs_table_find_info_equivalent
{
  my ($table, $info) = @_;

  return &gst_share_nfs_table_find ($table, &gst_share_nfs_info_get_point ($info));
}

# --- share_export_nfs_client_info; information on a particular NFS export's client --- #

sub gst_share_nfs_client_info_new
{
  my $info = {};
  return $info;
}

sub gst_share_nfs_client_info_dup
{
  my ($orig) = @_;
  my $dup;

  $dup = { %$orig };
  return $dup;
}

sub gst_share_nfs_client_info_set
{
  my ($info, $key, $value) = @_;
  
  if ($value eq "")
  {
    delete $info->{$key};
  }
  else
  {
    $info->{$key} = $value;
  }
}

sub gst_share_nfs_client_info_get_pattern
{
  return $_[0]->{'pattern'};
}

sub gst_share_nfs_client_info_set_pattern
{
  &gst_share_nfs_client_info_set ($_[0], 'pattern', $_[1]);
}

sub gst_share_nfs_client_info_get_write
{
  return $_[0]->{'write'};
}

sub gst_share_nfs_client_info_set_write
{
  &gst_share_nfs_client_info_set ($_[0], 'write', $_[1]);
}

# --- share_nfs_client_table; multiple instances of share_smb_client_info --- #

sub gst_share_nfs_client_table_new
{
  my @array;
  return \@array;
}

sub gst_share_nfs_client_table_dup
{
  my ($orig) = @_;
  my $dup = &gst_share_nfs_client_table_new ();
  my $i;

  foreach $i (@$orig)
  {
    &gst_share_nfs_client_table_add ($dup, &gst_share_nfs_client_info_dup ($i));
  }

  return $dup;
}

sub gst_share_nfs_client_table_add
{
  my ($table, $info) = @_;
  push @$table, $info;
}

# --- Parsing --- #

sub gst_share_parse_smb_conf
{
  my ($smb_conf_name) = @_;
  my (@sections, $table);

  $table = gst_share_smb_table_new ();

  # Get the sections.

  @sections = &Utils::Parse::get_ini_sections ($smb_conf_name);

  for $section (@sections)
  {
    next if ($section =~ /^(global)|(homes)|(printers)|(print\$)$/);
    next if (&Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "printable"));

    my $sesi = &gst_share_smb_info_new ();
    my $point, $comment, $enabled, $browseable, $public, $writable, $printable;

    $point      = &Utils::Parse::get_from_ini      ($smb_conf_name, $section, "path");
    $comment    = &Utils::Parse::get_from_ini      ($smb_conf_name, $section, "comment");
    $enabled    = &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "available");
    $browseable = &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "browsable")   ||
                  &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "browseable");
    $public     = &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "public")      ||
                  &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "guest");
    $writable   = &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "writable")    ||
                  &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "writeable");

    &gst_share_smb_info_set_name    ($sesi, $section);
    &gst_share_smb_info_set_point   ($sesi, $point);
    &gst_share_smb_info_set_comment ($sesi, $comment);
    &gst_share_smb_info_set_enabled ($sesi, $enabled);
    &gst_share_smb_info_set_browse  ($sesi, $browseable);
    &gst_share_smb_info_set_public  ($sesi, $public);
    &gst_share_smb_info_set_write   ($sesi, $writable);

    &gst_share_smb_table_add ($table, $sesi);
  }

  return $table;
}

sub gst_share_parse_nfs_exports
{
  my ($nfs_exports_name) = @_;
  my (@sections, $table, $entries);
  my $point;

  $table = &gst_share_nfs_table_new ();

  $entries = &Utils::Parse::split_hash_with_continuation ($nfs_exports_name, "[ \t]+", "[ \t]+");

  foreach $point (keys %$entries)
  {
    my $clients = $$entries{$point};
    my $info = &gst_share_nfs_info_new ();
    my $client_table = &gst_share_nfs_client_table_new ();

    &gst_share_nfs_info_set_point ($info, $point);

    foreach $client (@$clients)
    {
      my $cinfo = &gst_share_nfs_client_info_new ();
      my $pattern;

      $client =~ /^([a-zA-Z0-9.-_*?@\/]+)/;
      $pattern = $1;
      $pattern = "0.0.0.0/0" if $pattern eq "";
      &gst_share_nfs_client_info_set_pattern ($cinfo, $pattern);

      my $option_str = "";
      my @options;

      if ($client =~ /\((.+)\)/) { $option_str = $1; }
      @options = ($option_str =~ /([a-zA-Z0-9_=-]+),?/mg);

      for $option (@options)
      {
        if ($option eq "rw") { &gst_share_nfs_client_info_set_write ($cinfo, 1); }
        # Add supported NFS export options here. Some might have to be split on '='.
      }

      &gst_share_nfs_client_table_add ($client_table, $cinfo);
    }

    &gst_share_nfs_info_set_client_table ($info, $client_table);
    &gst_share_nfs_table_add ($table, $info);
  }

  return $table;
}

# --- Replacing --- #

sub gst_share_replace_smb_conf
{
  my ($file, $table) = @_;
  my (@sections, $export);

  # Get the sections.

  @sections = &Utils::Parse::get_ini_sections ($file);

  for $section (@sections)
  {
    next if ($section =~ /^(global)|(homes)|(printers)|(print\$)$/);
    next if (&Utils::Parse::get_from_ini_bool ($file, $section, "printable"));

    if (!&gst_share_smb_table_find ($table, $section))
    {
      &Utils::Replace::remove_ini_section ($file, $section);
    }
  }

  for $export (@$table)
  {
    my $point, $comment, $enabled, $browseable, $public, $writable, $printable;
    my $name = &gst_share_smb_info_get_name ($export);

    &Utils::Replace::set_ini      ($file, $name, "path",       &gst_share_smb_info_get_point      ($export));
    &Utils::Replace::set_ini      ($file, $name, "comment",    &gst_share_smb_info_get_comment    ($export));
    &Utils::Replace::set_ini_bool ($file, $name, "available",  &gst_share_smb_info_get_enabled    ($export));
    &Utils::Replace::set_ini_bool ($file, $name, "browseable", &gst_share_smb_info_get_browse     ($export));
    &Utils::Replace::set_ini_bool ($file, $name, "public",     &gst_share_smb_info_get_public     ($export));
    &Utils::Replace::set_ini_bool ($file, $name, "writable",   &gst_share_smb_info_get_write      ($export));

    &Utils::Replace::remove_ini_var ($file, $name, "browsable");
    &Utils::Replace::remove_ini_var ($file, $name, "guest");
    &Utils::Replace::remove_ini_var ($file, $name, "writeable");
  }
}

sub gst_share_nfs_exports_get_next_entry_line
{
  my ($infd, $outfd) = @_;

  while (<$infd>)
  {
    # Each line is in the following format:
    # <point> <clients>
    my @line = split /[ \t]+/, $_;
    if ($line[0] eq "") { shift @line; }
    if (@line < 1 || &Utils::Util::ignore_line (@line)) { print $outfd $_; next; }

    return $_;
  }

  return undef;
}

sub gst_share_nfs_exports_get_entry_line_fields  # line
{
  my ($line) = @_;

  # Remove leading spaces.
  $line =~ s/^[ \t]*//;

  # Remove trailing spaces and comments.
  $line =~ s/[ \t]*\#.*//;

  return split /[ \t]+/, $line;
}

sub gst_share_nfs_info_print_clients
{
  my ($info) = @_;
  my $line = "";
  my $clients, $client;

  $clients = &gst_share_nfs_info_get_client_table ($info);

  for $client (@$clients)
  {
    $line .= &gst_share_nfs_client_info_get_pattern ($client);
    $line .= "(rw)" if (&gst_share_nfs_client_info_get_write ($client));
    $line .= " ";
  }

  return $line;
}

sub gst_share_nfs_info_print_entry
{
  my ($info) = @_;
  my $line;

  # <point>

  $line = sprintf ("%-15s ", &gst_share_nfs_info_get_point ($info));

  # <clients>

  $line .= &gst_share_nfs_info_print_clients ($info);

  return $line;
}

sub gst_share_nfs_client_print_option_hash
{
  my ($opthash) = @_;
  my $string = "";

  for $key (keys %$opthash)
  {
    my $value = $$opthash{$key};

    $string .= "," if $string ne "";
    $string .= $key;

    if ($value eq " ")
    {
      $string .= "=";
    }
    elsif ($value ne "")
    {
      $string .= "=" . $value;
    }
  }

  return $string;
}

sub gst_share_nfs_info_print_synthesized_entry
{
  my ($info, $line) = @_;
  my $outline;
  my $ctable = &gst_share_nfs_info_get_client_table ($info);

  # <point>

  $outline = sprintf ("%-15s", &gst_share_nfs_info_get_point ($info));

  # <clients>

  chomp $line;
  my @clients = split /[ \t]+/, $line;
  shift @clients;

  # Make client hash based on line.

  my $chash = { };

  for $client (@clients)
  {
    my $opthash = { };

    $client =~ /^([a-zA-Z0-9.-_*?@\/]+)/;
    my $pattern = $1;
    $$chash{$pattern} = $opthash;

    my $option_str = "";
    if ($client =~ /\((.+)\)/) { $option_str = $1; }
    @options = ($option_str =~ /([a-zA-Z0-9_=-]+),?/mg);

    for $option (@options)
    {
      my ($key, $value) = split /[=]/, $option;
      next if ($key eq "");

      if ($value eq "" && $option =~ /=/) { $value = " "; }
      $$opthash{$key} = $value;
    }
  }

  # @clients contains client(options) entries.

  for $cinfo (@$ctable)
  {
    my $pattern = &gst_share_nfs_client_info_get_pattern ($cinfo);
    my $opthash = $$chash{$pattern};

    if (&gst_share_nfs_client_info_get_write ($cinfo))
    {
      $$opthash{'rw'} = "";
    }
    else
    {
      delete $$opthash{'rw'};
    }

    $outline .= " " . &gst_share_nfs_client_info_get_pattern ($cinfo);
    my $client_string = &gst_share_nfs_client_print_option_hash ($opthash);
    if ($client_string ne "")
    {
      $outline .= "(" . $client_string . ")";
    }
  }

  return $outline;
}

sub gst_share_nfs_exports_add_entry
{
  my ($file, $info) = @_;
  my ($infd, $outfd);
  my ($line);

  ($infd, $outfd) = &Utils::File::open_filter_write_from_names ($file);
  return undef if !$outfd;

  while (<$infd>) { print $outfd $_; }
  &Utils::File::close_file ($infd);

  print $outfd &gst_share_nfs_info_print_entry ($info) . "\n";
  &Utils::File::close_file ($outfd);
}

sub gst_share_nfs_exports_update_entry  # filename, filesys_info
{
  my ($file, $info) = @_;
  my ($infd, $outfd);
  my ($line);
  my $replaced = 0;

  ($infd, $outfd) = &Utils::File::open_filter_write_from_names ($file);
  return undef if !$outfd;

  while ($line = &gst_share_nfs_exports_get_next_entry_line ($infd, $outfd))
  {
    my $point = &gst_share_nfs_exports_get_entry_line_point ($line);

    if (!$replaced && $point eq &gst_share_nfs_info_get_point ($info))
    {
      print $outfd &gst_share_nfs_info_print_synthesized_entry ($info, $line) . "\n";
      $replaced = 1;
    }
    else
    {
      print $outfd $line;
    }
  }

  &Utils::File::close_file ($infd);
  &Utils::File::close_file ($outfd);
}

sub gst_share_nfs_exports_remove_entry
{
  my ($file, $info) = @_;
  my ($infd, $outfd);
  my ($line);

  ($infd, $outfd) = &Utils::File::open_filter_write_from_names ($file);
  return undef if !$outfd;

  while ($line = &gst_share_nfs_exports_get_next_entry_line ($infd, $outfd))
  {
    my $point = &gst_share_nfs_exports_get_entry_line_point ($line);

    if ($point ne &gst_share_nfs_info_get_point ($info))
    {
      print $outfd $line;
    }
  }

  &Utils::File::close_file ($infd);
  &Utils::File::close_file ($outfd);
}

sub gst_share_nfs_exports_get_entry_line_point
{
  my ($line) = @_;
  my $point;

  ($point) = split /[ \t]+/, $line;
  return $point;
}

sub gst_share_replace_nfs_exports  # filename, table
{
  my ($file, $table) = @_;
  my ($new_table, $old_table);

  $old_table = &gst_share_parse_nfs_exports ($file);
  $new_table = &gst_share_nfs_table_dup ($table);

  for $info (@$new_table)
  {
    my $old_info = &gst_share_nfs_table_find_info_equivalent ($old_table, $info);

    if (!$old_info)
    {
      &gst_share_nfs_exports_add_entry ($file, $info);
    }
    elsif ($old_info && !&gst_share_nfs_info_match_data ($old_info, $info))
    {
      &gst_share_nfs_exports_update_entry ($file, $info);
    }
  }

  for $old_info (@$old_table)
  {
    if (!&gst_share_nfs_table_find_info_equivalent ($new_table, $old_info))
    {
      &gst_share_nfs_exports_remove_entry ($file, $old_info);
    }
  } 
}

sub get_files
{
  my ($smb_comb, $exports);
  my (@arr);

  %dist_attrib = &gst_network_get_parse_table ();
  push @arr, $dist_attrib{"fn"}{"SMB_CONF"};

  # This is pretty standard
  push @arr, "/etc/exports";

  return \@arr;
}

sub get_list
{
  my ($smb_exports, $nfs_exports);
  my ($arr);

  $arr = &get_files ();

  $smb_exports = &gst_share_parse_smb_conf    ($$arr[0]);
  $nfs_exports = &gst_share_parse_nfs_exports ($$arr[1]);

  return ($smb_exports, $nfs_exports);
}

1;
