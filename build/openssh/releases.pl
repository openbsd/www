#!/usr/bin/perl
#
# Build a web page containing all of the OpenSSH release notes in reverse
# chronological order for easy searching.
#
# Placed in the public domain.

use strict;
use warnings 'all';

my $txtdir = "../../openssh/txt/";

# These days we commit the release notes on the day of release.  For those,
# we use the date the release notes were first committed.
# Releases before that are listed in this hash which is checked before we
# check cvs.  If we know the exact release date then it's listed here, if
# not we list an empty string, which supresses the date from the output.
my %date_override = (
	'1.2.2p1'	=> '',
	'1.2.3p1'	=> '',
	'2.1.0p1'	=> '',
	'2.1.1p1'	=> '',
	'2.1.1p2'	=> '',
	'2.1.1p3'	=> '',
	'2.1.1p4'	=> '',
	'2.2.0p1'	=> '',
	'2.3.0p1'	=> '',
	'2.5.1p1'	=> '',
	'2.5.1p2'	=> '',
	'2.5.2p2'	=> '',
	'2.9'		=> '',
	'2.9.9'		=> '',
	'2.9p2'		=> '',
	'3.0'		=> '2001-11-06',
	'3.0.1'		=> '2001-11-19',
	'3.0.2'		=> '2002-12-04',
	'3.2.2'		=> '2002-05-16',
	'3.2.3'		=> '2002-05-23',
	'3.3'		=> '2002-06-21',
	'3.4'		=> '2002-06-26',
	'3.5'		=> '2002-10-15',
	'3.6'		=> '2003-03-31',
	'3.6.1'		=> '2003-04-01',
	'3.6.1p2'	=> '2003-04-30',
	'3.7'		=> '2003-09-16',
	'3.7.1"'	=> '2003-09-16',
	'3.7.1p2'	=> '2003-09-23',
	'3.8'		=> '2004-02-24',
	'3.8.1p1'	=> '2004-04-19',
	'3.9'		=> '2004-08-18',
	'4.0'		=> '2005-03-09',
);

my %releases;

# For each release-* file in the txtdir directory, extract the release
# number and figure out the release date, either by looking in the map above
# or by extracting the date of rev 1.1 from cvs.
opendir(my $dh, $txtdir) || die $!;
while (readdir $dh) {
	my $file =$_;
	next unless (/release-(.*)/);
	my $rel = $1;
	my $date = "";
	if (defined($date_override{$rel})) {
		$date = $date_override{$rel};
	} else {
		$_ = `cd $txtdir && cvs log -r1.1 $file | grep date:`;
		/date: (\S+)/;
		$date = $1;
		$date =~ s|/|-|g;
	}
	warn "processing $rel $date\n";
	$releases{$rel} = $date;
}

# Output the release notes in reverse revision order.
foreach my $rel (reverse sort keys(%releases)) {
	my $date = $releases{$rel};
	my $desc;
	if ($rel =~ /p/) {
		# Portable only release
		$desc = "OpenSSH $rel";
	} else {
		# Joint release
		$desc = "OpenSSH $rel/$rel-p1";
	}
	print "<h3><a href='txt/release-$rel'>$desc</a>";
	print " ($date)" if ($date ne ''); # suppress if unknown
	print "</h3>\n";
	print "<pre>\n";
	system("cat $txtdir/release-$rel");
	print "</pre><hr>\n";
}
