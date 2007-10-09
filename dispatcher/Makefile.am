INCLUDES = \
	-Wall	\
	$(DISPATCHER_CFLAGS) \
	$(POLKIT_CFLAGS)

bin_PROGRAMS = system-tools-backends

system_tools_backends_LDADD = $(DISPATCHER_LIBS) $(POLKIT_LIBS)
system_tools_backends_SOURCES = \
	dispatcher.c  dispatcher.h	\
	main.c
