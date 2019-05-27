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
		print "<tbody><tr><th colspan=\"5\""
		if (country == "United States") {
			n = split("USA", labels, " ")
		} else {
			n = split(country, labels, " ")
		}
		print "id='" labels[1] "'>"
		print country
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
	print "<td>" 
		if (indv != "")
			print indv "<br>" 
		print "<b>" org "</b><br>" addr
	print "	<td>" city "<br>" prov
	print "	<td>" 
		if (phone != "")
			print phone "<br>" 
		print freq
	print "	<td>"
		if (email != "")
			print "<a href=\"mailto:" email "\">" email "</a>" "<br>"
		print "<a href=\"" url "\">" url "</a>"
	print "	<td>" note
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
