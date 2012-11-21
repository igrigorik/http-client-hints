.\" 
.pl 10.0i
.po 0
.ll 7.2i
.lt 7.2i
.nr LL 7.2i
.nr LT 7.2i
.ds LF Reschke
.ds RF FORMFEED[Page %]
.ds CF 
.ds LH 
.ds RH March 2010
.ds CH Basic Test Cases for RFC2629 Formatting
.hy 0
.nh
.ad l
.nf
.in 0
RFC2629 basis sample                                          J. Reschke
                                                              greenbytes
                                                          March 31, 2010


.ce
Basic Test Cases for RFC2629 Formatting

.in 3


.in 0
Table of Contents

   1.  Lists  . . . . . . . . . . . . . . . . . . . . . . . . . . . .  3
     1.1.  hanging list . . . . . . . . . . . . . . . . . . . . . . .  3
     1.2.  numbered list  . . . . . . . . . . . . . . . . . . . . . .  3
     1.3.  ordered list (letters) . . . . . . . . . . . . . . . . . .  3
     1.4.  no explicit counters . . . . . . . . . . . . . . . . . . .  4
     1.5.  with explicit counters . . . . . . . . . . . . . . . . . .  5
     1.6.  Nested list  . . . . . . . . . . . . . . . . . . . . . . .  6
     1.7.  list without style . . . . . . . . . . . . . . . . . . . .  6
   2.  spanx  . . . . . . . . . . . . . . . . . . . . . . . . . . . .  7
   3.  Tables . . . . . . . . . . . . . . . . . . . . . . . . . . . .  8
     3.1.  no borders . . . . . . . . . . . . . . . . . . . . . . . .  9
     3.2.  borders around headers . . . . . . . . . . . . . . . . . .  9
     3.3.  example from xml2rc README . . . . . . . . . . . . . . . .  9
     3.4.  no column titles . . . . . . . . . . . . . . . . . . . . . 10
     3.5.  referencing tables . . . . . . . . . . . . . . . . . . . . 10
     3.6.  table captions . . . . . . . . . . . . . . . . . . . . . . 10
     3.7.  single column  . . . . . . . . . . . . . . . . . . . . . . 11
     3.8.  table alignment  . . . . . . . . . . . . . . . . . . . . . 11
   4.  Figures  . . . . . . . . . . . . . . . . . . . . . . . . . . . 13
     4.1.  with preamble, no title... . . . . . . . . . . . . . . . . 13
     4.2.  with postamble and title...  . . . . . . . . . . . . . . . 13
     4.3.  Whitespace handling  . . . . . . . . . . . . . . . . . . . 13
     4.4.  Whitespace around figures  . . . . . . . . . . . . . . . . 13
   5.  References . . . . . . . . . . . . . . . . . . . . . . . . . . 15
     5.1.  xref with no content . . . . . . . . . . . . . . . . . . . 15
     5.2.  xref to named <t> element  . . . . . . . . . . . . . . . . 15
     5.3.  xref to named <t> element inside list  . . . . . . . . . . 15
     5.4.  xref to named <cref> element . . . . . . . . . . . . . . . 15
     5.5.  xref to named <t> element inside list  . . . . . . . . . . 15
     5.6.  xref with no \%auto-formatting . . . . . . . . . . . . . . . 15
     5.7.  xref with content and \%auto-formatting  . . . . . . . . . . 15
     5.8.  xref with content and \'none\' formatting  . . . . . . . . . 15
     5.9.  eref with no content . . . . . . . . . . . . . . . . . . . 15
     5.10. eref with content  . . . . . . . . . . . . . . . . . . . . 16
     5.11. iref inside paragraph  . . . . . . . . . . . . . . . . . . 16
   6.  Paragraph formatting . . . . . . . . . . . . . . . . . . . . . 17
   7.  Sections . . . . . . . . . . . . . . . . . . . . . . . . . . . 18
