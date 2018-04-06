#!/usr/bin/perl
#
# Build a web page containing all of the OpenSSH release notes in reverse
# chronological order for easy searching.
#
# Placed in the public domain.

use strict;
use warnings 'all';

my $txtdir = "../../openssh/txt/";
my $bzurl = "https://bugzilla.mindrot.org/show_bug.cgi?id=";

# These days we commit the release notes on the day of release.  For those,
# we use the date the release notes were first committed.
# Releases before that are listed in this hash which is checked before we
# check cvs.  If we know the exact release date then it's listed here, if
# not we list an empty string, which supresses the date from the output.
my %date_override = (
	'1.0pre2'	=> '1999-09-27',
	'1.2pre3'	=> '1999-09-27',
	'1.2pre4'	=> '1999-10-28',
	'1.2pre5'	=> '1999-10-28',
	'1.2pre6'	=> '1999-10-29',
	'1.2pre7'	=> '1999-10-30',
	'1.2pre8'	=> '1999-11-08',
	'1.2pre9'	=> '1999-11-09',
	'1.2pre10'	=> '1999-11-12',
	'1.2pre11'	=> '1999-11-12',
	'1.2pre12'	=> '1999-11-15',
	'1.2pre13'	=> '1999-11-19',
	'1.2pre14'	=> '1999-11-22',
	'1.2pre15'	=> '1999-11-25',
	'1.2pre16'	=> '1999-12-07',
	'1.2pre17'	=> '1999-12-09',
	'1.2.1pre18'	=> '1999-12-16',
	'1.2.1pre19'	=> '1999-12-21',
	'1.2.1pre20'	=> '1999-12-25',
	'1.2.1pre21'	=> '1999-12-26',
	'1.2.1pre22'	=> '1999-12-28',
	'1.2.1pre23'	=> '1999-12-30',
	'1.2.1pre24'	=> '1999-12-31',
	'1.2.1pre25'	=> '2000-01-07',
	'1.2.1pre26'	=> '2000-01-16',
	'1.2.1pre27'	=> '2000-01-17',
	'1.2.2p1'	=> '2000-03-05',
	'1.2.2'		=> '2000-01-26',
	'1.2.3p1'	=> '2000-03-24',
	'2.0.0beta1'	=> '2000-05-02',
	'2.0.0beta2'	=> '2000-05-08',
	'2.1.0p2'	=> '2000-05-20',
	'2.1.0p3'	=> '2000-05-30',
	'2.1.0p1'	=> '2000-05-09',
	'2.1.1p1'	=> '2000-06-09',
	'2.1.1p2'	=> '2000-07-01',
	'2.1.1p3'	=> '2000-07-12',
	'2.1.1p4'	=> '2000-07-16',
	'2.2.0p1'	=> '2000-09-01',
	'2.3.0p1'	=> '2000-11-06',
	'2.5.1p1'	=> '2001-02-19',
	'2.5.1p2'	=> '2001-03-20',
	'2.5.2p2'	=> '2001-03-22',
	'2.9'		=> '2001-04-29',
	'2.9.9'		=> '2001-09-25',
	'2.9p2'		=> '2001-06-17',
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
	'3.8.1'		=> '',
	'3.8.1p1'	=> '2004-04-19',
	'3.9'		=> '2004-08-18',
	'4.0'		=> '2005-03-09',
);

my %releases;

# Uncomment to cache release dates rather than looking up in CVS
# every time.  Handy to speed things up while making changes.
dbmopen(%releases, "/tmp/openssh-releases", 0644) || die;

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
		warn "overridden $rel $date\n";
	} elsif (defined($releases{$rel})) {
		$date = $releases{$rel};
		warn "cached $rel $date\n";
	} else {
		$_ = `cd $txtdir && cvs log -r1.1 $file | grep date:`;
		/date: (\S+)/;
		$date = $1;
		$date =~ s|/|-|g;
		warn "looked up $rel $date\n";
	}
	$releases{$rel} = $date;
}

sub output_release
{
	my ($rel, $date) = @_;
	my $fixdate = 0;
	my @notes;

	open(my $fh, '<', "$txtdir/release-$rel") || die;
	while (<$fh>) {
		if (/has just been released/) {
			$fixdate = 1;
			s|has just been released|was released on $date|;
			s|It will be available from|It is available from|;
		}
		push(@notes, $_);

		# expand bugzilla references into URLs.
		s|bz#(\d+)|<a href='$bzurl$1'>bz#$1</a>|g;
		s|bz #(\d+)|<a href='$bzurl$1'>bz #$1</a>|g;
		print $_;
	}
	close($fh);
	if ($fixdate) {
		warn "Fixing dates in release notes for $rel $date\n";
		open($fh, '>', "$txtdir/release-$rel") || die;
		print $fh join('', @notes) || die;
		close($fh);
	}
}

# Output the release notes in reverse revision order.
foreach my $rel (reverse sort keys(%releases)) {
	my $date = $releases{$rel};
	my $desc;
	my $extra = "";
	if ($rel =~ /p/) {
		# Portable only release
	} else {
		# Joint release
		my $port = $rel . "p1";
		$extra = "/<a href='txt/release-$rel' name='$port'>$port</a>";
	}
	print "<h3><a href='txt/release-$rel' name='$rel'>OpenSSH $rel</a>";
	print $extra;
	print " ($date)" if ($date ne ''); # suppress if unknown
	print "</h3>\n";
	print "<pre>\n";
	output_release($rel, $date);
	print "</pre><hr>\n";
}
