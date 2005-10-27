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

# Where are the tools?
$cmd_groupdel = &Utils::File::locate_tool ("groupdel");
$cmd_groupadd = &Utils::File::locate_tool ("groupadd");
$cmd_groupmod = &Utils::File::locate_tool ("groupmod");
$cmd_gpasswd  = &Utils::File::locate_tool ("gpasswd");	
$cmd_pw       = &Utils::File::locate_tool ("pw");

sub del_group
{
  my ($group) = @_;

  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    $command = "$cmd_pw groupdel -n \'" . $$group[1] . "\'";
  }
  else
  {
    $command = "$cmd_groupdel \'" . $$group[1] . "\'";
  }

  &Utils::File::run ($command);
}

sub add_group
{
  my ($group) = @_;
  my ($u, $user, $users);

  $u = $$group[4];

  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    $users = join (",", sort @$u);
      
    $command = "$cmd_pw groupadd -n \'" . $$group[1] .
      "\' -g \'" . $$group[3] .
      "\' -M \'" . $users . "\'";

    &Utils::File::run ($command);
  }
  else
  {
    $command = "$cmd_groupadd -g \'" . $$group[3] .
        "\' " . $$group[1];

    &Utils::File::run ($command);

    foreach $user (sort @$u)
    {
      $command = "$cmd_gpasswd -a \'" . $user .
          "\' " . $$group[1];

      &Utils::File::run ($command);
    }
  }
}

sub change_group
{
	my ($old_group, $new_group) = @_;
  my (%users, $user, $users_arr, $str);

	my ($n, $o, $users, $i, $j, $max_n, $max_o, $r, @tmp); # for iterations

  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    $users_arr = $$new_group[4];
    $str = join (",", sort @$users_arr);

    $command = "$cmd_pw groupmod -n \'" . $$old_group[1] .
        "\' -g \'" . $$new_group[3] .
        "\' -l \'" . $$new_group[1] .
        "\' -M \'" . $str . "\'";

    &Utils::File::run ($command);
  }
  else
  {
    $command = "$cmd_groupmod -g \'" . $$new_group[3] .
        "\' -n \'" . $$new_group[1] . "\' " .
        "\'" . $$old_group[1] . "\'";
  
    &Utils::File::run ($command);

    # Let's see if the users that compose the group have changed.
    if (!Utils::Util::struct_eq ($$new_group[4], $$old_group[4]))
    {
      $users{$_} |= 1 foreach (@{$$new_group[4]});
      $users{$_} |= 2 foreach (@{$$old_group[4]});

      foreach $user (keys %users)
      {
        $state = $users{$u};

        if ($state == 2)
        {
          # users with state 2 are those that only appeared
          # in the old group configuration, so we must delete them
          $command = "$cmd_gpasswd -d \'" . $user . "\' \'" . 
              $$new_group[1] . "\'";

          &Utils::File::run ($command);
        }
        else
        {
          # users with state 1 are those who were added
          # to the new group configuration
          $command = "$cmd_gpasswd -a \'" . $user . "\' \'" . 
              $$new_group[1] . "\'";

          &Utils::File::run ($command);
        }
      }
    }
  }
}

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
    unshift @line, $i;
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

sub set
{
  my ($config) = @_;
  my ($old_config, %groups);
  my (%config_hash, %old_config_hash);

  if ($config)
  {
    # Make backup manually, otherwise they don't get backed up.
    &Utils::File::do_backup ($group_names);

    $old_config = &get ();

    foreach $i (@$config) 
    {
      $groups{$$i[1]} |= 1;
      $config_hash{$$i[1]} = $i;
	  }	
	
    foreach $i (@$old_config)
    {
	    $groups{$$i[1]} |= 2;
      $old_config_hash{$$i[1]} = $i;
    }

    # Delete all groups that only appeared in the old configuration
    foreach $i (sort (keys (%groups)))
    {
      $state = $groups{$i};

      if ($state == 1)
      {
        # Groups with state 1 have been added to the config
        &add_group ($config_hash{$i});
      }
      elsif ($state == 2)
      {
        # Groups with state 2 have been deleted from the config
        &del_group ($old_config_hash{$i});
      }
      elsif (($state == 3) &&
             (!Utils::Util::struct_eq ($config_hash{$i}, $old_config_hash{$i})))
      {
        &change_group ($old_config_hash{$i}, $config_hash{$i});
      }
    }
  }
}

1;