.bp
     7.1.  Subsection with TOC entry  . . . . . . . . . . . . . . . . 18
       7.2.1.  \%Sub-subsection with TOC entry  . . . . . . . . . . . . 18
   8.  Comments . . . . . . . . . . . . . . . . . . . . . . . . . . . 19
   9.  Artwork width  . . . . . . . . . . . . . . . . . . . . . . . . 20
   10. Blank Lines  . . . . . . . . . . . . . . . . . . . . . . . . . 21
   11. Other  . . . . . . . . . . . . . . . . . . . . . . . . . . . . 22
     11.1. Comments in Text . . . . . . . . . . . . . . . . . . . . . 22
   12. References . . . . . . . . . . . . . . . . . . . . . . . . . . 23
   Editorial Comments . . . . . . . . . . . . . . . . . . . . . . . .
   Index  . . . . . . . . . . . . . . . . . . . . . . . . . . . . . . 25
   Author\'s Address . . . . . . . . . . . . . . . . . . . . . . . . . 26
.bp
.fi
.in 4
.ti 0
1.  Lists
.in 3

.in 6
.ti 0
1.1.  hanging list
.in 3

.in 6
.ti 3
Name:\0 timeout

.ti 3
Namespace:\0 DAV:

.ti 3
Purpose:\0 The timeout associated with a lock

.ti 3
Value:\0 TimeType ;Defined in section 9.8

.in 3
.in 6
.ti 0
1.2.  numbered list
.in 3

A numbered list:

.in 7
.ti 3
1.  one

.ti 3
2.  two

.ti 3
3.  three

.in 3
.in 6
.ti 0
1.3.  ordered list (letters)
.in 3

An ordered list using letters:

.in 8
.ti 3
a.   one

.ti 3
b.   two

.ti 3
c.   three

.ti 3
d.   one

.ti 3
e.   two

.ti 3
f.   three

.ti 3
g.   one

.ti 3
h.   two

.ti 3
i.   three

.ti 3
j.   one

.ti 3
k.   two
.bp
.ti 3
l.   three

.ti 3
m.   one

.ti 3
n.   two

.ti 3
o.   three

.ti 3
p.   one

.ti 3
q.   two

.ti 3
r.   three

.ti 3
s.   one

.ti 3
t.   two

.ti 3
u.   three

.ti 3
v.   one

.ti 3
w.   two

.ti 3
x.   three

.ti 3
y.   one

.ti 3
z.   two

.ti 3
aa.  three

.ti 3
ab.  one

.ti 3
ac.  two

.ti 3
ad.  three

.in 3
.in 6
.ti 0
1.4.  no explicit counters
.in 3

Example for numbered list with \%user-defined-format:

.in 8
.ti 3
R1:  R1

.ti 3
R2:  R2

.in 3
Another list:
.bp
.in 8
.ti 3
S1:  S1

.ti 3
S2:  S2

.in 3
Next list should continue counting R\'s:

.in 8
.ti 3
R1:  R3

.ti 3
R2:  R4

.in 3
Same with \%character-based numbering:

.in 9
.ti 3
\%c-a:  \%c-a

.ti 3
\%c-b:  \%c-b

.in 3
.in 6
.ti 0
1.5.  with explicit counters
.in 3

A few requirements:

.in 8
.ti 3
R1:  req R1

.ti 3
R2:  req R2

.in 3
More requirements:

.in 8
.ti 3
R3:  req R3

.ti 3
R4:  req R4

.in 3
A few rules:

.in 8
.ti 3
R1:  rule R1

.ti 3
R2:  rule R2

.ti 3
R3:  rule R3

.in 3
Explicit counter with name matching it\'s format string:

.in 9
.ti 3
\%c-a:  \%c-c

.ti 3
\%c-b:  \%c-d

.in 3
Same, without counter:
.bp
.in 9
.ti 3
\%c-a:  \%c-e

.ti 3
\%c-b:  \%c-f

.in 3
.in 6
.ti 0
1.6.  Nested list
.in 3

.in 7
.ti 3
1.  One

.ti 3
2.  Two

.in 11
.ti 7
A.  17

.ti 7
B.  42

.in 7
.ti 3
3.  Three

.in 3
.in 6
.ti 0
1.7.  list without style
.in 3

