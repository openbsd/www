#!/usr/bin/perl
# $OpenBSD: pkgstable.pl,v 1.2 2006/11/01 09:47:21 sturm Exp $

# Public Domain, Nikolay Sturm <sturm@openbsd.org>

use strict;
use warnings;

die "usage: $0 <OpenBSD release>" unless $ARGV[0];
my $release = $ARGV[0];

my $packages = "packages-$release";
open(my $fh, "< $packages") or die "Cannot read $packages: $!";

while (<$fh>) {
	chomp;
	my ($pkg, $desc) = split / /, $_, 2;

	printf "<dt>";
	if (not defined $desc) {
		printf "<font color=\"#e00000\">$pkg</font>\n";
		$desc = "Security fix";
	} else {
		printf "$pkg\n";
	}

	printf "<a href=\"ftp://ftp.openbsd.org/pub/OpenBSD/$release/packages/i386/$pkg\">i386</a>\n";
	if ($release == 4.0) {
		printf "<a href=\"ftp://ftp.openbsd.org/pub/OpenBSD/$release/packages/amd64/$pkg\">amd64</a>\n";
	}
	printf "<dd>$desc\n";
}

close($fh);
