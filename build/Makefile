# Makefile for WWW subdirectory.

all: ../groups.html ../support.html

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

clean:
		rm -f *.countries