.in 6
.ti 6
One

.ti 6
Two

.ti 6
Three

.in 3
.bp
.in 4
.ti 0
2.  spanx
.in 3

This is _default_.

This is _emph(asized)_.

This is *strong*.

This is "verb(atim)".

Here is "a carriage return inside" a spanx element.
.bp
.in 4
.ti 0
3.  Tables
.in 3

.ce 8192
The list of valid keywords are:
.ce 0
.in 0
.nf

   \%+--------------+--------------+--------------------------+----------+
   |      keyword |    default   | meaning                  | not      |
   |              |              |                          | aligned  |
   \%+--------------+--------------+--------------------------+----------+
   |       strict |      no      | try to enforce the       | a        |
   |              |              | \%ID-nits conventions and  |          |
   |              |              | DTD validity             |          |
   |              |              |                          |          |
   |  iprnotified |      no      | include boilerplate from | bb bb    |
   |              |              | Section 10.4(d) of       |          |
   |              |              | [RFC2026]                |          |
   |              |              |                          |          |
   |      compact |      no      | when producing a         | ccc ccc  |
   |              |              | txt/nroff file, try to   | ccc      |
   |              |              | conserve vertical        |          |
   |              |              | whitespace               |          |
   |              |              |                          |          |
   |   subcompact |    compact   | if compact is "yes",     | dddd     |
   |              |              | then setting this to     | dddd     |
   |              |              | "no" will make things a  | dddd     |
   |              |              | little less compact      | dddd     |
   |              |              |                          |          |
   |    needLines |      n/a     | an integer hint          | eeeee    |
   |              |              | indicating how many      | eeeee    |
   |              |              | contiguous lines are     | eeeee    |
   |              |              | needed at this point in  | eeeee    |
   |              |              | the output               | eeeee    |
   |              |              |                          |          |
   |    here come |              |                          |          |
   |  empty cells |              |                          |          |
   \%+--------------+--------------+--------------------------+----------+

.in 3
.fi
.ce 8192
Remember, that as with everything else in XML, keywords and values
are \%case-sensitive.
.ce 0
.bp
.in 6
.ti 0
3.1.  no borders
.in 3

.ce 8192
The table below should appear with no borders.
.ce 0
.in 0
.nf

                                   C1 C2

                                   11 12

                                   21 22

.in 3
.ce
Table\01: a table with no borders

.fi
.in 6
.ti 0
3.2.  borders around headers
.in 3

.ce 8192
The table below should appear with borders just around the headers.
.ce 0
.in 0
.nf

                                   C1 C2
                                   \%-- \%--
                                   11 12

                                   21 22

.in 3
.fi
.in 6
.ti 0
3.3.  example from xml2rc README
.in 3

.ce 8192
So, putting it all together, we have, e.g.,
.ce 0
.in 0
.nf

                          \%+----------+----------+
                          | ttcol #1 | ttcol #2 |
                          \%+----------+----------+
                          |   c #1   |   c #2   |
                          |          |          |
                          |   c #3   |   c #4   |
                          |          |          |
                          |   c #5   |   c #6   |
                          \%+----------+----------+

.in 3
.fi
.ce 8192
which is a very simple example.
.ce 0

.ce
Table\02

.bp
.in 6
.ti 0
3.4.  no column titles
.in 3

.ce 8192
The table below should appear with no titles.
.ce 0
.in 0
.nf

                                \%+----+----+
                                | 11 | 12 |
                                |    |    |
                                | 21 | 22 |
                                \%+----+----+

.in 3
.ce
Table\03: a table with no column titles

.fi
.ce 8192
The table below should appear with column titles (one being \%non-
empty).
.ce 0
.in 0
.nf

                               \%+-----+----+
                               | FOO |    |
                               \%+-----+----+
                               | 11  | 12 |
                               |     |    |
                               | 21  | 22 |
                               \%+-----+----+

.in 3
.ce
Table\04: a table with a single column title

.fi
.in 6
.ti 0
3.5.  referencing tables
.in 3

Table\01 shows a table with no borders.

The table above (Table\01) shows a table with no borders.

