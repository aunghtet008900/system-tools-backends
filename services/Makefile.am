services_in = \
	org.freedesktop.SystemToolsBackends.GroupsConfig.service.in \
	org.freedesktop.SystemToolsBackends.HostsConfig.service.in \
	org.freedesktop.SystemToolsBackends.IfacesConfig.service.in \
	org.freedesktop.SystemToolsBackends.NFSConfig.service.in \
	org.freedesktop.SystemToolsBackends.NTPConfig.service.in \
        org.freedesktop.SystemToolsBackends.Platform.service.in \
        org.freedesktop.SystemToolsBackends.ServicesConfig.service.in \
	org.freedesktop.SystemToolsBackends.SMBConfig.service.in \
	org.freedesktop.SystemToolsBackends.TimeConfig.service.in \
	org.freedesktop.SystemToolsBackends.UsersConfig.service.in

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
	org.freedesktop.SystemToolsBackends.UsersConfig.service

EXTRA_DIST = $(services_in)
CLEANFILES = $(services)

# Dbus service files
servicedir = $(DBUS_SERVICES_DIR)
service_DATA = $(services)
