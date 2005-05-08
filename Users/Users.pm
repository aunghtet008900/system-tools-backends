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

# Best viewed with 100 columns of width.

# Configuration files affected:
#
# /etc/passwd
# /etc/group
# /etc/shadow
# /etc/login.defs
# /etc/shells
# /etc/skel/

# NIS support will come later.

# Running programs affected/used:
#
# adduser: creating users.
# usermod: modifying user data.
# passwd: assigning or changing passwords. (Un)locking users.
# chfn: modifying finger information - Name, Office, Office phone, Home phone.
# pw: modifying users/groups and user/group data on FreeBSD.

package Users::Users;

use Utils::Util;
use Utils::Report;
use Utils::File;
use Utils::XML;
use Utils::Backend;
use Utils::Platform;
use Utils::Replace;

# --- Tool information --- #

$name = "users";
$version = "@VERSION@";
@platforms = ("redhat-5.2", "redhat-6.0", "redhat-6.1", "redhat-6.2", "redhat-7.0", "redhat-7.1",
              "redhat-7.2", "redhat-7.3", "redhat-8.0", "redhat-9",
              "openna-1.0",
              "mandrake-7.1", "mandrake-7.2", "mandrake-9.0", "mandrake-9.1", "mandrake-9.2",
              "mandrake-10.0", "mandrake-10.1",
              "debian-2.2", "debian-3.0", "debian-sarge",
              "suse-7.0", "suse-9.0", "suse-9.1", "turbolinux-7.0",
              "slackware-8.0.0", "slackware-8.1", "slackware-9.0.0", "slackware-9.1.0", "slackware-10.0.0", "slackware-10.1.0",
              "freebsd-4", "freebsd-5", "freebsd-6",
              "gentoo",
              "archlinux-0.7",
              "pld-1.0", "pld-1.1", "pld-1.99", "fedora-1", "fedora-2", "fedora-3", "specifix", "vine-3.0", "vine-3.1");

$description =<<"end_of_description;";
       Manages system users.
end_of_description;

# --- System config file locations --- #

# We list each config file type with as many alternate locations as possible.
# They are tried in array order. First found = used.

@passwd_names =     ( "/etc/passwd" );
@shadow_names =     ( "/etc/shadow", "/etc/master.passwd" );
@group_names =      ( "/etc/group" );
@login_defs_names = ( "/etc/login.defs", "/etc/adduser.conf" );
@shell_names =      ( "/etc/shells" );
@skel_dir =         ( "/usr/share/skel", "/etc/skel" );

$profile_file =     "profiles.xml";


# Where are the tools?

$cmd_usermod  = &Utils::File::locate_tool ("usermod");
$cmd_userdel  = &Utils::File::locate_tool ("userdel");
$cmd_useradd  = &Utils::File::locate_tool ("useradd");	
$cmd_groupdel = &Utils::File::locate_tool ("groupdel");
$cmd_groupadd = &Utils::File::locate_tool ("groupadd");
$cmd_groupmod = &Utils::File::locate_tool ("groupmod");
$cmd_gpasswd  = &Utils::File::locate_tool ("gpasswd");	
$cmd_chfn     = &Utils::File::locate_tool ("chfn");
$cmd_pw       = &Utils::File::locate_tool ("pw");

# --- Mapping constants --- #

%users_prop_map = ();
@users_prop_array = ();

@users_prop_array = (
  "key", 0,
  "login", 1,
  "password", 2,
  "uid", 3,
  "gid", 4,
  "comment", 5,
  "home", 6,
  "shell", 7,
  "", "");

for ($i = 0; $users_prop_array[$i] ne ""; $i += 2)
{
  $users_prop_map {$users_prop_array[$i]} = $users_prop_array[$i + 1];
  $users_prop_map {$users_prop_array[$i + 1]} = $users_prop_array[$i];
}

%groups_prop_map = ();
@groups_prop_array = (
  "key", 0,
  "name", 1,
	"password", 2,
	"gid", 3,
	"users", 4,
	"", "");

for ($i = 0; $groups_prop_array[$i] ne ""; $i += 2)
{
  $groups_prop_map {$groups_prop_array[$i]} = $groups_prop_array[$i + 1];
  $groups_prop_map {$groups_prop_array[$i + 1]} = $groups_prop_array[$i];
}

# Please, keep this list sorted
%groups_desc_map = (
  # TRANSLATORS: this is a list of infinitive actions
  "adm"       => _("Monitor system logs"),
  "audio"     => _("Use audio devices"),
  "cdrom"     => _("Access to CD-ROM drives"),
  "dialout"   => _("Access to modem devices"),
  "dip"       => _("Connect to Internet through modem devices"),
  "fax"       => _("Send and receive faxes"),
  "floppy"    => _("Access to floppy drives"),
  "plugdev"   => _("Enable access to external storage devices automatically"),
  "tape"      => _("Access to tape drives"),
  "wheel"     => _("Be able to get administrator privileges"),
);

%login_defs_prop_map = ();
%profiles_prop_map = ();

