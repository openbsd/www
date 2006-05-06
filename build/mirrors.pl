#!/usr/bin/perl
# Placed in the public domain by
# Alexander von Gernler <grunk@openbsd.org> in 2005
#
# processes mirror data for www tree, ftplist and online mirror testing

use strict;
use warnings 'all';
use IO::Handle;		# for $fh->getlines()
my $RCS_ID = '$OpenBSD: mirrors.pl,v 1.7 2006/05/06 06:02:59 steven Exp $';

# note: some files are being reused because they would be identical
my $sources = {
	'mirrors.dat'	=> 'mirrors.dat',
	'openbsd-ftp-head'	=> 'mirrors/ftp.html.head',
	'openbsd-ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'openbsd-ftp-mid2'	=> 'mirrors/ftp.html.mid2',
	'openbsd-ftp-end'	=> 'mirrors/ftp.html.end',
	'openbgpd-ftp-head'	=> 'mirrors/openbgpd-ftp.html.head',
	'openbgpd-ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'openbgpd-ftp-mid2'	=> 'mirrors/openntpd-ftp.html.mid2',
	'openbgpd-ftp-end'	=> 'mirrors/openbgpd-ftp.html.end',
	'openntpd-ftp-head'	=> 'mirrors/openntpd-ftp.html.head',
	'openntpd-ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'openntpd-ftp-mid2'	=> 'mirrors/openntpd-ftp.html.mid2',
	'openntpd-ftp-end'	=> 'mirrors/openntpd-ftp.html.end',
	'openntpd-portable-head'=> 'mirrors/openntpd-portable.html.head',
	'openntpd-portable-mid1'=> 'mirrors/ftp.html.mid1',
	'openntpd-portable-mid2'=> 'mirrors/openntpd-ftp.html.mid2',
	'openntpd-portable-end'	=> 'mirrors/openntpd-ftp.html.end',
	'anoncvs-head'		=> 'mirrors/anoncvs.html.head',
	'anoncvs-end'		=> 'mirrors/anoncvs.html.end'
};
my $targets = {
	'ftplist'		=> '../ftplist',
	'openbsd-ftp'		=> '../ftp.html',
	'openbgpd-ftp'		=> '../openbgpd/ftp.html',
	'openntpd-ftp'		=> '../openntpd/ftp.html',
	'openntpd-portable'	=> '../openntpd/portable.html',
	'anoncvs'		=> '../anoncvs.html'
};

# read in mirror list from given file into an array of hash references.
# each hash represents one mirror and contains key/value pairs for given mirror
sub read_mirrors ($) {
	my $filename = shift;

	open(my $fh, '<', $filename) or die "open $filename: $!";
	my @mirrors;
	my $record = {};
	my $lineno = 0;
	while (my $line = <$fh>) {
		$lineno++;
		next if $line =~ /^#/;		# skip comments
		next if $line =~ /^\s*$/;	# skip empty lines
		if ($line =~ /^0$/) {		# delimiter -- start new record
			# XXX more validity checks on contents of mirror record
			# before pushing, else die
			push(@mirrors, $record) if (int(keys(%$record)));
			$record = {};		# new empty one
		} elsif ($line =~ /^([A-Z]{2})\s+(.*)/) {
			($record->{$1})
				and die "dupe $1 in $filename:$lineno";
			$record->{$1} = $2;	# add key/value pair
		} else {
			die "parse error $filename:$lineno: $line";
		}
	}
	close($fh) or die "close $filename: $!";

	# don't forget the last record
	push(@mirrors, $record) if (int(keys(%$record)));
	return @mirrors;
}


# writes out the ftplist file to a given filename using the mirrors
# array referenced by the second argument
sub write_ftplist($$$) {
	my ($filename, $ver, $mirrorref) = @_;

	open(my $fh, '>', $filename) or die "open $filename: $!";

	for my $lv (1, 2, 3) {
	for my $type ('UF', 'UH') {
		foreach my $mirror (sort _by_country @$mirrorref) {
			next if (($lv <= 2) &&
			    (! defined $mirror->{'LF'}));
			next if ((defined $mirror->{'LF'})
			    && ($mirror->{'LF'} != $lv));
			next unless ($mirror->{$type});
			my $loc = '';
			$loc .= "$mirror->{'GT'}, " if $mirror->{'GT'};
			$loc .= "$mirror->{'GS'}, " if $mirror->{'GS'};
			$loc .= "$mirror->{'GC'}" if $mirror->{'GC'};
			(my $url = $mirror->{$type}) =~ s,/$,,;
			if ((length($url) + length($loc) < 78)
					&& (length($loc) > 25)) {
				my $lr = 78 - length($url);
				printf $fh "%s %" . $lr . "s\n", $url, $loc;
			} else {
				printf $fh "%-54s %s\n", $url, $loc;
			}
		}
	}
	}

	close($fh) or die "close $filename: $!";
}


