INCLUDES = \
	-Wall	\
	$(DISPATCHER_CFLAGS) \
	$(POLKIT_CFLAGS) \
	$(GIO_CFLAGS)

sbin_PROGRAMS = system-tools-backends

if HAVE_GIO
file_monitor_sources = file-monitor.c file-monitor.h
endif

system_tools_backends_LDADD = $(DISPATCHER_LIBS) $(POLKIT_LIBS) $(GIO_LIBS)
system_tools_backends_SOURCES = \
	$(file_monitor_sources) \
	dispatcher.c  dispatcher.h	\
	main.c