sub get_login_defs_prop_array
{
  my @prop_array;
  my @login_defs_prop_array_default =
    (
     "QMAIL_DIR",      "qmail_dir",
     "MAIL_DIR",       "mailbox_dir",
     "MAIL_FILE",      "mailbox_file",
     "PASS_MAX_DAYS",  "pwd_maxdays",
     "PASS_MIN_DAYS",  "pwd_mindays",
     "PASS_MIN_LEN",   "pwd_min_length",
     "PASS_WARN_AGE",  "pwd_warndays",
     "UID_MIN",        "umin",
     "UID_MAX",        "umax",
     "GID_MIN",        "gmin",
     "GID_MAX",        "gmax",
     "USERDEL_CMD",    "del_user_additional_command",
     "CREATE_HOME",    "create_home",
     "", "");

  my @login_defs_prop_array_suse =
    (
     "QMAIL_DIR",      "qmail_dir",
     "MAIL_DIR",       "mailbox_dir",
     "MAIL_FILE",      "mailbox_file",
     "PASS_MAX_DAYS",  "pwd_maxdays",
     "PASS_MIN_DAYS",  "pwd_mindays",
     "PASS_MIN_LEN",   "pwd_min_length",
     "PASS_WARN_AGE",  "pwd_warndays",
     "UID_MIN",        "umin",
     "UID_MAX",        "umax",
     "SYSTEM_GID_MIN", "gmin",
     "GID_MAX",        "gmax",
     "USERDEL_CMD",    "del_user_additional_command",
     "CREATE_HOME",    "create_home",
     "", "");
  
  if ($Utils::Backend::tool{"platform"} =~ /^suse/)
  {
    @prop_array = @login_defs_prop_array_suse;
  }
  else
  {
    @prop_array = @login_defs_prop_array_default;
  }

  for ($i = 0; $prop_array [$i] ne ""; $i += 2)
  {
    $login_defs_prop_map {$prop_array [$i]}     = $prop_array [$i + 1];
    $login_defs_prop_map {$prop_array [$i + 1]} = $prop_array [$i];
  }
}

sub get_profiles_prop_array
{
  my @prop_array;
  my @profiles_prop_array_default =
    (
     "NAME" ,          "name",
     "COMMENT",        "comment",
     "LOGINDEFS",      "login_defs",
     "HOME_PREFFIX",   "home_prefix",
     "SHELL",          "shell",
     "GROUP",          "group",
     "SKEL_DIR",       "skel_dir",
     "QMAIL_DIR" ,     "qmail_dir",
     "MAIL_DIR" ,      "mailbox_dir",
     "MAIL_FILE" ,     "mailbox_file",
     "PASS_RANDOM",    "pwd_random",
     "PASS_MAX_DAYS" , "pwd_maxdays",
     "PASS_MIN_DAYS" , "pwd_mindays",
     "PASS_MIN_LEN" ,  "pwd_min_length",
     "PASS_WARN_AGE" , "pwd_warndays",
     "UID_MIN" ,       "umin",
     "UID_MAX" ,       "umax",
     "GID_MIN" ,       "gmin",
     "GID_MAX" ,       "gmax",
     "USERDEL_CMD" ,   "del_user_additional_command",
     "CREATE_HOME" ,   "create_home",
     "", "");

  my @profiles_prop_array_suse =
    (
     "NAME" ,          "name",
     "COMMENT",        "comment",
     "LOGINDEFS",      "login_defs",
     "HOME_PREFFIX",   "home_prefix",
     "SHELL",          "shell",
     "GROUP",          "group",
     "SKEL_DIR",       "skel_dir",
     "QMAIL_DIR" ,     "qmail_dir",
     "MAIL_DIR" ,      "mailbox_dir",
     "MAIL_FILE" ,     "mailbox_file",
     "PASS_RANDOM",    "pwd_random",
     "PASS_MAX_DAYS" , "pwd_maxdays",
     "PASS_MIN_DAYS" , "pwd_mindays",
     "PASS_MIN_LEN" ,  "pwd_min_length",
     "PASS_WARN_AGE" , "pwd_warndays",
     "UID_MIN" ,       "umin",
     "UID_MAX" ,       "umax",
     "GID_MIN" ,       "gmin",
     "GID_MAX" ,       "gmax",
     "USERDEL_CMD" ,   "del_user_additional_command",
     "CREATE_HOME" ,   "create_home",
     "", "");

  if ($Utils::Backend::tool{"platform"} =~ /suse/)
  {
    @prop_array = @profiles_prop_array_suse;
  }
  else
  {
    @prop_array = @profiles_prop_array_default;
  }

  for ($i = 0; $prop_array[$i] ne ""; $i += 2)
  {
    $profiles_prop_map {$prop_array [$i]}     = $prop_array [$i + 1];
    $profiles_prop_map {$prop_array [$i + 1]} = $prop_array [$i];
  }
}

my $rh_logindefs_defaults = {
  'shell'       => '/bin/bash',
  'group'       => '$user',
  'skel_dir'    => '/etc/skel/',
};

my $gentoo_logindefs_defaults = {
  'shell'       => '/bin/bash',
  'group'       => 'users',
  'skel_dir'    => '/etc/skel/',
};

my $freebsd_logindefs_defaults = {
  'shell'       => '/bin/sh',
  'group'       => '$user',
  'skel_dir'    => '/etc/skel/',
};

my $logindefs_dist_map = {
  'redhat-5.2'      => $rh_logindefs_defaults,
  'redhat-6.0'      => $rh_logindefs_defaults,
  'redhat-6.1'      => $rh_logindefs_defaults,
  'redhat-6.2'      => $rh_logindefs_defaults,
  'redhat-7.0'      => $rh_logindefs_defaults,
  'redhat-7.1'      => $rh_logindefs_defaults,
  'redhat-7.2'      => $rh_logindefs_defaults,
  'redhat-7.3'      => $rh_logindefs_defaults,
  'redhat-8.0'      => $rh_logindefs_defaults,
  'redhat-9'        => $rh_logindefs_defaults,
  'openna-1.0'      => $rh_logindefs_defaults,
  'mandrake-7.1'    => $rh_logindefs_defaults,
  'mandrake-7.2'    => $rh_logindefs_defaults,
  'mandrake-9.0'    => $rh_logindefs_defaults,
  'mandrake-9.1'    => $rh_logindefs_defaults,
  'mandrake-9.2'    => $rh_logindefs_defaults,
  'mandrake-10.0'   => $rh_logindefs_defaults,
  'mandrake-10.1'   => $rh_logindefs_defaults,
  'pld-1.0'         => $rh_logindefs_defaults,
  'pld-1.1'         => $rh_logindefs_defaults,
  'pld-1.99'        => $rh_logindefs_defaults,
  'fedora-1'        => $rh_logindefs_defaults,
  'fedora-2'        => $rh_logindefs_defaults,
  'fedora-3'        => $rh_logindefs_defaults,
  'specifix'        => $rh_logindefs_defaults,
  'debian-2.2'      => $rh_logindefs_defaults,
  'debian-3.0'      => $rh_logindefs_defaults,
  'debian-sarge'    => $rh_logindefs_defaults,
  'vine-3.0'        => $rh_logindefs_defaults,
  'vine-3.1'        => $rh_logindefs_defaults,
  'gentoo'	        => $gentoo_logindefs_defaults,
  'archlinux-0.7'   => $gentoo_logindefs_defaults,
  'slackware-9.1.0' => $gentoo_logindefs_defaults,
  'slackware-10.0.0' => $gentoo_logindefs_defaults,
  'slackware-10.1.0' => $gentoo_logindefs_defaults,
  'freebsd-4'       => $freebsd_logindefs_defaults,
  'freebsd-5'       => $freebsd_logindefs_defaults,
  'freebsd-6'       => $freebsd_logindefs_defaults,
  'suse-7.0'        => $gentoo_logindefs_defaults,
  'suse-9.0'        => $gentoo_logindefs_defaults,
  'suse-9.1'        => $gentoo_logindefs_defaults,

  # FIXME: I don't know about those, so using RH values for now.
  'turbolinux-7.0'  => $rh_logindefs_defaults,
  'slackware-8.0.0' => $rh_logindefs_defaults,
  'slackware-8.1'   => $rh_logindefs_defaults,
  'slackware-9.0.0' => $rh_logindefs_defaults,
};


