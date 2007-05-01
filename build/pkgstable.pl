#!/usr/bin/perl
# $OpenBSD: pkgstable.pl,v 1.5 2007/05/01 17:02:12 sturm Exp $

# Public Domain, Nikolay Sturm <sturm@openbsd.org>

use strict;
use warnings;

die "usage: $0 <OpenBSD release>" unless $ARGV[0];
my $release = $ARGV[0];

my $packages = "packages-$release";
open(my $fh, "<", "$packages") or die "Cannot read $packages: $!";

while (<$fh>) {
	chomp;
	my ($pkg, $desc) = split / /, $_, 2;
	my $archs = "amd64 i386";

	if (defined $desc and $desc =~ /^i386 ?(.*)/) {
		$archs = "i386";
		$desc = $1;
	}

	print "<dt>";
	if (not defined $desc or $desc eq "") {
		print "<font color=\"#e00000\">$pkg</font>\n";
		$desc = "Security fix";
	} else {
		print "$pkg\n";
	}

	print "<a href=\"ftp://ftp.openbsd.org/pub/OpenBSD/$release/packages/i386/$pkg\">i386</a>\n";
	if ($release >= 4.0 and $archs =~ /amd64/) {
		print "<a href=\"ftp://ftp.openbsd.org/pub/OpenBSD/$release/packages/amd64/$pkg\">amd64</a>\n";
	}
	print "<dd>$desc\n";
}

close($fh);
