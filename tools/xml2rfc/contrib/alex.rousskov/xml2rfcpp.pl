#!/usr/bin/perl -w
use strict;

#
# About:
#       This script intends to do the following,
#       in the specified order: 
#           - read standard input
#           - find various xml2rfc-include statements
#           - substitute those statements with included files
#           - find declarations of XML internal entities
#           - delete those declarations
#           - substitute declared internal entity names with their definitions
#           - trim space in artwork element that has trimspace=yes
#           - write the result to standard output.
#       The only recognized XML internal entity declaration 
#       pattern is:  <!ENTITY name "definition">
#       XML_LIBRARY environment variable is used as a path for includes.
#
# Bugs:
#        This script is not XML-aware.
#        Self-referencing entities or include statements 
#        result in an infinite loop.
#
# Legal: 
#        This script has been placed in public domain by
#        the good folks at The Measurement Factory.
# 
# $Id: xmlpp.pl,v 1.8 2004/05/05 08:12:06 rousskov Exp $

# read everything in
my $xml = '';
while (<STDIN>) {
	$xml .= $_;
}

# handle includes
$xml =~ s/<\?rfc\s+include=['"]([^'"]+)['"]\s*\?>/&loadFile($1)/esg;

# find entity declarations
my %Entities = ();
while ($xml =~ s/<!ENTITY\s+([\w-]+)\s+"([^"]*)"\s*>//s) {
	my $name = $1;
	my $value = $2;
	if (exists $Entities{$name}) {
		die("entity $name redefined from ".
			"'$Entities{$name}' to '$name' near '$&', stopped");
	} else {
		$Entities{$name} = $value;
	}
}

# substitute entities recursively
my $stable;
do {
	$stable = 1;
	while (my ($name, $value) = each %Entities) {
		$stable = 0 if $xml =~ s/\&$name\;/$value/g;
	}
} until $stable;


# check that all entries are resolved

my $xml_nocd = $xml;
$xml_nocd =~ s|\Q<![CDATA[\E.*?\Q]]>\E||sg; # remove CDATA
my %reported = map { $_ => 0 } qw(lt amp quot apos rfc);
my @remaining = ($xml_nocd =~ /\&([\w-]+)/g);
my $errCount = 0;
foreach my $e (@remaining) {
	next if exists $reported{$e};
	warn(sprintf("error: unresolved or malformed XML entity '%s'\n", $e));
	$reported{$e} = 1;
	$errCount++;
}
die(sprintf("error: %d unresolved or malformed XML entity(ies)\n", $errCount))
	if $errCount > 0;

# handle trimspace
$xml =~ s|<artwork\s+trimspace=['"]([^'"]+)['"]\s*>(.*?)</artwork>|&trimSpace($1,$2)|esg;

print $xml;

exit 0;



sub loadFile {
	my $name = $_[0];

	my $dirs = $ENV{'XML_LIBRARY'};
	$dirs = '.' unless defined $dirs;
	foreach my $dir (split (/:+/, $dirs)) {
		my $fname = "$dir/$name";
		next unless -e $fname;

		my $content = '';
		open(IF, "<$fname") or die("cannot read included file: $fname, stopped");
		while (<IF>) {
			$content .= $_;
		}
		close(IF);
		return $content;
	}

	if (defined $ENV{'XML_LIBRARY'}) {
		warn("search path derived from the XML_LIBRARY environment variable;\n");
	} else {
		warn("XML_LIBRARY environment variable is not set;\n");
	}
	die("cannot find included '$name' in '$dirs' path, stopped");
}

sub trimSpace {
	my ($trim, $artwork) = @_;

	my @lines = split(/\n/s, $artwork);
	my $indent = ($trim eq 'indent') ? '    ' : '';

	if (($trim eq 'yes' || $trim eq 'indent') && @lines) {
		$lines[0] =~ s/^\s+//g;
		$lines[$#lines] =~ s/\s+$//g;

		if (@lines > 2) {
			my ($tabs) = ($lines[1] =~ /^(\t*)/);
			if (length($tabs) > 0) {
				foreach my $line (@lines) {
					$line =~ s/^$tabs|\s+$/$indent/;
				} 
			}
		}

		shift @lines unless length($lines[0]);
		pop @lines unless length($lines[$#lines]);
	}

	return '<artwork>' . join("\n", @lines) . '</artwork>';
}
	