# Add reporting table.

&Utils::Report::add ({
  'users_read_profiledb_success' => ['info', 'Profiles read successfully.'],
  'users_read_profiledb_fail'    => ['warn', 'Profiles read failed.'],
  'users_read_users_success'     => ['info', 'Users read successfully.'],
  'users_read_users_fail'        => ['warn', 'Users read failed.'],
  'users_read_groups_success'    => ['info', 'Groups read successfully.'],
  'users_read_groups_fail'       => ['warn', 'Groups read failed.'],
  'users_read_shells_success'    => ['info', 'Shells read successfully.'],
  'users_read_shells_fail'       => ['warn', 'Reading shells failed.'],

  'users_write_profiledb_success' => ['info', 'Profiles written successfully.'],
  'users_write_profiledb_fail'    => ['warn', 'Writing profiles failed.'],
  'users_write_users_success'     => ['info', 'Users written successfully.'],
  'users_write_users_fail'        => ['warn', 'Writing users failed.'],
  'users_write_groups_success'    => ['info', 'Groups written successfully.'],
  'users_write_groups_fail'       => ['warn', 'Writing groups failed.'],
});


# --- Utility stuff --- #

sub max
{
  return $_[0] > $_[1]? $_[0]: $_[1];
}

sub arr_cmp_recurse
{
	my ($a1, $a2) = @_;
	my $i;
	
	return -1 if ($#$a1 != $#$a2);
	
	for ($i = 0; $i <= $#$a1; $i++) {
	  if (ref ($$a1[$i]) eq "ARRAY") { # see if this is a reference.
		  return -1 if &arr_cmp_recurse ($$a1[$i], $$a2[$i]); # we assume it is a ref to an array.
		} elsif ($$a1[$i] ne $$a2[$i]) {
		  return -1;
		}
	}
	
	return 0;
}

sub get_logindefs
{
  my $profiledb = shift;
  return unless $profiledb;

  foreach my $profile (@$profiledb)
  {
    return $profile if (exists ($profile->{'login_defs'}));
  }
}

# --- Configuration manipulation --- #

sub read
{
  my (%hash);

  &read_group         (\%hash);
  &read_passwd_shadow (\%hash);
  &read_profiledb     (\%hash);
  &read_shells        (\%hash);

  return \%hash;
}

sub check_use_md5
{
  my ($file) = @_;
  my ($fh, @line, $i, $use_md5);

  my $fh = &Utils::File::open_read_from_names ("/etc/pam.d/$file");
  return 0 if (!$fh);

  $use_md5 = 0;

  while (<$fh>)
  {
    next if &Utils::Util::ignore_line ($_);
    chomp;
    @line = split /[ \t]+/;

    if ($line[0] eq "\@include")
    {
      $use_md5 = &check_use_md5 ($line[1]);
    }
    elsif ($line[0] eq "password")
    {
      foreach $i (@line)
      {
        $use_md5 = 1 if ($i eq "md5");
      }
    }
  }

  close $fh;
  return $use_md5;
}

sub logindefs_add_defaults
{
  # Common for all distros
  my $logindefs = {
    'name'        => _("Default"),
    'comment'     => _("Default profile"),
    'default'     => 1,
    'login_defs'  => 1,
    'home_prefix' => '/home/$user',
  };

  # Distro specific
  my $dist_specific = $logindefs_dist_map->{$Utils::Backend::tool{"platform"}};

  # Just to be 100% sure SOMETHING gets filled:
  unless ($dist_specific)
  {
    $dist_specific = $rh_logindefs_defaults;
  }

  foreach my $key (keys %$dist_specific)
  {
    # Make sure there's no crappy entries
    if (exists ($profiles_prop_map{$key}) || $key eq "groups")
    {
      $logindefs->{$key} = $dist_specific->{$key};
    }
  }
  return $logindefs;
}

sub read_logindefs
{
  my $profiledb = shift;
  my $logindefs =  &get_logindefs ($profiledb);

  unless ($logindefs)
  {
    $logindefs = &logindefs_add_defaults ();
    push @$profiledb, $logindefs;
  }

  # Get new data in case someone has changed login_defs manually.
  my $fh = &Utils::File::open_read_from_names (@login_defs_names);

  if ($fh)
  {
    while (<$fh>)
    {
      next if &Utils::Util::ignore_line ($_);
      chomp;
      my @line = split /[ \t]+/;
      if (exists $login_defs_prop_map{$line[0]})
      {
        $logindefs->{$login_defs_prop_map{$line[0]}} = $line[1];
      }
    }

    close $fh;
  }
  else
  {
    # Put safe defaults for distros/OS that don't have any defaults file
    $logindefs->{"umin"} = '1000';
    $logindefs->{"umax"} = '60000';
    $logindefs->{"gmin"} = '1000';
    $logindefs->{"gmax"} = '60000';
  }
}

sub read_profiledb
{
  my ($hash) = @_;
  my $path;
  my $profiles = [];

  $$hash{'profiledb'} = $profiles;

  $path = &Utils::File::get_data_path () . "/" . $main::tool->{'name'} . "/" . $profile_file;
  my $tree = &Utils::XML::scan ($path, $tool);

  if ($tree && scalar @$tree)
  {
    if ($$tree[0] eq 'profiledb')
    {
      &xml_parse_profiledb ($$tree[1], $hash);
    }
    else
    {
      &Utils::Report::do_report ('xml_unexp_tag', $$tree[0]);
    }
  }

  &read_logindefs ($profiles);

  if (scalar @$profiles)
  {
    &Utils::Report::do_report ('users_read_profiledb_success');
  }
  else
  {
    &Utils::Report::do_report ('users_read_profiledb_fail');
  }
}

sub get
{
  my ($ifh, @users, %users_hash);
  my (@line);
  my $login_pos    = $users_prop_map{"login"};
  my $comment_pos  = $users_prop_map{"comment"};
  my $last_arr_pos = $users_prop_map{"passwd_disable"};
  my $i = 0;

  # Find the passwd file.
  $ifh = &Utils::File::open_read_from_names(@passwd_names);
  return unless ($ifh);

  %users_hash = ();

  while (<$ifh>)
  {
    chomp;
    # FreeBSD allows comments in the passwd file.
    next if &Utils::Util::ignore_line ($_);

    @line  = split ':', $_, -1;

    unshift @line, $i;
    $login = $line[$login_pos];
    @comment = split ',', $line[$comment_pos], 5;
    $line[$comment_pos] = [@comment];
    
    $$users_hash{$login} = [@line];
    $i++;
  }

  &Utils::File::close_file ($ifh);
  $ifh = &Utils::File::open_read_from_names(@shadow_names);

  if ($ifh) {
    my $passwd_pos = $users_prop_map{"password"};

    while (<$ifh>)
    {
      chomp;
      # FreeBSD allows comments in the shadow passwd file.
      next if &Utils::Util::ignore_line ($_);

      @line = split ':', $_, -1;
      $login = shift @line;
      $passwd = shift @line;

      $$users_hash{$login}[$passwd_pos] = $passwd;
      push @{$$users_hash{$login}}, @line;
    }

    &Utils::File::close_file ($ifh);
  }

  # transform the hash into an array
  foreach $login (keys %$users_hash)
  {
    push @users, \@$arr;
  }

  return \@users;
}

sub get_files
{
  my @arr;

  push @arr, @passwd_names;
  push @arr, @shadow_names;

  return \@arr;
}

sub read_group
{
  my ($hash) = @_;
  my ($ifh, @groups, %groups_hash, $group_last_modified);
  my (@line, $copy, @a);
  my $i = 0;

  # Find the file.

  $ifh = &Utils::File::open_read_from_names(@group_names);
  unless ($ifh)
  {
    &Utils::Report::do_report ('users_read_groups_fail');
    return;
  }
  $group_last_modified = (stat ($ifh))[9]; # &get the mtime.

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
    $groups_hash{sprintf ("%06d", $i)} = $copy;
    push (@groups, $copy);
    $i ++;
  }
  &Utils::File::close_file ($ifh);

  $$hash{"groups"}      = \@groups;
  $$hash{"groups_hash"} = \%groups_hash;
  $$hash{"group_last_modified"} = $group_last_modified;

  if (scalar @groups)
  {
    &Utils::Report::do_report ('users_read_groups_success');
  }
  else
  {
    &Utils::Report::do_report ('users_read_groups_fail');
  }
}

