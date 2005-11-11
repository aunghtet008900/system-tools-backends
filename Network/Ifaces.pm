#-*- Mode: perl; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*-
# Network Interfaces Configuration handling
#
# Copyright (C) 2000-2001 Ximian, Inc.
#
# Authors: Hans Petter Jansson <hpj@ximian.com>
#          Arturo Espinosa <arturo@ximian.com>
#          Michael Vogt <mvo@debian.org> - Debian 2.[2|3] support.
#          David Lee Ludwig <davidl@wpi.edu> - Debian 2.[2|3] support.
#          Grzegorz Golawski <grzegol@pld-linux.org> - PLD support
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

package Network::Ifaces;

use Utils::Util;
use Init::Services;

# FIXME: this function isn't IPv6-aware
# it checks if a IP address is in the same network than another
sub is_ip_in_same_network
{
  my ($address1, $address2, $netmask) = @_;
  my (@add1, @add2, @mask);
  my ($i);

  return 0 if (!$address1 || !$address2 || !$netmask);

  @add1 = split (/\./, $address1);
  @add2 = split (/\./, $address2);
  @mask = split (/\./, $netmask);

  for ($i = 0; $i < 4; $i++)
  {
    $add1[$i] += 0;
    $add2[$i] += 0;
    $mask[$i] += 0;

    return 0 if (($add1[$i] & $mask[$i]) != ($add2[$i] & $mask[$i]));
  }

  return 1;
}

sub ensure_iface_broadcast_and_network
{
  my ($iface) = @_;
    
  if (exists $$iface{"netmask"} &&
      exists $$iface{"address"})
  {
    if (! exists $$iface{"broadcast"})
    {
      $$iface{"broadcast"} = &Utils::Util::ip_calc_broadcast ($$iface{"address"}, $$iface{"netmask"});
    }

    if (! exists $$iface{"network"})
    {
      $$iface{"network"} = &Utils::Util::ip_calc_network ($$iface{"address"}, $$iface{"netmask"});
    }
  }
}

sub check_pppd_plugin
{
  my ($plugin) = @_;
  my ($version, $output);

  $version = &Utils::File::run_backtick ("pppd --version", 1);
  $version =~ s/.*version[ \t]+//;
  chomp $version;

  return 0 if !version;
  return &Utils::File::exists ("/usr/lib/pppd/$version/$plugin.so");
}

sub get_linux_wireless_ifaces
{
  my ($fd, $line);
  my (@ifaces, $command);

  $command = &Utils::File::get_cmd_path ("iwconfig");
  open $fd, "$command |";
  return @ifaces if $fd eq undef;

  while (<$fd>)
  {
    if (/^([a-zA-Z0-9]+)[\t ].*$/)
    {
      push @ifaces, $1;
    }
  }

  &Utils::File::close_file ($fd);

  &Utils::Report::leave ();
  return \@ifaces;
}

sub get_freebsd_wireless_ifaces
{
  my ($fd, $line, $iface);
  my (@ifaces, $command);

  $command = &Utils::File::get_cmd_path ("iwconfig");
  open $fd, "$command |";
  return @ifaces if $fd eq undef;

  while (<$fd>)
  {
    if (/^([a-zA-Z]+[0-9]+):/)
    {
      $iface = $1;
    }

    if (/media:.*wireless.*/i)
    {
      push @ifaces, $iface;
    }
  }

  &Utils::File::close_file ($fd);
  &Utils::Report::leave ();

  return \@ifaces;
}

# Returns an array with the wireless devices found
sub get_wireless_ifaces
{
  my ($plat) = $Utils::Backend::tool{"system"};
    
  return &get_linux_wireless_ifaces   if ($plat eq "Linux");
  return &get_freebsd_wireless_ifaces if ($plat eq "FreeBSD");
}

# returns interface type depending on it's interface name
# types_cache is a global var for caching interface types
sub get_interface_type
{
  my ($dev) = @_;
  my (@wireless_ifaces, $wi, $type);

  return $types_cache{$dev} if (exists $types_cache{$dev});

  #check whether interface is wireless
  $wireless_ifaces = &get_wireless_ifaces ();
  foreach $wi (@$wireless_ifaces)
  {
    if ($dev eq $wi)
    {
      $types_cache{$dev} = "wireless";
      return $types_cache{$dev};
    }
  }

  if ($dev =~ /^(ppp|tun)/)
  {
    # check whether the proper plugin exists
    if (&check_pppd_plugin ("capiplugin"))
    {
      $types_cache{$dev} = "isdn";
    }
    else
    {
      $types_cache{$dev} = "modem";
    }
  }
  elsif ($dev =~ /(eth|dc|ed|bfe|em|fxp|bge|de|xl|ixgb|txp|vx|lge|nge|pcn|re|rl|sf|sis|sk|ste|ti|tl|tx|vge|vr|wb|cs|ex|ep|fe|ie|lnc|sn|xe|le|an|awi|wi|ndis|wlaue|axe|cue|kue|rue|fwe|nve)[0-9]/)
  {
    $types_cache{$dev} = "ethernet";
  }
  elsif ($dev =~ /irlan[0-9]/)
  {
    $types_cache{$dev} = "irlan";
  }
  elsif ($dev =~ /plip[0-9]/)
  {
    $types_cache{$dev} = "plip";
  }
  elsif ($dev =~ /lo[0-9]?/)
  {
    $types_cache{$dev} = "loopback";
  }

  return $types_cache{$dev};
}

sub get_freebsd_interfaces_info
{
  my ($dev, %ifaces, $fd);

  &Utils::Report::enter ();
  &Utils::Report::do_report ("network_iface_active_get");

  $fd = &Utils::File::run_pipe_read ("ifconfig");
  return {} if $fd eq undef;
  
  while (<$fd>)
  {
    chomp;
    if (/^([^ \t:]+):.*(<.*>)/)
    {
      $dev = $1;
      $ifaces{$dev}{"dev"}    = $dev;
      $ifaces{$dev}{"enabled"} = 1 if ($2 =~ /[<,]UP[,>]/);
    }
    
    s/^[ \t]+//;
    if ($dev)
    {
      $ifaces{$dev}{"hwaddr"}  = $1 if /ether[ \t]+([^ \t]+)/i;
      $ifaces{$dev}{"addr"}    = $1 if /inet[ \t]+([^ \t]+)/i;
      $ifaces{$dev}{"mask"}    = $1 if /netmask[ \t]+([^ \t]+)/i;
      $ifaces{$dev}{"bcast"}   = $1 if /broadcast[ \t]+([^ \t]+)/i;
    }
  }
  
  &Utils::File::close_file ($fd);
  &Utils::Report::leave ();
  return %ifaces;
}

sub get_linux_interfaces_info
{
  my ($dev, %ifaces, $fd);

  &Utils::Report::enter ();
  &Utils::Report::do_report ("network_iface_active_get");

  $fd = &Utils::File::run_pipe_read ("ifconfig -a");
  return {} if $fd eq undef;
  
  while (<$fd>)
  {
    chomp;
    if (/^([^ \t:]+)/)
    {
      $dev = $1;
      $ifaces{$dev}{"enabled"} = 0;
      $ifaces{$dev}{"dev"}    = $dev;
    }
    
    s/^[ \t]+//;
    if ($dev)
    {
      $ifaces{$dev}{"hwaddr"}  = $1 if /HWaddr[ \t]+([^ \t]+)/i;
      $ifaces{$dev}{"addr"}    = $1 if /addr:([^ \t]+)/i;
      $ifaces{$dev}{"mask"}    = $1 if /mask:([^ \t]+)/i;
      $ifaces{$dev}{"bcast"}   = $1 if /bcast:([^ \t]+)/i;
      $ifaces{$dev}{"enabled"} = 1  if /^UP[ \t]/i;
    }
  }
  
  &Utils::File::close_file ($fd);
  &Utils::Report::leave ();
  return %ifaces;
}

