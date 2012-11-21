.\" 
.pl 10.0i
.po 0
.ll 7.2i
.lt 7.2i
.nr LL 7.2i
.nr LT 7.2i
.ds LF Crocker & Overell
.ds RF FORMFEED[Page %]
.ds CF Standards Track
.ds LH RFC\05234
.ds RH January 2008
.ds CH ABNF
.hy 0
.nh
.ad l
.nf
.in 0
Network Working Group                                    D. Crocker, Ed.
Request for Comments: 5234                   Brandenburg InternetWorking
STD: 68                                                       P. Overell
Obsoletes: 4234                                                THUS plc.
Category: Standards Track                                   January 2008


.ce
Augmented BNF for Syntax Specifications: ABNF

.in 3
.ti 0
Status of This Memo

.fi
This document specifies an Internet standards track protocol for the
Internet community, and requests discussion and suggestions for
improvements.  Please refer to the current edition of the "Internet
Official Protocol Standards" (STD\01) for the standardization state
and status of this protocol.  Distribution of this memo is unlimited.

.ti 0
Abstract

Internet technical specifications often need to define a formal
syntax.  Over the years, a modified version of \%Backus-Naur Form
(BNF), called Augmented BNF (ABNF), has been popular among many
Internet specifications.  The current specification documents ABNF.
It balances compactness and simplicity with reasonable
representational power.  The differences between standard BNF and
ABNF involve naming rules, repetition, alternatives, \%order-
independence, and value ranges.  This specification also supplies
additional rule definitions and encoding for a core lexical analyzer
of the type common to several Internet specifications.
.bp
.in 0
Table of Contents

.nf
   1.  Introduction . . . . . . . . . . . . . . . . . . . . . . . . .  3
   2.  Rule Definition  . . . . . . . . . . . . . . . . . . . . . . .  3
     2.1.  Rule Naming  . . . . . . . . . . . . . . . . . . . . . . .  3
     2.2.  Rule Form  . . . . . . . . . . . . . . . . . . . . . . . .  4
     2.3.  Terminal Values  . . . . . . . . . . . . . . . . . . . . .  4
     2.4.  External Encodings . . . . . . . . . . . . . . . . . . . .  6
   3.  Operators  . . . . . . . . . . . . . . . . . . . . . . . . . .  6
     3.1.  Concatenation:  Rule1 Rule2  . . . . . . . . . . . . . . .  6
     3.2.  Alternatives:  Rule1 / Rule2 . . . . . . . . . . . . . . .  7
     3.3.  Incremental Alternatives: Rule1 =/ Rule2 . . . . . . . . .  7
     3.4.  Value Range Alternatives:  \%%c##-## . . . . . . . . . . . .  8
     3.5.  Sequence Group:  (Rule1 Rule2) . . . . . . . . . . . . . .  8
     3.6.  Variable Repetition:  *Rule  . . . . . . . . . . . . . . .  9
     3.7.  Specific Repetition:  nRule  . . . . . . . . . . . . . . .  9
     3.8.  Optional Sequence:  [RULE] . . . . . . . . . . . . . . . .  9
     3.9.  Comment:  ; Comment  . . . . . . . . . . . . . . . . . . . 10
     3.10. Operator Precedence  . . . . . . . . . . . . . . . . . . . 10
   4.  ABNF Definition of ABNF  . . . . . . . . . . . . . . . . . . . 10
   5.  Security Considerations  . . . . . . . . . . . . . . . . . . . 12
   6.  References . . . . . . . . . . . . . . . . . . . . . . . . . . 12
     6.1.  Normative References . . . . . . . . . . . . . . . . . . . 12
     6.2.  Informative References . . . . . . . . . . . . . . . . . . 12
   Appendix A.  Acknowledgements  . . . . . . . . . . . . . . . . . . 13
   Appendix B.  Core ABNF of ABNF . . . . . . . . . . . . . . . . . . 13
     B.1.  Core Rules . . . . . . . . . . . . . . . . . . . . . . . . 13
     B.2.  Common Encoding  . . . . . . . . . . . . . . . . . . . . . 15