.in 6
.ti 0
3.6.  table captions
.in 3

.ce 8192
No anchor, no title
.ce 0
.in 0
.nf

                            \%+--------+-------+
                            | Anchor | Title |
                            \%+--------+-------+
                            | \%-      | \%-     |
                            \%+--------+-------+

.in 3
.bp
.fi
.ce 8192
Anchor (not being referenced), no title
.ce 0
.in 0
.nf

                            \%+--------+-------+
                            | Anchor | Title |
                            \%+--------+-------+
                            | yes    | \%-     |
                            \%+--------+-------+

.in 3
.ce
Table\05

.fi
.ce 8192
No anchor, with title
.ce 0
.in 0
.nf

                           \%+--------+---------+
                           | Anchor | Title   |
                           \%+--------+---------+
                           | \%-      | "title" |
                           \%+--------+---------+

.in 3
.ce
title

.fi
.ce 8192
Both anchor and title
.ce 0
.in 0
.nf

                           \%+--------+---------+
                           | Anchor | Title   |
                           \%+--------+---------+
                           | yes    | "title" |
                           \%+--------+---------+

.in 3
.ce
Table\06: title

.fi
.in 6
.ti 0
3.7.  single column
.in 3
.in 0
.nf

                                 \%+-------+
                                 | title |
                                 \%+-------+
                                 | 1     |
                                 |       |
                                 | 2     |
                                 \%+-------+

.in 3
.fi
.in 6
.ti 0
3.8.  table alignment
.in 3
.in 0
.nf

   \%+------+
   | left |
   \%+------+
   | 1    |
   \%+------+

.bp
.in 3
.in 0
.fi
.nf
                                \%+--------+
                                | center |
                                \%+--------+
                                | 1      |
                                \%+--------+

.in 3
.in 0
.fi
.nf
                                                               \%+-------+
                                                               | right |
                                                               \%+-------+
                                                               | 1     |
                                                               \%+-------+

.in 3
.in 0
.fi
.nf
                                \%+---------+
                                | default |
                                \%+---------+
                                | 1       |
                                \%+---------+

.in 3
.bp
.fi
.in 4
.ti 0
4.  Figures
.in 3

.in 6
.ti 0
4.1.  with preamble, no title...
.in 3

with preamble, no title...
.nf

  +--+
  |  |
  +--+

.fi
.in 6
.ti 0
4.2.  with postamble and title...
.in 3
.nf

  +--+
  |  |
  +--+

.fi
with postamble and title...

.ce
Figure\01: another figure

The figure above has the title "another figure".

.in 6
.ti 0
4.3.  Whitespace handling
.in 3

Para...

Leading whitespace
.nf

test test (leading ws)

.fi
Para...

Trailing whitespace
.nf
test test (trailing ws)

.fi
Para...

No whitespace
.nf
test test (no ws)

.fi
Para...

.in 6
.ti 0
4.4.  Whitespace around figures
.in 3

spacing paragraph
.nf
ART

.fi
spacing paragraph
.bp
preamble, then
.nf
ART

.fi
spacing paragraph
.nf
ART
.fi
then postamble

spacing paragraph
.bp
.in 4
.ti 0
5.  References
.in 3

.in 6
.ti 0
5.1.  xref with no content
.in 3

Section\05 is the parent section.

.in 6
.ti 0
5.2.  xref to named <t> element
.in 3

With content: see first sentence of previous section.

Without content: see Paragraph\01.

.in 6
.ti 0
5.3.  xref to named <t> element inside list
.in 3

With content: see first element in list below.

.in 6
.ti 3
test\0 Test

.in 3
.in 6
.ti 0
5.4.  xref to named <cref> element
.in 3

With content: see test comment.

Without content: see \%Comment\0comment-test.

.in 6
.ti 0
5.5.  xref to named <t> element inside list
.in 3

See last entry in Section\01.3.

.in 6
.ti 0
5.6.  xref with no \%auto-formatting
.in 3

So far we have sections 1 ("Lists") through 5 ("References").

.in 6
.ti 0
5.7.  xref with content and \%auto-formatting
.in 3

