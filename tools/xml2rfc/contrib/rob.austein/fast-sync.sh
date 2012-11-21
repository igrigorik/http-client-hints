#!/bin/sh -
# Fast synchronization of xml2rfc bibliographic database.
#
# Rob Austein <sra@hactrn.net>
#
# This is the approved "easy" way:
#
#wget -q -P rfc   -r -l 1 -A .xml -nd -N
http://xml.resource.org/public/rfc/bibxml/
#wget -q -P draft -r -l 1 -A .xml -nd -N
http://xml.resource.org/public/rfc/bibxml3/
#
# ...but it's incredibly painful to watch, because it spends an insane
# amount of time and bandwidth sucking down stuff which it then
# immediately discards.  So here's a script that tries to be a little
# smarter about what it does.  The implementation below is icky, one
# could no doubt do better with some relatively trivial Perl code, but
# this will do as a proof of concept.
#
# The idea here is to suck down just the basic HTML index, extract the
# URLs of the files we actually want from that, then suck down those
# files.   We use wget options which should (in theory) prevent us from
# actually sucking down anything of which we have an up-to-date copy.
# The definition of "interesting files" is all in the sed filter,
# which is looking for filenames of the form reference.*.xml.  The sed
# code knows far too much about what a generic Apache directory
# listing looks like after it's been run through "lynx -dump"; if that
# bothers you, feel free to fix it and send me the code.

fetch_dir() {
  prefix="$1"
  url="$2"
  wget -q -nd -N -P "$prefix" "$url"
  echo "<BASE HREF=\"$url\">" |
  cat - "$prefix/index.html" |
  lynx -force_html -dump /dev/stdin |
  sed -n '/^References/,${; /reference\..*\.xml$/s/^ *[0-9]*\. *//p; }' |
  wget -q -nd -N -P "$prefix" -i -
}

cd $HOME/ietf/xml
fetch_dir rfc   http://xml.resource.org/public/rfc/bibxml/
fetch_dir draft http://xml.resource.org/public/rfc/bibxml3/