sub get_interfaces_info
{
  my (%ifaces, $type);

  %ifaces = &get_linux_interfaces_info   if ($Utils::Backend::tool{"system"} eq "Linux");
  %ifaces = &get_freebsd_interfaces_info if ($Utils::Backend::tool{"system"} eq "FreeBSD");

  foreach $dev (keys %ifaces)
  {
    $type = &get_interface_type ($dev);
    $ifaces{$dev}{"type"} = $type;

    #delete unknown ifaces
    if (!$type)
    {
      delete $ifaces{$dev};
    }
  }

  return %ifaces;
}

# boot method parsing/replacing
sub get_rh_bootproto
{
  my ($file, $key) = @_;
  my %rh_to_proto_name =
	 (
	  "bootp" => "bootp",
	  "dhcp"  => "dhcp",
    "pump"  => "pump",
	  "none"  => "none"
	  );
  my $ret;

  $ret = &Utils::Parse::get_sh ($file, $key);
  
  if (!exists $rh_to_proto_name{$ret})
  {
    &Utils::Report::do_report ("network_bootproto_unsup", $file, $ret);
    $ret = "none";
  }
  return $rh_to_proto_name{$ret};
}

sub set_rh_bootproto
{
  my ($file, $key, $value) = @_;
  my %proto_name_to_rh =
	 (
	  "bootp"    => "bootp",
	  "dhcp"     => "dhcp",
    "pump"     => "pump",
	  "none"     => "none"
	  );

  return &Utils::Replace::set_sh ($file, $key, $proto_name_to_rh{$value});
}

sub get_debian_bootproto
{
  my ($file, $iface) = @_;
  my (@stanzas, $stanza, $method, $bootproto);
  my %debian_to_proto_name =
      (
       "bootp"    => "bootp",
       "dhcp"     => "dhcp",
       "loopback" => "none",
       "ppp"      => "none",
       "static"   => "none"
       );

  &Utils::Report::enter ();
  @stanzas = &Utils::Parse::get_interfaces_stanzas ($file, "iface");

  foreach $stanza (@stanzas)
  {
    if (($$stanza[0] eq $iface) && ($$stanza[1] eq "inet"))
    {
      $method = $$stanza[2];
      last;
    }
  }

  if (exists $debian_to_proto_name {$method})
  {
    $bootproto = $debian_to_proto_name {$method};
  }
  else
  {
    $bootproto = "none";
    &Utils::Report::do_report ("network_bootproto_unsup", $method, $iface);
  }

  &Utils::Report::leave ();
  return $bootproto;
}

sub set_debian_bootproto
{
  my ($file, $iface, $value) = @_;
  my (@stanzas, $stanza, $method, $bootproto);
  my %proto_name_to_debian =
      (
       "bootp"    => "bootp",
       "dhcp"     => "dhcp",
       "loopback" => "loopback",
       "ppp"      => "ppp",
       "none"     => "static"
       );

  my %dev_to_method = 
      (
       "lo" => "loopback",
       "ppp" => "ppp",
       "ippp" => "ppp"
       );

  foreach $i (keys %dev_to_method)
  {
    $value = $dev_to_method{$i} if $iface =~ /^$i/;
  }

  return &Utils::Replace::set_interfaces_stanza_value ($file, $iface, 2, $proto_name_to_debian{$value});
}

sub get_slackware_bootproto
{
  my ($file, $iface) = @_;

  if (&Utils::Parse::get_rcinet1conf_bool ($file, $iface, USE_DHCP))
  {
    return "dhcp"
  }
  else
  {
    return "none";
  }
}

sub set_slackware_bootproto
{
    my ($file, $iface, $value) = @_;

    if ($value eq "dhcp")
    {
      &Utils::Replace::set_rcinet1conf ($file, $iface, USE_DHCP, "yes");
    }
    else
    {
      &Utils::Replace::set_rcinet1conf ($file, $iface, USE_DHCP);
    }
}

sub get_bootproto
{
  my ($file, $key) = @_;
  my ($str);

  $str = &Utils::Parse::get_sh ($file, $key);

  return "dhcp"  if ($key =~ /dhcp/i);
  return "bootp" if ($key =~ /bootp/i);
  return "none";
}

sub set_suse_bootproto
{
  my ($file, $key, $value) = @_;
  my %proto_name_to_suse90 =
     (
      "dhcp"     => "dhcp",
      "bootp"    => "bootp",
      "static"   => "none",
     );

  return &Utils::Replace::set_sh ($file, $key, $proto_name_to_suse90{$value});
}

sub set_gentoo_bootproto
{
  my ($file, $dev, $value) = @_;

  return if ($dev =~ /^ppp/);

  return &Utils::Replace::split ($file, "config_$dev", "[ \t]*=[ \t]*", "\"dhcp\"") if ($value ne "none");

  # replace with a fake IP address, I know it's a hack
  return &Utils::Replace::split ($file, "config_$dev", "[ \t]*=[ \t]*", "\"0.0.0.0\"");
}

sub set_freebsd_bootproto
{
  my ($file, $dev, $value) = @_;

  return &Utils::Replace::set_sh ($file, "ifconfig_$dev", "dhcp") if ($value ne "none");
  return &Utils::Replace::set_sh ($file, "ifconfig_$dev", "");
}

# Functions to get the system interfaces, these are distro dependent
sub sysconfig_dir_get_existing_ifaces
{
  my ($dir) = @_;
  my (@ret, $i, $name);
  local *IFACE_DIR;
  
  if (opendir IFACE_DIR, "$gst_prefix/$dir")
  {
    foreach $i (readdir (IFACE_DIR))
    {
      push @ret, $1 if ($i =~ /^ifcfg-(.+)$/);
    }

    closedir (IFACE_DIR);
  }

  return \@ret;
}

sub get_existing_rh62_ifaces
{
  return @{&sysconfig_dir_get_existing_ifaces ("/etc/sysconfig/network-scripts")};
}

sub get_existing_rh72_ifaces
{
  my ($ret, $arr);
  
  # This syncs /etc/sysconfig/network-scripts and /etc/sysconfig/networking
  &Utils::File::run ("redhat-config-network-cmd");
  
  $ret = &sysconfig_dir_get_existing_ifaces
      ("/etc/sysconfig/networking/profiles/default");
  $arr = &sysconfig_dir_get_existing_ifaces
      ("/etc/sysconfig/networking/devices");

  &Utils::Util::arr_merge ($ret, $arr); 
  return @$ret;
}

sub get_existing_suse_ifaces
{
  return @{&sysconfig_dir_get_existing_ifaces ("/etc/sysconfig/network")};
}

sub get_existing_pld_ifaces
{
  return @{&sysconfig_dir_get_existing_ifaces ("/etc/sysconfig/interfaces")};
}

sub get_pap_passwd
{
  my ($file, $login) = @_;
  my (@arr, $passwd);

  $login = '"?' . $login . '"?';
  &Utils::Report::enter ();
  &Utils::Report::do_report ("network_get_pap_passwd", $login, $file);
  $arr = &Utils::Parse::split_first_array ($file, $login, "[ \t]+", "[ \t]+");

  $passwd = $$arr[1];
  &Utils::Report::leave ();

  $passwd =~ s/^\"([^\"]*)\"$/$1/;

  return $passwd;
}

sub get_wep_key_type
{
  my ($func) = shift @_;
  my ($val);

  $val = &$func (@_);

  return undef if (!$val);
  return "ascii" if ($val =~ /^s\:/);
  return "hexadecimal";
}

sub get_wep_key
{
  my ($func) = shift @_;
  my ($val);

  $val = &$func (@_);
  $val =~ s/^s\://;

  return $val;
}

