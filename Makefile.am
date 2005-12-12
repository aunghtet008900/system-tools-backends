SUBDIRS = m4macros files po Init Network Shares Time Users Utils

scripts = \
	Loader.pl		\
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
	intltool-extract.in \
	intltool-merge.in \
	intltool-update.in \
	system-tools-backends-2.0.pc.in \
	README \
	AUTHORS \
	NEWS

CLEANFILES = $(scripts)

DISTCLEANFILES = \
	intltool-extract 	\
	intltool-merge		\
	intltool-update

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = system-tools-backends-2.0.pc

# Dbus service file
servicedir = $(DBUS_SERVICES_DIR)
service_DATA = org.freedesktop.SystemToolsBackends.service

