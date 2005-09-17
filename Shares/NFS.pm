#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
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

package Shares::NFS;

use Utils::Parse;


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

sub get_distro_nfs_file
{
  # This is quite generic
  return "/etc/exports";
}

sub get_share_info
{
  my ($point) = @_;

  
}

sub get
{
  my ($nfs_exports_name);
  my (@sections, @table, $entries);
  my $point;

  $nfs_exports_name = &get_distro_nfs_file ();

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

  return \@table;
}

1;
