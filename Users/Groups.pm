#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>,
#          Arturo Espinosa <arturo@ximian.com>,
#          Tambet Ingo <tambet@ximian.com>.
#          Grzegorz Golawski <grzegol@pld-linux.org> (PLD Support)
#
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

package Users::Groups;

# quite generic data
$group_names = "/etc/group";

sub get
{
  my ($ifh, @groups, %groups_hash, $group_last_modified);
  my (@line, $copy, @a);
  my (%hash);
  my $i = 0;

  # Find the file.

  $ifh = &Utils::File::open_read_from_names($group_names);
  return unless ($ifh);

  # Parse the file.
  @groups = ();
  %groups_hash = ();

  while (<$ifh>)
  {
    chomp;

    # FreeBSD allows comments in the group file. */
    next if &Utils::Util::ignore_line ($_);
    $_ = &Utils::XML::unquote ($_);

    @line = split ':', $_, -1;
    unshift @line, sprintf ("%06d", $i);
    @a = split ',', pop @line;
    push @line, [@a];
    $copy = [@line];
    push (@groups, $copy);
    $i++;
  }

  &Utils::File::close_file ($ifh);

  $$hash{"groups"}      = \@groups;
  $$hash{"groups_hash"} = \%groups_hash;

  return \@groups;
}

sub get_files
{
  my @arr;

  push @arr, $group_names;
  return \@arr;
}