.bp
.fi
.in 4
.ti 0
1.  Introduction
.in 3

Internet technical specifications often need to define a formal
syntax and are free to employ whatever notation their authors deem
useful.  Over the years, a modified version of \%Backus-Naur Form
(BNF), called Augmented BNF (ABNF), has been popular among many
Internet specifications.  It balances compactness and simplicity with
reasonable representational power.  In the early days of the Arpanet,
each specification contained its own definition of ABNF.  This
included the email specifications, [RFC733] and then [RFC822], which
came to be the common citations for defining ABNF.  The current
document separates those definitions to permit selective reference.
Predictably, it also provides some modifications and enhancements.

The differences between standard BNF and ABNF involve naming rules,
repetition, alternatives, \%order-independence, and value ranges.
Appendix\0B supplies rule definitions and encoding for a core lexical
analyzer of the type common to several Internet specifications.  It
is provided as a convenience and is otherwise separate from the meta
language defined in the body of this document, and separate from its
formal status.

.in 4
.ti 0
2.  Rule Definition
.in 3

.in 6
.ti 0
2.1.  Rule Naming
.in 3

The name of a rule is simply the name itself, that is, a sequence of
characters, beginning with an alphabetic character, and followed by a
combination of alphabetics, digits, and hyphens (dashes).

.in 6
.ti 3
NOTE:  \0

.ti 6
Rule names are case insensitive.

.in 3
The names <rulename>, <Rulename>, <RULENAME>, and <rUlENamE> all
refer to the same rule.

Unlike original BNF, angle brackets ("<", ">") are not required.
However, angle brackets may be used around a rule name whenever their
presence facilitates in discerning the use of a rule name.  This is
typically restricted to rule name references in \%free-form prose, or
to distinguish partial rules that combine into a string not separated
by white space, such as shown in the discussion about repetition,
below.
.bp
.in 6
.ti 0
2.2.  Rule Form
.in 3

A rule is defined by the following sequence:
.nf


      name =  elements crlf

.fi
where <name> is the name of the rule, <elements> is one or more rule
names or terminal specifications, and <crlf> is the \%end-of-line
indicator (carriage return followed by line feed).  The equal sign
separates the name from the definition of the rule.  The elements
form a sequence of one or more rule names and/or value definitions,
combined according to the various operators defined in this document,
such as alternative and repetition.

For visual ease, rule definitions are left aligned.  When a rule
requires multiple lines, the continuation lines are indented.  The
left alignment and indentation are relative to the first lines of the
ABNF rules and need not match the left margin of the document.

.in 6
.ti 0
2.3.  Terminal Values
.in 3

Rules resolve into a string of terminal values, sometimes called
characters.  In ABNF, a character is merely a \%non-negative integer.
In certain contexts, a specific mapping (encoding) of values into a
character set (such as ASCII) will be specified.

Terminals are specified by one or more numeric characters, with the
base interpretation of those characters indicated explicitly.  The
following bases are currently defined:
.nf


      b           =  binary

      d           =  decimal

      x           =  hexadecimal

.fi
Hence:
.nf


      CR          =  %d13

      CR          =  %x0D

.fi
respectively specify the decimal and hexadecimal representation of
\%[US-ASCII] for carriage return.
.bp
A concatenated string of such values is specified compactly, using a
period (".") to indicate a separation of characters within that
value.  Hence:
.nf


      CRLF        =  %d13.10

.fi
ABNF permits the specification of literal text strings directly,
enclosed in quotation marks.  Hence:
.nf


      command     =  "command string"

.fi
Literal text strings are interpreted as a concatenated set of
printable characters.

.in 6
.ti 3
NOTE:  \0

.ti 6
ABNF strings are case insensitive and the character set for these
strings is \%US-ASCII.

.in 3
Hence:
.nf


      rulename = "abc"

.fi
and:
.nf


      rulename = "aBc"

