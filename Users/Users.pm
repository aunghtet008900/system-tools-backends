#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
# Users account manager. Designed to be architecture and distribution independent.
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>,
#          Arturo Espinosa <arturo@ximian.com>,
#          Tambet Ingo <tambet@ximian.com>.
#          Grzegorz Golawski <grzegol@pld-linux.org> (PLD Support)
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
use Utils::Backend;
use Utils::Replace;

# --- System config file locations --- #

# We list each config file type with as many alternate locations as possible.
# They are tried in array order. First found = used.
@passwd_names =     ( "/etc/passwd" );
@shadow_names =     ( "/etc/shadow", "/etc/master.passwd" );
@login_defs_names = ( "/etc/login.defs", "/etc/adduser.conf" );
@shell_names =      ( "/etc/shells" );
@skel_dir =         ( "/usr/share/skel", "/etc/skel" );

# Where are the tools?
$cmd_usermod  = &Utils::File::locate_tool ("usermod");
$cmd_userdel  = &Utils::File::locate_tool ("userdel");
$cmd_useradd  = &Utils::File::locate_tool ("useradd");

$cmd_adduser  = &Utils::File::locate_tool ("adduser");
$cmd_deluser  = &Utils::File::locate_tool ("deluser");

$cmd_chfn     = &Utils::File::locate_tool ("chfn");
$cmd_pw       = &Utils::File::locate_tool ("pw");

# enum like for verbose group array positions
my $LOGIN   = 0;
my $PASSWD  = 1;
my $UID     = 2;
my $GID     = 3;
my $COMMENT = 4;
my $HOME    = 5;
my $SHELL   = 6;

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
  'shell'    => '/bin/bash',
  'group'    => -1,
  'skel_dir' => '/etc/skel/',
};

my $gentoo_logindefs_defaults = {
  'shell'    => '/bin/bash',
  'group'    => 100,
  'skel_dir' => '/etc/skel/',
};