sub get_modem_volume
{
  my ($file) = @_;
  my ($volume);

  $volume = &Utils::Parse::get_from_chatfile ($file, "AT.*(M0|L[1-3])");

  return 3 if ($volume eq undef);

  $volume =~ s/^[ml]//i;
  return $volume;
}

sub check_type
{
  my ($type) = shift @_;
  my ($expected_type) =  shift @_;
  my ($func) =  shift @_;

  if ($type =~ "^$expected_type")
  {
    &$func (@_);
  }
}

# Distro specific helper functions
sub get_debian_auto_by_stanza
{
  my ($file, $iface) = @_;
  my (@stanzas, $stanza, $i);

  @stanzas = &Utils::Parse::get_interfaces_stanzas ($file, "auto");

  foreach $stanza (@stanzas)
  {
    foreach $i (@$stanza)
    {
      return $stanza if $i eq $iface;
    }
  }

  return undef;
}

sub get_debian_auto
{
  my ($file, $iface) = @_;

  return (&get_debian_auto_by_stanza ($file, $iface) ne undef)? 1 : 0;
}

sub get_debian_remote_address
{
  my ($file, $iface) = @_;
  my ($str, @tuples, $tuple, @res);

  &Utils::Report::enter ();
  &Utils::Report::do_report ("network_get_remote", $iface);
  
  @tuples = &Utils::Parse::get_interfaces_option_tuple ($file, $iface, "up", 1);

  &Utils::Report::leave ();
  
  foreach $tuple (@tuples)
  {
    @res = $$tuple[1] =~ /[ \t]+pointopoint[ \t]+([^ \t]+)/;
    return $res[0] if $res[0];
  }

  return undef;
}

sub get_suse_dev_name
{
  my ($iface) = @_;
  my ($ifaces, $dev, $hwaddr, $d);
  my ($dev);

  $dev = &Utils::Parse::get_sh ("/var/run/sysconfig/if-$iface", "interface");

  if ($dev eq undef)
  {
    $fd = &Utils::File::run_backtick ("getcfg-interface $iface");
  }

  if ($dev eq undef)
  {
    # Those are the last cases, we make rough guesses
    if ($iface =~ /-pcmcia-/)
    {
      # it's something like wlan-pcmcia-0
      $dev =~ s/-pcmcia-//;
    }
    elsif ($iface =~ /-id-([a-fA-F0-9\:]*)/)
    {
      # it's something like eth-id-xx:xx:xx:xx:xx:xx, which is the NIC MAC
      $hwaddr = $1;
      $ifaces = &get_interfaces_info ();

      foreach $d (keys %$ifaces)
      {
        if ($hwaddr eq $$ifaces{$d}{"hwaddr"})
        {
          $dev = $d;
          last;
        }
      }
    }
  }

  if ($dev eq undef)
  {
    # We give up, take $iface as $dev
    $dev = $iface;
  }

  return $dev;
}

sub get_suse_auto
{
  my ($file, $key) = @_;
  my ($ret);

  $ret = &Utils::Parse::get_sh ($file, $key);

  return 1 if ($ret =~ /^onboot$/i);
  return 0;
}

sub get_suse_gateway
{
  my ($file, $address, $netmask) = @_;
  my ($gateway) = &Utils::Parse::split_first_array_pos ($file, "default", 0, "[ \t]+", "[ \t]+");

  return $gateway if &is_ip_in_same_network ($address, $gateway, $netmask);
  return undef;
}

# Return IP address or netmask, depending on $what
sub get_pld_ipaddr
{
  my ($file, $key, $what) = @_;
  my ($ipaddr, $netmask, $ret, $i);
	my @netmask_prefixes = (0, 128, 192, 224, 240, 248, 252, 254, 255);
  
  $ipaddr = &Utils::Parse::get_sh($file, $key);
  return undef if $ipaddr eq "";
  
  if($ipaddr =~ /([^\/]*)\/([[:digit:]]*)/)
  {
    $netmask = $2;
    return undef if $netmask eq "";

    if($what eq "address")
    {
      return $1;
    }

    for($i = 0; $i < int($netmask/8); $i++)
    {
      $ret .= "255.";
    }

    $ret .= "$netmask_prefixes[$b%8]." if $netmask < 32;

    for($i = int($netmask/8) + 1; $i < 4; $i++)
    {
      $ret .= "0.";
    }

    chop($ret);
    return $ret;
  }
  return undef;
}

sub get_gateway
{
  my ($file, $key, $address, $netmask) = @_;
  my ($gateway);

  return undef if ($address eq undef);

  $gateway = &Utils::Parse::get_sh ($file, $key);

  return $gateway if &is_ip_in_same_network ($address, $gateway, $netmask);
  return undef;
}

# looks for eth_up $eth_iface_number
sub get_slackware_auto
{
  my ($file, $rclocal, $iface) = @_;
  my ($search) = 0;
  my ($buff);

  if ($iface =~ /^eth/)
  {
    $buff = &Utils::File::load_buffer ($file);
    &Utils::File::join_buffer_lines ($buff);

    $iface =~ s/eth//;

    foreach $i (@$buff)
    {
      if ($i =~ /^[ \t]*'start'\)/)
      {
        $search = 1;
      }
      elsif (($i =~ /^[ \t]*;;/) && ($search == 1))
      {
        return 0;
      }
      elsif (($i =~ /^[ \t]*eth_up (\S+)/) && ($search == 1))
      {
        return 1 if ($1 == $iface);
      }
    }

    return 0;
  }
  elsif ($iface =~ /^ppp/)
  {
    return &Utils::Parse::get_kw ($rclocal, "ppp-go");
  }
}

sub get_freebsd_auto
{
  my ($file, $defaults_file, $iface) = @_;
  my ($val);

  $val = &Utils::Parse::get_sh ($file, "network_interfaces");
  $val = &Utils::Parse::get_sh ($defaults_file, "network_interfaces") if ($val eq undef);

  return 1 if ($val eq "auto");
  return 1 if ($val =~ /$iface/);
  return 0;
}

sub get_freebsd_ppp_persist
{
  my ($startif, $iface) = @_;
  my ($val);

  if ($iface =~ /^tun[0-9]+/)
  {
    $val = &Utils::Parse::get_startif ($startif, "ppp[ \t]+\-(auto|ddial)[ \t]+");

    return 1 if ($val eq "ddial");
    return 0;
  }

  return undef;
}