.fi
will match "abc", "Abc", "aBc", "abC", "ABc", "aBC", "AbC", and
"ABC".

.in 6
.ti 6
To specify a rule that is case sensitive, specify the characters
individually.

.in 3
For example:
.nf


      rulename    =  %d97 %d98 %d99

.fi
or
.nf


      rulename    =  %d97.98.99

.fi
will match only the string that comprises only the lowercase
.bp
characters, abc.
.br

.in 6
.ti 0
2.4.  External Encodings
.in 3

External representations of terminal value characters will vary
according to constraints in the storage or transmission environment.
Hence, the same \%ABNF-based grammar may have multiple external
encodings, such as one for a \%7-bit \%US-ASCII environment, another for
a binary octet environment, and still a different one when \%16-bit
Unicode is used.  Encoding details are beyond the scope of ABNF,
although Appendix\0B provides definitions for a \%7-bit \%US-ASCII
environment as has been common to much of the Internet.

By separating external encoding from the syntax, it is intended that
alternate encoding environments can be used for the same syntax.

.in 4
.ti 0
3.  Operators
.in 3

.in 6
.ti 0
3.1.  Concatenation:  Rule1 Rule2
.in 3

A rule can define a simple, ordered string of values (i.e., a
concatenation of contiguous characters) by listing a sequence of rule
names.  For example:
.nf


      foo         =  %x61           ; a

      bar         =  %x62           ; b

      mumble      =  foo bar foo

.fi
So that the rule <mumble> matches the lowercase string "aba".

Linear white space: Concatenation is at the core of the ABNF parsing
model.  A string of contiguous characters (values) is parsed
according to the rules defined in ABNF.  For Internet specifications,
there is some history of permitting linear white space (space and
horizontal tab) to be freely and implicitly interspersed around major
constructs, such as delimiting special characters or atomic strings.

NOTE:

.in 6
.ti 6
This specification for ABNF does not provide for implicit
specification of linear white space.

.in 3
Any grammar that wishes to permit linear white space around
delimiters or string segments must specify it explicitly.  It is
often useful to provide for such white space in "core" rules that are
.bp
then used variously among \%higher-level rules.  The "core" rules might
be formed into a lexical analyzer or simply be part of the main
ruleset.

.in 6
.ti 0
3.2.  Alternatives:  Rule1 / Rule2
.in 3

Elements separated by a forward slash ("/") are alternatives.
Therefore,
.nf


      foo / bar

.fi
will accept <foo> or <bar>.

.in 6
.ti 3
NOTE:  \0

.ti 6
A quoted string containing alphabetic characters is a special form
for specifying alternative characters and is interpreted as a \%non-
terminal representing the set of combinatorial strings with the
contained characters, in the specified order but with any mixture
of \%upper- and lowercase.

.in 3
.in 6
.ti 0
3.3.  Incremental Alternatives: Rule1 =/ Rule2
.in 3

It is sometimes convenient to specify a list of alternatives in
fragments.  That is, an initial rule may match one or more
alternatives, with later rule definitions adding to the set of
alternatives.  This is particularly useful for otherwise independent
specifications that derive from the same parent ruleset, such as
often occurs with parameter lists.  ABNF permits this incremental
definition through the construct:
.nf


      oldrule     =/ additional-alternatives

.fi
So that the ruleset
.nf


      ruleset     =  alt1 / alt2

      ruleset     =/ alt3

      ruleset     =/ alt4 / alt5

.fi
is the same as specifying
.nf


      ruleset     =  alt1 / alt2 / alt3 / alt4 / alt5
.bp
.fi
.in 6
.ti 0
3.4.  Value Range Alternatives:  \%%c##-##
.in 3

A range of alternative numeric values can be specified compactly,
using a dash \%("-") to indicate the range of alternative values.
Hence:
.nf


      DIGIT       =  %x30-39

.fi
is equivalent to:
.nf


      DIGIT       =  "0" / "1" / "2" / "3" / "4" / "5" / "6" /

                     "7" / "8" / "9"

