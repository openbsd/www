#!/usr/bin/perl
#
# Build a web page containing all of the rpki-client release notes in reverse
# order for easy searching.
#
# Placed in the public domain.

use strict;
use warnings 'all';

my $txtdir = "../../rpki-client/txt/";
my $dlurl = "https://cdn.openbsd.org/pub/OpenBSD/rpki-client";
my $rfcurl = "https://datatracker.ietf.org/html/rfc";
my $drafturl = "https://datatracker.ietf.org/doc/html";

my @releases;

# For each rpki-client-*.txt file in txtdir, extract the release number
opendir(my $dh, $txtdir) || die $!;
while (readdir $dh) {
	next unless (/rpki-client-(.*).txt/);
	push(@releases, $1);
}

sub output_release
{
	my $rel = shift(@_);
	my $file = "$txtdir/rpki-client-$rel.txt";

	open(my $fh, '<', $file) || die "can't open '$file': $!";
	while (<$fh>) {
		# escape <> before any URLs are inserted
		s|<|&lt;|g;
		s|>|&gt;|g;

		# expand any URLs into actual links
		if (m|https?://\S+[\.\(\)]+\s|) {  # trailing non-link tokens
			s|(https?://\S+)([\.\(\)]+)\s|<a href='$1'>$1</a>$2|g;
		} elsif (m|https?://\S+|) { # all other URLs
			s|(https?://\S+)|<a href='$1'>$1</a>|g;
		} elsif (m|draft-\S+\.|) {
			s|(draft-\S+)\.$|<a href='$drafturl/$1'>$1</a>.|g;
		} elsif (m|draft-\S+|) {
			s|(draft-\S+)|<a href='$drafturl/$1'>$1</a>|g;
		}

		# expand RFC references into links.
		s|RFC(\d{4})|<a href='$rfcurl$1'>RFC$1</a>|g;
		s|RFC (\d{4})|<a href='$rfcurl$1'>RFC $1</a>|g;

		# download links.
		s|(rpki-client-[\d\.]+.tar.gz)|<a href='$dlurl/$1'>$1</a>|g;

		# email links.
		s|(security\@rpki-client.org)|<a href='mailto:$1'>$1</a>|g;

		print $_;
	}
	close($fh);
}

sub numsort {
	($a =~ /^(\d+)/)[0] <=> ($b =~ /^(\d+)/)[0] || $a cmp $b
}

# Output the release notes in reverse revision order.
foreach my $rel (reverse sort numsort @releases) {
	print "<h3><a href='#$rel' id='$rel'>rpki-client $rel</a> ";
	print "(<a href='$dlurl/rpki-client-$rel.txt'>txt</a>, ";
	print "<a href='$dlurl/rpki-client-$rel.tar.gz'>tar.gz</a>)";
	print "</h3>\n";
	print "<pre>\n";
	output_release($rel);
	print "</pre><hr>\n";
}
