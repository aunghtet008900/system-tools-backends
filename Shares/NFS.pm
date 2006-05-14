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

sub get_distro_nfs_file
{
  # This is quite generic
  return "/etc/exports";
}

sub get_share_client_info
{
  my ($client) = @_;
  my ($pattern, $options_str, @options, $option);
  my ($rw);

  $client =~ /^([a-zA-Z0-9.-_*?@\/]+)/;
  $pattern = $1;
  $pattern = "0.0.0.0/0" if $pattern eq "";
  $rw = 0;

  if ($client =~ /\((.+)\)/)
  {
    $option_str = $1;
    @options = ($option_str =~ /([a-zA-Z0-9_=-]+),?/mg);

    for $option (@options)
    {
      $rw = ($option eq "rw") ? 1 : 0;
      # Add supported NFS export options here. Some might have to be split on '='.
    }
  }

  return [ $pattern, $rw ];
}

sub get_share_info
{
  my ($clients) = @_;
  my (@share_info, $client);

  foreach $client (@$clients)
  {
    push @share_info, &get_share_client_info ($client);
  }

  return \@share_info;
}

sub get_export_line
{
  my ($share) = @_;
  my ($str);

  $str = sprintf ("%-15s ", $$share[0]);

  foreach $i (@{$$share[1]})
  {
    $str .= $$i[0];
    $str .= "(rw)" if (!$$i[1]);
    $str .= " ";
  }

  $str .= "\n";
  return $str;
}

sub add_entry
{
  my ($share, $file) = @_;
  my ($buff);

  $buff = &Utils::File::load_buffer ($file);
  push @$buff, &get_export_line ($share);

  &Utils::File::save_buffer ($buff, $file);
}

sub delete_entry
{
  my ($share, $file) = @_;
  my ($buff, $i, $line, @arr);

  $buff = &Utils::File::load_buffer ($file);
  $i = 0;

  while ($$buff[$i])
  {
    if (!&Utils::Util::ignore_line ($$buff[$i]))
    {
      @arr = split /[ \t]+/, $$buff[$i];
      delete $$buff[$i] if ($arr[0] eq $$share[0]);
    }

    $i++;
  }

  &Utils::File::clean_buffer ($buff);
  &Utils::File::save_buffer  ($buff, $file);
}

sub change_entry
{
  my ($old_share, $share, $file) = @_;
  my ($buff, $i, $line, @arr);

  $buff = &Utils::File::load_buffer ($file);
  $i = 0;

  while ($$buff[$i])
  {
    if (!&Utils::Util::ignore_line ($$buff[$i]))
    {
      @arr = split /[ \t]+/, $$buff[$i];
      $$buff[$i] = &get_export_line ($share) if ($arr[0] eq $$old_share[0]);
    }

    $i++;
  }

  &Utils::File::clean_buffer ($buff);
  &Utils::File::save_buffer  ($buff, $file);
}

sub get
{
  my ($nfs_exports_name);
  my (@sections, @table, $entries);
  my $point, $share_info;

  $nfs_exports_name = &get_distro_nfs_file ();

  $entries = &Utils::Parse::split_hash_with_continuation ($nfs_exports_name, "[ \t]+", "[ \t]+");

  foreach $point (keys %$entries)
  {
    my $clients = $$entries{$point};

    $share_info = &get_share_info ($clients);
    push @table, [ $point, $share_info ];
  }

  return \@table;
}

sub set
{
  my ($config) = @_;
  my ($nfs_exports_file);
  my ($old_config, %shares);
  my (%config_hash, %old_config_hash);
  my ($state, $i);

  $nfs_exports_name = &get_distro_nfs_file ();
  $old_config = &get ();

  foreach $i (@$config)
  {
    $shares{$$i[0]} |= 1;
    $config_hash{$$i[0]} = $i;
  }

  foreach $i (@$old_config)
  {
    $shares{$$i[0]} |= 2;
    $old_config_hash{$$i[0]} = $i;
  }

  foreach $i (sort keys (%shares))
  {
    $state = $shares{$i};

    if ($state == 1)
    {
      # These entries have been added
      &add_entry ($config_hash{$i}, $nfs_exports_name);
    }
    elsif ($state == 2)
    {
      # These entries have been deleted
      &delete_entry ($old_config_hash{$i}, $nfs_exports_name);
    }
    elsif (($state == 3) &&
           (!Utils::Util::struct_eq ($config_hash{$i}, $old_config_hash{$i})))
    {
      # These entries have been modified
      &change_entry ($old_config_hash{$i}, $config_hash{$i}, $nfs_exports_name);
    }
  }
}

1;