.fi
Concatenated numeric values and numeric value ranges cannot be
specified in the same string.  A numeric value may use the dotted
notation for concatenation or it may use the dash notation to specify
one value range.  Hence, to specify one printable character between
\%end-of-line sequences, the specification could be:
.nf


      char-line = %x0D.0A %x20-7E %x0D.0A

.fi
.in 6
.ti 0
3.5.  Sequence Group:  (Rule1 Rule2)
.in 3

Elements enclosed in parentheses are treated as a single element,
whose contents are strictly ordered.  Thus,
.nf


      elem (foo / bar) blat

.fi
matches (elem foo blat) or (elem bar blat), and
.nf


      elem foo / bar blat

.fi
matches (elem foo) or (bar blat).

.in 6
.ti 3
NOTE:  \0

.ti 6
It is strongly advised that grouping notation be used, rather than
relying on the proper reading of "bare" alternations, when
alternatives consist of multiple rule names or literals.

.in 3
.bp
Hence, it is recommended that the following form be used:
.nf


     (elem foo) / (bar blat)

.fi
It will avoid misinterpretation by casual readers.
.br

The sequence group notation is also used within free text to set off
an element sequence from the prose.

.in 6
.ti 0
3.6.  Variable Repetition:  *Rule
.in 3

The operator "*" preceding an element indicates repetition.  The full
form is:
.nf


      <a>*<b>element

.fi
where <a> and <b> are optional decimal values, indicating at least
<a> and at most <b> occurrences of the element.

Default values are 0 and infinity so that *<element> allows any
number, including zero; 1*<element> requires at least one;
3*3<element> allows exactly 3; and 1*2<element> allows one or two.

.in 6
.ti 0
3.7.  Specific Repetition:  nRule
.in 3

A rule of the form:
.nf


      <n>element

.fi
is equivalent to
.nf


      <n>*<n>element

.fi
That is, exactly <n> occurrences of <element>.  Thus, 2DIGIT is a
\%2-digit number, and 3ALPHA is a string of three alphabetic
characters.

.in 6
.ti 0
3.8.  Optional Sequence:  [RULE]
.in 3

Square brackets enclose an optional element sequence:
.nf


      [foo bar]
.bp
.fi
is equivalent to
.nf


      *1(foo bar).

.fi
.in 6
.ti 0
3.9.  Comment:  ; Comment
.in 3

A semicolon starts a comment that continues to the end of line.  This
is a simple way of including useful notes in parallel with the
specifications.

.in 7
.ti 0
3.10.  Operator Precedence
.in 3

The various mechanisms described above have the following precedence,
from highest (binding tightest) at the top, to lowest (loosest) at
the bottom:

.in 6
.ti 6
Rule name, \%prose-val, Terminal value

.ti 6
Comment

.ti 6
Value range

.ti 6
Repetition

.ti 6
Grouping, Optional

.ti 6
Concatenation

.ti 6
Alternative

.in 3
Use of the alternative operator, freely mixed with concatenations,
can be confusing.

.in 6
.ti 6
Again, it is recommended that the grouping operator be used to
make explicit concatenation groups.

.in 3
.in 4
.ti 0
4.  ABNF Definition of ABNF
.in 3

.in 6
.ti 3
NOTES:\0

.in 10
.ti 6
1.  This syntax requires a formatting of rules that is relatively
strict.  Hence, the version of a ruleset included in a
specification might need preprocessing to ensure that it can
be interpreted by an ABNF parser.

.ti 6
2.  This syntax uses the rules provided in Appendix\0B.