sub get_interface_parse_table
{
  my %dist_map =
	 (
    "redhat-5.2"   => "redhat-6.2",
	  "redhat-6.0"   => "redhat-6.2",
	  "redhat-6.1"   => "redhat-6.2",
	  "redhat-6.2"   => "redhat-6.2",
	  "redhat-7.0"   => "redhat-6.2",
	  "redhat-7.1"   => "redhat-6.2",
	  "redhat-7.2"   => "redhat-7.2",
    "redhat-8.0"   => "redhat-8.0",
    "redhat-9"     => "redhat-8.0",
	  "openna-1.0"   => "redhat-6.2",
	  "mandrake-7.1" => "redhat-6.2",
    "mandrake-7.2" => "redhat-6.2",
    "mandrake-9.0" => "mandrake-9.0",
    "mandrake-9.1" => "mandrake-9.0",
    "mandrake-9.2" => "mandrake-9.0",
    "mandrake-10.0" => "mandrake-9.0",
    "mandrake-10.1" => "mandrake-9.0",
    "blackpanther-4.0" => "mandrake-9.0",
    "conectiva-9"  => "conectiva-9",
    "conectiva-10" => "conectiva-9",
    "debian-3.0"   => "debian-3.0",
    "debian-sarge" => "debian-3.0",
    "suse-9.0"     => "suse-9.0",
    "suse-9.1"     => "suse-9.0",
	  "turbolinux-7.0"   => "redhat-6.2",
    "pld-1.0"      => "pld-1.0",
    "pld-1.1"      => "pld-1.0",
    "pld-1.99"     => "pld-1.0",
    "fedora-1"     => "redhat-7.2",
    "fedora-2"     => "redhat-7.2",
    "fedora-3"     => "redhat-7.2",
    "specifix"     => "redhat-7.2",
    "vine-3.0"     => "vine-3.0",
    "vine-3.1"     => "vine-3.0",
    "slackware-9.1.0" => "slackware-9.1.0",
    "slackware-10.0.0" => "slackware-9.1.0",
    "slackware-10.1.0" => "slackware-9.1.0",
    "gentoo"       => "gentoo",
    "freebsd-5"    => "freebsd-5",
    "freebsd-6"    => "freebsd-5",
   );
  
  my %dist_tables =
    (
     "redhat-6.2" =>
     {
       ifaces_get => \&get_existing_rh62_ifaces,
       fn =>
       {
         IFCFG   => "/etc/sysconfig/network-scripts/ifcfg-#iface#",
         CHAT    => "/etc/sysconfig/network-scripts/chat-#iface#",
         IFACE   => "#iface#",
         TYPE    => "#type#",
         PAP     => "/etc/ppp/pap-secrets",
         CHAP    => "/etc/ppp/chap-secrets",
         PUMP    => "/etc/pump.conf",
         WVDIAL  => "/etc/wvdial.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,          IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
        [ "dev",                \&Utils::Parse::get_sh,      IFCFG, DEVICE ],
        [ "address",            \&Utils::Parse::get_sh,      IFCFG, IPADDR ],
        [ "netmask",            \&Utils::Parse::get_sh,      IFCFG, NETMASK ],
        [ "broadcast",          \&Utils::Parse::get_sh,      IFCFG, BROADCAST ],
        [ "network",            \&Utils::Parse::get_sh,      IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh,      IFCFG, GATEWAY ],
        [ "remote_address",     \&Utils::Parse::get_sh,      IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
#        [ "ppp_options",        \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ],
        [ "section",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,       IFCFG, WVDIALSECT ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool,  IFCFG, PEERDNS ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,       IFCFG, MTU ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,       IFCFG, MRU ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,       IFCFG, PAPNAME ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP,  "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,       IFCFG, MODEMPORT ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,       IFCFG, LINESPEED ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool,  IFCFG, DEFROUTE ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool,  IFCFG, PERSIST ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool,  IFCFG, ESCAPECHARS ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool,  IFCFG, HARDFLOWCTL ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Phone" ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto DNS" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Username" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Password" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Modem" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Baud" ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Check Def Route" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto Reconnect" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Command" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Prefix" ]],
#        [ "enabled",            \&gst_network_interface_active, IFACE,
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
       ]
     },

     "redhat-7.2" =>
     {
       ifaces_get => \&get_existing_rh72_ifaces,
       fn =>
       {
         IFCFG => ["/etc/sysconfig/networking/profiles/default/ifcfg-#iface#",
                   "/etc/sysconfig/networking/devices/ifcfg-#iface#",
                   "/etc/sysconfig/network-scripts/ifcfg-#iface#"],
         CHAT  => "/etc/sysconfig/network-scripts/chat-#iface#",
         IFACE => "#iface#",
         TYPE  => "#type#",
         PAP   => "/etc/ppp/pap-secrets",
         CHAP  => "/etc/ppp/chap-secrets",
         PUMP  => "/etc/pump.conf",
         WVDIAL => "/etc/wvdial.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,   IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
#        [ "name",               \&Utils::Parse::get_sh,      IFCFG, NAME ],
#        [ "name",               \&Utils::Parse::get_trivial, IFACE ],
        [ "dev",                \&Utils::Parse::get_sh, IFCFG, DEVICE ],
        [ "address",            \&Utils::Parse::get_sh, IFCFG, IPADDR ],
        [ "netmask",            \&Utils::Parse::get_sh, IFCFG, NETMASK ],
        [ "broadcast",          \&Utils::Parse::get_sh, IFCFG, BROADCAST ],
        [ "network",            \&Utils::Parse::get_sh, IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh, IFCFG, GATEWAY ],
        [ "essid",              \&Utils::Parse::get_sh, IFCFG, ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_sh, IFCFG, KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_sh, IFCFG, KEY ]],
        [ "remote_address",     \&Utils::Parse::get_sh,      IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
        [ "section",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, WVDIALSECT ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PEERDNS ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MTU ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MRU ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, PAPNAME ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP,  "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MODEMPORT ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, LINESPEED ]],
#        [ "ppp_options",        \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, DEFROUTE ]],
#        [ "debug",              \&Utils::Parse::get_sh_bool, IFCFG, DEBUG ],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PERSIST ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, ESCAPECHARS ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, HARDFLOWCTL ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ]],
#        [ "enabled",            \&gst_network_interface_active, "%dev%",
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&gst_network_interface_active, IFACE,
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
        # wvdial settings
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Phone" ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto DNS" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Username" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Password" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Modem" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Baud" ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Check Def Route" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto Reconnect" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Command" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Prefix" ]],
       ]
     },

     "redhat-8.0" =>
     {
       ifaces_get => \&get_existing_rh72_ifaces,
       fn =>
       {
         IFCFG   => ["/etc/sysconfig/networking/profiles/default/ifcfg-#iface#",
                     "/etc/sysconfig/networking/devices/ifcfg-#iface#",
                     "/etc/sysconfig/network-scripts/ifcfg-#iface#"],
         CHAT    => "/etc/sysconfig/network-scripts/chat-#iface#",
         TYPE    => "#type#",
         IFACE   => "#iface#",
         PAP     => "/etc/ppp/pap-secrets",
         CHAP    => "/etc/ppp/chap-secrets",
         PUMP    => "/etc/pump.conf",
         WVDIAL  => "/etc/wvdial.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,     IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
#        [ "name",               \&Utils::Parse::get_sh,      IFCFG, NAME ],
#        [ "name",               \&Utils::Parse::get_trivial, IFACE ],
        [ "dev",                \&Utils::Parse::get_sh, IFCFG, DEVICE ],
        [ "address",            \&Utils::Parse::get_sh, IFCFG, IPADDR ],
        [ "netmask",            \&Utils::Parse::get_sh, IFCFG, NETMASK ],
        [ "broadcast",          \&Utils::Parse::get_sh, IFCFG, BROADCAST ],
        [ "network",            \&Utils::Parse::get_sh, IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh, IFCFG, GATEWAY ],
        [ "essid",              \&Utils::Parse::get_sh, IFCFG, WIRELESS_ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "remote_address",     \&Utils::Parse::get_sh,      IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
        [ "section",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, WVDIALSECT ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PEERDNS ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MTU ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MRU ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, PAPNAME ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP,  "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MODEMPORT ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, LINESPEED ]],
#        [ "ppp_options",        \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, DEFROUTE ]],
#        [ "debug",              \&Utils::Parse::get_sh_bool, IFCFG, DEBUG ],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PERSIST ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, ESCAPECHARS ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, HARDFLOWCTL ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ]],
#        [ "enabled",            \&gst_network_interface_active, "%dev%",
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&gst_network_interface_active, IFACE,
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
        # wvdial settings
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Phone" ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto DNS" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Username" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Password" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Modem" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Baud" ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Check Def Route" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto Reconnect" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Command" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Prefix" ]],
       ]
     },

     "vine-3.0" =>
     {
       ifaces_get => \&get_existing_rh62_ifaces,
       fn =>
       {
         IFCFG   => "/etc/sysconfig/network-scripts/ifcfg-#iface#",
         CHAT    => "/etc/sysconfig/network-scripts/chat-#iface#",
         TYPE    => "#type#",
         IFACE   => "#iface#",
         PAP     => "/etc/ppp/pap-secrets",
         CHAP    => "/etc/ppp/chap-secrets",
         PUMP    => "/etc/pump.conf",
         WVDIAL  => "/etc/wvdial.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,     IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
#        [ "name",               \&Utils::Parse::get_sh,      IFCFG, NAME ],
        [ "dev",                \&Utils::Parse::get_sh, IFCFG, DEVICE ],
        [ "address",            \&Utils::Parse::get_sh, IFCFG, IPADDR ],
        [ "netmask",            \&Utils::Parse::get_sh, IFCFG, NETMASK ],
        [ "broadcast",          \&Utils::Parse::get_sh, IFCFG, BROADCAST ],
        [ "network",            \&Utils::Parse::get_sh, IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh, IFCFG, GATEWAY ],
        [ "essid",              \&Utils::Parse::get_sh, IFCFG, ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_sh, IFCFG, KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_sh, IFCFG, KEY ]],
        [ "remote_address",     \&Utils::Parse::get_sh, IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
        [ "section",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, WVDIALSECT ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PEERDNS ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MTU ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MRU ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, PAPNAME ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP,  "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MODEMPORT ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, LINESPEED ]],
#        [ "ppp_options",        \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, DEFROUTE ]],
#        [ "debug",              \&Utils::Parse::get_sh_bool, IFCFG, DEBUG ],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PERSIST ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, ESCAPECHARS ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, HARDFLOWCTL ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ]],
#        [ "enabled",            \&gst_network_interface_active, IFACE, \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
        # wvdial settings
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Phone" ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto DNS" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Username" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Password" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Modem" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Baud" ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Check Def Route" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto Reconnect" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Command" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Prefix" ]],
       ]
     },

     "mandrake-9.0" =>
     {
       ifaces_get => \&get_existing_rh62_ifaces,
       fn =>
       {
         IFCFG   => "/etc/sysconfig/network-scripts/ifcfg-#iface#",
         CHAT    => "/etc/sysconfig/network-scripts/chat-#iface#",
         TYPE    => "#type#",
         IFACE   => "#iface#",
         PAP     => "/etc/ppp/pap-secrets",
         CHAP    => "/etc/ppp/chap-secrets",
         PUMP    => "/etc/pump.conf",
         WVDIAL  => "/etc/wvdial.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,     IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
#        [ "name",               \&Utils::Parse::get_sh,      IFCFG, NAME ],
        [ "dev",                \&Utils::Parse::get_sh, IFCFG, DEVICE ],
        [ "address",            \&Utils::Parse::get_sh, IFCFG, IPADDR ],
        [ "netmask",            \&Utils::Parse::get_sh, IFCFG, NETMASK ],
        [ "broadcast",          \&Utils::Parse::get_sh, IFCFG, BROADCAST ],
        [ "network",            \&Utils::Parse::get_sh, IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh, IFCFG, GATEWAY ],
        [ "essid",              \&Utils::Parse::get_sh, IFCFG, WIRELESS_ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "remote_address",     \&Utils::Parse::get_sh, IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
        [ "section",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, WVDIALSECT ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PEERDNS ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MTU ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MRU ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, PAPNAME ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP,  "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MODEMPORT ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, LINESPEED ]],
#        [ "ppp_options",        \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, DEFROUTE ]],
#        [ "debug",              \&Utils::Parse::get_sh_bool, IFCFG, DEBUG ],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PERSIST ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, ESCAPECHARS ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, HARDFLOWCTL ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ]],
#        [ "enabled",            \&gst_network_interface_active, IFACE,
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
        # wvdial settings
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Phone" ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto DNS" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Username" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Password" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Modem" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Baud" ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Check Def Route" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto Reconnect" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Command" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Prefix" ]],
       ]
     },

     "conectiva-9" =>
     {
       ifaces_get => \&get_existing_rh62_ifaces,
       fn =>
       {
         IFCFG   => "/etc/sysconfig/network-scripts/ifcfg-#iface#",
         CHAT    => "/etc/sysconfig/network-scripts/chat-#iface#",
         TYPE    => "#type#",
         IFACE   => "#iface#",
         PAP     => "/etc/ppp/pap-secrets",
         CHAP    => "/etc/ppp/chap-secrets",
         PUMP    => "/etc/pump.conf",
         WVDIAL  => "/etc/wvdial.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,     IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
#        [ "name",               \&Utils::Parse::get_sh,      IFCFG, NAME ],
        [ "dev",                \&Utils::Parse::get_sh, IFCFG, DEVICE ],
        [ "address",            \&Utils::Parse::get_sh, IFCFG, IPADDR ],
        [ "netmask",            \&Utils::Parse::get_sh, IFCFG, NETMASK ],
        [ "broadcast",          \&Utils::Parse::get_sh, IFCFG, BROADCAST ],
        [ "network",            \&Utils::Parse::get_sh, IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh, IFCFG, GATEWAY ],
        [ "essid",              \&Utils::Parse::get_sh, IFCFG, WIRELESS_ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "remote_address",     \&Utils::Parse::get_sh, IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
        [ "section",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, WVDIALSECT ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PEERDNS ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MTU ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MRU ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, PAPNAME ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP,  "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, MODEMPORT ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, LINESPEED ]],
        [ "ppp_options",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, DEFROUTE ]],
#        [ "debug",              \&Utils::Parse::get_sh_bool, IFCFG, DEBUG ],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, PERSIST ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, ESCAPECHARS ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_sh_bool, IFCFG, HARDFLOWCTL ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ]],
#        [ "enabled",            \&gst_network_interface_active, IFACE,
#                                                                \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
        # wvdial settings
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Phone" ]],
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto DNS" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Username" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Password" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Modem" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Baud" ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Check Def Route" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Auto Reconnect" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Command" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_ini, WVDIAL, "Dialer %section%", "Dial Prefix" ]],
       ]
     },

     "debian-3.0" =>
     {
       fn =>
       {
         INTERFACES  => "/etc/network/interfaces",
         IFACE       => "#iface#",
         TYPE        => "#type#",
         CHAT        => "/etc/chatscripts/%section%",
         PPP_OPTIONS => "/etc/ppp/peers/%section%",
         PAP         => "/etc/ppp/pap-secrets",
         CHAP        => "/etc/ppp/chap-secrets",
       },
       table =>
       [
        [ "dev",                \&Utils::Parse::get_trivial, IFACE ],
        [ "bootproto",          \&get_debian_bootproto,      [INTERFACES, IFACE]],
        [ "auto",               \&get_debian_auto,           [INTERFACES, IFACE]],
        [ "address",            \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "address" ],
        [ "netmask",            \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "netmask" ],
        [ "broadcast",          \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "broadcast" ],
        [ "network",            \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "network" ],
        [ "gateway",            \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "gateway" ],
        [ "essid",              \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "wireless[_-]essid" ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_interfaces_option_str, INTERFACES, IFACE, "wireless[_-]key1?" ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_interfaces_option_str, INTERFACES, IFACE, "wireless[_-]key1?" ]],
        [ "remote_address",     \&get_debian_remote_address, [INTERFACES, IFACE]],
        [ "section",            \&Utils::Parse::get_interfaces_option_str,    [INTERFACES, IFACE], "provider" ],
        [ "update_dns",         \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::get_kw, PPP_OPTIONS, "usepeerdns" ]],
        [ "noauth",             \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::get_kw, PPP_OPTIONS, "noauth" ]],
        [ "mtu",                \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::split_first_str, PPP_OPTIONS, "mtu", "[ \t]+" ]],
        [ "mru",                \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::split_first_str, PPP_OPTIONS, "mru", "[ \t]+" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^(/dev/[^ \t]+)" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^([0-9]+)" ]],
        [ "login",              \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^user \"?([^\"]*)\"?" ]],
        [ "password",           \&check_type, [TYPE, "(modem|isdn)", \&get_pap_passwd, PAP, "%login%" ]],
        [ "password",           \&check_type, [TYPE, "(modem|isdn)", \&get_pap_passwd, CHAP, "%login%" ]],
