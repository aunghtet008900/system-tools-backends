SUBDIRS = m4macros files Init Network Shares Time Users Utils

scripts = \
	SystemToolsBackends.pl	\
	GroupsConfig.pm		\
	HostsConfig.pm		\
	IfacesConfig.pm		\
	NFSConfig.pm		\
	NTPConfig.pm		\
	ServicesConfig.pm	\
	SMBConfig.pm		\
	TimeConfig.pm		\
	UsersConfig.pm	

scripts_SCRIPTS = $(scripts)

EXTRA_DIST = \
	system-tools-backends-2.0.pc.in \
	README \
	AUTHORS \
	NEWS

CLEANFILES = \
	SystemToolsBackends.pl		\
	system-tools-backends-2.0.pc	\
	org.freedesktop.SystemToolsBackends.service

#DISTCLEANFILES =

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = system-tools-backends-2.0.pc

# Dbus service file
servicedir = $(DBUS_SERVICES_DIR)
service_DATA = org.freedesktop.SystemToolsBackends.service

