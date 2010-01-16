if INTERNAL_NET_DBUS
net_dbus_SUBDIRS = Net-DBus
endif

SUBDIRS = dispatcher services files Init Network Shares Time Users Utils po $(net_dbus_SUBDIRS)

modulesdir = $(scriptsdir)
modules_DATA =	\
	Platform.pm	\
	StbObject.pm	\
	GroupConfig.pm	\
	GroupsConfig.pm	\
	HostsConfig.pm		\
	IfacesConfig.pm	\
	NFSConfig.pm		\
	NTPConfig.pm		\
	ServicesConfig.pm	\
	SMBConfig.pm		\
	TimeConfig.pm		\
	UserConfig.pm		\
	UsersConfig.pm		\
	SelfConfig.pm

scripts = \
	SystemToolsBackends.pl

scripts_SCRIPTS = $(scripts)

EXTRA_DIST = \
	system-tools-backends-2.0.pc.in \
	org.freedesktop.SystemToolsBackends.conf \
	$(policy_in_files) \
	org.freedesktop.SystemToolsBackends.service.in \
	test-backends.in \
	diagnostics.pl \
	$(modules_DATA) \
	README \
	AUTHORS \
	NEWS

CLEANFILES = \
	test-backends			\
	SystemToolsBackends.pl		\
	system-tools-backends-2.0.pc	\
	org.freedesktop.SystemToolsBackends.service \
	$(policy_DATA)

#DISTCLEANFILES =

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = system-tools-backends-2.0.pc

# Dbus service file
servicedir = $(DBUS_SERVICES_DIR)
service_DATA = org.freedesktop.SystemToolsBackends.service

# DBus system.d file
systemddir = $(DBUS_SYSTEMD_DIR)
systemd_DATA = org.freedesktop.SystemToolsBackends.conf

policy_in_files = org.freedesktop.SystemToolsBackends.policy.in

policydir = $(POLKIT_POLICY_DIR)
policy_DATA = $(policy_in_files:.policy.in=.policy)

@INTLTOOL_POLICY_RULE@