#        [ "ppp_options",        \&check_type, [TYPE, "modem", \&gst_network_get_ppp_options_unsup, PPP_OPTIONS ]],
        [ "set_default_gw",     \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::get_kw, PPP_OPTIONS, "defaultroute" ]],
        [ "debug",              \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::get_kw, PPP_OPTIONS, "debug" ]],
        [ "persist",            \&check_type, [TYPE, "(modem|isdn)", \&Utils::Parse::get_kw, PPP_OPTIONS, "persist" ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::split_first_str, PPP_OPTIONS, "escape", "[ \t]+" ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "crtscts" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile, CHAT, "atd[^0-9]([0-9*#]*)[wW]" ]],
        [ "external_line",      \&check_type, [TYPE, "isdn",  \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^number[ \t]+(.+)[wW]" ]],
        [ "phone_number",       \&check_type, [TYPE, "isdn",  \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^number.*[wW \t](.*)" ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile, CHAT, "atd.*[ptwW]([0-9, -]+)" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile, CHAT, "(atd[tp])[0-9, -w]+" ]],
        [ "volume",             \&check_type, [TYPE, "modem", \&get_modem_volume, CHAT ]],
#        [ "enabled",            \&gst_network_interface_active,       IFACE,
#                                                                    \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial,                  0 ]
       ]
     },

     "suse-9.0" =>
     {
       ifaces_get => \&get_existing_suse_ifaces,
       fn =>
       {
         IFCFG      => "/etc/sysconfig/network/ifcfg-#iface#",
         ROUTES_CONF => "/etc/sysconfig/network/routes",
         PROVIDERS  => "/etc/sysconfig/network/providers/%section%",
         IFACE      => "#iface#",
         TYPE       => "#type#",
       },
       table =>
       [
        [ "dev",            \&get_suse_dev_name, IFACE ],
#        [ "enabled",        \&gst_network_interface_active,        "%dev%", \&gst_network_active_interfaces_get ],
        [ "auto",           \&get_suse_auto,        IFCFG, STARTMODE ],
        [ "bootproto",      \&get_bootproto,        IFCFG, BOOTPROTO ],
        [ "address",        \&Utils::Parse::get_sh, IFCFG, IPADDR ],
        [ "netmask",        \&Utils::Parse::get_sh, IFCFG, NETMASK ],
        [ "remote_address", \&Utils::Parse::get_sh, IFCFG, REMOTE_IPADDR ],
        [ "essid",          \&Utils::Parse::get_sh, IFCFG, WIRELESS_ESSID ],
        [ "key_type",       \&get_wep_key_type,     [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "key",            \&get_wep_key,          [ \&Utils::Parse::get_sh, IFCFG, WIRELESS_KEY ]],
        [ "gateway",        \&get_suse_gateway,     ROUTES_CONF, "%address%", "%netmask%" ],
        [ "gateway",        \&get_suse_gateway,     ROUTES_CONF, "%remote_address%", "255.255.255.255" ],
        # Modem stuff goes here
        [ "serial_port",    \&Utils::Parse::get_sh, IFCFG, MODEM_DEVICE ],
        [ "serial_speed",   \&Utils::Parse::get_sh, IFCFG, SPEED ],
        [ "mtu",            \&Utils::Parse::get_sh, IFCFG, MTU ],
        [ "mru",            \&Utils::Parse::get_sh, IFCFG, MRU ],
#        [ "ppp_options",    \&Utils::Parse::get_sh, IFCFG,   PPPD_OPTIONS ],
        [ "dial_command",   \&Utils::Parse::get_sh, IFCFG, DIALCOMMAND ],
        [ "external_line",  \&Utils::Parse::get_sh, IFCFG, DIALPREFIX ],
        [ "section",        \&Utils::Parse::get_sh, IFCFG, PROVIDER ],
        [ "volume",         \&Utils::Parse::get_sh_re, IFCFG, INIT8, "AT.*[ml]([0-3])" ],
        [ "login",          \&Utils::Parse::get_sh, PROVIDERS, USERNAME ],
        [ "password",       \&Utils::Parse::get_sh, PROVIDERS, PASSWORD ],
        [ "phone_number",   \&Utils::Parse::get_sh, PROVIDERS, PHONE ],
        [ "dns1",           \&Utils::Parse::get_sh, PROVIDERS, DNS1 ],
        [ "dns2",           \&Utils::Parse::get_sh, PROVIDERS, DNS2 ],
        [ "update_dns",     \&Utils::Parse::get_sh_bool, PROVIDERS, MODIFYDNS ],
        [ "persist",        \&Utils::Parse::get_sh_bool, PROVIDERS, PERSIST ],
        [ "stupid",         \&Utils::Parse::get_sh_bool, PROVIDERS, STUPIDMODE ],
        [ "set_default_gw", \&Utils::Parse::get_sh_bool, PROVIDERS, DEFAULTROUTE ],
       ]
     },

     "pld-1.0" =>
     {
       ifaces_get => \&get_existing_pld_ifaces,
       fn =>
       {
         IFCFG => "/etc/sysconfig/interfaces/ifcfg-#iface#",
         CHAT  => "/etc/sysconfig/interfaces/data/chat-#iface#",
         TYPE  => "#type#",
         IFACE => "#iface#",
         PAP   => "/etc/ppp/pap-secrets",
         CHAP  => "/etc/ppp/chap-secrets",
         PUMP  => "/etc/pump.conf"
       },
       table =>
       [
        [ "bootproto",          \&get_rh_bootproto,          IFCFG, BOOTPROTO ],
        [ "auto",               \&Utils::Parse::get_sh_bool, IFCFG, ONBOOT ],
#        [ "user",               \&Utils::Parse::get_sh_bool, IFCFG, USERCTL ],
#        [ "name",               \&Utils::Parse::get_sh,      IFCFG, DEVICE ],
        [ "dev",                \&Utils::Parse::get_sh,      IFCFG, DEVICE ],
        [ "address",            \&get_pld_ipaddr,            IFCFG, IPADDR, "address" ],
        [ "netmask",            \&get_pld_ipaddr,            IFCFG, IPADDR, "netmask" ],
#        [ "broadcast",          \&Utils::Parse::get_sh,      IFCFG, BROADCAST ],
#        [ "network",            \&Utils::Parse::get_sh,      IFCFG, NETWORK ],
        [ "gateway",            \&Utils::Parse::get_sh,      IFCFG, GATEWAY ],
        [ "remote_address",     \&Utils::Parse::get_sh,      IFCFG, REMIP ],
#        [ "update_dns",         \&gst_network_pump_get_nodns, PUMP, "%dev%", "%bootproto%" ],
#        [ "dns1",               \&Utils::Parse::get_sh,      IFCFG, DNS1 ],
#        [ "dns2",               \&Utils::Parse::get_sh,      IFCFG, DNS2 ],
        [ "update_dns",         \&Utils::Parse::get_sh_bool, IFCFG, PEERDNS ],
        [ "mtu",                \&Utils::Parse::get_sh,      IFCFG, MTU ],
        [ "mru",                \&Utils::Parse::get_sh,      IFCFG, MRU ],
        [ "login",              \&Utils::Parse::get_sh,      IFCFG, PAPNAME ],
        [ "password",           \&get_pap_passwd,            PAP,  "%login%" ],
        [ "password",           \&get_pap_passwd,            CHAP, "%login%" ],
        [ "serial_port",        \&Utils::Parse::get_sh,      IFCFG, MODEMPORT ],
        [ "serial_speed",       \&Utils::Parse::get_sh,      IFCFG, LINESPEED ],
#        [ "ppp_options",        \&Utils::Parse::get_sh,      IFCFG, PPPOPTIONS ],
#        [ "section",            \&Utils::Parse::get_sh,      IFCFG, WVDIALSECT ],
        [ "set_default_gw",     \&Utils::Parse::get_sh_bool, IFCFG, DEFROUTE ],
#        [ "debug",              \&Utils::Parse::get_sh_bool, IFCFG, DEBUG ],
        [ "persist",            \&Utils::Parse::get_sh_bool, IFCFG, PERSIST ],
        [ "serial_escapechars", \&Utils::Parse::get_sh_bool, IFCFG, ESCAPECHARS ],
        [ "serial_hwctl",       \&Utils::Parse::get_sh_bool, IFCFG, HARDFLOWCTL ],
        [ "phone_number",       \&Utils::Parse::get_from_chatfile,    CHAT, "^atd[^0-9]*([0-9, -]+)" ],
#        [ "enabled",            \&gst_network_interface_active, IFACE, \&gst_network_active_interfaces_get ],
#        [ "enabled",            \&Utils::Parse::get_trivial, 0 ]
       ]
     },

     "slackware-9.1.0" =>
     {
       fn =>
       {
         RC_INET_CONF => "/etc/rc.d/rc.inet1.conf",
         RC_INET      => "/etc/rc.d/rc.inet1",
         RC_LOCAL     => "/etc/rc.d/rc.local",
         TYPE         => "#type#",
         IFACE        => "#iface#",
         WIRELESS     => "/etc/pcmcia/wireless.opts",
         PPP_OPTIONS  => "/etc/ppp/options",
         PAP          => "/etc/ppp/pap-secrets",
         CHAP         => "/etc/ppp/chap-secrets",
         CHAT         => "/etc/ppp/pppscript",
       },
       table =>
       [
#        [ "user",               \&Utils::Parse::get_trivial,     0 ], # not supported.
        [ "dev",                \&Utils::Parse::get_trivial,     IFACE ],
        [ "address",            \&Utils::Parse::get_rcinet1conf, [RC_INET_CONF, IFACE], IPADDR ],
        [ "netmask",            \&Utils::Parse::get_rcinet1conf, [RC_INET_CONF, IFACE], NETMASK ],
        [ "gateway",            \&get_gateway,                   RC_INET_CONF, GATEWAY, "%address%", "%netmask%" ],
        [ "auto",               \&get_slackware_auto,            [RC_INET, RC_LOCAL, IFACE]],
        [ "bootproto",          \&get_slackware_bootproto,       [RC_INET_CONF, IFACE]],
        [ "essid",              \&Utils::Parse::get_wireless_opts,            [ WIRELESS, IFACE], \&get_wireless_ifaces, ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_wireless_opts, [ WIRELESS, IFACE], \&get_wireless_ifaces, KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_wireless_opts, [ WIRELESS, IFACE], \&get_wireless_ifaces, KEY ]],
#        [ "enabled",            \&gst_network_interface_active,       IFACE, \&gst_network_active_interfaces_get ],
        # Modem stuff
        [ "update_dns",         \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "usepeerdns" ]],
        [ "noauth",             \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "noauth" ]],
        [ "mtu",                \&check_type, [TYPE, "modem", \&Utils::Parse::split_first_str, PPP_OPTIONS, "mtu", "[ \t]+" ]],
        [ "mru",                \&check_type, [TYPE, "modem", \&Utils::Parse::split_first_str, PPP_OPTIONS, "mru", "[ \t]+" ]],
        [ "serial_port",        \&check_type, [TYPE, "modem", \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^(/dev/[^ \t]+)" ]],
        [ "serial_speed",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^([0-9]+)" ]],
        [ "login",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_ppp_options_re, PPP_OPTIONS, "^name \"?([^\"]*)\"?" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, PAP, "%login%" ]],
        [ "password",           \&check_type, [TYPE, "modem", \&get_pap_passwd, CHAP, "%login%" ]],
#        [ "ppp_options",        \&check_type, [TYPE, "modem", \&gst_network_get_ppp_options_unsup, PPP_OPTIONS ]],
        [ "set_default_gw",     \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "defaultroute" ]],
        [ "debug",              \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "debug" ]],
        [ "persist",            \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "persist" ]],
        [ "serial_escapechars", \&check_type, [TYPE, "modem", \&Utils::Parse::split_first_str, PPP_OPTIONS, "escape", "[ \t]+" ]],
        [ "serial_hwctl",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_kw, PPP_OPTIONS, "crtscts" ]],
        [ "external_line",      \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile, CHAT, "atd[^0-9]*([0-9*#]*)[wW]" ]],
        [ "phone_number",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile, CHAT, "atd.*[ptw]([0-9, -]+)" ]],
        [ "dial_command",       \&check_type, [TYPE, "modem", \&Utils::Parse::get_from_chatfile, CHAT, "(atd[tp])[0-9, -w]+" ]],
        [ "volume",             \&check_type, [TYPE, "modem", \&get_modem_volume, CHAT ]],
       ]
     },

     "gentoo" =>
     {
       fn =>
       {
         NET          => "/etc/conf.d/net",
         PPPNET       => "/etc/conf.d/net.#iface#",
         INIT         => "net.#iface#",
         TYPE         => "#type#",
         IFACE        => "#iface#",
         WIRELESS     => "/etc/pcmcia/wireless.opts",
       },
       table =>
       [
        [ "auto",               \&Init::Services::get_gentoo_service_status, INIT, "default" ],
        [ "user",               \&Utils::Parse::get_trivial, 0 ], # not supported.
        [ "dev",                \&Utils::Parse::get_trivial, IFACE ],
        [ "address",            \&Utils::Parse::get_sh_re,   NET, "iface_%dev%", "^[ \t]*([0-9\.]+)" ],
        [ "netmask",            \&Utils::Parse::get_sh_re,   NET, "iface_%dev%", "netmask[ \t]+([0-9\.]*)" ],
        [ "remote_address",     \&Utils::Parse::get_sh_re,   NET, "iface_%dev%", "dest_address[ \t]+([0-9\.]*)" ],
        [ "gateway",            \&Utils::Parse::get_sh_re,   NET, "gateway", "%dev%/([0-9\.\:]*)" ],
#        [ "enabled",            \&gst_network_interface_active,    IFACE, \&gst_network_active_interfaces_get ],
        [ "bootproto",          \&get_bootproto,             NET, "iface_%dev%" ],
        [ "essid",              \&Utils::Parse::get_wireless_opts, [ WIRELESS, IFACE], \&get_wireless_ifaces, ESSID ],
        [ "key_type",           \&get_wep_key_type, [ \&Utils::Parse::get_wireless_opts, [ WIRELESS, IFACE], \&get_wireless_ifaces, KEY ]],
        [ "key",                \&get_wep_key,      [ \&Utils::Parse::get_wireless_opts, [ WIRELESS, IFACE], \&get_wireless_ifaces, KEY ]],
        # modem stuff
        [ "update_dns",         \&Utils::Parse::get_sh_bool, PPPNET, PEERDNS ],
        [ "mtu",                \&Utils::Parse::get_sh,      PPPNET, MTU ],
        [ "mru",                \&Utils::Parse::get_sh,      PPPNET, MRU ],
        [ "serial_port",        \&Utils::Parse::get_sh,      PPPNET, MODEMPORT ],
        [ "serial_speed",       \&Utils::Parse::get_sh,      PPPNET, LINESPEED ],
        [ "login",              \&Utils::Parse::get_sh,      PPPNET, USERNAME ],
        [ "password",           \&Utils::Parse::get_sh,      PPPNET, PASSWORD ],
        [ "ppp_options",        \&Utils::Parse::get_sh,      PPPNET, PPPOPTIONS ],
        [ "set_default_gw",     \&Utils::Parse::get_sh_bool, PPPNET, DEFROUTE ],
        [ "debug",              \&Utils::Parse::get_sh_bool, PPPNET, DEBUG ],
        [ "persist",            \&Utils::Parse::get_sh_bool, PPPNET, PERSIST ],
        [ "serial_escapechars", \&Utils::Parse::get_sh_bool, PPPNET, ESCAPECHARS ],
        [ "serial_hwctl",       \&Utils::Parse::get_sh_bool, PPPNET, HARDFLOWCTL ],
        [ "external_line",      \&Utils::Parse::get_sh_re,   PPPNET, NUMBER, "^([0-9*#]*)wW" ],
        [ "phone_number",       \&Utils::Parse::get_sh_re,   PPPNET, NUMBER, "w?([0-9]*)\$" ],
        [ "volume",             \&Utils::Parse::get_sh_re,   PPPNET, INITSTRING, "^at.*[ml]([0-3])" ],
       ]
     },

     "freebsd-5" =>
     {
       fn =>
       {
         RC_CONF         => "/etc/rc.conf",
         RC_CONF_DEFAULT => "/etc/defaults/rc.conf",
         STARTIF         => "/etc/start_if.#iface#",
         PPPCONF         => "/etc/ppp/ppp.conf",
         TYPE            => "#type#",
         IFACE           => "#iface#",
       },
       table =>
       [
        [ "auto",           \&get_freebsd_auto,               [RC_CONF, RC_CONF_DEFAULT, IFACE ]],
#        [ "user",           \&Utils::Parse::get_trivial,      0 ], # not supported.
        [ "dev",            \&Utils::Parse::get_trivial,      IFACE ],
        # we need to double check these values both in the start_if and in the rc.conf files, in this order
        [ "address",        \&Utils::Parse::get_startif,      STARTIF, "inet[ \t]+([0-9\.]+)" ],
        [ "address",        \&Utils::Parse::get_sh_re,        RC_CONF, "ifconfig_%dev%", "inet[ \t]+([0-9\.]+)" ],
        [ "netmask",        \&Utils::Parse::get_startif,      STARTIF, "netmask[ \t]+([0-9\.]+)" ],
        [ "netmask",        \&Utils::Parse::get_sh_re,        RC_CONF, "ifconfig_%dev%", "netmask[ \t]+([0-9\.]+)" ],
        [ "remote_address", \&Utils::Parse::get_startif,      STARTIF, "dest_address[ \t]+([0-9\.]+)" ],
        [ "remote_address", \&Utils::Parse::get_sh_re,        RC_CONF, "ifconfig_%dev%", "dest_address[ \t]+([0-9\.]+)" ],
        [ "essid",          \&Utils::Parse::get_startif,      STARTIF, "ssid[ \t]+(\".*\"|[^\"][^ ]+)" ],
        [ "essid",          \&Utils::Parse::get_sh_re,        RC_CONF, "ifconfig_%dev%", "ssid[ \t]+([^ ]*)" ],
        # this is for plip interfaces
        [ "gateway",        \&get_gateway,                    RC_CONF, "defaultrouter", "%remote_address%", "255.255.255.255" ],
        [ "gateway",        \&get_gateway,                    RC_CONF, "defaultrouter", "%address%", "%netmask%" ],
#        [ "enabled",        \&gst_network_interface_active,   IFACE, \&gst_network_freebsd5_active_interfaces_get ],
        [ "bootproto",      \&get_bootproto,                  RC_CONF, "ifconfig_%dev%" ],
        # Modem stuff
        [ "serial_port",    \&Utils::Parse::get_pppconf,      [ PPPCONF, STARTIF, IFACE ], "device"   ],
        [ "serial_speed",   \&Utils::Parse::get_pppconf,      [ PPPCONF, STARTIF, IFACE ], "speed"    ],
        [ "mtu",            \&Utils::Parse::get_pppconf,      [ PPPCONF, STARTIF, IFACE ], "mtu"      ],
        [ "mru",            \&Utils::Parse::get_pppconf,      [ PPPCONF, STARTIF, IFACE ], "mru"      ],
        [ "login",          \&Utils::Parse::get_pppconf,      [ PPPCONF, STARTIF, IFACE ], "authname" ],
        [ "password",       \&Utils::Parse::get_pppconf,      [ PPPCONF, STARTIF, IFACE ], "authkey"  ],
        [ "update_dns",     \&Utils::Parse::get_pppconf_bool, [ PPPCONF, STARTIF, IFACE ], "dns"      ],
        [ "set_default_gw", \&Utils::Parse::get_pppconf_bool, [ PPPCONF, STARTIF, IFACE ], "default HISADDR" ],
        [ "external_line",  \&Utils::Parse::get_pppconf_re,   [ PPPCONF, STARTIF, IFACE ], "phone", "[ \t]+([0-9]+)[wW]" ],
        [ "phone_number",   \&Utils::Parse::get_pppconf_re,   [ PPPCONF, STARTIF, IFACE ], "phone", "[wW]?([0-9]+)[ \t]*\$" ],
        [ "dial_command",   \&Utils::Parse::get_pppconf_re,   [ PPPCONF, STARTIF, IFACE ], "dial",  "(ATD[TP])" ],
        [ "volume",         \&Utils::Parse::get_pppconf_re,   [ PPPCONF, STARTIF, IFACE ], "dial",  "AT.*[ml]([0-3]) OK " ],
        [ "persist",        \&get_freebsd_ppp_persist,        [ STARTIF, IFACE ]],
       ]
     },
	  );
  
  my $dist = $dist_map{$Utils::Backend::tool{"platform"}};
  return %{$dist_tables{$dist}} if $dist;

  &Utils::Report::do_report ("platform_no_table", $$tool{"platform"});
  return undef;
}

