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

package Shares::SMB;

use Utils::File;

# --- share_export_smb_info; information on a particular SMB export --- #

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

sub get_distro_smb_file
{
  my ($smb_comb);

# FIXME: should have a hash table with distro information
#  %dist_attrib = &gst_network_get_parse_table ();
#  $smb_conf    = $dist_attrib{"fn"}{"SMB_CONF"};
  $smb_conf = "/etc/samba/smb.conf";

  return $smb_conf;
}

sub get_share_info
{
  my ($smb_conf_name, $section) = @_;
  my @share;

  my $path;

  push @share, $section;
  push @share, &Utils::Parse::get_from_ini      ($smb_conf_name, $section, "path");
  push @share, &Utils::Parse::get_from_ini      ($smb_conf_name, $section, "comment");
  push @share, &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "available");
  push @share, &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "browsable") ||
               &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "browseable");
  push @share, &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "public")      ||
               &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "guest");
  push @share, &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "writable")    ||
               &Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "writeable");

  return \@share;
}

sub get
{
  my ($smb_conf_name);
  my (@sections, @table, $share);

  $smb_conf_name = &get_distro_smb_file;

  # Get the sections.
  @sections = &Utils::Parse::get_ini_sections ($smb_conf_name);

  for $section (@sections)
  {
    next if ($section =~ /^(global)|(homes)|(printers)|(print\$)$/);
    next if (&Utils::Parse::get_from_ini_bool ($smb_conf_name, $section, "printable"));

    $share = &get_share_info ($smb_conf_name, $section);
    push @table, $share;
  }

  return \@table;
}

1;