This is a subsection of References (Section\05).

.in 6
.ti 0
5.8.  xref with content and \'none\' formatting
.in 3

Here we are referring to RFC 2026, without emitting extra formatting.

Here we are referring to this Section, without emitting extra
formatting.

.in 6
.ti 0
5.9.  eref with no content
.in 3

See also <http://greenbytes.de/tech/webdav>.  Here\'s another one that
is quite long: <http://greenbytes.de/tech/webdav/
\%draft-reschke-rfc3744bis-issues.html#5.7_inherited-acl-set-
.bp
protected>.  Does it break properly?

.in 7
.ti 0
5.10.  eref with content
.in 3

See also greenbytes WebDAV resources\0[1].

.in 7
.ti 0
5.11.  iref inside paragraph
.in 3

This paragraph contains an inline iref.
.bp
.in 4
.ti 0
6.  Paragraph formatting
.in 3

This is the first sentence of the paragraph.  This is the second
sentence of the paragraph (with two leading blanks).  Here\'s another
sentence that was started on a separate line in the input file.

This is the second paragraph.
.bp
.in 4
.ti 0
7.  Sections
.in 3

.in 6
.ti 0
7.1.  Subsection with TOC entry
.in 3

.in 6
.ti 0
7.2.  Subsection without TOC entry
.in 3

.in 8
.ti 0
7.2.1.  \%Sub-subsection with TOC entry
.in 3
.bp
.in 4
.ti 0
8.  Comments
.in 3

This line contains a few comments. \%[comment-test] This line contains
a few comments. [comment1] This line contains a few comments.
[comment2] This line contains a few comments. [anchor37] This line
contains a few comments. [anchor38]<http://xml.resource.org> This
line contains a few comments.
.bp
.in 4
.ti 0
9.  Artwork width
.in 3

This should fit (69 characters plus three spaces of indentation in
text output).
.nf

012345678901234567890123456789012345678901234567890123456789012345678

.fi
This shouldn\'t.
.nf

.in 2
0123456789012345678901234567890123456789012345678901234567890123456789

.in 3
.bp
.fi
.in 5
.ti 0
10.  Blank Lines
.in 3

Just a forced
.br
line break.

One
.sp 1
blank line.

Seven
.sp 7
blank lines.
.bp
.in 5
.ti 0
11.  Other
.in 3

.in 7
.ti 0
11.1.  Comments in Text
.in 3

First sentence (before XML comment, invisible here).  Second
sentence.
.bp
.in 5
.ti 0
12.  References
.in 3

.in 14
.ti 3
[RFC2026]  Bradner, S., "The Internet Standards Process \%-- Revision
3", BCP\09, RFC\02026, October\01996.

.ti 3
[RFC2396]  \%Berners-Lee, T., Fielding, R., and L. Masinter, "Uniform
Resource Identifiers (URI): Generic Syntax", RFC\02396,
August\01998.

This RFC will soon be updated, check <http://
\%cvs.apache.org/viewcvs.cgi/*checkout*/ietf-uri/rev-2002/
rfc2396bis.html> for the latest draft.

The issues list is at <http://cvs.apache.org/viewcvs.cgi/
\%*checkout*/ietf-uri/rev-2002/issues.html>.

.in 8
.ti 3
[1]  <http://greenbytes.de/tech/webdav>
.bp
.ti 0
Editorial Comments

.in 19
.ti 3
[anchor37]      No anchor, no source.

.ti 3
[anchor38]      No anchor, no source, but embedded markup:.

.ti 3
\%[comment-test]  JRE: No anchor, source given.

.ti 3
[comment1]      Anchor given, no source.

.ti 3
[comment2]      JRE: Both specified.
.bp
.in 0
Index
.in 12
.br

.ti 3
I
.br
.ti 6
inline iref  16
.bp
.in 3
.nf
.ti 0
Author\'s Address

Julian F. Reschke
greenbytes GmbH
Hafenweg 16
Muenster, NW  48155
Germany

Email: julian.reschke@greenbytes.de
URI:   http://greenbytes.de/tech/webdav/