# helper function for just slurping template files into an open
# filedescriptor
sub _paste_in($$) {
	my ($fh, $filename) = @_;

	open(my $rfh, '<', $filename) or die "open $filename: $!";
	print $fh $rfh->getlines();
	close($rfh) or die "close $filename: $!";
}


# writes out the FTP/HTTP mirrorlist to a given filehandle
sub _paste_mirrorlist($$$$$$) {
	my ($fh, $mirrorref, $type, $proj, $version, $links) = @_;

	print $fh ' ' x 4;		# indent for first <td> to come
	for my $lv (1, 2, 3) {
	foreach my $mirror (sort _by_country @$mirrorref) {
		if ($type eq 'UF' || $type eq 'UH' || $type eq 'UR') {
			next if (($lv <= 2) && !defined $mirror->{'LF'});
			next if ((defined $mirror->{'LF'}) && ($mirror->{'LF'} != $lv));
		}
		elsif ($type eq 'AH') {
			next if (($lv <= 2) && !defined $mirror->{'LC'});
			next if ((defined $mirror->{'LC'}) && ($mirror->{'LC'} != $lv));
		}
		next unless ($mirror->{$type});
		my $loc = _get_location ($type, $mirror);
		if ($type eq 'UF' || $type eq 'UH' || $type eq 'UR') {
			my $url = $mirror->{$type};
			if ($proj eq 'openbgpd-ftp') {
				$url .= "OpenBGPD/openbgpd-${version}.tgz";
			}
			elsif ($proj eq 'openntpd-ftp') {
				$url .= "OpenNTPD/openntpd-${version}.tgz";
			}
			elsif ($proj eq 'openntpd-portable') {
				$url .= "OpenNTPD/openntpd-${version}.tar.gz";
			}
			print $fh "<tr>\n\t<td>\n\t<strong>$loc</strong>\n";
			print $fh "\t</td><td>\n";
			($links) && print $fh "	<a href=\"$url\">\n";
			print $fh "\t$url";
			($links) && print $fh "</a>";
			print $fh "\n\t</td>\n    </tr>";
		}
		elsif ($type eq 'AH') {
			if ($mirror->{'AH'} && $mirror->{'AU'} && $mirror->{'AR'}) {
				print $fh "<li><strong>CVSROOT=",
					$mirror->{'AU'}, '@',
					$mirror->{'AH'}, ':',
					$mirror->{'AR'}, "</strong><br>\n";
			} else {
				die "Unable to determine CVSROOT for $mirror->{AH}.\nCheck for missing fields.\n";
			}
			if ($mirror->{'HA'}) {
				print $fh "Host also known as <strong>",
				join(", ", split(/\s+/, $mirror->{'HA'})),
				"</strong>.<br>\n";
			}
			print $fh "Location: $loc.<br>\n";
			print $fh "Maintained by <a href=\"mailto:",
					$mirror->{'ME'}, "\">",
					$mirror->{'MN'}, "</a>.<br>\n"
				if ($mirror->{'ME'} && $mirror->{'MN'});
			print $fh "Protocols: $mirror->{'AP'}.<br>\n"
				if ($mirror->{'AP'});
			if ($mirror->{'CE'}) {
				print $fh "Updated every $mirror->{'CE'} hours";
				print $fh " from $mirror->{'CF'}"
					if ($mirror->{'CF'});
				print $fh ".<br>\n";
			}
			print $fh "SSH fingerprints:<br>\n"
				if ($mirror->{'SD'} || $mirror->{'SR'} ||
					$mirror->{'SO'});
			print $fh "(RSA1) $mirror->{'SO'}<br>\n"
				if ($mirror->{'SO'});
			print $fh "(RSA) $mirror->{'SR'}<br>\n"
				if ($mirror->{'SR'});
			print $fh "(DSA) $mirror->{'SD'}<br>\n"
				if ($mirror->{'SD'});
			print $fh "<p>\n";
		}
	}
	}
	print $fh "\n";
}


