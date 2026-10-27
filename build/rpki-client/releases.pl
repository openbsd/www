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

my %releases = (
	'6.6p2' => '2020-04-19',
	'6.7p0' => '2020-05-18',
	'6.7p1' => '2020-07-27',
	'6.8p0' => '2020-10-20',
	'6.8p1' => '2020-11-12',
	'7.0' => '2021-04-15',
	'7.1' => '2021-05-18',
	'7.2' => '2021-09-21',
	'7.3' => '2021-09-22',
	'7.4' => '2021-10-30',
	'7.5' => '2021-11-09',
	'7.6' => '2022-02-07',
	'7.7' => '2022-04-07',
	'7.8' => '2022-04-09',
	'7.9' => '2022-07-13',
	'8.0' => '2022-09-11',
	'8.2' => '2022-12-13',
	'8.3' => '2023-03-19',
	'8.4' => '2023-05-02',
	'8.5' => '2023-07-28',
	'8.6' => '2023-10-04',
	'8.7' => '2023-12-20',
	'8.8' => '2023-12-29',
	'8.9' => '2024-02-12',
	'9.0' => '2024-03-02',
	'9.1' => '2024-06-19',
	'9.2' => '2024-08-21',
	'9.3' => '2024-09-19',
	'9.4' => '2025-01-07',
	'9.5' => '2025-04-08',
	'9.6' => '2025-09-20',
	'9.7' => '2026-01-13',
	'9.8' => '2026-04-14',
	'9.9' => '2026-08-22',
);

# For each rpki-client-*.txt file in txtdir, extract the release number
# and date (hardcoded or extracted from cvs history).
opendir(my $dh, $txtdir) || die $!;
while (readdir $dh) {
	my $file = $_;
	next unless (/rpki-client-(.*).txt/);
	my $rel = $1;
	my $date = "";
	if (!defined($releases{$rel})) {
		$_ = `cd $txtdir && cvs log -r1.1 $file | grep date:`;
		if (/date: (\S+)/) {
			$date = $1;
			$date =~ s|/|-|g;
		} else {
			die "failed to look up date for $file";
		}
		$releases{$rel} = $date;
	}
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
foreach my $rel (reverse sort numsort keys(%releases)) {
	print "<h3><a href='#$rel' id='$rel'>rpki-client $rel</a> ";
	print "($releases{$rel}) ";
	print "<a href='$dlurl/rpki-client-$rel.txt'>txt</a>, ";
	print "<a href='$dlurl/rpki-client-$rel.tar.gz'>tar.gz</a>";
	print "</h3>\n";
	print "<pre>\n";
	output_release($rel);
	print "</pre><hr>\n";
}
