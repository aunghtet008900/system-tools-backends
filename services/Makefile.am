services = \
	org.freedesktop.SystemToolsBackends.GroupsConfig.service \
	org.freedesktop.SystemToolsBackends.HostsConfig.service \
	org.freedesktop.SystemToolsBackends.IfacesConfig.service \
	org.freedesktop.SystemToolsBackends.NFSConfig.service \
	org.freedesktop.SystemToolsBackends.NTPConfig.service \
        org.freedesktop.SystemToolsBackends.Platform.service \
        org.freedesktop.SystemToolsBackends.ServicesConfig.service \
	org.freedesktop.SystemToolsBackends.SMBConfig.service \
	org.freedesktop.SystemToolsBackends.TimeConfig.service \
	org.freedesktop.SystemToolsBackends.UserConfig.service \
	org.freedesktop.SystemToolsBackends.UsersConfig.service

EXTRA_DIST = \
	$(services:.service=.service.in)

CLEANFILES = $(services)

# Dbus service files
servicedir = $(DBUS_SERVICES_DIR)
service_DATA = $(services)