.bp
.in 6
.in 3
.nf
      rulelist       =  1*( rule / (*c-wsp c-nl) )

      rule           =  rulename defined-as elements c-nl
                             ; continues if next line starts
                             ;  with white space

      rulename       =  ALPHA *(ALPHA / DIGIT / "-")

      defined-as     =  *c-wsp ("=" / "=/") *c-wsp
                             ; basic rules definition and
                             ;  incremental alternatives

      elements       =  alternation *c-wsp

      c-wsp          =  WSP / (c-nl WSP)

      c-nl           =  comment / CRLF
                             ; comment or newline

      comment        =  ";" *(WSP / VCHAR) CRLF

      alternation    =  concatenation
                        *(*c-wsp "/" *c-wsp concatenation)

      concatenation  =  repetition *(1*c-wsp repetition)

      repetition     =  [repeat] element

      repeat         =  1*DIGIT / (*DIGIT "*" *DIGIT)

      element        =  rulename / group / option /
                        char-val / num-val / prose-val

      group          =  "(" *c-wsp alternation *c-wsp ")"

      option         =  "[" *c-wsp alternation *c-wsp "]"

      char-val       =  DQUOTE *(%x20-21 / %x23-7E) DQUOTE
                             ; quoted string of SP and VCHAR
                             ;  without DQUOTE

      num-val        =  "%" (bin-val / dec-val / hex-val)

      bin-val        =  "b" 1*BIT
                        [ 1*("." 1*BIT) / ("-" 1*BIT) ]
                             ; series of concatenated bit values
                             ;  or single ONEOF range

.bp
      dec-val        =  "d" 1*DIGIT
                        [ 1*("." 1*DIGIT) / ("-" 1*DIGIT) ]

      hex-val        =  "x" 1*HEXDIG
                        [ 1*("." 1*HEXDIG) / ("-" 1*HEXDIG) ]




      prose-val      =  "<" *(%x20-3D / %x3F-7E) ">"
                             ; bracketed string of SP and VCHAR
                             ;  without angles
                             ; prose description, to be used as
                             ;  last resort

.fi
.in 4
.ti 0
5.  Security Considerations
.in 3

Security is truly believed to be irrelevant to this document.

.in 4
.ti 0
6.  References
.in 3

.in 6
.ti 0
6.1.  Normative References
.in 3

.in 15
.ti 3
\%[US-ASCII]  American National Standards Institute, "Coded Character
Set \%-- \%7-bit American Standard Code for Information
Interchange", ANSI\0X3.4, 1986.

.in 6
.ti 0
6.2.  Informative References
.in 3

.in 15
.ti 3
[RFC733]    Crocker, D., Vittal, J., Pogran, K., and D. Henderson,
"Standard for the format of ARPA network text messages",
RFC\0733, November\01977.

.ti 3
[RFC822]    Crocker, D., "Standard for the format of ARPA Internet
text messages", STD\011, RFC\0822, August\01982.
.bp
.in 13
.ti 0
Appendix A.  Acknowledgements
.in 3

The syntax for ABNF was originally specified in RFC 733.  Ken L.
Harrenstien, of SRI International, was responsible for \%re-coding the
BNF into an Augmented BNF that makes the representation smaller and
easier to understand.

This recent project began as a simple effort to cull out the portion
of RFC 822 that has been repeatedly cited by \%non-email specification
writers, namely the description of Augmented BNF.  Rather than simply
and blindly converting the existing text into a separate document,
the working group chose to give careful consideration to the
deficiencies, as well as benefits, of the existing specification and
related specifications made available over the last 15 years, and
therefore to pursue enhancement.  This turned the project into
something rather more ambitious than was first intended.
Interestingly, the result is not massively different from that
original, although decisions, such as removing the list notation,
came as a surprise.

This "separated" version of the specification was part of the DRUMS
working group, with significant contributions from Jerome Abela,
Harald Alvestrand, Robert Elz, Roger Fajman, Aviva Garrett, Tom
Harsch, Dan Kohn, Bill McQuillan, Keith Moore, Chris Newman, Pete
Resnick, and Henning Schulzrinne.

Julian Reschke warrants a special thanks for converting the Draft
Standard version to XML source form.

.in 13
.ti 0
Appendix B.  Core ABNF of ABNF
.in 3

This appendix contains some basic rules that are in common use.
Basic rules are in uppercase.  Note that these rules are only valid
for ABNF encoded in \%7-bit ASCII or in characters sets that are a
superset of \%7-bit ASCII.