sub get_shells
{
  my ($hash) = @_;
  my ($ifh, @shells, $file, $available);

  # Init @shells, I think every *nix has /bin/false.
  if (stat ("/bin/false"))
  {
    push @shells, ["/bin/false", 1];
  }
  
  $ifh = &Utils::File::open_read_from_names(@shell_names);
  return unless $ifh;

  while (<$ifh>)
  {
    next if &Utils::Util::ignore_line ($_);
    chomp;
    $file = $_;
    $available = (stat ($_)) ? 1 : 0;
    push @shells, [$file, $available];
  }

  &Utils::File::close_file ($ifh);
  &Utils::Report::do_report ('users_read_shells_success');
  return \@shells;
}


sub write_group_passwd
{
  my ($hash) = @_;
  my ($users, $users_hash, $groups, $groups_hash);
  my ($passwd_last_modified, $group_last_modified);
  my ($i, $j, $k);
  my (%old_hash);
  my (%users_all, $parse_users_hash, $parse_users, $parse_passwd_last_modified);
  my (%groups_all, $parse_groups_hash, $parse_groups, $parse_group_last_modified);

  $parse_users = $$hash{"users"};
  $parse_users_hash = $$hash{"users_hash"};
  $parse_passwd_last_modified = $$hash{"passwd_last_modified"};
  $parse_groups = $$hash{"groups"};
  $parse_groups_hash = $$hash{"groups_hash"};
  $parse_group_last_modified = $$hash{"group_last_modified"};

  &read_passwd_shadow (\%old_hash);
  &read_group (\%old_hash);

  $users = $old_hash{"users"};
  $users_hash = $old_hash{"users_hash"};
  $passwd_last_modified = $old_hash{"passwd_last_modified"};
  $groups = $old_hash{"groups"};
  $groups_hash = $old_hash{"groups_hash"};
  $group_last_modified = $old_hash{"group_last_modified"};

#	if ($passwd_last_modified > $parse_passwd_last_modified) 
#	{
#	  print STDERR "Password file may be inconsistent! No changes made.\n";
#		return;
#	}

  foreach $i (keys (%$users_hash)) 
	{
		$users_all{$i} |= 1;
	}	
	
	foreach $i (keys (%$parse_users_hash))
	{
	  $users_all{$i} |= 2;
	}
	
  foreach $i (keys (%$groups_hash)) 
	{
		$groups_all{$i} |= 1;
	}	
	
	foreach $i (keys (%$parse_groups_hash))
	{
	  $groups_all{$i} |= 2;
	}
	
	foreach $i (sort (keys (%users_all)))
	{
	  &del_user ($$users_hash{$i}) if ($users_all{$i} == 1);
	}

  foreach $i (sort (keys (%groups_all)))
	{
	  &del_group ($$groups_hash{$i}) if ($groups_all{$i} == 1);
	}
	
	foreach $i (sort (keys (%groups_all)))
	{
	  &add_group ($$parse_groups_hash{$i}) if ($groups_all{$i} == 2);
	}
	
	foreach $i (sort (keys (%users_all)))
	{
	  &add_user ($$parse_users_hash{$i}) if ($users_all{$i} == 2);
	}

	foreach $i (sort (keys (%groups_all)))
	{
	  if ($groups_all{$i} == 3 && &arr_cmp_recurse ($$groups_hash{$i}, $$parse_groups_hash{$i}))
		{
		  &change_group ($$groups_hash{$i}, $$parse_groups_hash{$i});
		}
	}
	
	foreach $i (sort (keys (%users_all)))
	{
	  if ($users_all{$i} == 3 && &arr_cmp_recurse ($$users_hash{$i}, $$parse_users_hash{$i}))
		{
		  &change_user ($$users_hash{$i}, $$parse_users_hash{$i});
		}
	}

  &Utils::Report::do_report ('users_write_users_success');
  &Utils::Report::do_report ('users_write_groups_success');
}

