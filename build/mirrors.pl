#!/usr/bin/perl
# Placed in the public domain by
# Alexander von Gernler <grunk@openbsd.org> in 2005
#
# processes mirror data for www tree, ftplist and online mirror testing

use strict;
use warnings 'all';
use IO::Handle;		# for $fh->getlines()
my $RCS_ID = '$OpenBSD: mirrors.pl,v 1.3 2006/01/28 14:14:53 steven Exp $';

my $sources = {
	'mirrors.dat'	=> 'mirrors.dat',
	'ftp-head'	=> 'mirrors/ftp.html.head',
	'ftp-mid1'	=> 'mirrors/ftp.html.mid1',
	'ftp-mid2'	=> 'mirrors/ftp.html.mid2',
	'ftp-end'	=> 'mirrors/ftp.html.end',
};
my $targets = {
	'ftplist'	=> '../ftplist',
	'ftp.html'	=> '../ftp.html'
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
sub write_ftplist($$) {
	my ($filename, $mirrorref) = @_;

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
sub _paste_mirrorlist($$$$) {
	my ($fh, $mirrorref, $type, $links) = @_;

	print $fh ' ' x 4;		# indent for first <td> to come
	for my $lv (1, 2, 3) {
	foreach my $mirror (sort _by_country @$mirrorref) {
		next if (($lv <= 2) && (! defined $mirror->{'LF'}));
		next if ((defined $mirror->{'LF'}) && ($mirror->{'LF'} != $lv));
		next unless ($mirror->{$type});
		# first/second level mirrors have different title
		my $title;
		if ((defined $mirror->{'LF'}) && ($mirror->{'LF'} == 1)) {
			$title = "Master Fanout Site ($mirror->{'GC'})";
		} elsif ((defined $mirror->{'LF'}) && ($mirror->{'LF'} == 2)) {
			$title = "Second Level Mirror<br>";
			$title .= '(' if ($mirror->{'GT'} || $mirror->{'GS'}
			    || $mirror->{'GC'});
			$title .= $mirror->{'GT'} if $mirror->{'GT'};
			$title .= ", $mirror->{'GS'}" if $mirror->{'GS'};
			$title .= ", $mirror->{'GC'}" if $mirror->{'GC'};
			$title .= ')' if ($mirror->{'GT'} || $mirror->{'GS'}
			    || $mirror->{'GC'});
		} else {
			$title = "$mirror->{'GC'}";
			$title .= " ($mirror->{'GT'}" if ($mirror->{'GT'});
			$title .= ", $mirror->{'GS'}" if ($mirror->{'GS'});
			$title .= ')' if ($mirror->{'GT'});
		}
		print $fh "<tr>\n	<td>\n	<strong>$title</strong>\n";
		print $fh "	</td><td>\n";
		($links) && print $fh "	<a href=\"$mirror->{$type}\">\n";
		print $fh "	$mirror->{$type}";
		($links) && print $fh "</a>";
		print $fh "\n	</td>\n    </tr>";
	}
	}
	print $fh "\n";
}


# writes out the ftplist file to a given filename using the mirrors
# array referenced by the second argument
sub write_ftphtml($$) {
	my ($filename, $mirrorref) = @_;

	open(my $fh, '>', $filename) or die "open $filename: $!";
	_paste_in($fh, $sources->{'ftp-head'});
	# produce ftp mirror list
	_paste_mirrorlist($fh, $mirrorref, 'UF', 1);
	_paste_in($fh, $sources->{'ftp-mid1'});
	# produce http mirror list
	_paste_mirrorlist($fh, $mirrorref, 'UH', 1);
	_paste_in($fh, $sources->{'ftp-mid2'});
	# produce rsync mirror list
	_paste_mirrorlist($fh, $mirrorref, 'UR', 0);
	_paste_in($fh, $sources->{'ftp-end'});
	close($fh) or die "close $filename: $!";
}


# helper function to sort entries by country
sub _by_country {
	$a->{'GC'} cmp $b->{'GC'}
}

# main()
my @mirrors = read_mirrors($sources->{'mirrors.dat'});

# XXX write_ftplist() works, but HTML entities have to be converted in
# output, and grunk has to find a proper way of getting ftplist into the
# FTP distribution.
#write_ftplist($targets->{'ftplist'}, \@mirrors);

write_ftphtml($targets->{'ftp.html'}, \@mirrors);
