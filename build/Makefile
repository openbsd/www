# Makefile for WWW subdirectory.

STABLE_VERSION=	5.7
PREV_VERSION=	5.6

OPENBGPD_VERSION=		4.6
OPENNTPD_PORTABLE_VERSION=	5.7p4

OPENSSH_VERSION=		7.0
OPENSSH_PORTABLE_VERSION=	7.0p1

all: ../groups.html ../support.html ../pkg-stable.html \
	../pkg-stable${PREV_VERSION:S/.//}.html \
	../ftp.html

# Build the user groups page.
../groups.html:	groups.dat groups.awk groups.skel Makefile mkcountries
		sh mkcountries groups.dat > groups.countries
		awk -f groups.awk groups.dat > groups-tbl.html
		m4 groups.skel > ../groups.html
		@rm -f groups-tbl.html groups.countries

# Build the support/consultants page.
../support.html: support.dat support.awk support.skel Makefile mkcountries
		sh mkcountries support.dat > support.countries
		awk -f support.awk support.dat > support-tbl.html
		m4 support.skel > ../support.html
		@rm -f support-tbl.html support.countries

# Build stable packages pages.
../pkg-stable.html: packages-${STABLE_VERSION} pkg-stable.html.head \
	pkg-stable.html.tail
		sed -e "s/_STABLE_/${STABLE_VERSION}/g" pkg-stable.html.head > $@
		perl pkgstable.pl ${STABLE_VERSION} >> $@
		cat pkg-stable.html.tail >> $@

../pkg-stable${PREV_VERSION:S/.//}.html: packages-${PREV_VERSION} \
	pkg-stable.prev.html.head pkg-stable.html.tail
		sed -e "s/_PREV_/${PREV_VERSION}/g" pkg-stable.prev.html.head > $@
		perl pkgstable.pl ${PREV_VERSION} >> $@
		cat pkg-stable.html.tail >> $@

# Build the FTP/HTTP/RSYNC mirrors page.
ftp: mirrors.pl mirrors.dat mirrors/ftp.html.{end,head,mid1,mid2} \
     mirrors/openntpd-ftp.html.{end,head,mid2} \
     mirrors/openntpd-portable.html.head mirrors/openbgpd-ftp.html.{end,head}
	perl mirrors.pl openbsd-ftp ${STABLE_VERSION}
	perl mirrors.pl openbgpd-ftp ${OPENBGPD_VERSION}
	perl mirrors.pl openntpd-portable ${OPENNTPD_PORTABLE_VERSION}
	perl mirrors.pl openssh-ftp ${OPENSSH_VERSION}
	perl mirrors.pl openssh-portable ${OPENSSH_PORTABLE_VERSION}
	perl mirrors.pl ftplist ${STABLE_VERSION}

anoncvs: mirrors.pl mirrors.dat mirrors/anoncvs.html.{end,head}
	perl mirrors.pl anoncvs ${STABLE_VERSION}

cvsync: mirrors.pl mirrors.dat mirrors/cvsync.html.{end,head}
	perl mirrors.pl cvsync ${STABLE_VERSION}

clean:
		rm -f *.countries
