if INTERNAL_NET_DBUS
net_dbus_SUBDIRS = Net-DBus
endif

SUBDIRS = files Init Network Shares Time Users Utils $(net_dbus_SUBDIRS)

modulesdir = $(scriptsdir)
modules_DATA =	\
	GroupsConfig.pm	\
	HostsConfig.pm		\
	IfacesConfig.pm	\
	NFSConfig.pm		\
	NTPConfig.pm		\
	ServicesConfig.pm	\
	SMBConfig.pm		\
	TimeConfig.pm		\
	UsersConfig.pm

scripts = \
	SystemToolsBackends.pl

scripts_SCRIPTS = $(scripts)

EXTRA_DIST = \
	system-tools-backends-2.0.pc.in \
	system-tools-backends.conf.in \
	org.freedesktop.SystemToolsBackends.service.in \
	test-backends.in \
	$(modules_DATA) \
	README \
	AUTHORS \
	NEWS

CLEANFILES = \
	test-backends			\
	SystemToolsBackends.pl		\
	system-tools-backends-2.0.pc	\
	system-tools-backends.conf	\
	org.freedesktop.SystemToolsBackends.service

#DISTCLEANFILES =

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = system-tools-backends-2.0.pc

# Dbus service file
servicedir = $(DBUS_SERVICES_DIR)
service_DATA = org.freedesktop.SystemToolsBackends.service

# DBus system.d file
systemddir = $(DBUS_SYSTEMD_DIR)
systemd_DATA = system-tools-backends.conf

