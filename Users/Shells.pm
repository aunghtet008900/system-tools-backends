#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# Users account mannager. Designed to be architecture and distribution independent.
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>,
#          Arturo Espinosa <arturo@ximian.com>,
#          Tambet Ingo <tambet@ximian.com>.
#          Grzegorz Golawski <grzegol@pld-linux.org> (PLD Support)
#          Carlos Garnacho <carlosg@gnome.org>
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

package Users::Shells;

use Utils::Util;
use Utils::Report;
use Utils::File;
use Utils::Replace;

# Totally generic atm
$shells_file = "/etc/shells";

sub get_files
{
  return $shells_file;
}

sub get
{
  my ($ifh, @shells);

  # Init @shells, I think every *nix has /bin/false.
  if (stat ("/bin/false"))
  {
    push @shells, "/bin/false";
  }
  
  $ifh = &Utils::File::open_read_from_names($shells_file);
  return unless $ifh;

  while (<$ifh>)
  {
    next if &Utils::Util::ignore_line ($_);
    chomp;
    push @shells, $_ if (stat ($_));
  }

  &Utils::File::close_file ($ifh);

  return \@shells;
}

sub set
{
  my ($shells) = @_;
  my ($buff, $line, $nline);

  $buff = &Utils::File::load_buffer ($shells_file);
  return unless $buff;

  &Utils::File::join_buffer_lines ($buff);
  $nline = 0;

  # delete all file entries that really exist,
  # this is done for not deleting entries that
  # might be installed later
  while ($nline <= $#$buff)
  {
    $line = $$buff[$nline];
    chomp $line;

    if (!&Utils::Util::ignore_line ($line))
    {
	 delete $$buff[$nline] if (stat ($line));
    }

    $nline++;
  }

  # Add shells list
  foreach $line (@$shells)
  {
    push @$buff, "$line\n" if (stat ($line));
  }

  &Utils::File::save_buffer ($buff, $shells_file);
}