# writes out the ftplist file to a given filename using the mirrors
# array referenced by the second argument
sub write_ftphtml($$$$) {
	my ($what, $filename, $ver, $mirrorref) = @_;

	open(my $fh, '>', $filename) or die "open $filename: $!";
	_paste_in($fh, $sources->{"${what}-head"});
	# produce ftp mirror list
	_paste_mirrorlist($fh, $mirrorref, 'UF', $what, $ver, 1);
	_paste_in($fh, $sources->{"${what}-mid1"});
	# produce http mirror list
	_paste_mirrorlist($fh, $mirrorref, 'UH', $what, $ver, 1);
	_paste_in($fh, $sources->{"${what}-mid2"});
	# produce rsync mirror list
	_paste_mirrorlist($fh, $mirrorref, 'UR', $what, $ver, 0);
	_paste_in($fh, $sources->{"${what}-end"});
	close($fh) or die "close $filename: $!";
}

sub write_anoncvshtml($$$) {
	my ($filename, $ver, $mirrorref) = @_;

	open(my $fh, '>', $filename) or die "open $filename: $!";
	_paste_in($fh, $sources->{'anoncvs-head'});
	# produce cvsync mirror list
	_paste_mirrorlist($fh, $mirrorref, 'AH', 'openbsd', $ver, 1);
	_paste_in($fh, $sources->{'anoncvs-end'});
	close($fh) or die "close $filename: $!";
}


# helper function to sort entries by country
sub _by_country {
	my ($x, $y) = ($a->{'GC'}, $b->{'GC'});
	$x =~ s/^the\s+//i;	# ignore leading 'the' as in 'The Netherlands'
	$y =~ s/^the\s+//i;
	return lc($x) cmp lc($y);
}

# helper function to make a location string
sub _get_location($$) {
	my $type = shift;
	my $m = shift;

	my $location = "";
	if ($type eq 'UF' || $type eq 'UH' || $type eq 'UR') {
		# first/second level mirrors have different title
		if ((defined $m->{'LF'}) && ($m->{'LF'} == 1)) {
			$location = "Master Fanout Site ($m->{'GC'})";
		} elsif ((defined $m->{'LF'}) && ($m->{'LF'} == 2)) {
			$location = "Second Level Mirror<br>";
			$location .= '(' if ($m->{'GT'} || $m->{'GS'} ||
				$m->{'GC'});
			$location .= $m->{'GT'} if $m->{'GT'};
			$location .= ", $m->{'GS'}" if $m->{'GS'};
			$location .= ", $m->{'GC'}" if $m->{'GC'};
			$location .= ')' if ($m->{'GT'} || $m->{'GS'} ||
				$m->{'GC'});
		} else {
			$location = "$m->{'GC'}";
			$location .= " ($m->{'GT'}" if ($m->{'GT'});
			$location .= ", $m->{'GS'}" if ($m->{'GS'});
			$location .= ')' if ($m->{'GT'});
		}
	}
	elsif ($type eq 'AH') {
		$location .= "$m->{'GI'}, " if ($m->{'GI'});
		$location .= "$m->{'GT'}, " if ($m->{'GT'});
		$location .= "$m->{'GS'}, " if ($m->{'GS'});
		$location .= "$m->{'GC'}" if ($m->{'GC'});
	}

	return $location;
}

# main()
my @mirrors = read_mirrors($sources->{'mirrors.dat'});

# XXX write_ftplist() works, but HTML entities have to be converted in
# output, and grunk has to find a proper way of getting ftplist into the
# FTP distribution.

if (@ARGV == 2) {
	my $cmd = $ARGV[0];
	my $ver = $ARGV[1];

	if ($cmd eq 'ftplist') {
		write_ftplist($targets->{'ftplist'}, $ver, \@mirrors);
	} elsif ($cmd eq 'openbsd-ftp' || $cmd eq 'openbgpd-ftp' ||
		 $cmd eq 'openntpd-ftp' || $cmd eq 'openntpd-portable') {
		write_ftphtml($cmd, $targets->{"$cmd"}, $ver, \@mirrors);
	} elsif ($cmd eq 'anoncvs') {
		write_anoncvshtml($targets->{'anoncvs'}, $ver, \@mirrors);
	} else {
		die "Unknown mirror target.\n"
	}
} else {
	die "Wrong number of arguments.\n"
}
