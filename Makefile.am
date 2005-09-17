SUBDIRS = m4macros files po Shares Time Users Utils

scripts = \
	Loader.pl			\
	GroupsConfig.pm	\
	NFSConfig.pm		\
	NTPConfig.pm		\
	ServicesList.pm	\
	SharesList.pm		\
	ShellsConfig.pm	\
	SMBConfig.pm		\
	TimeConfig.pm		\
	UsersConfig.pm		\
	network.pl

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

DISTCLEANFILES =	\
	intltool-extract 	\
	intltool-merge		\
	intltool-update

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = system-tools-backends-2.0.pc