sub del_user
{
	my ($data) = @_;
  my ($command);
	
  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/) {
    $command = "$cmd_pw userdel -n \'" . $$data[$users_prop_map{"login"}] . "\' ";
  } else {
    $command = "$cmd_userdel \'" . $$data[$users_prop_map{"login"}] . "\'";
  }
  &Utils::File::run ($command);
}

sub change_user_chfn
{
  my ($old_comment, $comment, $username) = @_;
  my ($fname, $office, $office_phone, $home_phone);
  my ($command, @line, @old_line);

  return if !$username;

  @line     = split /\,/, $comment;
  @old_line = split /\,/, $old_comment;

  # Compare old and new data
  return if (!&arr_cmp_recurse (\@line, \@old_line));

  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/)
  {
    $command = "$cmd_pw usermod -n " . $username . " -c \'" . $comment . "\'";
  }
  else
  {
    ($fname, $office, $office_phone, $home_phone) = @line;

    $fname = "-f \'" . $fname . "\'";
    $home_phone = "-h \'" . $home_phone . "\'";

    if ($Utils::Backend::tool{"platform"} =~ /^debian/ ||
        $Utils::Backend::tool{"platform"} =~ /^archlinux/)
    {
      $office = "-r \'" . $office . "\'";
      $office_phone = "-w \'" . $office_phone . "\'";
    }
    else
    {
      $office = "-o \'" . $office . "\'";
      $office_phone = "-p \'" . $office_phone . "\'";
    }  
  
    $command = "$cmd_chfn $fname $office $office_phone $home_phone $username";
  }

  &Utils::File::run ($command);
}

