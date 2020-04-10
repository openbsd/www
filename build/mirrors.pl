#!/usr/bin/perl
# Placed in the public domain by
# Alexander von Gernler <grunk@openbsd.org> in 2005
#
# processes mirror data for www tree, ftplist and online mirror testing

use strict;
use warnings 'all';
use IO::Handle;		# for $fh->getlines()
my $RCS_ID = '$OpenBSD: mirrors.pl,v 1.51 2020/04/10 21:45:17 deraadt Exp $';

my %format;
$format{'alias'}	= 'Host also known as <strong>%s</strong>.';
$format{'location'}	= 'Location: %s.';
$format{'maintainer'}	= 'Maintained by <a href="mailto:%s">%s</a>.';
$format{'proto'}	= 'Protocols: %s.';
$format{'updated'}	= 'Updated every %s hours.';
$format{'updated_from'}	= 'Updated every %s hours from %s.';
$format{'fingerprints'}	= 'SSH fingerprints:';
$format{'cvsroot'}	= '<strong>CVSROOT=%s@%s:%s</strong>';

# note: some files are being reused because they would be identical
my $sources = {
	'mirrors.dat'	=> 'mirrors.dat',

	'openbsd-ftp-head'	=> 'mirrors/ftp.html.head',
	'openbsd-ftp-mid0'	=> 'mirrors/ftp.html.mid0',
	'openbsd-ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'openbsd-ftp-mid2'	=> 'mirrors/ftp.html.mid2',
	'openbsd-ftp-end'	=> 'mirrors/ftp.html.end',

	'openbgpd-ftp-head'	=> 'mirrors/openbgpd-ftp.html.head',
	'openbgpd-ftp-mid0'	=> 'mirrors/ftp.html.mid0',
	'openbgpd-ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'openbgpd-ftp-mid2'	=> 'mirrors/ftp.html.mid2',
	'openbgpd-ftp-end'	=> 'mirrors/openbgpd-ftp.html.end',

	'openntpd-portable-head'=> 'mirrors/openntpd-portable.html.head',
	'openntpd-portable-mid0'=> 'mirrors/ftp.html.mid0',
	'openntpd-portable-mid1'=> 'mirrors/ftp.html.mid1',
	'openntpd-portable-mid2'=> 'mirrors/ftp.html.mid2',
	'openntpd-portable-end'	=> 'mirrors/openntpd-portable.html.end',

	'rpki-client-portable-head'=> 'mirrors/rpki-client-portable.html.head',
	'rpki-client-portable-mid0'=> 'mirrors/ftp.html.mid0',
	'rpki-client-portable-mid1'=> 'mirrors/ftp.html.mid1',
	'rpki-client-portable-mid2'=> 'mirrors/ftp.html.mid2',
	'rpki-client-portable-end'	=> 'mirrors/rpki-client-portable.html.end',

	'openssh-ftp-head'	=> 'mirrors/openssh-ftp.html.head',
	'openssh-ftp-mid0'	=> 'mirrors/ftp.html.mid0',
	'openssh-ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'openssh-ftp-mid2'	=> 'mirrors/ftp.html.mid2',
	'openssh-ftp-end'	=> 'mirrors/openssh-ftp.html.end',
	'openssh-portable-head' => 'mirrors/openssh-portable.html.head',
	'openssh-portable-mid0' => 'mirrors/ftp.html.mid0',
	'openssh-portable-mid1' => 'mirrors/openssh-portable.html.mid1',
	'openssh-portable-mid2' => 'mirrors/ftp.html.mid2',
	'openssh-portable-end'	=> 'mirrors/openssh-ftp.html.end',

	'anoncvs-head'		=> 'mirrors/anoncvs.html.head',
	'anoncvs-end'		=> 'mirrors/anoncvs.html.end',
};
my $srcdir = $ENV{BSDSRCDIR};
$srcdir //= '/usr/src';
my $targets = {
	'ftplist'		=> '../ftplist',
	'httpslist'		=> '../httpslist',
	'mirror_list'		=> '../mirror_list',
	'openbsd-ftp'		=> '../ftp.html',
	'openbgpd-ftp'		=> '../openbgpd/ftp.html',
	'openntpd-portable'	=> '../openntpd/portable.html',
	'rpki-client-portable'	=> '../rpki-client/portable.html',
	'openssh-ftp'		=> '../openssh/ftp.html',
	'openssh-portable'	=> '../openssh/portable.html',
	'anoncvs'		=> '../anoncvs.html',
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
		} elsif ($line =~ /^(S[DER2])\s+(.*)/) {
			if ($record->{$1}) {
				$record->{$1} .= ", <code>".$2."</code>";	# append key/value pair
			} else {
				$record->{$1} = "<code>".$2."</code>";	# add key/value pair
			}
		} elsif ($line =~ /^([A-Z0-9]{2,3})\s+(.*)/) {
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
sub write_ftplist($$$$) {
	my ($filename, $ver, $mirrorref, $type) = @_;

	# ftplist is displayed in the installer (with the protocol stripped
	# off) with cat -n, so 71 char max after removing the protocol.
	my $MAXWIDTH = 71 + length("ftp://");

	open(my $fh, '>', $filename) or die "open $filename: $!";

	foreach my $mirror (sort _by_country @$mirrorref) {
		next unless ($mirror->{$type});
		my $loc = '';
		if ($mirror->{'GC'} eq 'Anycast') {
			$loc .= "$mirror->{'GI'} (CDN)";
		} else {
			$loc .= "$mirror->{'GT'}, " if $mirror->{'GT'};
			$loc .= "$mirror->{'GS'}, " if $mirror->{'GS'};
			$loc .= "$mirror->{'GC'}";
		}
		$loc =~ s/&auml;/a/g ;
		$loc =~ s/&ouml;/o/g ;
		$loc =~ s/&uuml;/u/g ;
		$loc =~ s/&eacute;/e/g ;
		$loc =~ s/&ntilde;/n/g ;
		(my $url = $mirror->{$type}) =~ s,/$,,;
		my $pad = $MAXWIDTH - length($url) - 1;
		# + 4 for aesthetics; force some whitespace
		if (length($url) + length($loc) + 4 > $MAXWIDTH) {
			die "Entry for $url too long";
		}
		printf $fh "%s %" . $pad . "s\n", $url, $loc;
	}

	close($fh) or die "close $filename: $!";
}


# writes out the ftplist in mirmon format
sub write_mirror_list($$) {
	my ($filename, $mirrorref) = @_;

	open(my $fh, '>', $filename) or die "open $filename: $!";

	foreach my $mirror (sort _by_country @$mirrorref) {
		my ($url, $loc, $chosen);
		for my $type ('UF', 'UR', 'UH', 'UHS') {
			next unless ($mirror->{$type});
			$chosen = $type;
			($url = $mirror->{$type}) =~ s,/$,,;
			if (($type eq 'UH'  && not $url =~ m,^http://,) ||
			    ($type eq 'UHS' && not $url =~ m,^https://,) ||
			    ($type eq 'UF'  && not $url =~ m,^ftp://,) ||
			    ($type eq 'UR'  && not $url =~ m,^rsync://,)) {
				warn('bad URL format for '.$type.': '.$url);
			}
		}
		next unless defined $chosen;
		if (defined $mirror->{'GZ'}) {
			if ((defined $mirror->{'LF'})
			    && ($mirror->{'LF'} == 2)) {
				$loc = 'L2';
			} else {
				$loc = "$mirror->{'GZ'}";
			}
		} else {
			warn('no GZ for '.$mirror->{$chosen});
		}
		printf $fh "%s %s\n", $loc, $mirror->{$chosen};
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

	# indent for first <td> to come
	print $fh ' ' x 4 if ($type eq 'UH' || $type eq 'UF' || $type eq 'UR');
	foreach my $mirror (sort _by_country @$mirrorref) {
		next unless ($mirror->{$type});

		# if this mirror already has https, don't bother listing http
		next if ($type eq 'UH' && defined $mirror->{'UHS'});

		my $loc = _get_location ($type, $mirror);
		if ($type =~ m/^(UH|UHS|UF|UR)$/) {
			my $url = $mirror->{$type};
			if ($proj eq 'openbgpd-ftp') {
				$url .= "OpenBGPD/openbgpd-${version}.tar.gz";
			}
			elsif ($proj eq 'openssh-ftp') {
				#next if ($type eq 'UR');
				$url .= "OpenSSH/openssh-${version}.tar.gz";
			}
			elsif ($proj eq 'openssh-portable') {
				#next if ($type eq 'UR');
				$url .= "OpenSSH/portable/";
			}
			elsif ($proj eq 'openntpd-portable') {
				$url .= "OpenNTPD/openntpd-${version}.tar.gz";
			}
			elsif ($proj eq 'rpki-client-portable') {
				$url .= "rpki-client/rpki-client-${version}.tar.gz";
			}
			print $fh "<tr>\n\t<td>\n\t<strong>$loc</strong>\n";
			print $fh "\t</td><td>\n";
			($links) && print $fh "	<a href=\"$url\" rel=\"nofollow\">\n";
			print $fh "\t$url";
			($links) && print $fh "</a>";
			print $fh "\n\t</td>\n    </tr>";
		}
		elsif ($type eq 'AH') {
			if ($mirror->{'AH'} && $mirror->{'AU'} && $mirror->{'AR'}) {
				printf $fh "<li>".$format{'cvsroot'}."<br>\n",
					$mirror->{'AU'}, $mirror->{'AH'},
					$mirror->{'AR'};
			} else {
				die "Unable to determine CVSROOT for $mirror->{AH}.\nCheck for missing fields.\n";
			}
			printf $fh "<strong>reposync %s</strong><br>\n", $mirror->{'CR'} if ($mirror->{'CR'});
			if ($mirror->{'HA'}) {
				my $alias = $mirror->{'HA'};
				$alias =~ s/$mirror->{'AH'}\s*//;
				if ($alias ne '') {
					printf $fh $format{'alias'}."<br>\n",
					    join(", ", split(/\s+/, $alias));
				}
			}
			printf $fh $format{'location'}."<br>\n", $loc;
			printf $fh $format{'maintainer'}."<br>\n",
					$mirror->{'ME'}, $mirror->{'MN'}
				if ($mirror->{'ME'} && $mirror->{'MN'});
			printf $fh $format{'proto'}."<br>\n", $mirror->{'AP'}
				if ($mirror->{'AP'});
			if ($mirror->{'CE'}) {
				my $f;
				$mirror->{'LC'} //= '';
				if ($mirror->{'LC'} eq 2) {
					$f = sprintf $format{'updated_from'},
					$mirror->{'CE'}, "main server";
				} elsif ($mirror->{'CF'}) {
					$f = sprintf $format{'updated_from'},
					$mirror->{'CE'}, $mirror->{'CF'};
				} else {
					$f = sprintf $format{'updated'},
					$mirror->{'CE'};
				}
				$f =~ s/every 1 hours/hourly/;
				print $fh $f."<br>\n";
			}
			printf $fh $format{'fingerprints'}."<br>\n"
				if ($mirror->{'SR'} || $mirror->{'SE'} ||
					$mirror->{'S2'});
			print $fh "(RSA) $mirror->{'SR'}<br>\n"
				if ($mirror->{'SR'});
			print $fh "(ECDSA) $mirror->{'SE'}<br>\n"
				if ($mirror->{'SE'});
			print $fh "(ED25519) $mirror->{'S2'}<br>\n"
				if ($mirror->{'S2'});
			print $fh "<p>\n";
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
	_paste_mirrorlist($fh, $mirrorref, 'UHS', $what, $ver, 1);
	_paste_in($fh, $sources->{"${what}-mid0"});
	_paste_mirrorlist($fh, $mirrorref, 'UH', $what, $ver, 1);
	_paste_in($fh, $sources->{"${what}-mid1"});
	_paste_mirrorlist($fh, $mirrorref, 'UF', $what, $ver, 1);
	_paste_in($fh, $sources->{"${what}-mid2"});
	_paste_mirrorlist($fh, $mirrorref, 'UR', $what, $ver, 0);
	_paste_in($fh, $sources->{"${what}-end"});
	close($fh) or die "close $filename: $!";
}

sub write_cvshtml($$$$) {
	my ($what, $filename, $ver, $mirrorref) = @_;
	my $code;

	if ($what eq 'anoncvs') {
		$code = 'AH';
	} else {
		die "illegal command: $what\n";
	}

	open(my $fh, '>', $filename) or die "open $filename: $!";
	_paste_in($fh, $sources->{"${what}-head"});
	# produce anoncvs mirror list
	_paste_mirrorlist($fh, $mirrorref, $code, 'openbsd', $ver, 1);
	_paste_in($fh, $sources->{"${what}-end"});
	close($fh) or die "close $filename: $!";
}


# helper function to sort entries by country
sub _by_country {
	my ($x, $y) = ($a->{GC}, $b->{GC});
	$x =~ s/^the\s+//i;	# ignore leading 'the' as in 'The Netherlands'
	$y =~ s/^the\s+//i;
	if (($x eq $y) and $a->{GS} and $b->{GS}) {
		return lc($a->{GS}) cmp lc($b->{GS})
	}
	return lc($x) cmp lc($y);
}

# helper function to make a location string
sub _get_location($$) {
	my $type = shift;
	my $m = shift;

	my $location = "";
	if ($type =~ m/^(UH|UHS|UF|UR)$/) {
		if ($m->{'GC'} eq 'Anycast') {
			$location = "$m->{'GI'} (CDN)";
		} else {
			$location = "$m->{'GC'}";
			$location .= " ($m->{'GT'}" if ($m->{'GT'});
			$location .= ", $m->{'GS'}" if ($m->{'GS'});
			$location .= ')' if ($m->{'GT'});
		}
	}
	else {
		if ($type eq 'AH') {
			$location .= "$m->{'GI'}, " if ($m->{'GI'});
		}
		if ($type eq 'AH' || $type =~ /^mirlist/) {
			$location .= "$m->{'GT'}, " if ($m->{'GT'});
			$location .= "$m->{'GS'}, " if ($m->{'GS'});
		}
		if ($type eq 'AH' || $type eq 'mirlist1') {
			$location .= "$m->{'GC'}" if ($m->{'GC'});
		}
		$location =~ s/, , /, /g;
		$location =~ s/, $//g;
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
		write_ftplist($targets->{'ftplist'}, $ver, \@mirrors, 'UH');
		write_ftplist($targets->{'httpslist'}, $ver, \@mirrors, 'UHS');
		write_mirror_list($targets->{'mirror_list'}, \@mirrors);
	} elsif ($cmd eq 'openbsd-ftp' || $cmd eq 'openbgpd-ftp' ||
		 $cmd eq 'openntpd-portable' ||
		 $cmd eq 'rpki-client-portable' ||
		 $cmd eq 'openssh-ftp' || $cmd eq 'openssh-portable') {
		write_ftphtml($cmd, $targets->{"$cmd"}, $ver, \@mirrors);
	} elsif ($cmd eq 'anoncvs') {
		write_cvshtml($cmd, $targets->{"$cmd"}, $ver, \@mirrors);
	} else {
		die "Unknown mirror target.\n"
	}
} else {
	die "Wrong number of arguments.\n"
}
