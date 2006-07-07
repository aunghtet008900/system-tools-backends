SUBDIRS = lib

EXTRA_DIST = Makefile.PL DBus.xs

INCLUDES = -I$(top_srcdir)

AM_CPPFLAGS=@CPPFLAGS@ -I$(top_srcdir) -I$(top_builddir) @DBUS_CFLAGS@
AM_CFLAGS=@CFLAGS@ @DBUS_CFLAGS@
AM_STANDARD_CFLAGS=@DBUS_CFLAGS@

PERL=@PERL_PATH@

PERL_MAKEFILE=Makefile.perl

PERL_CRUFT=pm_to_blib $(PERL_MAKEFILE).old

fakedir=$(prefix)
fake_DATA=build-perl-stamp

$(PERL_MAKEFILE): DBus.xs
	test -e Makefile.PL || $(LN_S) $(srcdir)/Makefile.PL .
	VERSION=$(VERSION) CC=$(CC) CFLAGS="$(AM_CPPFLAGS) $(AM_CFLAGS) $(SWIG_OPTS) $(CPPFLAGS) $(AM_STANDARD_CFLAGS)" $(PERL) $(srcdir)/Makefile.PL DESTDIR=$(DESTDIR) PREFIX=$(prefix) $(MAKE_PL_OPTS)

-perl install-perl: $(PERL_MAKEFILE)
	target=`echo $@ | sed -e 's/-perl//'`; \
	$(MAKE) -f $(PERL_MAKEFILE) DESTDIR=$(DESTDIR) PREFIX=$(prefix) $$target

test-perl: $(PERL_MAKEFILE)
	$(RUN)$(MAKE) -f $(PERL_MAKEFILE) test

clean-perl realclean-perl:
	@target=`echo $@ | sed -e 's/-perl//'`; \
	if test -r $(PERL_MAKEFILE); then \
	  echo $(MAKE) -f $(PERL_MAKEFILE) $$target; \
	  $(MAKE) -f $(PERL_MAKEFILE) $$target; \
	fi

build-perl: -perl

build-perl-stamp:
	$(MAKE) build-perl && touch build-perl-stamp

clean-local:
	rm -f DBus.bs  DBus.c  DBus.o
	rm -rf blib $(PERL_MAKEFILE) $(PERL_MAKEFILE).old build-perl-stamp $(PERL_CRUFT)
	-test -L Makefile.PL && rm Makefile.PL


# perl module installation disabled since broken wrt to make distcheck
install-fakeDATA: install-perl

uninstall-local:
	find $(DESTDIR)$(prefix) -name perllocal.pod -exec rm -f {} \;
	true

