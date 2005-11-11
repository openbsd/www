# Makefile for WWW subdirectory.

STABLE_VERSION=	3.8
PREV_VERSION=	3.7

all: ../groups.html ../support.html ../pkg-stable.html \\
	../pkg-stable${PREV_VERSION:S/.//}.html

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
		cat pkg-stable.html.head > $@
		perl pkgstable.pl ${STABLE_VERSION} >> $@
		cat pkg-stable.html.tail >> $@

../pkg-stable${PREV_VERSION:S/.//}.html: packages-${PREV_VERSION} \
	pkg-stable.prev.html.head pkg-stable.html.tail
		cat pkg-stable.prev.html.head > $@
		perl pkgstable.pl ${PREV_VERSION} >> $@
		cat pkg-stable.html.tail >> $@

clean:
		rm -f *.countries
