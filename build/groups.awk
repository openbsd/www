#!/usr/bin/nawk -f

# Called from makefile to convert from groups.dat to ../groups.html

# convert data like this (order doesn't matter except 0 at front)
# 0
# C Erewhon
# P Ontario
# T Dictionopolis
# A R R # 1
# O OpenBSD User Group of Greater Erewhon
# I Ian F. Darwin
# F Every Monday at 25:00
# M ian@ougge.erewhon
# U http://www.ougge.erewhon/
# N OpenBSD

# into HTML to make nice neat tables.

/^#/ { next; }

$1 == "0" {
	if (country == "" && prov == "")
		next;
	dump();
	reset();
	next;
	}

$1 == "C" { country = substr($0, 3);
	if (country == "USA")
		country = "United States"
	if (country != oldCountry) {
		print "<tr><td bgcolor=\"#E0E0E0\" colspan=\"6\" align=\"center\">"
		if (country == "United States") {
			n = split("USA", labels, " ")
		} else {
			n = split(country, labels, " ")
		}
		print "<a name='" labels[1] "'></a>"
		print "<b>" country "</b></td></tr>"
	 }
	oldCountry = country
	next
}
$1 == "P" { prov = substr($0, 3); next }
$1 == "T" { city = substr($0, 3); next }
$1 == "A" { addr = substr($0, 3); next }
$1 == "O" { org = substr($0, 3); next }
$1 == "I" { indv = substr($0, 3); next }
$1 == "B" { phone = substr($0, 3); next }
$1 == "F" { freq = substr($0, 3); next }
$1 == "M" { email = substr($0, 3); next }
$1 == "U" { url = substr($0, 3); next }
$1 == "N" { note = substr($0, 3); next }

# left over - must be part of note?
	{
	note = note "\n" $0
	next
	}

function dump() {
	print "<tr>"
	print "<td bgcolor=\"White\">" 
		if (indv != "")
			print indv "<br />" 
		print "<b>" org "</b><br />" addr "</td>"
	print "	<td>" city "<br />" prov "</td>"
	print "	<td>" 
		if (phone != "")
			print phone "<br />" 
		print freq "</td>"
	print "	<td>"
		if (email != "")
			print "<a href=\"mailto:" email "\">" email "</a>" "<br />"
		print "<a href=\"" url "\">" url "</a>" "</td>"
	print "	<td>" note "</td>"
	print "</tr>"
}

function reset() {
	prov = ""
	city = ""
	addr = ""
	org = ""
	indv = ""
	email = ""
	phone = ""
	freq = ""
	url = ""
	note = ""
}

END {
	dump();		# don't forget the last guy!
}
