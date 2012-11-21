# $Id: concat.pl,v 1.3 2004/06/27 18:07:11 sra Exp $

# Process all the <?rfc include="xyz" ?> directives to produce a
# single XML file, to make things easier for the RFC Editor.

sub concat {
    my $fn = shift;
    local *FH;
    open(FH, $fn) or die("Couldn't open \"$fn\": $!");
    while (<FH>) {
	if (my ($h,$q,$f,$t) = /\A(.*[^ \t])?[ \t]*<\?rfc[ \t]+include=(.)(.+)\2[ \t]*\?>[ \t]*([^ \t].*)?\z/s) {
	    print($h);
	    concat($f . '.xml');
	    print($t);
	} else {
	    print;
	}
    }
    close(FH) or warn("Couldn't close \"$fn\": $!");
}

concat(shift(@ARGV))
    while (@ARGV);
