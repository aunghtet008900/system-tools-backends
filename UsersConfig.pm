#!/usr/bin/env perl
#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-

# DBus object for the Users list
#
# Copyright (C) 2005 Carlos Garnacho
#
# Authors: Carlos Garnacho Parro  <carlosg@gnome.org>
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

package UsersConfig;

use base qw(Net::DBus::Object);
use Utils::Backend;
use Users::Users;

my $OBJECT_NAME = "UsersConfig";
my $SHARES_PATH = $Utils::Backend::DBUS_PATH . "/" . $OBJECT_NAME;

sub new
{
  my $class  = shift;
  my $self   = $class->SUPER::new ($SHARES_PATH,
                                   {
                                     $OBJECT_NAME => {
                                       methods => {
                                         "get" => {
                                           params  => [],
                                           returns => [[ "array", [ "struct", "int32", "string", "string", "int32", "int32", [ "array", "string"], "string", "string" ]],
                                                       "int32", "int32", "int32", "string" ]
                                         },
                                       },
                                       signals => {
                                         "changed" => [],
                                       },
                                     },
                                   },
                                   @_);
  bless $self, $class;
  Utils::Monitor::monitor_files (&Users::Users::get_files (),
                                 $self, $OBJECT_NAME, "changed");

  return $self;
}

sub get
{
  my ($self) = @_;
  my $logindefs, $users, $use_md5;

  $use_md5 = &Users::Users::get_use_md5 ();
  $logindefs = &Users::Users::get_logindefs ();
  $users = &Users::Users::get ();

  return ($users, $use_md5, $$logindefs{"umin"}, $$logindefs{"umax"}, $$logindefs{"home_prefix"});
}

1;