.in 6
.ti 0
B.1.  Core Rules
.in 3

Certain basic rules are in uppercase, such as SP, HTAB, CRLF, DIGIT,
ALPHA, etc.
.nf


      ALPHA          =  %x41-5A / %x61-7A   ; A-Z / a-z

      BIT            =  "0" / "1"

.bp
      CHAR           =  %x01-7F
                             ; any 7-bit US-ASCII character,
                             ;  excluding NUL

      CR             =  %x0D
                             ; carriage return

      CRLF           =  CR LF
                             ; Internet standard newline

      CTL            =  %x00-1F / %x7F
                             ; controls

      DIGIT          =  %x30-39
                             ; 0-9

      DQUOTE         =  %x22
                             ; " (Double Quote)

      HEXDIG         =  DIGIT / "A" / "B" / "C" / "D" / "E" / "F"

      HTAB           =  %x09
                             ; horizontal tab

      LF             =  %x0A
                             ; linefeed

      LWSP           =  *(WSP / CRLF WSP)
                             ; Use of this linear-white-space rule
                             ;  permits lines containing only white
                             ;  space that are no longer legal in
                             ;  mail headers and have caused
                             ;  interoperability problems in other
                             ;  contexts.
                             ; Do not use when defining mail
                             ;  headers and use with caution in
                             ;  other contexts.

      OCTET          =  %x00-FF
                             ; 8 bits of data

      SP             =  %x20

      VCHAR          =  %x21-7E
                             ; visible (printing) characters

      WSP            =  SP / HTAB
                             ; white space
.bp
.fi
.in 6
.ti 0
B.2.  Common Encoding
.in 3

Externally, data are represented as "network virtual ASCII" (namely,
\%7-bit \%US-ASCII in an \%8-bit field), with the high (8th) bit set to
zero.  A string of values is in "network byte order", in which the
\%higher-valued bytes are represented on the \%left-hand side and are
sent over the network first.

.nf
.ti 0
Authors\' Addresses

Dave Crocker (editor)
Brandenburg InternetWorking
675 Spruce Dr.
Sunnyvale, CA  94086
US

Phone: +1.408.246.8253
EMail: dcrocker@bbiw.net


Paul Overell
THUS plc.
1/2 Berkeley Square,
99 Berkeley Street
Glasgow  G3 7HR
UK

EMail: paul.overell@thus.net
.bp
.ti 0
Full Copyright Statement

.fi
Copyright (C) The IETF Trust (2008).

This document is subject to the rights, licenses and restrictions
contained in BCP\078, and except as set forth therein, the authors
retain all their rights.

This document and the information contained herein are provided on an
"AS IS" basis and THE CONTRIBUTOR, THE ORGANIZATION HE/SHE REPRESENTS
OR IS SPONSORED BY (IF ANY), THE INTERNET SOCIETY, THE IETF TRUST AND
THE INTERNET ENGINEERING TASK FORCE DISCLAIM ALL WARRANTIES, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTY THAT THE USE OF
THE INFORMATION HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY IMPLIED
WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.

.ti 0
Intellectual Property

The IETF takes no position regarding the validity or scope of any
Intellectual Property Rights or other rights that might be claimed to
pertain to the implementation or use of the technology described in
this document or the extent to which any license under such rights
might or might not be available; nor does it represent that it has
made any independent effort to identify any such rights.  Information
on the procedures with respect to rights in RFC documents can be
found in BCP\078 and BCP\079.

Copies of IPR disclosures made to the IETF Secretariat and any
assurances of licenses to be made available, or the result of an
attempt made to obtain a general license or permission for the use of
such proprietary rights by implementers or users of this
specification can be obtained from the IETF \%on-line IPR repository at
http://www.ietf.org/ipr.

The IETF invites any interested party to bring to its attention any
copyrights, patents or patent applications, or other proprietary
rights that may cover technology that may be required to implement
this standard.  Please address the information to the IETF at
\%ietf-ipr@ietf.org.

.ti 0