sub get_interfaces
{
  my (%dist_attrib, %config_hash, %hash, %fn);
  my (@config_ifaces, @ifaces, $iface, $dev);
  my ($dist, $value, $file, $proc);
  my ($i, $j);
  my ($modem_settings);

  %hash = &get_interfaces_info ();
  %dist_attrib = &get_interface_parse_table ();
  %fn = %{$dist_attrib{"fn"}};
  $proc = $dist_attrib{"ifaces_get"};

  if ($proc)
  {
    @ifaces = &$proc ();
  }
  else
  {
    @ifaces = keys %hash;
  }

  # clear unneeded hash elements
  foreach $i (@ifaces)
  {
    delete $hash{$i}{"addr"};
    delete $hash{$i}{"bcast"};
    delete $hash{$i}{"mask"};

    foreach $j (keys (%fn))
    {
      ${$dist_attrib{"fn"}}{$j} = &Utils::Parse::expand ($fn{$j},
                                                         "iface", $i,
                                                         "type",  $hash{$i}{"type"});
    }

    $iface = &Utils::Parse::get_from_table ($dist_attrib{"fn"},
                                            $dist_attrib{"table"});

    &ensure_iface_broadcast_and_network ($iface);
    $$iface{"file"} = $i if ($$iface{"file"} eq undef);

    $dev = $$iface{"dev"};
    delete $$iface{"dev"};

    if (exists $hash{$dev})
    {
      $hash{$dev}{"configuration"} = $iface;
    }
    elsif (($dev eq "ppp0") || ($dev eq "tun0"))
    {
      $modem_settings = $iface;
    }
  }

  # only show PPP and ISDN devices if pppd exists
  # and they aren't configured yet
  $dev = "ppp0" if ($Utils::Backend::tool{"system"} eq "Linux");
  $dev = "tun0" if ($Utils::Backend::tool{"system"} eq "FreeBSD");

  if (!exists $hash{$dev} && &Utils::File::locate_tool ("pppd"))
  {
    $hash{$dev}{"dev"} = $dev;
    $hash{$dev}{"enabled"} = 0;
    $hash{$dev}{"type"} = &get_interface_type ($dev);
    $hash{$dev}{"configuration"} = $modem_settings if ($modem_settings);
  }

  return \%hash;
}

sub get
{
  &get_interfaces ();
  return undef;
}

1;