my $freebsd_logindefs_defaults = {
  'shell'    => '/bin/sh',
  'group'    => -1,
  'skel_dir' => '/etc/skel/',
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
  'rpath'           => $rh_logindefs_defaults,
  'debian-2.2'      => $rh_logindefs_defaults,
  'debian-3.0'      => $rh_logindefs_defaults,
  'debian-sarge'    => $rh_logindefs_defaults,
  'ubuntu-5.04'     => $rh_logindefs_defaults,
  'ubuntu-5.10'     => $rh_logindefs_defaults,
  'ubuntu-6.04'     => $rh_logindefs_defaults,
  'vine-3.0'        => $rh_logindefs_defaults,
  'vine-3.1'        => $rh_logindefs_defaults,
  'gentoo'	        => $gentoo_logindefs_defaults,
  'vlos-1.2'	      => $gentoo_logindefs_defaults,
  'archlinux'       => $gentoo_logindefs_defaults,
  'slackware-9.1.0' => $gentoo_logindefs_defaults,
  'slackware-10.0.0' => $gentoo_logindefs_defaults,
  'slackware-10.1.0' => $gentoo_logindefs_defaults,
  'slackware-10.2.0' => $gentoo_logindefs_defaults,
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


sub do_get_use_md5
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
      $use_md5 = &do_get_use_md5 ($line[1]);
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

sub get_use_md5
{
  return &do_get_use_md5 ("passwd");
}

sub logindefs_add_defaults
{
  # Common for all distros
  my $logindefs = {
    'home_prefix' => '/home/',
  };

  &get_profiles_prop_array ();

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

sub get_logindefs
{
  my $logindefs;

  &get_login_defs_prop_array ();
  $logindefs = &logindefs_add_defaults ();

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

  return $logindefs;
}

sub get
{
  my ($ifh, @users, %users_hash);
  my (@line, @users);

  # Find the passwd file.
  $ifh = &Utils::File::open_read_from_names(@passwd_names);
  return unless ($ifh);

  while (<$ifh>)
  {
    chomp;
    # FreeBSD allows comments in the passwd file.
    next if &Utils::Util::ignore_line ($_);

    @line  = split ':', $_, -1;

    $login = $line[$LOGIN];
    @comment = split ',', $line[$COMMENT], 5;

    # we need to make sure that there are 5 elements
    push @comment, "" while (scalar (@comment) < 5);
    $line[$COMMENT] = [@comment];
    
    $users_hash{$login} = [@line];
  }

  &Utils::File::close_file ($ifh);
  $ifh = &Utils::File::open_read_from_names(@shadow_names);

  if ($ifh)
  {
    while (<$ifh>)
    {
      chomp;

      # FreeBSD allows comments in the shadow passwd file.
      next if &Utils::Util::ignore_line ($_);

      @line = split ':', $_, -1;
      $login = shift @line;
      $passwd = shift @line;

      $users_hash{$login}[$PASSWD] = $passwd;

      # FIXME: add the rest of the fields?
      #push @{$$users_hash{$login}}, @line;
    }

    &Utils::File::close_file ($ifh);
  }

  # transform the hash into an array
  foreach $login (keys %users_hash)
  {
    push @users, $users_hash{$login};
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


sub del_user
{
	my ($user) = @_;
  my ($command);
	
  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    $command = "$cmd_pw userdel -n \'" . $$user[$LOGIN] . "\' ";
  }
  else
  {
    if ($cmd_deluser)
    {
      $command = "$cmd_deluser '". $$user[$LOGIN] . "'";
    }
    else
    {
      $command = "$cmd_userdel \'" . $$user[$LOGIN] . "\'";
    }
  }

  &Utils::File::run ($command);
}

sub change_user_chfn
{
  my ($login, $old_comment, $comment) = @_;
  my ($fname, $office, $office_phone, $home_phone);
  my ($command);

  return if !$login;

  # Compare old and new data
  return if (Utils::Util::struct_eq ($old_comment, $comment));

  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    my ($str);

    $str = join (",", @$comment);
    $command = "$cmd_pw usermod -n " . $login . " -c \'" . $str . "\'";
  }
  else
  {
    ($fname, $office, $office_phone, $home_phone) = @$comment;

    $command = "$cmd_chfn" .
        " -f \'" . $fname . "\'" .
        " -h \'" . $home_phone . "\'";

    if ($Utils::Backend::tool{"platform"} =~ /^debian/ ||
        $Utils::Backend::tool{"platform"} =~ /^archlinux/)
    {
      $command .= " -r \'" . $office . "\'" .
          " -w \'" . $office_phone . "\'";
    }
    else
    {
      $command .= " -o \'" . $office . "\'" .
          " -p \'" . $office_phone . "\'";
    }  
  }

  &Utils::File::run ($command);
}

sub add_user
{
	my ($user) = @_;
	my ($home_parents, $tool_mkdir);
  
  $tool_mkdir = &Utils::File::locate_tool ("mkdir");

  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    my $pwdpipe;
    my $home;

    # FreeBSD doesn't create the home directory
    $home = $$user[$HOME];
    &Utils::File::run ("$tool_mkdir -p $home");

    $command = "$cmd_pw useradd " .
        " -n \'" . $$user[$LOGIN] . "\'" .
        " -u \'" . $$user[$UID]   . "\'" .
        " -d \'" . $$user[$HOME]  . "\'" .
        " -g \'" . $$user[$GID]   . "\'" .
        " -s \'" . $$user[$SHELL] . "\'" .
        " -H 0"; # pw(8) reads password from STDIN

    $pwdpipe = &Utils::File::run_pipe_write ($command);
    print $pwdpipe $$user[$PASSWD];
    &Utils::File::close_file ($pwdpipe);
  }
  else
  {
    $home_parents = $$user[$HOME];
    $home_parents =~ s/\/+[^\/]+\/*$//;
    &Utils::File::run ("$tool_mkdir -p $home_parents");

    if ($cmd_adduser)
    {
      # use adduser if available, set empty gecos fields
      # and password, they will be filled out later
      $command = "$cmd_adduser --gecos '' --disabled-password" .
          " --home \'"  . $$user[$HOME]   . "\'" .
          " --gid \'"   . $$user[$GID]    . "\'" .
          " --shell \'" . $$user[$SHELL]  . "\'" .
          " --uid \'"   . $$user[$UID]    . "\'" .
          " \'"         . $$user[$LOGIN]  . "\'";

      &Utils::File::run ($command);

      # password can't be set in non-interactive
      # mode with adduser, call usermod instead
      $command = "$cmd_usermod " .
          "' -p '" . $$user[$PASSWD] . "' " . $$user[$LOGIN];

      &Utils::File::run ($command);
    }
    else
    {
      # fallback to useradd
      $command = "$cmd_useradd -m" .
          " --home \'"     . $$user[$HOME]   . "\'" .
          " --gid \'"      . $$user[$GID]    . "\'" .
          " --password \'" . $$user[$PASSWD] . "\'" .
          " --shell \'"    . $$user[$SHELL]  . "\'" .
          " --uid \'"      . $$user[$UID]    . "\'" .
          " \'"            . $$user[$LOGIN]  . "\'";

      &Utils::File::run ($command);
    }
  }

  &change_user_chfn ($$user[$LOGIN], undef, $$user[$COMMENT]);
}

sub change_user
{
  my ($old_user, $new_user) = @_;
	
  if ($Utils::Backend::tool{"system"} eq "FreeBSD")
  {
    my $pwdpipe;

    $command = "$cmd_pw usermod \'" . $$old_user[$LOGIN] . "\'" .
        " -l \'" . $$new_user[$LOGIN] . "\'" .
        " -u \'" . $$new_user[$UID]   . "\'" .
        " -d \'" . $$new_user[$HOME]  . "\'" .
        " -g \'" . $$new_user[$GID]   . "\'" .
        " -s \'" . $$new_user[$SHELL] . "\'" .
        " -H 0"; # pw(8) reads password from STDIN

    $pwdpipe = &Utils::File::run_pipe_write ($command);
    print $pwdpipe $$new_user[$PASSWD];
    &Utils::File::close_file ($pwdpipe);
  }
  else
  {
    $command = "$cmd_usermod" .
        " -d \'" . $$new_user[$HOME]   . "\'" .
        " -g \'" . $$new_user[$GID]    . "\'" .
        " -l \'" . $$new_user[$LOGIN]  . "\'" .
        " -p \'" . $$new_user[$PASSWD] . "\'" .
        " -s \'" . $$new_user[$SHELL]  . "\'" .
        " -u \'" . $$new_user[$UID]    . "\'" .
        " \'" . $$old_user[$LOGIN] . "\'";

    &Utils::File::run ($command);
  }

  &change_user_chfn ($$new_user[$LOGIN], $$old_user[$COMMENT], $$new_user[$COMMENT]);
}

sub set_logindefs
{
  my ($config) = @_;
  my ($logindefs, $key, $file);

  return unless $config;

  &get_login_defs_prop_array ();

  foreach $key (@login_defs_names)
  {
    if (-f $key)
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

  foreach $key (keys (%$config))
  {
    # Write ONLY login.defs values.
    if (exists ($login_defs_prop_map{$key}))
    {
      &Utils::Replace::split ($file, $login_defs_prop_map{$key}, "[ \t]+", $$config{$key});
    }
  }
}

sub set
{
  my ($config) = @_;
  my ($old_config, %users);
  my (%config_hash, %old_config_hash);

  if ($config)
  {
    # Make backups manually, otherwise they don't get backed up.
    &Utils::File::do_backup ($_) foreach (@passwd_names);
    &Utils::File::do_backup ($_) foreach (@shadow_names);

    $old_config = &get ();

    foreach $i (@$config) 
    {
      $users{$$i[0]} |= 1;
      $config_hash{$$i[0]} = $i;
	  }	
	
    foreach $i (@$old_config)
    {
      $users{$$i[0]} |= 2;
      $old_config_hash{$$i[0]} = $i;
    }

    # Delete all groups that only appeared in the old configuration
    foreach $i (sort (keys (%users)))
    {
      $state = $users{$i};

      if ($state == 1)
      {
        # Groups with state 1 have been added to the config
        &add_user ($config_hash{$i});
      }
      elsif ($state == 2)
      {
        # Groups with state 2 have been deleted from the config
        &del_user ($old_config_hash{$i});
      }
      elsif (($state == 3) &&
             (!Utils::Util::struct_eq ($config_hash{$i}, $old_config_hash{$i})))
      {
        &change_user ($old_config_hash{$i}, $config_hash{$i});
      }
	  }
  }
}

1;