sub add_user
{
	my ($data) = @_;
	my ($home_parents, $tool_mkdir);
  
  $log = $$data[$users_prop_map{"login"}];
  $tool_mkdir = &Utils::File::locate_tool ("mkdir");

  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/)
  {
    my $pwdpipe;
    my $home;

    # FreeBSD doesn't create the home directory
    $home = $$data[$users_prop_map{"home"}];
    &Utils::File::run ("$tool_mkdir -p $home");

    $command = "$cmd_pw useradd " .
     " -n \'" . $$data[$users_prop_map{"login"}] . "\'" .
     " -u \'" . $$data[$users_prop_map{"uid"}] . "\'" .
     " -d \'" . $$data[$users_prop_map{"home"}] . "\'" .
     " -g \'" . $$data[$users_prop_map{"gid"}] . "\'" .
     " -s \'" . $$data[$users_prop_map{"shell"}] . "\'" .
     " -H 0"; # pw(8) reads password from STDIN

    $pwdpipe = &Utils::File::run_pipe_write ($command);
    print $pwdpipe $$data[$users_prop_map{"password"}];
    &Utils::File::close_file ($pwdpipe);
  }
  else
  {
    $home_parents = $$data[$users_prop_map{"home"}];
    $home_parents =~ s/\/+[^\/]+\/*$//;
    &Utils::File::run ("$tool_mkdir -p $home_parents");

    $command = "$cmd_useradd" . " -d \'" . $$data[$users_prop_map{"home"}] .
     "\' -g \'"    . $$data[$users_prop_map{"gid"}] .
     "\' -m -p \'" . $$data[$users_prop_map{"password"}] .
     "\' -s \'"    . $$data[$users_prop_map{"shell"}] .
     "\' -u \'"    . $$data[$users_prop_map{"uid"}] .
     "\' \'"       . $$data[$users_prop_map{"login"}] . "\'";
    &Utils::File::run ($command);
  }

  &change_user_chfn (undef, $$data[$users_prop_map{"comment"}], $$data[$users_prop_map{"login"}]);
}

sub change_user
{
  my ($old_data, $new_data) = @_;
	
  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/)
  {
    my $pwdpipe;

    $command = "$cmd_pw usermod \'" . $$old_data[$users_prop_map{"login"}] . "\'" .
     " -l \'" . $$new_data[$users_prop_map{"login"}] . "\'" .
     " -u \'" . $$new_data[$users_prop_map{"uid"}]   . "\'" .
     " -d \'" . $$new_data[$users_prop_map{"home"}]  . "\'" .
     " -g \'" . $$new_data[$users_prop_map{"gid"}]   . "\'" .
     " -s \'" . $$new_data[$users_prop_map{"shell"}] . "\'" .
     " -H 0"; # pw(8) reads password from STDIN

    $pwdpipe = &Utils::File::run_pipe_write ($command);
    print $pwdpipe $$data[$users_prop_map{"password"}];
    &Utils::File::close_file ($pwdpipe);
  }
  else
  {
    $command = "$cmd_usermod" . " -d \'" . $$new_data[$users_prop_map{"home"}] .
     "\' -g \'" . $$new_data[$users_prop_map{"gid"}] .
     "\' -l \'" . $$new_data[$users_prop_map{"login"}] .
     "\' -p \'" . $$new_data[$users_prop_map{"password"}] .
     "\' -s \'" . $$new_data[$users_prop_map{"shell"}] .
     "\' -u \'" . $$new_data[$users_prop_map{"uid"}] .
     "\' \'" . $$old_data[$users_prop_map{"login"}] . "\'";
    &Utils::File::run ($command);
  }

  &change_user_chfn ($$old_data[$users_prop_map{"comment"}],
                     $$new_data[$users_prop_map{"comment"}],
                     $$new_data[$users_prop_map{"login"}]);
}

sub del_group
{
  my ($data) = @_;

  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/)
  {
    $command = "$cmd_pw groupdel -n \'" . $$data[$groups_prop_map{"name"}] . "\'";
  }
  else
  {
    $command = "$cmd_groupdel \'" . $$data[$groups_prop_map{"name"}] . "\'";
  }
  &Utils::File::run ($command);
}

sub add_group
{
  my ($data) = @_;
  my ($u, $user, $users);

  $u = [ @{$$data[$groups_prop_map{"users"}]} ]; sort @$u;
	
  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/)
  {
    $users = join (",", @$u);
      
    $command = "$cmd_pw groupadd -n \'" . $$data[$groups_prop_map{"name"}] .
      "\' -g \'" . $$data[$groups_prop_map{"gid"}] .
      "\' -M \'" . $users . "\'";
    &Utils::File::run ($command);
  }
  else
  {
    $command = "$cmd_groupadd -g \'" . $$data[$groups_prop_map{"gid"}] .
      "\' " . $$data[$groups_prop_map{"name"}];
    &Utils::File::run ($command);

    foreach $user (@$u)
    {
      $command = "$cmd_gpasswd -a \'" . $user .
        "\' " . $$data[$groups_prop_map{"name"}];
      &Utils::File::run ($command);
    }
  }
}

sub change_group
{
	my ($old_data, $new_data) = @_;
	my ($n, $o, $users, $i, $j, $max_n, $max_o, $r, @tmp); # for iterations

  if ($Utils::Backend::tool{"platform"} =~ /^freebsd/)
  {
    $n = [ @{$$new_data[$groups_prop_map{"users"}]} ]; sort @$n;
    $users = join (",", @$n);

    $command = "$cmd_pw groupmod -n \'" . $$old_data[$groups_prop_map{"name"}] .
        "\' -g \'" . $$new_data[$groups_prop_map{"gid"}] .
        "\' -l \'" . $$new_data[$groups_prop_map{"name"}] .
        "\' -M \'" . $users . "\'";

    &Utils::File::run ($command);
  }
  else
  {
    $command = "$cmd_groupmod -g \'" . $$new_data[$groups_prop_map{"gid"}] .
      "\' -n \'" . $$new_data[$groups_prop_map{"name"}] . "\' " .
      "\'" . $$old_data[$groups_prop_map{"name"}] . "\'";
  
    &Utils::File::run ($command);
	
    # Let's see if the users that compose the group have changed.
    if (&arr_cmp_recurse ($$new_data[$groups_prop_map{"users"}],
                          $$old_data[$groups_prop_map{"users"}])) {

      $n = [ @{$$new_data[$groups_prop_map{"users"}]} ]; sort @$n;
      $o = [ @{$$old_data[$groups_prop_map{"users"}]} ]; sort @$o;
		
      $max_n = $#$n;
      $max_o = $#$o;
      for ($i = 0, $j = 0; $i <= &max ($max_n, $max_o); ) {
        $r = $$n[$i] cmp $$o[$j];
        $r *= -1 if (($$o[$j] eq "") || ($$n[$i] eq ""));

        if ($r < 0) { # add this user to the group.
          $command = "$cmd_gpasswd -a \'" . $$n[$i] . "\' \'" . 
            $$new_data[$groups_prop_map{"name"}] . "\'";
          $i ++;
				
          &Utils::File::run ($command);
			  } elsif ($r > 0) { # delete the user from the group.
          $command = "$cmd_gpasswd -d \'" . $$o[$j] . "\' \'" . 
            $$new_data[$groups_prop_map{"name"}] . "\'";
          $j ++;
				
          &Utils::File::run ($command);
			  } else { # The information is the same. Go to next tuple.
          $i ++; $j ++;
			  }	
		  }	
	  }
  }
}


sub write_logindefs
{
  my ($login_defs) = @_;
  my ($key);
  my $file;

  return unless $login_defs;

  foreach $key (@login_defs_names)
  {
    if (-e $key)
    {
      $file = $key;
      last;
    }
  }

  unless ($file) 
  {
    &Utils::Report::do_report ("file_open_read_failed", join (", ", @login_defs_names));
    return;
  }

  foreach $key (keys (%$login_defs))
  {
    # Write ONLY login.defs values.
    if (exists ($login_defs_prop_map{$key}))
    {
      &Utils::Replace::split ($file, $login_defs_prop_map{$key}, "[ \t]+", $$login_defs{$key});
    }
  }
}


sub write_profiledb
{
  my ($hash) = @_;
  my $profiledb = $hash->{'profiledb'};

  unless ($profiledb)
  {
    &Utils::Report::do_report ('users_write_profiledb_fail');
    return;
  }

  # Update login.defs file.  
  &write_logindefs (&get_logindefs ($profiledb));

  # Write our profiles.
  my $path = &Utils::File::get_data_path () . "/" . $main::tool->{'name'} . "/" . $profile_file;
  my $fh = &Utils::File::open_write_from_names ($path);
  if ($fh)
  {
    local *STDOUT = $fh;
    &xml_print_profiledb ($hash);
    close ($fh);
    &Utils::Report::do_report ('users_write_profiledb_success');
  }
  else
  {
    &Utils::Report::do_report ('users_write_profiledb_fail');
  }
}


# --- XML parsing --- #

# Scan XML from standard input to an internal tree.

sub xml_parse
{
  my ($tool) = @_;
  my ($tree, %hash);
	
  # Scan XML to tree.

  $tree = &Utils::XML::scan (undef, $tool);

  $hash{"users"} = [];
  $hash{"users_hash"} = {};
  $hash{"groups"} = [];
  $hash{"groups_hash"} = {};
  $hash{"profiledb"} = [];

  # Walk the tree recursively and extract configuration parameters.
  # This is the top level - find and enter the "users" tag.

  while (@$tree)
  {
    if ($$tree[0] eq "users") { &xml_parse_users($$tree[1], \%hash); }

    shift @$tree;
    shift @$tree;
  }

  return (\%hash);
}

sub xml_parse_users
{
  my ($tree, $hash) = @_;
	
  shift @$tree;  # Skip attributes.

  while (@$tree)
	{
	  if ($$tree[0] eq "logindefs") { &xml_parse_login_defs ($$tree[1], $hash); }
		elsif ($$tree[0] eq "passwd_last_modified") { &xml_parse_passwd_last_modified ($$tree[1], $hash); }
		elsif ($$tree[0] eq "group_last_modified") { &xml_parse_group_last_modified ($$tree[1], $hash); }
		elsif ($$tree[0] eq "userdb") { &xml_parse_userdb ($$tree[1], $hash); }
		elsif ($$tree[0] eq "groupdb") { &xml_parse_groupdb ($$tree[1], $hash); }
		elsif ($$tree[0] eq "shelldb")  { }
		elsif ($$tree[0] eq "profiledb")  { &xml_parse_profiledb ($$tree[1], $hash); }
		else
		{
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
		}

    shift @$tree;
    shift @$tree;
  }
}

sub xml_parse_passwd_last_modified
{
  my ($tree, $hash) = @_;
	
  shift @$tree;  # Skip attributes.
	
	&Utils::Report::do_report ("xml_unexp_arg", "", "passwd_last_modified") if ($$tree[0] ne "0");
	$$hash{"passwd_last_modified"} = $$tree[1];
}

sub xml_parse_group_last_modified
{
  my ($tree, $hash) = @_;
	
  shift @$tree;  # Skip attributes.
	
	&Utils::Report::do_report ("xml_unexp_arg", "", "group_last_modified") if ($$tree[0] ne "0");
	$$hash{"group_last_modified"} = $$tree[1];
}	

sub xml_parse_userdb
{
  my ($tree, $hash) = @_;
	
  shift @$tree;  # Skip attributes.

  while (@$tree)
	{
	  if ($$tree[0] eq "user") { &xml_parse_user ($$tree[1], $hash); }
		else
		{
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
		}

    shift @$tree;
    shift @$tree;
  }
}

sub xml_parse_user
{
  my ($tree, $hash) = @_;
  my ($users, $users_hash);
  my @line = ();

  $users = $$hash{"users"};
  $users_hash = $$hash{"users_hash"};
	
  shift @$tree;  # Skip attributes.

	while (@$tree)
	{
		if ($users_prop_map{$$tree[0]} ne undef)
		{
		  $line[$users_prop_map{$$tree[0]}] = &Utils::XML::unquote($$tree[1][2]);
		}
		else
		{
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
		}
		
		shift @$tree;
		shift @$tree;
	}

  $$users_hash{sprintf ("%06d", $line[0])} = [@line];
  push (@$users, [@line]);
}	
	
sub xml_parse_groupdb
{
  my ($tree, $hash) = @_;
  my $tree = $_[0];
	
  shift @$tree;  # Skip attributes.

  while (@$tree)
  {
    if ($$tree[0] eq "group") { &xml_parse_group ($$tree[1], $hash); }
    else
    {
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
    }

    shift @$tree;
    shift @$tree;
  }
}

sub xml_parse_group
{
  my ($tree, $hash) = @_;
	my (@line, $copy, $a, @u);
  my ($groups, $users_hash);
	
  $groups = $$hash{"groups"};
  $groups_hash = $$hash{"groups_hash"};
	
  shift @$tree;  # Skip attributes.

	while (@$tree)
	{
		if ($groups_prop_map{$$tree[0]} ne undef)
		{
		  if ($$tree[0] eq "users") { $line[$groups_prop_map{$$tree[0]}] = $$tree[1]; }
			else { $line[$groups_prop_map{$$tree[0]}] = $$tree[1][2]; }
		}
		else
		{
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
		}
		
		shift @$tree;
		shift @$tree;
	}
	
	# @$a should be a parse tree of the array of users.
	$a = pop @line;
	shift @$a;
	while (@$a) {
	  if ($$a[0] eq "user") {
		  push @u, $$a[1][2];
		}
		else
		{
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
		}
		shift @$a;
		shift @$a;
	}
	
	push @line, [@u];
	$copy = [@line];
	$$groups_hash{sprintf ("%06d", $line[0])} = $copy;
	push (@$groups, $copy);
}

sub xml_parse_profile_groups
{
  my ($tree) = @_;
  my ($arr);

  shift @$tree; # Skip attributes.

  while (@$tree)
  {
    if ($$tree[0] eq "group")
    {
      push @$arr, $$tree[1][2];
    }
    else
    {
      &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
    }

    shift @$tree;
    shift @$tree;
  }

  return $arr;
}

sub xml_parse_profile
{
  my ($tree, $hash) = @_;
  my (%profile);

  shift @$tree;  # Skip attributes.

  while (@$tree)
	{
    # The "default" tag is not in the map, but we need to parse it
		if ($profiles_prop_map{$$tree[0]} || $$tree[0] eq "default")
		{
		  $profile{$$tree[0]} = $$tree[1][2];
		}
    elsif ($$tree[0] eq "groups")
    {
      $profile{$$tree[0]} = &xml_parse_profile_groups ($$tree[1]);
    }
		elsif ($$tree[0] ne "files") # files tag is ignored for parsing. # FIXME!
    {
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
		}

    shift @$tree;
		shift @$tree;
	}

  push @{$hash->{'profiledb'}}, \%profile;
}

sub xml_parse_profiledb
{
  my ($tree, $hash) = @_;

  shift @$tree; # Skip attributes.

  while (@$tree)
  {
    if ($$tree[0] eq "profile") { &xml_parse_profile ($$tree[1], $hash); }
    else
    {
		  &Utils::Report::do_report ("xml_unexp_tag", $$tree[0]);
    }

    shift @$tree;
    shift @$tree;
  }
}


# --- XML printing --- #

sub xml_print_profiledb
{
  my ($hash) = @_;

  my $profiledb = $$hash{"profiledb"};

  return unless scalar @$profiledb;

  &Utils::XML::container_enter ('profiledb');

  foreach my $profile (@$profiledb)
  {
    my $key;
    &Utils::XML::container_enter ('profile');
    foreach $key (keys %$profile)
    {
      if ($key eq "groups")
      {
        &Utils::XML::container_enter ('groups');
        &Utils::XML::print_array ($profile->{$key}, "group");
        &Utils::XML::container_leave ('groups');
      }
      else
      {
        &Utils::XML::print_pcdata ($key, $profile->{$key});
      }
    }
    &Utils::XML::container_leave ();
  }

  &Utils::XML::container_leave ();
	&Utils::XML::print_vspace ();
}

sub xml_print_shells
{
  my ($hash) = @_;
  my ($i, $shells);

  $shells = $$hash{"shelldb"};
  return unless scalar @$shells;

  &Utils::XML::container_enter ('shelldb');

  foreach $i (@$shells) {
    &Utils::XML::print_pcdata ('shell', $i);
  }

  &Utils::XML::container_leave ();
	&Utils::XML::print_vspace ();
}

sub xml_print
{
  my ($hash) = @_;
  my ($key, $value, $i, $j, $k);
  my ($passwd_last_modified, $users, $desc);

  $passwd_last_modified = $$hash{"passwd_last_modified"};
  $users = $$hash{"users"};
  $group_last_modified = $$hash{"group_last_modified"};
  $groups = $$hash{"groups"};

  &Utils::XML::print_begin ();

  &Utils::XML::print_pcdata ("use_md5", $$hash{"use_md5"});

  &Utils::XML::print_vspace ();
  &Utils::XML::print_comment ('Profiles configuration starts here');
  &Utils::XML::print_vspace ();

  &xml_print_profiledb ($hash);
  &xml_print_shells ($hash);

  &Utils::XML::print_comment ('Now the users');
  &Utils::XML::print_vspace ();

  &Utils::XML::print_comment ('When was the passwd file last modified (since the epoch)?');
  &Utils::XML::print_vspace ();
  &Utils::XML::print_pcdata ('passwd_last_modified', $passwd_last_modified);
  &Utils::XML::print_vspace ();

  &Utils::XML::container_enter ('userdb');
	foreach $i (@$users)
	{
    &Utils::XML::print_vspace ();
	  &Utils::XML::container_enter ('user');
		for ($j = 0; $j < ($#users_prop_array - 1) / 2; $j++)
    {
      &Utils::XML::print_pcdata ($users_prop_map{$j}, $$i[$j]);
		}
		&Utils::XML::container_leave ();
	}
	&Utils::XML::container_leave ();
  &Utils::XML::print_vspace ();
	
  &Utils::XML::print_comment ('Now the groups');
  &Utils::XML::print_vspace ();
	
  &Utils::XML::print_comment ('When was the group file last modified (since the epoch)?');
  &Utils::XML::print_vspace ();
  &Utils::XML::print_pcdata ('group_last_modified', $group_last_modified);
  &Utils::XML::print_vspace ();
	
	&Utils::XML::container_enter ('groupdb');
	foreach $i (@$groups)
	{
    &Utils::XML::print_vspace ();
	  &Utils::XML::container_enter ('group');
		for ($j = 0; $j < ($#groups_prop_array - 1) / 2 - 1; $j++)
    {
      &Utils::XML::print_pcdata ($groups_prop_map{$j}, $$i[$j]);
		}

		# Add the description based on the group name
		$desc = $groups_desc_map{$$i[1]};
		&Utils::XML::print_pcdata ("allows_to", $desc) if ($desc ne undef);

		&Utils::XML::container_enter ('users');
		$k = $$i[$groups_prop_map{"users"}];
		foreach $j (@$k)
		{
			&Utils::XML::print_pcdata ('user', $j);
		}
		&Utils::XML::container_leave ();

		&Utils::XML::container_leave ();
	}
	&Utils::XML::container_leave ();
  &Utils::XML::print_vspace ();

  &Utils::XML::print_end ();
}


# --- Get (read) config --- #


sub set
{
  my ($tool) = @_;
  my ($hash);

  $hash = &xml_parse ($tool);

  if ($hash)
  {
    # Make backup manually, otherwise they don't get backed up.
    &Utils::File::do_backup ($_) foreach (@passwd_names);
    &Utils::File::do_backup ($_) foreach (@shadow_names);
    &Utils::File::do_backup ($_) foreach (@group_names);

    &write_profiledb ($hash);
    &write_group_passwd ($hash);
  }

  &Utils::Report::end ();
}

1;
