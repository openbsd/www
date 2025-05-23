# Makefile for WWW subdirectory.

STABLE_VERSION=	7.7
PREV_VERSION=	7.6

# also update mirrors/openbgpd-ftp.html.head
OPENBGPD_VERSION=		8.8

# also update mirrors/openntpd-ftp.html.head
OPENNTPD_PORTABLE_VERSION=	6.8p1

# also update mirrors/rpki-client-portable.html.head
RPKI_CLIENT_PORTABLE_VERSION=	9.5

OPENSSH_VERSION=		10.0
OPENSSH_PORTABLE_VERSION=	10.0p1

all: ../groups.html ../support.html ../ftp.html

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

# Build the FTP/HTTP/RSYNC mirrors page.
../ftp.html ftp: Makefile mirrors.pl mirrors.dat \
     mirrors/ftp.html.{head,end,mid0,mid1,mid2} \
     mirrors/openbgpd-ftp.html.{head,end} \
     mirrors/openntpd-portable.html.{head,end} \
     mirrors/openssh-ftp.html.{head,end} \
     mirrors/openssh-portable.html.{head,end,mid1} \
     mirrors/rpki-client-portable.html.{head,end}
	perl mirrors.pl openbsd-ftp ${STABLE_VERSION}
	perl mirrors.pl openbgpd-ftp ${OPENBGPD_VERSION}
	perl mirrors.pl openntpd-portable ${OPENNTPD_PORTABLE_VERSION}
	perl mirrors.pl rpki-client-portable ${RPKI_CLIENT_PORTABLE_VERSION}
	perl mirrors.pl openssh-ftp ${OPENSSH_VERSION}
	perl mirrors.pl openssh-portable ${OPENSSH_PORTABLE_VERSION}
	perl mirrors.pl ftplist ${STABLE_VERSION}

anoncvs: mirrors.pl mirrors.dat mirrors/anoncvs.html.{end,head}
	perl mirrors.pl anoncvs ${STABLE_VERSION}

clean:
	rm -f *.countries

version:
	sh versionup ${STABLE_VERSION} ${PREV_VERSION}
	make anoncvs ftp
