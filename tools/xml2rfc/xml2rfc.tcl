#!/bin/sh
# the next line restarts using the correct interpreter \
exec tclsh "$0" "$0" "$@"


#
# xml2rfc.tcl - convert technical memos written using XML to TXT/HTML/NROFF
#
# (c) 1998-01 Invisible Worlds, Inc.
#

global prog prog_version prog_url prog_ack
set prog "xml2rfc"
set prog_version "v1.36"
set prog_url "http://xml.resource.org/"
set prog_ack \
"This document was produced
using $prog&nbsp;$prog_version (of %PROGURL%)
from a source in RFC-2629 XML format."

# "encoding system" is already set at this point and we want that
# because we print warnings and errors to the terminal.
# Now we want the C collation, month names, etc.
foreach v {LC_ALL LC_ADDRESS LC_COLLATE LC_CTYPE LC_IDENTIFICATION
           LC_MESSAGES LC_MEASUREMENT LC_MONETARY LC_NAME LC_NUMERIC
           LC_PAPER LC_TELEPHONE LC_TIME LANG LANGUAGE LINGUAS} {
    set env($v) C
}


#   {{{1 TclXML 1.1.1 (modified)


# earlier versions used to "package require xml 1.8", but because newer tcl
# installations have an incompatibly-versioned sgml package, this caused
# nothing but problems. hence, we just include TclXML-1.1.1 wholesale toward
# the end of the file...


#       {{{2 sgml.tcl

# sgml.tcl --
#
#       This file provides generic parsing services for SGML-based
#       languages, namely HTML and XML.
#
#       NB.  It is a misnomer.  There is no support for parsing
#       arbitrary SGML as such.
#
# Copyright (c) 1998,1999 Zveno Pty Ltd
# http://www.zveno.com/
#
# Zveno makes this software available free of charge for any purpose.
# Copies may be made of this software but all of this notice must be included
# on any copy.
#
# The software was developed for research purposes only and Zveno does not
# warrant that it is error free or fit for any purpose.  Zveno disclaims any
# liability for all claims, expenses, losses, damages and costs any user may
# incur as a result of using, copying or modifying this software.
#
# Copyright (c) 1997 ANU and CSIRO on behalf of the
# participants in the CRC for Advanced Computational Systems ('ACSys').
#
# ACSys makes this software and all associated data and documentation
# ('Software') available free of charge for any purpose.  You may make copies
# of the Software but you must include all of this notice on any copy.
#
# The Software was developed for research purposes and ACSys does not warrant
# that it is error free or fit for any purpose.  ACSys disclaims any
# liability for all claims, expenses, losses, damages and costs any user may
# incur as a result of using, copying or modifying the Software.
#
# $Id$

package provide sgml 1.6

namespace eval sgml {
    namespace export tokenise parseEvent

    namespace export parseDTD

    # Convenience routine
    proc cl x {
        return "\[$x\]"
    }

    # Define various regular expressions
    # white space
    variable Wsp " \t\r\n"
    variable noWsp [cl ^$Wsp]

    # Various XML names
    variable nmtoken [cl -a-zA-Z0-9._]+
    variable name [cl a-zA-Z_][cl -a-zA-Z0-9._]*

    # Other
    variable ParseEventNum
    if {![info exists ParseEventNum]} {
        set ParseEventNum 0
    }
    variable ParseDTDnum
    if {![info exists ParseDTDNum]} {
        set ParseDTDNum 0
    }

    # table of predefined entities for XML

    variable EntityPredef
    array set EntityPredef {
        lt <   gt >   amp &   quot \"   apos '
    }

}

# sgml::tokenise --
#
#       Transform the given HTML/XML text into a Tcl list.
#
# Arguments:
#       sgml            text to tokenize
#       elemExpr        RE to recognise tags
#       elemSub         transform for matched tags
#       args            options
#
# Valid Options:
#       -final          boolean         True if no more data is to be supplied
#       -statevariable  varName         Name of a variable used to store info
#
# Results:
#       Returns a Tcl list representing the document.

proc sgml::tokenise {sgml elemExpr elemSub args} {
    array set options {-final 1}
    catch {array set options $args}
    set options(-final) [Boolean $options(-final)]

    # If the data is not final then there must be a variable to store
    # unused data.
    if {!$options(-final) && ![info exists options(-statevariable)]} {
        return -code error {option "-statevariable" required if not final}
    }

    # Pre-process stage
    #
    # Extract the internal DTD subset, if any

    catch {upvar #0 $options(-internaldtdvariable) dtd}
    set intdtdref "\\&xml:intdtd;"
    while {[regexp {<!DOCTYPE[^[<]+\[([^]]+)\]} $sgml discard dtd2]} {
        append dtd $dtd2
        set text ""
        append text [string repeat "\n" [num_eols $dtd2]]
        regsub {(<!DOCTYPE[^[<]+)(\[[^]]+\])} $sgml "\\1$text$intdtdref" sgml
        set intdtdref ""
    }

    # Protect Tcl special characters
    regsub -all {([{}\\])} $sgml {\\\1} sgml

    # Do the translation

    if {[info exists options(-statevariable)]} {
        upvar #0 $opts(-statevariable) unused
        if {[info exists unused]} {
            regsub -all $elemExpr $unused$sgml $elemSub sgml
            unset unused
        } else {
            regsub -all $elemExpr $sgml $elemSub sgml
        }
        set sgml "{} {} {} {} \{$sgml\}"

        # Performance note (Tcl 8.0):
        #       Use of lindex, lreplace will cause parsing to list object

        if {[regexp {^([^<]*)(<[^>]*$)} [lindex $sgml end] x text unused]} {
            set sgml [lreplace $sgml end end $text]
        }

    } else {

        # Performance note (Tcl 8.0):
        #       In this case, no conversion to list object is performed

        regsub -all $elemExpr $sgml $elemSub sgml
        set sgml "{} {} {} {} \{$sgml\}"
    }

    return $sgml

}

# sgml::parseEvent --
#
#       Produces an event stream for a XML/HTML document,
#       given the Tcl list format returned by tokenise.
#
#       This procedure checks that the document is well-formed,
#       and throws an error if the document is found to be not
#       well formed.  Warnings are passed via the -warningcommand script.
#
#       The procedure only check for well-formedness,
#       no DTD is required.  However, facilities are provided for entity expansion.
#
# Arguments:
#       sgml            Instance data, as a Tcl list.
#       args            option/value pairs
#
# Valid Options:
#       -final                  Indicates end of document data
#       -elementstartcommand    Called when an element starts
#       -elementendcommand      Called when an element ends
#       -characterdatacommand   Called when character data occurs
#       -entityreferencecommand Called when an entity reference occurs
#       -processinginstructioncommand   Called when a PI occurs
#       -externalentityrefcommand       Called for an external entity reference
#
#       (Not compatible with expat)
#       -xmldeclcommand         Called when the XML declaration occurs
#       -doctypecommand         Called when the document type declaration occurs
#       -commentcommand         Called when a comment occurs
#
#       -errorcommand           Script to evaluate for a fatal error
#       -warningcommand         Script to evaluate for a reportable warning
#       -statevariable          global state variable
#       -normalize              whether to normalize names
#       -reportempty            whether to include an indication of empty elements
#
# Results:
#       The various callback scripts are invoked.
#       Returns empty string.
#
# BUGS:
#       If command options are set to empty string then they should not be invoked.

proc sgml::parseEvent {sgml args} {
    variable Wsp
    variable noWsp
    variable nmtoken
    variable name
    variable ParseEventNum

    array set options [list \
        -elementstartcommand            [namespace current]::noop       \
        -elementendcommand              [namespace current]::noop       \
        -characterdatacommand           [namespace current]::noop       \
        -processinginstructioncommand   [namespace current]::noop       \
        -externalentityrefcommand       [namespace current]::noop       \
        -xmldeclcommand                 [namespace current]::noop       \
        -doctypecommand                 [namespace current]::noop       \
        -commentcommand                 [namespace current]::noop       \
        -entityreferencecommand         {}                              \
        -warningcommand                 [namespace current]::noop       \
        -errorcommand                   [namespace current]::Error      \
        -final                          1                               \
        -emptyelement                   [namespace current]::EmptyElement       \
        -parseattributelistcommand      [namespace current]::noop       \
        -normalize                      1                               \
        -internaldtd                    {}                              \
        -reportempty                    0                               \
        -entityvariable                 [namespace current]::EntityPredef       \
    ]
    catch {array set options $args}

    if {![info exists options(-statevariable)]} {
        set options(-statevariable) [namespace current]::ParseEvent[incr ParseEventNum]
    }

    upvar #0 $options(-statevariable) state
    upvar #0 $options(-entityvariable) entities

    if {![info exists state]} {
        # Initialise the state variable
        array set state {
            mode normal
            haveXMLDecl 0
            haveDocElement 0
            context {}
            stack {}
            line 0
            lineo 0
            linet 0
        }
    }

    foreach {tag close empty param text} $sgml {

        # Keep track of lines (open, text, current/next) in the input
        set ::xdv::lineno $state(line)
        set state(lineo) $state(line)
        incr state(line) [regsub -all \n $param {} discard]
        set state(linet) $state(line)
        incr state(line) [regsub -all \n $text {} discard]

        # If the current mode is cdata or comment then we must undo what the
        # regsub has done to reconstitute the data

        switch $state(mode) {
            comment {
                # This had "[string length $param] && " as a guard -
                # can't remember why :-(
                if {[regexp ([cl ^-]*)--\$ $tag discard comm1]} {
                    # end of comment (in tag)
                    set tag {}
                    set close {}
                    set empty {}
                    set state(mode) normal
                    uplevel #0 $options(-commentcommand) [list $state(commentdata)<$comm1]
                    unset state(commentdata)
                } elseif {[regexp ([cl ^-]*)--\$ $param discard comm1]} {
                    # end of comment (in attributes)
                    uplevel #0 $options(-commentcommand) [list $state(commentdata)<$close$tag$empty>$comm1]
                    unset state(commentdata)
                    set tag {}
                    set param {}
                    set close {}
                    set empty {}
                    set state(mode) normal
                } elseif {[regexp ([cl ^-]*)-->(.*) $text discard comm1 text]} {
                    # end of comment (in text)
                    uplevel #0 $options(-commentcommand) [list $state(commentdata)<$close$tag$param$empty>$comm1]
                    unset state(commentdata)
                    set tag {}
                    set param {}
                    set close {}
                    set empty {}
                    set state(mode) normal
                } else {
                    # comment continues
                    append state(commentdata) <$close$tag$param$empty>$text
                    continue
                }
            }
            cdata {
                if {[string length $param] && [regexp ([cl ^\]]*)\]\][cl $Wsp]*\$ $tag discard cdata1]} {
                    # end of CDATA (in tag)
                    uplevel #0 $options(-characterdatacommand) [list $state(cdata)<$close$cdata1$text]
                    set text {}
                    set tag {}
                    unset state(cdata)
                    set state(mode) normal
                } elseif {[regexp ([cl ^\]]*)\]\][cl $Wsp]*\$ $param discard cdata1]} {
                    # end of CDATA (in attributes)
                    uplevel #0 $options(-characterdatacommand) [list $state(cdata)<$close$tag$cdata1$text]
                    set text {}
                    set tag {}
                    set param {}
                    unset state(cdata)
                    set state(mode) normal
                } elseif {[regexp ([cl ^\]]*)\]\][cl $Wsp]*>(.*) $text discard cdata1 text]} {
                    # end of CDATA (in text)
                    uplevel #0 $options(-characterdatacommand) [list $state(cdata)<$close$tag$param$empty>$cdata1$text]
                    set text {}
                    set tag {}
                    set param {}
                    set close {}
                    set empty {}
                    unset state(cdata)
                    set state(mode) normal
                } else {
                    # CDATA continues
                    append state(cdata) <$close$tag$param$empty>$text
                    continue
                }
            }
        }

        # default: normal mode

        # Bug: if the attribute list has a right angle bracket then the empty
        # element marker will not be seen

        set isEmpty [uplevel #0 $options(-emptyelement) [list $tag $param $empty]]
        if {[llength $isEmpty]} {
            foreach {empty tag param} $isEmpty break
        }

        switch -glob -- [string length $tag],[regexp {^\?|!.*} $tag],$close,$empty {

            0,0,, {
                # Ignore empty tag - dealt with non-normal mode above
            }
            *,0,, {

                # Start tag for an element.

                # Check for a right angle bracket in an attribute value
                # This manifests itself by terminating the value before
                # the delimiter is seen, and the delimiter appearing
                # in the text

                # BUG: If two or more attribute values have right angle
                # brackets then this will fail on the second one.

                if {[regexp [format {=[%s]*"[^"]*$} $Wsp] $param] && \
                        [regexp {([^"]*"[^>]*)>(.*)} $text discard attrListRemainder text]} {
                    append param >$attrListRemainder
                } elseif {[regexp [format {=[%s]*'[^']*$} $Wsp] $param] && \
                        [regexp {([^']*'[^>]*)>(.*)} $text discard attrListRemainder text]} {
                    append param >$attrListRemainder
                }

                # Check if the internal DTD entity is in an attribute
                # value
                regsub -all &xml:intdtd\; $param \[$options(-internaldtd)\] param

                ParseEvent:ElementOpen $tag $param options
                set state(haveDocElement) 1

            }

            *,0,/, {

                # End tag for an element.

                ParseEvent:ElementClose $tag options

            }

            *,0,,/ {

                # Empty element

                ParseEvent:ElementOpen $tag $param options -empty 1
                ParseEvent:ElementClose $tag options -empty 1

            }

            *,1,* {
                # Processing instructions or XML declaration
                switch -glob -- $tag {

                    {\?xml} {
                        # XML Declaration
                        if {$state(haveXMLDecl)} {
                            uplevel #0 $options(-errorcommand) "unexpected characters \"<$tag\" around line $state(lineo)"
                        } elseif {![regexp {\?$} $param]} {
                            uplevel #0 $options(-errorcommand) "XML Declaration missing characters \"?>\" around line $state(linet)"
                        } else {

                            # Get the version number
                            if {[regexp {[      ]*version="(-+|[a-zA-Z0-9_.:]+)"[       ]*} $param discard version] || [regexp {[       ]*version='(-+|[a-zA-Z0-9_.:]+)'[       ]*} $param discard version]} {
                                if {[string compare $version "1.0"]} {
                                    # Should we support future versions?
                                    # At least 1.X?
                                    uplevel #0 $options(-errorcommand) "document XML version \"$version\" is incompatible with XML version 1.0"
                                }
                            } else {
                                uplevel #0 $options(-errorcommand) "XML Declaration missing version information around line $state(lineo)"
                            }

                            # Get the encoding declaration
                            set encoding {}
                            regexp {[   ]*encoding="([A-Za-z]([A-Za-z0-9._]|-)*)"[      ]*} $param discard encoding
                            regexp {[   ]*encoding='([A-Za-z]([A-Za-z0-9._]|-)*)'[      ]*} $param discard encoding

                            # Get the standalone declaration
                            set standalone {}
                            regexp {[   ]*standalone="(yes|no)"[        ]*} $param discard standalone
                            regexp {[   ]*standalone='(yes|no)'[        ]*} $param discard standalone

                            # Invoke the callback
                            uplevel #0 $options(-xmldeclcommand) [list $version $encoding $standalone]

                        }

                    }

                    {\?*} {
                        # Processing instruction
                        if {   ![regsub {\?$} $param {} param]
                            && !(   ![string compare $param ""]
                                 && [regsub {\?$} $tag {} tag]
                                 && [string compare $tag ""])} {
                            uplevel #0 $options(-errorcommand) "PI: expected '?' character around line $state(linet)"
                        } else {
                            uplevel #0 $options(-processinginstructioncommand) [list [string range $tag 1 end] $param]
                        }
                    }

                    !DOCTYPE {
                        # External entity reference
                        # This should move into xml.tcl
                        # Parse the params supplied.  Looking for Name, ExternalID and MarkupDecl
                        regexp ^[cl $Wsp]*($name)(.*) $param x state(doc_name) param
                        set state(doc_name) [Normalize $state(doc_name) $options(-normalize)]
                        set externalID {}
                        set pubidlit {}
                        set systemlit {}
                        set externalID {}
                        if {[regexp -nocase ^[cl $Wsp]*(SYSTEM|PUBLIC)(.*) $param x id param]} {
                            switch [string toupper $id] {
                                SYSTEM {
                                    if {[regexp ^[cl $Wsp]+"([cl ^"]*)"(.*) $param x systemlit param] || [regexp ^[cl $Wsp]+'([cl ^']*)'(.*) $param x systemlit param]} {
                                        set externalID [list SYSTEM $systemlit] ;# "
                                    } else {
                                        uplevel #0 $options(-errorcommand) {{syntax error: SYSTEM identifier not followed by literal}}
                                    }
                                }
                                PUBLIC {
                                    if {[regexp ^[cl $Wsp]+"([cl ^"]*)"(.*) $param x pubidlit param] || [regexp ^[cl $Wsp]+'([cl ^']*)'(.*) $param x pubidlit param]} {
                                        if {[regexp ^[cl $Wsp]+"([cl ^"]*)"(.*) $param x systemlit param] || [regexp ^[cl $Wsp]+'([cl ^']*)'(.*) $param x systemlit param]} {
                                            set externalID [list PUBLIC $pubidlit $systemlit]
                                        } else {
                                            uplevel #0 $options(-errorcommand) "syntax error: PUBLIC identifier not followed by system literal around line $state(lineo)"
                                        }
                                    } else {
                                        uplevel #0 $options(-errorcommand) "syntax error: PUBLIC identifier not followed by literal around line $state(lineo)"
                                    }
                                }
                            }
                            if {[regexp -nocase ^[cl $Wsp]+NDATA[cl $Wsp]+($name)(.*) $param x notation param]} {
                                lappend externalID $notation
                            }
                        }

                        uplevel #0 $options(-doctypecommand) $state(doc_name) [list $pubidlit $systemlit $options(-internaldtd)]

                    }

                    !--* {

                        # Start of a comment
                        # See if it ends in the same tag, otherwise change the
                        # parsing mode

                        regexp {!--(.*)} $tag discard comm1
                        if {[regexp ([cl ^-]*)--[cl $Wsp]*\$ $comm1 discard comm1_1]} {
                            # processed comment (end in tag)
                            uplevel #0 $options(-commentcommand) [list $comm1_1]
                        } elseif {[regexp ([cl ^-]*)--[cl $Wsp]*\$ $param discard comm2]} {
                            # processed comment (end in attributes)
                            uplevel #0 $options(-commentcommand) [list $comm1$comm2]
                        } elseif {[regexp ([cl ^-]*)-->(.*) $text discard comm2 text]} {
                            # processed comment (end in text)
                            uplevel #0 $options(-commentcommand) [list $comm1$param>$comm2]
                        } else {
                            # start of comment
                            set state(mode) comment
                            set state(commentdata) "$comm1$param>$text"
                            continue
                        }
                    }

                    {!\[CDATA\[*} {

                        regexp {!\[CDATA\[(.*)} $tag discard cdata1
                        if {[regexp {(.*)]]$} $param discard cdata2]} {
                            # processed CDATA (end in attribute)
                            uplevel #0 $options(-characterdatacommand) [list $cdata1$cdata2$text]
                            set text {}
                        } elseif {[regexp {(.*)]]>(.*)} $text discard cdata2 text]} {
                            # processed CDATA (end in text)
                            uplevel #0 $options(-characterdatacommand) [list $cdata1$param$empty>$cdata2$text]
                            set text {}
                        } else {
                            # start CDATA
                            set state(cdata) "$cdata1$param>$text"
                            set state(mode) cdata
                            continue
                        }

                    }

                    !ELEMENT {
                        # Internal DTD declaration
                    }
                    !ATTLIST {
                    }
                    !ENTITY {
                    }
                    !NOTATION {
                    }


                    !* {
                        uplevel #0 $options(-processinginstructioncommand) [list $tag $param]
                    }
                    default {
                        uplevel #0 $options(-errorcommand) [list "unknown processing instruction \"<$tag>\" around line $state(lineo)"]
                    }
                }
            }
            *,1,* -
            *,0,/,/ {
                # Syntax error
                uplevel #0 $options(-errorcommand) [list [list syntax error: closed/empty tag: tag $tag param $param empty $empty close $close around line $state(lineo)]]
            }
        }

        # Process character data

        if {$state(haveDocElement) && [llength $state(stack)]} {

            # Check if the internal DTD entity is in the text
            regsub -all &xml:intdtd\; $text \[$options(-internaldtd)\] text

            # Look for entity references
            if {([array size entities] || [string length $options(-entityreferencecommand)]) && \
                [regexp {&[^;]+;} $text]} {

                # protect Tcl specials
                regsub -all {([][$\\])} $text {\\\1} text
                # Mark entity references
                regsub -all {&([^;]+);} $text [format {%s; %s {\1} ; %s %s} \}\} [namespace code [list Entity options $options(-entityreferencecommand) $options(-characterdatacommand) $options(-entityvariable)]] [list uplevel #0 $options(-characterdatacommand)] \{\{] text
                set text "uplevel #0 $options(-characterdatacommand) {{$text}}"
                eval $text
            } else {
                # Restore protected special characters
                regsub -all {\\([{}\\])} $text {\1} text
#                uplevel #0 $options(-characterdatacommand) [list $text]
                sgml::callback $state(lineo) \
                      $options(-characterdatacommand) [list $text]
            }
        } elseif {[string length [string trim $text]]} {
            uplevel #0 $options(-errorcommand) [list "unexpected text \"$text\" in document prolog around line $state(linet)"]
        }

    }

    # If this is the end of the document, close all open containers
    if {$options(-final) && [llength $state(stack)]} {
        eval $options(-errorcommand) [list [list element [lindex $state(stack) end] remains unclosed around line $state(line)]]
    }

    set ::xdv::lineno -1

    return {}
}

proc sgml::callback {lineno args} {
    global errorCode errorInfo

    set ::xdv::lineno $lineno
    if {[set code [catch { eval uplevel #0 $args } result]]} {
        append result " around line $lineno"
    }

    return -code $code -errorinfo $errorInfo -errorcode $errorCode $result
}

# sgml::ParseEvent:ElementOpen --
#
#       Start of an element.
#
# Arguments:
#       tag     Element name
#       attr    Attribute list
#       opts    Option variable in caller
#       args    further configuration options
#
# Options:
#       -empty boolean
#               indicates whether the element was an empty element
#
# Results:
#       Modify state and invoke callback

proc sgml::ParseEvent:ElementOpen {tag attr opts args} {
    upvar $opts options
    upvar #0 $options(-statevariable) state
    array set cfg {-empty 0}
    array set cfg $args

    if {$options(-normalize)} {
        set tag [string toupper $tag]
    }

    # Update state
    lappend state(stack) $tag

    # Parse attribute list into a key-value representation
    if {[string compare $options(-parseattributelistcommand) {}]} {
        if {[catch {uplevel #0 $options(-parseattributelistcommand) [list $attr]} attr]} {
            uplevel #0 $options(-errorcommand) [list $attr around line $state(lineo)]
            set attr {}
        }
    }

    set empty {}
    if {$cfg(-empty) && $options(-reportempty)} {
        set empty {-empty 1}
    }

    # Invoke callback
#    uplevel #0 $options(-elementstartcommand) [list $tag $attr] $empty
    sgml::callback $state(lineo) \
          $options(-elementstartcommand) [list $tag $attr] $empty

    return {}
}

# sgml::ParseEvent:ElementClose --
#
#       End of an element.
#
# Arguments:
#       tag     Element name
#       opts    Option variable in caller
#       args    further configuration options
#
# Options:
#       -empty boolean
#               indicates whether the element as an empty element
#
# Results:
#       Modify state and invoke callback

proc sgml::ParseEvent:ElementClose {tag opts args} {
    upvar $opts options
    upvar #0 $options(-statevariable) state
    array set cfg {-empty 0}
    array set cfg $args

    # WF check
    if {[string compare $tag [lindex $state(stack) end]]} {
        uplevel #0 $options(-errorcommand) [list "end tag \"$tag\" does not match open element \"[lindex $state(stack) end]\" around line $state(lineo)"]
        return
    }

    # Update state
    set state(stack) [lreplace $state(stack) end end]

    set empty {}
    if {$cfg(-empty) && $options(-reportempty)} {
        set empty {-empty 1}
    }

    # Invoke callback
#    uplevel #0 $options(-elementendcommand) [list $tag] $empty
    sgml::callback $state(lineo) \
          $options(-elementendcommand) [list $tag] $empty

    return {}
}

# sgml::Normalize --
#
#       Perform name normalization if required
#
# Arguments:
#       name    name to normalize
#       req     normalization required
#
# Results:
#       Name returned as upper-case if normalization required

proc sgml::Normalize {name req} {
    if {$req} {
        return [string toupper $name]
    } else {
        return $name
    }
}

# sgml::Entity --
#
#       Resolve XML entity references (syntax: &xxx;).
#
# Arguments:
#       opts            options array variable in caller
#       entityrefcmd    application callback for entity references
#       pcdatacmd       application callback for character data
#       entities        name of array containing entity definitions.
#       ref             entity reference (the "xxx" bit)
#
# Results:
#       Returns substitution text for given entity.

proc sgml::Entity {opts entityrefcmd pcdatacmd entities ref} {
    upvar 2 $opts options
    upvar #0 $options(-statevariable) state

    if {![string length $entities]} {
        set entities [namespace current EntityPredef]
    }

    switch -glob -- $ref {
        %* {
            # Parameter entity - not recognised outside of a DTD
        }
        #x* {
            # Character entity - hex
            if {[catch {format %c [scan [string range $ref 2 end] %x tmp; set tmp]} char]} {
                return -code error "malformed character entity \"$ref\""
            }
            uplevel #0 $pcdatacmd [list $char]

            return {}

        }
        #* {
            # Character entity - decimal
            if {[catch {format %c [scan [string range $ref 1 end] %d tmp; set tmp]} char]} {
                return -code error "malformed character entity \"$ref\""
            }
            uplevel #0 $pcdatacmd [list $char]

            return {}

        }
        default {
            # General entity
            upvar #0 $entities map
            if {[info exists map($ref)]} {

                if {![regexp {<|&} $map($ref)]} {

                    # Simple text replacement - optimise

                    uplevel #0 $pcdatacmd [list $map($ref)]

                    return {}

                }

                # Otherwise an additional round of parsing is required.
                # This only applies to XML, since HTML doesn't have general entities

                # Must parse the replacement text for start & end tags, etc
                # This text must be self-contained: balanced closing tags, and so on

                set tokenised [tokenise $map($ref) $::xml::tokExpr $::xml::substExpr]
                set final $options(-final)
                unset options(-final)
                eval parseEvent [list $tokenised] [array get options] -final 0
                set options(-final) $final

                return {}

            } elseif {[string length $entityrefcmd]} {

                uplevel #0 $entityrefcmd [list $ref]

                return {}

            }
        }
    }

    # If all else fails leave the entity reference untouched
    uplevel #0 $pcdatacmd [list &$ref\;]

    return {}
}

####################################
#
# DTD parser for SGML (XML).
#
# This DTD actually only handles XML DTDs.  Other language's
# DTD's, such as HTML, must be written in terms of a XML DTD.
#
# A DTD is represented as a three element Tcl list.
# The first element contains the content models for elements,
# the second contains the attribute lists for elements and
# the last element contains the entities for the document.
#
####################################

# sgml::parseDTD --
#
#       Entry point to the SGML DTD parser.
#
# Arguments:
#       dtd     data defining the DTD to be parsed
#       args    configuration options
#
# Results:
#       Returns a three element list, first element is the content model
#       for each element, second element are the attribute lists of the
#       elements and the third element is the entity map.

proc sgml::parseDTD {dtd args} {
    variable Wsp
    variable ParseDTDnum

    array set opts [list \
        -errorcommand           [namespace current]::noop \
        state                   [namespace current]::parseDTD[incr ParseDTDnum]
    ]
    array set opts $args

    set exp <!([cl ^$Wsp>]+)[cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*([cl ^>]*)>
    set sub {{\1} {\2} {\3} }
    regsub -all $exp $dtd $sub dtd

    foreach {decl id value} $dtd {
        catch {DTD:[string toupper $decl] $id $value} err
    }

    return [list [array get contentmodel] [array get attributes] [array get entities]]
}

# Procedures for handling the various declarative elements in a DTD.
# New elements may be added by creating a procedure of the form
# parse:DTD:_element_

# For each of these procedures, the various regular expressions they use
# are created outside of the proc to avoid overhead at runtime

# sgml::DTD:ELEMENT --
#
#       <!ELEMENT ...> defines an element.
#
#       The content model for the element is stored in the contentmodel array,
#       indexed by the element name.  The content model is parsed into the
#       following list form:
#
#               {}      Content model is EMPTY.
#                       Indicated by an empty list.
#               *       Content model is ANY.
#                       Indicated by an asterix.
#               {ELEMENT ...}
#                       Content model is element-only.
#               {MIXED {element1 element2 ...}}
#                       Content model is mixed (PCDATA and elements).
#                       The second element of the list contains the
#                       elements that may occur.  #PCDATA is assumed
#                       (ie. the list is normalised).
#
# Arguments:
#       id      identifier for the element.
#       value   other information in the PI

proc sgml::DTD:ELEMENT {id value} {
    dbgputs DTD_parse [list DTD:ELEMENT $id $value]
    variable Wsp
    upvar opts state
    upvar contentmodel cm

    if {[info exists cm($id)]} {
        eval $state(-errorcommand) element [list "element \"$id\" already declared"]
    } else {
        switch -- $value {
            EMPTY {
                set cm($id) {}
            }
            ANY {
                set cm($id) *
            }
            default {
                if {[regexp [format {^\([%s]*#PCDATA[%s]*(\|([^)]+))?[%s]*\)*[%s]*$} $Wsp $Wsp $Wsp $Wsp] discard discard mtoks]} {
                    set cm($id) [list MIXED [split $mtoks |]]
                } else {
                    if {[catch {CModelParse $state(state) $value} result]} {
                        eval $state(-errorcommand) element [list $result]
                    } else {
                        set cm($id) [list ELEMENT $result]
                    }
                }
            }
        }
    }
}

# sgml::CModelParse --
#
#       Parse an element content model (non-mixed).
#       A syntax tree is constructed.
#       A transition table is built next.
#
#       This is going to need alot of work!
#
# Arguments:
#       state   state array variable
#       value   the content model data
#
# Results:
#       A Tcl list representing the content model.

proc sgml::CModelParse {state value} {
    upvar #0 $state var

    # First build syntax tree
    set syntaxTree [CModelMakeSyntaxTree $state $value]

    # Build transition table
    set transitionTable [CModelMakeTransitionTable $state $syntaxTree]

    return [list $syntaxTree $transitionTable]
}

# sgml::CModelMakeSyntaxTree --
#
#       Construct a syntax tree for the regular expression.
#
#       Syntax tree is represented as a Tcl list:
#       rep {:choice|:seq {{rep list1} {rep list2} ...}}
#       where:  rep is repetition character, *, + or ?. {} for no repetition
#               listN is nested expression or Name
#
# Arguments:
#       spec    Element specification
#
# Results:
#       Syntax tree for element spec as nested Tcl list.
#
#       Examples:
#       (memo)
#               {} {:seq {{} memo}}
#       (front, body, back?)
#               {} {:seq {{} front} {{} body} {? back}}
#       (head, (p | list | note)*, div2*)
#               {} {:seq {{} head} {* {:choice {{} p} {{} list} {{} note}} } {* div2}}
#       (p | a | ul)+
#               + {:choice {{} p} {{} a} {{} ul}}

proc sgml::CModelMakeSyntaxTree {state spec} {
    upvar #0 $state var
    variable Wsp
    variable name

    # Translate the spec into a Tcl list.

    # None of the Tcl special characters are allowed in a content model spec.
    if {[regexp {\$|\[|\]|\{|\}} $spec]} {
        return -code error "illegal characters in specification"
    }

    regsub -all [format {(%s)[%s]*(\?|\*|\+)?[%s]*(,|\|)?} $name $Wsp $Wsp] $spec [format {%sCModelSTname %s {\1} {\2} {\3}} \n $state] spec
    regsub -all {\(} $spec "\nCModelSTopenParen $state " spec
    regsub -all [format {\)[%s]*(\?|\*|\+)?[%s]*(,|\|)?} $Wsp $Wsp] $spec [format {%sCModelSTcloseParen %s {\1} {\2}} \n $state] spec

    array set var {stack {} state start}
    eval $spec

    # Peel off the outer seq, its redundant
    return [lindex [lindex $var(stack) 1] 0]
}

# sgml::CModelSTname --
#
#       Processes a name in a content model spec.
#
# Arguments:
#       state   state array variable
#       name    name specified
#       rep     repetition operator
#       cs      choice or sequence delimiter
#
# Results:
#       See CModelSTcp.

proc sgml::CModelSTname {state name rep cs args} {
    if {[llength $args]} {
        return -code error "syntax error in specification: \"$args\""
    }

    CModelSTcp $state $name $rep $cs
}

# sgml::CModelSTcp --
#
#       Process a content particle.
#
# Arguments:
#       state   state array variable
#       name    name specified
#       rep     repetition operator
#       cs      choice or sequence delimiter
#
# Results:
#       The content particle is added to the current group.

proc sgml::CModelSTcp {state cp rep cs} {
    upvar #0 $state var

    switch -glob -- [lindex $var(state) end]=$cs {
        start= {
            set var(state) [lreplace $var(state) end end end]
            # Add (dummy) grouping, either choice or sequence will do
            CModelSTcsSet $state ,
            CModelSTcpAdd $state $cp $rep
        }
        :choice= -
        :seq= {
            set var(state) [lreplace $var(state) end end end]
            CModelSTcpAdd $state $cp $rep
        }
        start=| -
        start=, {
            set var(state) [lreplace $var(state) end end [expr {$cs == "," ? ":seq" : ":choice"}]]
            CModelSTcsSet $state $cs
            CModelSTcpAdd $state $cp $rep
        }
        :choice=| -
        :seq=, {
            CModelSTcpAdd $state $cp $rep
        }
        :choice=, -
        :seq=| {
            return -code error "syntax error in specification: incorrect delimiter after \"$cp\", should be \"[expr {$cs == "," ? "|" : ","}]\""
        }
        end=* {
            return -code error "syntax error in specification: no delimiter before \"$cp\""
        }
        default {
            return -code error "syntax error"
        }
    }

}

# sgml::CModelSTcsSet --
#
#       Start a choice or sequence on the stack.
#
# Arguments:
#       state   state array
#       cs      choice oir sequence
#
# Results:
#       state is modified: end element of state is appended.

proc sgml::CModelSTcsSet {state cs} {
    upvar #0 $state var

    set cs [expr {$cs == "," ? ":seq" : ":choice"}]

    if {[llength $var(stack)]} {
        set var(stack) [lreplace $var(stack) end end $cs]
    } else {
        set var(stack) [list $cs {}]
    }
}

# sgml::CModelSTcpAdd --
#
#       Append a content particle to the top of the stack.
#
# Arguments:
#       state   state array
#       cp      content particle
#       rep     repetition
#
# Results:
#       state is modified: end element of state is appended.

proc sgml::CModelSTcpAdd {state cp rep} {
    upvar #0 $state var

    if {[llength $var(stack)]} {
        set top [lindex $var(stack) end]
        lappend top [list $rep $cp]
        set var(stack) [lreplace $var(stack) end end $top]
    } else {
        set var(stack) [list $rep $cp]
    }
}

# sgml::CModelSTopenParen --
#
#       Processes a '(' in a content model spec.
#
# Arguments:
#       state   state array
#
# Results:
#       Pushes stack in state array.

proc sgml::CModelSTopenParen {state args} {
    upvar #0 $state var

    if {[llength $args]} {
        return -code error "syntax error in specification: \"$args\""
    }

    lappend var(state) start
    lappend var(stack) [list {} {}]
}

# sgml::CModelSTcloseParen --
#
#       Processes a ')' in a content model spec.
#
# Arguments:
#       state   state array
#       rep     repetition
#       cs      choice or sequence delimiter
#
# Results:
#       Stack is popped, and former top of stack is appended to previous element.

proc sgml::CModelSTcloseParen {state rep cs args} {
    upvar #0 $state var

    if {[llength $args]} {
        return -code error "syntax error in specification: \"$args\""
    }

    set cp [lindex $var(stack) end]
    set var(stack) [lreplace $var(stack) end end]
    set var(state) [lreplace $var(state) end end]
    CModelSTcp $state $cp $rep $cs
}

# sgml::CModelMakeTransitionTable --
#
#       Given a content model's syntax tree, constructs
#       the transition table for the regular expression.
#
#       See "Compilers, Principles, Techniques, and Tools",
#       Aho, Sethi and Ullman.  Section 3.9, algorithm 3.5.
#
# Arguments:
#       state   state array variable
#       st      syntax tree
#
# Results:
#       The transition table is returned, as a key/value Tcl list.

proc sgml::CModelMakeTransitionTable {state st} {
    upvar #0 $state var

    # Construct nullable, firstpos and lastpos functions
    array set var {number 0}
    foreach {nullable firstpos lastpos} [       \
        TraverseDepth1st $state $st {
            # Evaluated for leaf nodes
            # Compute nullable(n)
            # Compute firstpos(n)
            # Compute lastpos(n)
            set nullable [nullable leaf $rep $name]
            set firstpos [list {} $var(number)]
            set lastpos [list {} $var(number)]
            set var(pos:$var(number)) $name
        } {
            # Evaluated for nonterminal nodes
            # Compute nullable, firstpos, lastpos
            set firstpos [firstpos $cs $firstpos $nullable]
            set lastpos  [lastpos  $cs $lastpos  $nullable]
            set nullable [nullable nonterm $rep $cs $nullable]
        }       \
    ] break

    set accepting [incr var(number)]
    set var(pos:$accepting) #

    # var(pos:N) maps from position to symbol.
    # Construct reverse map for convenience.
    # NB. A symbol may appear in more than one position.
    # var is about to be reset, so use different arrays.

    foreach {pos symbol} [array get var pos:*] {
        set pos [lindex [split $pos :] 1]
        set pos2symbol($pos) $symbol
        lappend sym2pos($symbol) $pos
    }

    # Construct the followpos functions
    catch {unset var}
    followpos $state $st $firstpos $lastpos

    # Construct transition table
    # Dstates is [union $marked $unmarked]
    set unmarked [list [lindex $firstpos 1]]
    while {[llength $unmarked]} {
        set T [lindex $unmarked 0]
        lappend marked $T
        set unmarked [lrange $unmarked 1 end]

        # Find which input symbols occur in T
        set symbols {}
        foreach pos $T {
            if {$pos != $accepting && [lsearch $symbols $pos2symbol($pos)] < 0} {
                lappend symbols $pos2symbol($pos)
            }
        }
        foreach a $symbols {
            set U {}
            foreach pos $sym2pos($a) {
                if {[lsearch $T $pos] >= 0} {
                    # add followpos($pos)
                    if {$var($pos) == {}} {
                        lappend U $accepting
                    } else {
                        eval lappend U $var($pos)
                    }
                }
            }
            set U [makeSet $U]
            if {[llength $U] && [lsearch $marked $U] < 0 && [lsearch $unmarked $U] < 0} {
                lappend unmarked $U
            }
            set Dtran($T,$a) $U
        }

    }

    return [list [array get Dtran] [array get sym2pos] $accepting]
}

# sgml::followpos --
#
#       Compute the followpos function, using the already computed
#       firstpos and lastpos.
#
# Arguments:
#       state           array variable to store followpos functions
#       st              syntax tree
#       firstpos        firstpos functions for the syntax tree
#       lastpos         lastpos functions
#
# Results:
#       followpos functions for each leaf node, in name/value format

proc sgml::followpos {state st firstpos lastpos} {
    upvar #0 $state var

    switch -- [lindex [lindex $st 1] 0] {
        :seq {
            for {set i 1} {$i < [llength [lindex $st 1]]} {incr i} {
                followpos $state [lindex [lindex $st 1] $i]                     \
                        [lindex [lindex $firstpos 0] [expr $i - 1]]     \
                        [lindex [lindex $lastpos 0] [expr $i - 1]]
                foreach pos [lindex [lindex [lindex $lastpos 0] [expr $i - 1]] 1] {
                    eval lappend var($pos) [lindex [lindex [lindex $firstpos 0] $i] 1]
                    set var($pos) [makeSet $var($pos)]
                }
            }
        }
        :choice {
            for {set i 1} {$i < [llength [lindex $st 1]]} {incr i} {
                followpos $state [lindex [lindex $st 1] $i]                     \
                        [lindex [lindex $firstpos 0] [expr $i - 1]]     \
                        [lindex [lindex $lastpos 0] [expr $i - 1]]
            }
        }
        default {
            # No action at leaf nodes
        }
    }

    switch -- [lindex $st 0] {
        ? {
            # We having nothing to do here ! Doing the same as
            # for * effectively converts this qualifier into the other.
        }
        * {
            foreach pos [lindex $lastpos 1] {
                eval lappend var($pos) [lindex $firstpos 1]
                set var($pos) [makeSet $var($pos)]
            }
        }
    }

}

# sgml::TraverseDepth1st --
#
#       Perform depth-first traversal of a tree.
#       A new tree is constructed, with each node computed by f.
#
# Arguments:
#       state   state array variable
#       t       The tree to traverse, a Tcl list
#       leaf    Evaluated at a leaf node
#       nonTerm Evaluated at a nonterminal node
#
# Results:
#       A new tree is returned.

proc sgml::TraverseDepth1st {state t leaf nonTerm} {
    upvar #0 $state var

    set nullable {}
    set firstpos {}
    set lastpos {}

    switch -- [lindex [lindex $t 1] 0] {
        :seq -
        :choice {
            set rep [lindex $t 0]
            set cs [lindex [lindex $t 1] 0]

            foreach child [lrange [lindex $t 1] 1 end] {
                foreach {childNullable childFirstpos childLastpos} \
                        [TraverseDepth1st $state $child $leaf $nonTerm] break
                lappend nullable $childNullable
                lappend firstpos $childFirstpos
                lappend lastpos  $childLastpos
            }

            eval $nonTerm
        }
        default {
            incr var(number)
            set rep [lindex [lindex $t 0] 0]
            set name [lindex [lindex $t 1] 0]
            eval $leaf
        }
    }

    return [list $nullable $firstpos $lastpos]
}

# sgml::firstpos --
#
#       Computes the firstpos function for a nonterminal node.
#
# Arguments:
#       cs              node type, choice or sequence
#       firstpos        firstpos functions for the subtree
#       nullable        nullable functions for the subtree
#
# Results:
#       firstpos function for this node is returned.

proc sgml::firstpos {cs firstpos nullable} {
    switch -- $cs {
        :seq {
            set result [lindex [lindex $firstpos 0] 1]
            for {set i 0} {$i < [llength $nullable]} {incr i} {
                if {[lindex [lindex $nullable $i] 1]} {
                    eval lappend result [lindex [lindex $firstpos [expr $i + 1]] 1]
                } else {
                    break
                }
            }
        }
        :choice {
            foreach child $firstpos {
                eval lappend result $child
            }
        }
    }

    return [list $firstpos [makeSet $result]]
}

# sgml::lastpos --
#
#       Computes the lastpos function for a nonterminal node.
#       Same as firstpos, only logic is reversed
#
# Arguments:
#       cs              node type, choice or sequence
#       lastpos         lastpos functions for the subtree
#       nullable        nullable functions forthe subtree
#
# Results:
#       lastpos function for this node is returned.

proc sgml::lastpos {cs lastpos nullable} {
    switch -- $cs {
        :seq {
            set result [lindex [lindex $lastpos end] 1]
            for {set i [expr [llength $nullable] - 1]} {$i >= 0} {incr i -1} {
                if {[lindex [lindex $nullable $i] 1]} {
                    eval lappend result [lindex [lindex $lastpos $i] 1]
                } else {
                    break
                }
            }
        }
        :choice {
            foreach child $lastpos {
                eval lappend result $child
            }
        }
    }

    return [list $lastpos [makeSet $result]]
}

# sgml::makeSet --
#
#       Turn a list into a set, ie. remove duplicates.
#
# Arguments:
#       s       a list
#
# Results:
#       A set is returned, which is a list with duplicates removed.

proc sgml::makeSet s {
    foreach r $s {
        if {[llength $r]} {
            set unique($r) {}
        }
    }
    return [array names unique]
}

# sgml::nullable --
#
#       Compute the nullable function for a node.
#
# Arguments:
#       nodeType        leaf or nonterminal
#       rep             repetition applying to this node
#       name            leaf node: symbol for this node, nonterm node: choice or seq node
#       subtree         nonterm node: nullable functions for the subtree
#
# Results:
#       Returns nullable function for this branch of the tree.

proc sgml::nullable {nodeType rep name {subtree {}} } {
    switch -glob -- $rep:$nodeType {
        :leaf -
        +:leaf {
            return [list {} 0]
        }
        \\*:leaf -
        \\?:leaf {
            return [list {} 1]
        }
        \\*:nonterm -
        \\?:nonterm {
            return [list $subtree 1]
        }
        :nonterm -
        +:nonterm {
            switch -- $name {
                :choice {
                    set result 0
                    foreach child $subtree {
                        set result [expr $result || [lindex $child 1]]
                    }
                }
                :seq {
                    set result 1
                    foreach child $subtree {
                        set result [expr $result && [lindex $child 1]]
                    }
                }
            }
            return [list $subtree $result]
        }
    }
}

# These regular expressions are defined here once for better performance

namespace eval sgml {
    variable Wsp

    # Watch out for case-sensitivity

    set attlist_exp [cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*(#REQUIRED|#IMPLIED)
    set attlist_enum_exp [cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*\\(([cl ^)]*)\\)[cl $Wsp]*("([cl ^")])")? ;# "
    set attlist_fixed_exp [cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*(#FIXED)[cl $Wsp]*([cl ^$Wsp]+)

    set param_entity_exp [cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*([cl ^"$Wsp]*)[cl $Wsp]*"([cl ^"]*)"

    set notation_exp [cl $Wsp]*([cl ^$Wsp]+)[cl $Wsp]*(.*)

}

# sgml::DTD:ATTLIST --
#
#       <!ATTLIST ...> defines an attribute list.
#
# Arguments:
#       id      Element an attribute list is being defined for.
#       value   data from the PI.
#
# Results:
#       Attribute list variables are modified.

proc sgml::DTD:ATTLIST {id value} {
    variable attlist_exp
    variable attlist_enum_exp
    variable attlist_fixed_exp
    dbgputs DTD_parse [list DTD:ATTLIST $id $value]
    upvar opts state
    upvar attributes am

    if {[info exists am($id)]} {
        eval $state(-errorcommand) attlist [list "attribute list for element \"$id\" already declared"]
    } else {
        # Parse the attribute list.  If it were regular, could just use foreach,
        # but some attributes may have values.
        regsub -all {([][$\\])} $value {\\\1} value
        regsub -all $attlist_exp $value {[DTDAttribute {\1} {\2} {\3}]} value
        regsub -all $attlist_enum_exp $value {[DTDAttribute {\1} {\2} {\3}]} value
        regsub -all $attlist_fixed_exp $value {[DTDAttribute {\1} {\2} {\3} {\4}]} value
        subst $value
        set am($id) [array get attlist]
    }
}

# sgml::DTDAttribute --
#
#       Parse definition of a single attribute.
#
# Arguments:
#       name    attribute name
#       type    type of this attribute
#       default default value of the attribute
#       value   other information

proc sgml::DTDAttribute {name type default {value {}} } {
    upvar attlist al
    # This needs further work
    set al($name) [list $default $value]
}

# sgml::DTD:ENTITY --
#
#       <!ENTITY ...> PI
#
# Arguments:
#       id      identifier for the entity
#       value   data
#
# Results:
#       Modifies the caller's entities array variable

proc sgml::DTD:ENTITY {id value} {
    variable param_entity_exp
    dbgputs DTD_parse [list DTD:ENTITY $id $value]
    upvar opts state
    upvar entities ents

    if {[string compare % $id]} {
        # Entity declaration
        if {[info exists ents($id)]} {
            eval $state(-errorcommand) entity [list "entity \"$id\" already declared"]
        } else {
            if {![regexp {"([^"]*)"} $value x entvalue] && ![regexp {'([^']*)'} $value x entvalue]} {
                eval $state(-errorcommand) entityvalue [list "entity value \"$value\" not correctly specified"]
            } ;# "
            set ents($id) $entvalue
        }
    } else {
        # Parameter entity declaration
        switch -glob [regexp $param_entity_exp $value x name scheme data],[string compare {} $scheme] {
            0,* {
                eval $state(-errorcommand) entityvalue [list "parameter entity \"$value\" not correctly specified"]
            }
            *,0 {
                # SYSTEM or PUBLIC declaration
            }
            default {
                set ents($id) $data
            }
        }
    }
}

# sgml::DTD:NOTATION --

proc sgml::DTD:NOTATION {id value} {
    variable notation_exp
    upvar opts state

    if {[regexp $notation_exp $value x scheme data] == 2} {
    } else {
        eval $state(-errorcommand) notationvalue [list "notation value \"$value\" incorrectly specified"]
    }
}

### Utility procedures

# sgml::noop --
#
#       A do-nothing proc
#
# Arguments:
#       args    arguments
#
# Results:
#       Nothing.

proc sgml::noop args {
    return 0
}

# sgml::identity --
#
#       Identity function.
#
# Arguments:
#       a       arbitrary argument
#
# Results:
#       $a

proc sgml::identity a {
    return $a
}

# sgml::Error --
#
#       Throw an error
#
# Arguments:
#       args    arguments
#
# Results:
#       Error return condition.

proc sgml::Error args {
    uplevel return -code error [list $args]
}

### Following procedures are based on html_library

# sgml::zapWhite --
#
#       Convert multiple white space into a single space.
#
# Arguments:
#       data    plain text
#
# Results:
#       As above

proc sgml::zapWhite data {
    regsub -all "\[ \t\r\n\]+" $data { } data
    return $data
}

proc sgml::Boolean value {
    regsub {1|true|yes|on} $value 1 value
    regsub {0|false|no|off} $value 0 value
    return $value
}

proc sgml::dbgputs {where text} {
    variable dbg

    catch {if {$dbg} {puts stdout "DBG: $where ($text)"}}
}


#       }}}2 sgml.tcl
#       {{{2 xml.tcl

# xml.tcl --
#
#       This file provides XML services.
#       These services include a XML document instance and DTD parser,
#       as well as support for generating XML.
#
# Copyright (c) 1998,1999 Zveno Pty Ltd
# http://www.zveno.com/
#
# Zveno makes this software and all associated data and documentation
# ('Software') available free of charge for non-commercial purposes only. You
# may make copies of the Software but you must include all of this notice on
# any copy.
#
# The Software was developed for research purposes and Zveno does not warrant
# that it is error free or fit for any purpose.  Zveno disclaims any
# liability for all claims, expenses, losses, damages and costs any user may
# incur as a result of using, copying or modifying the Software.
#
# Copyright (c) 1997 Australian National University (ANU).
#
# ANU makes this software and all associated data and documentation
# ('Software') available free of charge for non-commercial purposes only. You
# may make copies of the Software but you must include all of this notice on
# any copy.
#
# The Software was developed for research purposes and ANU does not warrant
# that it is error free or fit for any purpose.  ANU disclaims any
# liability for all claims, expenses, losses, damages and costs any user may
# incur as a result of using, copying or modifying the Software.
#
# $Id$

package provide xml 1.8

# package require sgml 1.6

namespace eval xml {

    # Procedures for parsing XML documents
    namespace export parser
    # Procedures for parsing XML DTDs
    namespace export DTDparser

    # Counter for creating unique parser objects
    variable ParserCounter 0

    # Convenience routine
    proc cl x {
        return "\[$x\]"
    }

    # Define various regular expressions
    # white space
    variable Wsp " \t\r\n"
    variable noWsp [cl ^$Wsp]

    # Various XML names and tokens

    # BUG: NameChar does not include CombiningChar or Extender
    variable NameChar [cl -a-zA-Z0-9._:]
    variable Name [cl a-zA-Z_:]$NameChar*
    variable Nmtoken $NameChar+

    # Tokenising expressions

    variable tokExpr <(/?)([cl ^$Wsp>]+)([cl $Wsp]*[cl ^>]*)>
    variable substExpr "\}\n{\\2} {\\1} {} {\\3} \{"

    # table of predefined entities

    variable EntityPredef
    array set EntityPredef {
        lt <   gt >   amp &   quot \"   apos '
    }

}


# xml::parser --
#
#       Creates XML parser object.
#
# Arguments:
#       args    Unique name for parser object
#               plus option/value pairs
#
# Recognised Options:
#       -final                  Indicates end of document data
#       -elementstartcommand    Called when an element starts
#       -elementendcommand      Called when an element ends
#       -characterdatacommand   Called when character data occurs
#       -processinginstructioncommand   Called when a PI occurs
#       -externalentityrefcommand       Called for an external entity reference
#
#       (Not compatible with expat)
#       -xmldeclcommand         Called when the XML declaration occurs
#       -doctypecommand         Called when the document type declaration occurs
#
#       -errorcommand           Script to evaluate for a fatal error
#       -warningcommand         Script to evaluate for a reportable warning
#       -statevariable          global state variable
#       -reportempty            whether to provide empty element indication
#
# Results:
#       The state variable is initialised.

proc xml::parser {args} {
    variable ParserCounter

    if {[llength $args] > 0} {
        set name [lindex $args 0]
        set args [lreplace $args 0 0]
    } else {
        set name parser[incr ParserCounter]
    }

    if {[info command [namespace current]::$name] != {}} {
        return -code error "unable to create parser object \"[namespace current]::$name\" command"
    }

    # Initialise state variable and object command
    upvar \#0 [namespace current]::$name parser
    set sgml_ns [namespace parent]::sgml
    array set parser [list name $name                   \
        -final 1                                        \
        -elementstartcommand ${sgml_ns}::noop           \
        -elementendcommand ${sgml_ns}::noop             \
        -characterdatacommand ${sgml_ns}::noop          \
        -processinginstructioncommand ${sgml_ns}::noop  \
        -externalentityrefcommand ${sgml_ns}::noop      \
        -xmldeclcommand ${sgml_ns}::noop                \
        -doctypecommand ${sgml_ns}::noop                \
        -warningcommand ${sgml_ns}::noop                \
        -statevariable [namespace current]::$name       \
        -reportempty 0                                  \
        internaldtd {}                                  \
    ]

    proc [namespace current]::$name {method args} \
        "eval ParseCommand $name \$method \$args"

    eval ParseCommand [list $name] configure $args

    return [namespace current]::$name
}

# xml::ParseCommand --
#
#       Handles parse object command invocations
#
# Valid Methods:
#       cget
#       configure
#       parse
#       reset
#
# Arguments:
#       parser  parser object
#       method  minor command
#       args    other arguments
#
# Results:
#       Depends on method

proc xml::ParseCommand {parser method args} {
    upvar \#0 [namespace current]::$parser state

    switch -- $method {
        cget {
            return $state([lindex $args 0])
        }
        configure {
            foreach {opt value} $args {
                set state($opt) $value
            }
        }
        parse {
            ParseCommand_parse $parser [lindex $args 0]
        }
        reset {
            if {[llength $args]} {
                return -code error "too many arguments"
            }
            ParseCommand_reset $parser
        }
        default {
            return -code error "unknown method \"$method\""
        }
    }

    return {}
}

# xml::ParseCommand_parse --
#
#       Parses document instance data
#
# Arguments:
#       object  parser object
#       xml     data
#
# Results:
#       Callbacks are invoked, if any are defined

proc xml::ParseCommand_parse {object xml} {
    upvar \#0 [namespace current]::$object parser
    variable Wsp
    variable tokExpr
    variable substExpr

    set parent [namespace parent]
    if {![string compare :: $parent]} {
        set parent {}
    }

    set tokenised [lrange \
            [${parent}::sgml::tokenise $xml \
            $tokExpr \
            $substExpr \
            -internaldtdvariable [namespace current]::${object}(internaldtd)] \
        5 end]

    eval ${parent}::sgml::parseEvent \
        [list $tokenised \
            -emptyelement [namespace code ParseEmpty] \
            -parseattributelistcommand [namespace code ParseAttrs]] \
        [array get parser -*command] \
        [array get parser -entityvariable] \
        [array get parser -reportempty] \
        -normalize 0 \
        -internaldtd [list $parser(internaldtd)]

    return {}
}

# xml::ParseEmpty --
#
#       Used by parser to determine whether an element is empty.
#       This should be dead easy in XML.  The only complication is
#       that the RE above can't catch the trailing slash, so we have
#       to dig it out of the tag name or attribute list.
#
#       Tcl 8.1 REs should fix this.
#
# Arguments:
#       tag     element name
#       attr    attribute list (raw)
#       e       End tag delimiter.
#
# Results:
#       "/" if the trailing slash is found.  Optionally, return a list
#       containing new values for the tag name and/or attribute list.

proc xml::ParseEmpty {tag attr e} {

    if {[string match */ [string trimright $tag]] && \
            ![string length $attr]} {
        regsub {/$} $tag {} tag
        return [list / $tag $attr]
    } elseif {[string match */ [string trimright $attr]]} {
        regsub {/$} [string trimright $attr] {} attr
        return [list / $tag $attr]
    } else {
        return {}
    }

}

# xml::ParseAttrs --
#
#       Parse element attributes.
#
# There are two forms for name-value pairs:
#
#       name="value"
#       name='value'
#
# Watch out for the trailing slash on empty elements.
#
# Arguments:
#       attrs   attribute string given in a tag
#
# Results:
#       Returns a Tcl list representing the name-value pairs in the
#       attribute string

proc xml::ParseAttrs attrs {
    variable Wsp
    variable Name

    # First check whether there's any work to do
    if {![string compare {} [string trim $attrs]]} {
        return {}
    }

    # Strip the trailing slash on empty elements
    regsub [format {/[%s]*$} " \t\n\r"] $attrs {} atList

    set mode name
    set result {}
    foreach component [split $atList =] {
        switch $mode {
            name {
                set component [string trim $component]
                if {[regexp $Name $component]} {
                    lappend result $component
                } else {
                    return -code error "invalid attribute name \"$component\""
                }
                set mode value:start
            }
            value:start {
                set component [string trimleft $component]
                set delimiter [string index $component 0]
                set value {}
                switch -- $delimiter {
                    \" -
                    ' {
                        if {[regexp [format {%s([^%s]*)%s(.*)} $delimiter $delimiter $delimiter] $component discard value remainder]} {
                            lappend result $value
                            set remainder [string trim $remainder]
                            if {[string length $remainder]} {
                                if {[regexp $Name $remainder]} {
                                    lappend result $remainder
                                    set mode value:start
                                } else {
                                    return -code error "invalid attribute name \"$remainder\""
                                }
                            } else {
                                set mode end
                            }
                        } else {
                            set value [string range $component 1 end]
                            set mode value:continue
                        }
                    }
                    default {
                        return -code error "invalid value for attribute \"[lindex $result end]\""
                    }
                }
            }
            value:continue {
                if {[regexp [format {([^%s]*)%s(.*)} $delimiter $delimiter] $component discard valuepart remainder]} {
                    append value = $valuepart
                    lappend result $value
                    set remainder [string trim $remainder]
                    if {[string length $remainder]} {
                        if {[regexp $Name $remainder]} {
                            lappend result $remainder
                            set mode value:start
                        } else {
                            return -code error "invalid attribute name \"$remainder\""
                        }
                    } else {
                        set mode end
                    }
                } else {
                    append value = $component
                }
            }
            end {
                return -code error "unexpected data found after end of attribute list"
            }
        }
    }

    switch $mode {
        name -
        end {
            # This is normal
        }
        default {
            return -code error "unexpected end of attribute list"
        }
    }

    return $result
}

proc xml::OLDParseAttrs {attrs} {
    variable Wsp
    variable Name

    # First check whether there's any work to do
    if {![string compare {} [string trim $attrs]]} {
        return {}
    }

    # Strip the trailing slash on empty elements
    regsub [format {/[%s]*$} " \t\n\r"] $attrs {} atList

    # Protect Tcl special characters
    #regsub -all {([[\$\\])} $atList {\\\1} atList
    regsub -all & $atList {\&amp;} atList
    regsub -all {\[} $atList {\&ob;} atList
    regsub -all {\]} $atList {\&cb;} atlist
    # NB. sgml package delivers braces and backslashes quoted
    regsub -all {\\\{} $atList {\&oc;} atList
    regsub -all {\\\}} $atList {\&cc;} atlist
    regsub -all {\$} $atList {\&dollar;} atList
    regsub -all {\\\\} $atList {\&bs;} atList

    regsub -all [format {(%s)[%s]*=[%s]*"([^"]*)"} $Name $Wsp $Wsp] \
            $atList {[set parsed(\1) {\2}; set dummy {}] } atList       ;# "
    regsub -all [format {(%s)[%s]*=[%s]*'([^']*)'} $Name $Wsp $Wsp] \
            $atList {[set parsed(\1) {\2}; set dummy {}] } atList

    set leftovers [subst $atList]

    if {[string length [string trim $leftovers]]} {
        return -code error "syntax error in attribute list \"$attrs\""
    }

    return [ParseAttrs:Deprotect [array get parsed]]
}

# xml::ParseAttrs:Deprotect --
#
#       Reverse map Tcl special characters previously protected
#
# Arguments:
#       attrs   attribute list
#
# Results:
#       Characters substituted

proc xml::ParseAttrs:Deprotect attrs {

    regsub -all &amp\; $attrs \\& attrs
    regsub -all &ob\; $attrs \[ attrs
    regsub -all &cb\; $attrs \] attrs
    regsub -all &oc\; $attrs \{ attrs
    regsub -all &cc\; $attrs \} attrs
    regsub -all &dollar\; $attrs \$ attrs
    regsub -all &bs\; $attrs \\\\ attrs

    return $attrs

}

# xml::ParseCommand_reset --
#
#       Initialize parser data
#
# Arguments:
#       object  parser object
#
# Results:
#       Parser data structure initialised

proc xml::ParseCommand_reset object {
    upvar \#0 [namespace current]::$object parser

    array set parser [list \
            -final 1            \
            internaldtd {}      \
    ]
}

# xml::noop --
#
# A do-nothing proc

proc xml::noop args {}

### Following procedures are based on html_library

# xml::zapWhite --
#
#       Convert multiple white space into a single space.
#
# Arguments:
#       data    plain text
#
# Results:
#       As above

proc xml::zapWhite data {
    regsub -all "\[ \t\r\n\]+" $data { } data
    return $data
}

#
# DTD parser for XML is wholly contained within the sgml.tcl package
#

# xml::parseDTD --
#
#       Entry point to the XML DTD parser.
#
# Arguments:
#       dtd     XML data defining the DTD to be parsed
#       args    configuration options
#
# Results:
#       Returns a three element list, first element is the content model
#       for each element, second element are the attribute lists of the
#       elements and the third element is the entity map.

proc xml::parseDTD {dtd args} {
    return [eval [expr {[namespace parent] == {::} ? {} : [namespace parent]}]::sgml::parseDTD [list $dtd] $args]
}


#       }}}2 xml.tcl
#   }}}1 TclXML 1.1.1 (modified)

#   {{{1 textutil package (unless externally available)


if {[catch { package require textutil }]} {
namespace eval textutil {
    namespace export strRepeat

    variable HaveStrRepeat [ expr {![ catch { string repeat a 1 } ]} ]

    if {0} {
        # Problems with the deactivated code:
        # - Linear in 'num'.
        # - Tests for 'string repeat' in every call!
        #   (Ok, just the variable, still a test every call)
        # - Fails for 'num == 0' because of undefined 'str'.

        proc StrRepeat { char num } {
            variable HaveStrRepeat
            if { $HaveStrRepeat == 0 } then {
                for { set i 0 } { $i < $num } { incr i } {
                    append str $char
                }
            } else {
                set str [ string repeat $char $num ]
            }
            return $str
        }
    }
}

if {$::textutil::HaveStrRepeat} {
    proc ::textutil::strRepeat {char num} {
        return [string repeat $char $num]
    }
} else {
    proc ::textutil::strRepeat {char num} {
        if {$num <= 0} {
            # No replication required
            return ""
        } elseif {$num == 1} {
            # Quick exit for recursion
            return $char
        } elseif {$num == 2} {
            # Another quick exit for recursion
            return $char$char
        } elseif {0 == ($num % 2)} {
            # Halving the problem results in O (log n) complexity.
            set result [strRepeat $char [expr {$num / 2}]]
            return "$result$result"
        } else {
            # Uneven length, reduce problem by one
            return "$char[strRepeat $char [incr num -1]]"
        }
    }
}


#source [ file join [ file dirname [ info script ] ] adjust.tcl ]
#source [ file join [ file dirname [ info script ] ] split.tcl ]
#source [ file join [ file dirname [ info script ] ] tabify.tcl ]
#source [ file join [ file dirname [ info script ] ] trim.tcl ]
namespace eval ::textutil {

    namespace eval adjust {

        variable StrRepeat [ namespace parent ]::strRepeat
        variable Justify  left
        variable Length   72
        variable FullLine 0
        variable StrictLength 0

        namespace export adjust

        # This will be redefined later. We need it just to let
        # a chance for the next import subcommand to work
        #
        proc adjust { text args } { }

    }

    namespace import -force adjust::adjust
    namespace export adjust

}

#########################################################################

proc ::textutil::adjust::adjust { text args } {

    if { [ string length [ string trim $text ] ] == 0 } then {
        return ""
    }

    Configure $args
    Adjust text newtext

    return $newtext
}

proc ::textutil::adjust::Configure { args } {
    variable Justify   left
    variable Length    72
    variable FullLine  0
    variable StrictLength 0

    set args [ lindex $args 0 ]
    foreach { option value } $args {
        switch -exact -- $option {
            -full {
                if { ![ StringIsBoolean -strict $value ] } then {
                    error "expected boolean but got \"$value\""
                }
                set FullLine [ StringIsTrue $value ]
            }
            -justify {
                set lovalue [ string tolower $value ]
                switch -exact -- $lovalue {
                    left -
                    right -
                    center -
                    plain {
                        set Justify $lovalue
                    }
                    default {
                        error "bad value \"$value\": should be center, left, plain or right"
                    }
                }
            }
            -length {
                if { ![ StringIsInteger $value ] } then {
                    error "expected positive integer but got \"$value\""
                }
                if { $value < 1 } then {
                    error "expected positive integer but got \"$value\""
                }
                set Length $value
            }
            -strictlength {
                if { ![ StringIsBoolean -strict $value ] } then {
                    error "expected boolean but got \"$value\""
                }
                set StrictLength [ StringIsTrue $value ]
            }
            default {
                error "bad option \"$option\": must be -full, -justify, -length, or -strictlength"
            }
        }
    }

    return ""
}

proc ::textutil::adjust::StringIsBoolean { arg value } {
    switch -- [string tolower $value] {
        0 - false - no - off { return 1 }
        default { return [StringIsTrue $value] }
    }
}

proc ::textutil::adjust::StringIsTrue { value } {
    switch -- [string tolower $value] {
        1 - true - yes - on { return 1 }
        default { return 0 }
    }
}

proc ::textutil::adjust::StringIsInteger { value } {
    if {[catch { incr value }]} {
        return 0
    }
    return 1
}

proc ::textutil::adjust::Adjust { varOrigName varNewName } {
    variable Length
    variable StrictLength

    upvar $varOrigName orig
    upvar $varNewName  text

    regsub -all -- "(\n)|(\t)"     $orig  " "  text
    regsub -all -- " +"            $text  " "  text
    regsub -all -- "(^ *)|( *\$)"  $text  ""   text

    set ltext [ split $text ]

    if { $StrictLength } then {

        # Limit the length of a line to $Length. If any single
        # word is long than $Length, then split the word into multiple
        # words.

        set i 0
        foreach tmpWord $ltext {
            if { [ string length $tmpWord ] > $Length } then {

                # Since the word is longer than the line length,
                # remove the word from the list of words.  Then
                # we will insert several words that are less than
                # or equal to the line length in place of this word.

                set ltext [ lreplace $ltext $i $i ]
                incr i -1
                set j 0

                # Insert a series of shorter words in place of the
                # one word that was too long.

                while { $j < [ string length $tmpWord ] } {

                    # Calculate the end of the string range for this word.

                    if { [ expr { [string length $tmpWord ] - $j } ] > $Length } then {
                        set end [ expr { $j + $Length - 1} ]
                    } else {
                        set end [ string length $tmpWord ]
                    }

                    set ltext [ linsert $ltext [ expr {$i + 1} ] [ string range $tmpWord $j $end ] ]
                    incr i
                    incr j [ expr { $end - $j + 1 } ]
                }
            }
            incr i
        }
    }

    set line [ lindex $ltext 0 ]
    set pos [ string length $line ]
    set text ""
    set numline 0
    set numword 1
    set words(0) 1
    set words(1) [ list $pos $line ]

    foreach word [ lrange $ltext 1 end ] {
        set size [ string length $word ]
        if { ( $pos + $size ) < $Length } then {
            append line " $word"
            incr numword
            incr words(0)
            set words($numword) [ list $size $word ]
            incr pos
            incr pos $size
        } else {
            if { [ string length $text ] != 0 } then {
                append text "\n"
            }
            append text [ Justification $line [ incr numline ] words ]
            set line "$word"
            set pos $size
            catch { unset words }
            set numword 1
            set words(0) 1
            set words(1) [ list $size $word ]
        }
    }
    if { [ string length $text ] != 0 } then {
        append text "\n"
    }
    append text [ Justification $line end words ]

    return $text
}

proc ::textutil::adjust::Justification { line index arrayName } {
    variable Justify
    variable Length
    variable FullLine
    variable StrRepeat

    upvar $arrayName words

    set len [ string length $line ]
    if { $Length == $len } then {
        return $line
    }

    # Special case:
    # for the last line, and if the justification is set to 'plain'
    # the real justification is 'left' if the length of the line
    # is less than 90% (rounded) of the max length allowed. This is
    # to avoid expansion of this line when it is too small: without
    # it, the added spaces will 'unbeautify' the result.
    #

    set justify $Justify
    if { ( "$index" == "end" ) && \
             ( "$Justify" == "plain" ) && \
             ( $len < round($Length * 0.90) ) } then {
        set justify left
    }

    # For a left justification, nothing to do, but to
    # add some spaces at the end of the line if requested
    #

    if { "$justify" == "left" } then {
        set jus ""
        if { $FullLine } then {
            set jus [ $StrRepeat " " [ expr { $Length - $len } ] ]
        }
        return "${line}${jus}"
    }

    # For a right justification, just add enough spaces
    # at the beginning of the line
    #

    if { "$justify" == "right" } then {
        set jus [ $StrRepeat " " [ expr { $Length - $len } ] ]
        return "${jus}${line}"
    }

    # For a center justification, add half of the needed spaces
    # at the beginning of the line, and the rest at the end
    # only if needed.

    if { "$justify" == "center" } then {
        set mr [ expr { ( $Length - $len ) / 2 } ]
        set ml [ expr { $Length - $len - $mr } ]
        set jusl [ $StrRepeat " " $ml ]
        set jusr [ $StrRepeat " " $mr ]
        if { $FullLine } then {
            return "${jusl}${line}${jusr}"
        } else {
            return "${jusl}${line}"
        }
    }

    # For a plain justiciation, it's a little bit complex:
    # if some spaces are missing, then
    # sort the list of words in the current line by
    # decreasing size
    # foreach word, add one space before it, except if
    # it's the first word, until enough spaces are added
    # then rebuild the line
    #

    if { "$justify" == "plain" } then {
        set miss [ expr { $Length - [ string length $line ] } ]
        if { $miss == 0 } then {
            return "${line}"
        }

        for { set i 1 } { $i < $words(0) } { incr i } {
            lappend list [ eval list $i $words($i) 1 ]
        }
        lappend list [ eval list $i $words($words(0)) 0 ]
        set list [ SortList $list decreasing 1 ]

        set i 0
        while { $miss > 0 } {
            set elem [ lindex $list $i ]
            set nb [ lindex $elem 3 ]
            incr nb
            set elem [ lreplace $elem 3 3 $nb ]
            set list [ lreplace $list $i $i $elem ]
            incr miss -1
            incr i
            if { $i == $words(0) } then {
                set i 0
            }
        }
        set list [ SortList $list increasing 0 ]
        set line ""
        foreach elem $list {
            set jus [ $StrRepeat " " [ lindex $elem 3 ] ]
            set word [ lindex $elem 2 ]
            if { [ lindex $elem 0 ] == $words(0) } then {
                append line "${jus}${word}"
            } else {
                append line "${word}${jus}"
            }
        }

        return "${line}"
    }

    error "Illegal justification key \"$justify\""
}

proc ::textutil::adjust::SortList { list dir index } {

    if { [ catch { lsort -integer -$dir -index $index $list } sl ] != 0 } then {
        error "$sl"
    }

    return $sl
}
}

#   }}}1 textutil package (unless externally available)

#   {{{1 Top-level parsing


global parser
if {![info exists parser]} {
    set parser ""
}

proc xml2rfc {input {output ""} {remote ""} {cdP 1}} {
    global prog
    global errorCode errorInfo
    global parser
    global passno
    global passmax
    global errorP
    global ifile mode unpaginated ofile
    global out_fd
    global remoteP
    global xml2rfc_warnings

    set xml2rfc_warnings ""
    if {![string compare [file extension $input] ""]} {
        append input .xml
    }

    set inputD [file dirname [set ifile $input]]
    if {$cdP} {
        catch { cd $inputD }
    }

    if {![string compare $output ""]} {
        set output [file rootname $input].txt
    }
    if {[string compare $remote ""]} {
        set ofile $remote
        set remoteP 1
    } else {
        set ofile $output
        set remoteP 0
    }
    set ofile [file rootname [file tail $ofile]]

    if {![string compare $input $output]} {
        error "input and output files must be different"
    }

    if {[file exists [set file [file join $inputD .$prog.rc]]]} {
        catch { source $file }
    }

    unex_init
    set unpaginated 0
    switch -- [set mode [string range [file extension $output] 1 end]] {
        html - nr - txt {}

        unpg {
            set unpaginated 1
            set mode txt
        }

        xml {}

        default {
            error "unsupported output type: $mode"
        }
    }

    set code [catch {
        set in_fd [open $input { RDONLY }]
        catch { fconfigure $in_fd -encoding binary -translation lf }
        set data [prexml [read $in_fd]]
        catch { close $in_fd }
        set in_fd ""

        if {![string compare $mode xml]} {
            global prog_version
            set out_fd [open $output { WRONLY CREAT TRUNC }]
            catch { fconfigure $out_fd -encoding utf-8 }

            set comment [clock format [clock seconds] \
                            -format "<!-- automatically generated by $prog $prog_version on %Y-%m-%dT%H:%M:%SZ -->" \
                            -gmt true]
            regsub {\n} $data "\n$comment\n" data
            puts -nonewline $out_fd $data

            catch { close $out_fd }
            set out_fd ""

            # break from catch
            break
        }

        if {![string compare $parser ""]} {
            global emptyA

            set parser [xml::parser]
            catch { array unset emptyA }

            $parser configure \
                        -elementstartcommand          { begin               } \
                        -elementendcommand            { end                 } \
                        -characterdatacommand         { pcdata              } \
                        -processinginstructioncommand { pi                  } \
                        -xmldeclcommand               { xmldecl             } \
                        -doctypecommand               { doctype             } \
                        -entityreferencecommand       ""                      \
                        -errorcommand                 { unexpected error    } \
                        -warningcommand               { unexpected warning  } \
                        -entityvariable               emptyA                  \
                        -final                        1                       \
                        -reportempty                  0
        }

        set errorP 0
        set passmax 2
        set out_fd ""
        for {set passno 1} {$passno <= $passmax} {incr passno} {
            if {$passno >= 6} {
                error "too many passes (document doesn't stabilize)"
            }
            if {$passno >= 2} {
                set out_fd [open $output { WRONLY CREAT TRUNC }]
                catch { fconfigure $out_fd -encoding utf-8 }
            }
            pass start
            $parser parse $data
            pass end
            catch { close $out_fd }
            set out_fd ""
            if {$errorP} {
                break
            }
        }
    } result]
    set ecode $errorCode
    set einfo $errorInfo

    catch { close $in_fd }
    set in_fd ""
    catch { close $out_fd }
    set out_fd ""

    if {$code == 3} {
        # break ($mode == xml)
        set code 0
    } elseif {$code == 1} {
        set result [around2fl $result]

        catch {
            global stack
            global guiP

            if {[set i [llength $stack]] > 0} {
                set text \
  "Context (format:  \"file_basename:line_in_file:#elem_num:<elem ...>\"):"
                while {$i > 0} {
                    set frame [lindex $stack [incr i -1]]
                    set attrs 0; unset attrs
                    array set attrs [list av ""]
                    array set attrs [lrange $frame 1 end]
                    append text "\n    "
                    append text [linefile::get_fake_file $attrs(fnum) 1]:
                    append text $attrs(line):#$attrs(elemN):
                    append text "<[lindex $frame 0]"
                    foreach {k v} $attrs(av) {
                        regsub -all -- \" $v {\&quot;} v
                        append text " $k=\"$v\""
                    }
                    append text ">"
                }
                append result "\n\n$text"
                if {$guiP < 0} {
                    append result "\n$einfo"
                }
            }
        }
    }

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

proc xml2txt {input} {
    xml2rfc $input [file rootname $input].txt
}

proc xml2html {input} {
    xml2rfc $input [file rootname $input].html
}

proc xml2nroff {input} {
    return [xml2rfc $input [file rootname $input].nr]
###
    puts stderr "making xml->txt"
    xml2rfc $input [file rootname $input].txt
    file rename -force [file rootname $input].txt  [file rootname $input].orig

    puts stderr "making xml->rf"
    xml2rfc $input [file rootname $input].nr

    puts stderr "making rf->txt"
    exec nroff -ms < [file rootname $input].nr \
       | /usr/users/mrose/docs/fix.pl \
       | sed -e 1,3d \
       > [file rootname $input].txt
}

proc xml2unpg {input} {
    xml2rfc $input [file rootname $input].unpg
}

proc xml2ref {input output {formats {}} {item ""}} {
    global prog
    global errorCode errorInfo

    if {![string compare $input $output]} {
        error "input and output files must be different"
    }

    if {[file exists [set file [file join [set inputD [file dirname $input]] \
                                          .$prog.rc]]]} {
        source $file
    }

    set refT [ref::init]
    if {[set code [catch { ref::transform $refT $input $formats } result]]} {
        set ecode $errorCode
        set einfo $errorInfo

        catch { ref::fin $refT }

        return -code $code -errorinfo $einfo -errorcode $ecode $result
    }
    ref::fin $refT

    array set ref $result

    set out_fd [open $output { WRONLY CREAT TRUNC }]
    catch { fconfigure $out_fd -encoding utf-8 }

    set code [catch {
        puts -nonewline $out_fd $ref(body)
        flush $out_fd
    } result]
    set ecode $errorCode
    set einfo $errorInfo

    catch { close $out_fd }
    set out_fd ""

    if {($code == 0) \
            && ([string compare $item ""]) \
            && ([string compare $ref(info) ""])} {
        set out_fd [open $item { WRONLY CREAT TRUNC }]
        catch { fconfigure $out_fd -encoding utf-8 }

        set code [catch {
            puts -nonewline $out_fd $ref(info)
            flush $out_fd
        } result]
        set ecode $errorCode
        set einfo $errorInfo

        catch { close $out_fd }
        set out_fd ""

        #catch { file mtime $item $ref(mtime) }
    }

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}


#   }}}1 Top-level parsing

#   {{{1 XML preprocessor
#       {{{2 Some XML preprocessor globals

global httpP
if {[catch { package require http 2 }]} {
    set httpP 0
} else {
    set httpP 1
    catch {
        package require autoproxy
        autoproxy::init
    }
    # Make sure it's auto-loaded before attempting to modify its variable.
    ::http::config
    set ::http::defaultCharset unknown
}

proc check_vrsn {} {
    global env
    global guiP
    global prog_version prog_url

    if {[info exists env(DOCUMENT_ROOT)]} {
        return
    }
    if {$guiP == 1} {
        update
    }

    if {[string first "pre" $prog_version] > 0} {
        set file beta
    } else {
        set file version
    }

    catch {
        ::http::geturl ${prog_url}authoring/$file \
                       -command check_vrsn_command -timeout 3000
    }
}

proc check_vrsn_idle {} {
    catch { update }
}

proc check_vrsn_command {token} {
    global guiP
    global prog prog_version

    upvar #0 $token state

    if {($state(status) == "ok") \
            && ([::http::ncode $token] == 200) \
            && ([string compare $prog_version \
                        [set body [string trim $state(body)]]]) < 0} {
        set text "$body is now available, you are running $prog_version"
        if {$guiP != 1} {
            puts stdout "$prog: $text"
        } else {
            set w .fyi

            catch { destroy $w }
            toplevel    $w -class Dialog
            wm title    $w "$prog: fyi"
            wm iconname $w Dialog

            frame  $w.top
            pack   $w.top -side    top    -fill both  -expand 1
            frame  $w.bot
            pack   $w.bot -side    bottom -fill both
            label  $w.msg -justify left   -text $text
            pack   $w.msg -side    right  -fill both  -expand 1 \
                          -in      $w.top -padx 3m    -pady   3m
            label  $w.bmp -bitmap  info
            pack   $w.bmp -side    left \
                          -in      $w.top -padx 3m    -pady   3m
            button $w.bye -text    Dismiss \
                          -command "destroy $w"
            pack   $w.bye -in      $w.bot
        }
    }
    catch { ::http::cleanup $token }
}


global xml_library_path
set xml_library_path {.}

#       }}}2 Some XML preprocessor globals
#       {{{2 XML preprocessor entry function

proc prexml {stream} {
    global env tcl_platform
    global intentities extentities extfiles exturis
    global xml_library_path
    global ifile

    if {[catch { set xml_library_path $env(XML_LIBRARY) }]} {
        set xml_library_path [list [file dirname $ifile]]
    }
    switch -- $tcl_platform(platform) {
        windows { set c ";" }
        default { set c ":" }
    }
    set xml_library_path [split $xml_library_path $c]

    set stream [prexml_cdata $stream]
    set ifnum [linefile::new_file $ifile $ifile]

    catch { array unset intentities }
    catch { array unset extentities }
    catch { array unset extfiles }
    catch { array unset exturis }

    if {   [regexp -- {^<\?xml[ \t\r\n]} $stream]
        && ([set plen [string first "?>" $stream]] >= 0)} {

        set XMLDecl [string range $stream 0 [incr plen]]
        set stream [string range $stream [incr plen] end]
    } else {
        error "input file \"$ifile\" does not begin with an XML declaration"
    }

    set stream [prexml_convert $XMLDecl $stream $ifile]
    # Now that we are in UTF-8.
    set stream [str_norm_eol $stream \
                [expr   [regexp -- {[ \t\r\n]version="1\.[1-9][0-9]*"} $XMLDecl] \
                     || [regexp -- {[ \t\r\n]version='1\.[1-9][0-9]*'} $XMLDecl]]]

    linefile::init

    set n [num_eols $XMLDecl]
    set XMLDecl "<?xml version=\"1.0\" encoding=\"UTF-8\"[string repeat \n $n]?>"

    linefile::push_fnum $ifnum
    return $XMLDecl[prexml_stream $stream [expr 1 + $n]]
}

#       }}}2 XML preprocessor entry function
#       {{{2 XML preprocessor initial conversions

proc prexml_convert {XMLDecl stream file {default_charset UTF-8}} {
    if {   [regexp -- {[ \t\r\n]encoding="([A-Za-z][A-Za-z0-9._-]*)"} $XMLDecl x charset]
        || [regexp -- {[ \t\r\n]encoding='([A-Za-z][A-Za-z0-9._-]*)'} $XMLDecl x charset]
        || [string compare [set charset $default_charset] ""]} {
            if {![string compare [set enc [cs2enc $charset]] ""]} {
                set enc ascii
                unexpected warning \
  "unknown encoding/charset \"$charset\" in XML declaration of file \"$file\"; trying US-ASCII"
            }
    } else {
        set enc utf-8
    }

    catch { set stream [encoding convertfrom $enc $stream] }
    return $stream
}

proc prexml_cdata {stream} {
    set litN [string length [set litS "<!\[CDATA\["]]
    set litO [string length [set litT "\]\]>"]]

    set data ""
    while {[set x [string first $litS $stream]] >= 0} {
        append data [string range $stream 0 [expr $x-1]]
        set stream [string range $stream [expr $x+$litN] end]
        if {[set x [string first $litT $stream]] < 0} {
            error "missing close to CDATA"
        }
        set y [string range $stream 0 [expr $x-1]]
        regsub -all -- {&} $y {\&amp;} y
        regsub -all -- {<} $y {\&lt;}  y
        regsub -all -- {>} $y {\&gt;}  y
        append data $y
        set stream [string range $stream [expr $x+$litO] end]
    }
    append data $stream

    return $data
}

#       }}}2 XML preprocessor initial conversions
#       {{{2 XML preprocessor stream (file) handling

proc prexml_stream {stream {myline 1} {no_initial_pi 0}} {
    # Uses uplevel proc prexml_error.
    # Uses uplevel proc prexml_flush_blank.
    # Uses uplevel proc prexml_flush_new.
    # Uses uplevel proc prexml_flush_pi.
    # Uses uplevel proc prexml_flush_includes.
    # Uses uplevel proc prexml_prep_entity.

    global extentities intentities

    if {[info level] > 32} {
        error "recursion detected in XML preprocessing of included files and entities"
    }

    # Some useful regexp literals.
    set wsp  {[ \t\r\n]}
    set dqev \"(\[^\"\]*)\"
    set sqev \'(\[^\'\]*)\'
    set nme  {([A-Za-z_:][A-Za-z0-9._:-]*)}
    set rem  (.*)

    set myfnum [linefile::get_real_fnum]
    if {$no_initial_pi} {
        set data ""
    } else {
        set data [linefile::make_pi $myfnum $myline 1]
    }

    # We don't modify stream but scan across it and build data.

    for {
        # Loop Initialization.
        set pending_pi 0
        set new_data ""
        set new_lines 0
        set blank_lines 0
        set includes ""
        set start 0

        # Loop test.
    } {[regexp -indices -start $start -- {<\?rfc|<!ENTITY|&} $stream x]} {

        # Loop continuation.
        prexml_flush_new
        prexml_flush_includes
    } {
        # Loop body.
        set a [lindex $x 0]
        set b [lindex $x 1]
        set m [string range $stream $a $b]
        if {$a > $start} {
            prexml_flush_blank
            prexml_flush_pi
            set initial [string range $stream $start [expr $a - 1]]
            incr myline [num_eols $initial]
            append data $initial
            unset initial
        }
        incr b
        switch -- $m {
            <?rfc {
                if {![regexp -indices -start $b -- {\?>} $stream x]} {
                    prexml_error "missing close to $m"
                }
                set c [lindex $x 0]
                set pi [string range $stream $b [expr $c - 1]]
                incr new_lines [num_eols $pi]
                set start [incr c 2]
                # We'll normally append new_data later,
                # after $pi has been tweaked.
                if {![regexp -- ^$wsp $pi]} {
                    append new_data $m $pi ?>
                    continue
                }
                prexml_flush_pi
                set kept_pi_dirs 0
                set pil [string length $pi]
                set pi2 $pi
                while {1} {
                    set pi2s [expr $pil - [set pi2l [string length $pi2]]]
                    foreach {key val pi2} [pi_rfc_next $pi2] {break}
                    if {![string compare $key ""]} {
                        global mode

                        # We may be able to provide a better message later.
                        if {   [string compare $val ""]
                            && ![string compare $mode xml]} {
                            prexml_error "stopped preprocessing faulty rfc-PI at \"$val\""
                        }
                        # This makes sure the faulty rfc-PI is kept for later stages.
                        incr kept_pi_dirs
                        break
                    }
                    switch -- $key {
                        include {
                            set pi [streplace $pi $pi2s [expr $pi2l - [string length $pi2] + 1] "" 3]
                            foreach {fnum include charset} [prexml_find $val] {break}

                            set include [prexml_tweak_include $include $fnum $charset]
                            if {[string compare $include ""]} {
                                linefile::push_fnum $fnum
                                append includes [prexml_stream $include 1]
                                linefile::pop_fake_fnum
                            }
                        }

                        linefile {
                            incr kept_pi_dirs
                            if {![regexp -- {^([0-9]+)(:(.*))?$} \
                                         $val a b c d]} {
                                # Type of message must not attempt to
                                # supply its own line information which
                                # is not set up at this point.
                                unexpected warning \
  "ignoring invalid rfc-PI linefile-directive value \"$val\" around input line $myline in \"[linefile::get_fake_file $myfnum]\""
                                continue
                            }
                            prexml_flush_blank
                            if {[string length $c]} {
                                # May be empty.  User's choice!
                                set new_myfile $d
                            }
                            set new_myline $b
                        }

                        default {
                            incr kept_pi_dirs
                        }
                    }
                }

                # Do this after processing the whole PI so that
                # intermixed error or warning messages are not affected.
                if {[info exists new_myline]} {
                    if {[info exists new_myfile]} {
                        set myfnum [linefile::set_file $new_myfile]
                        unset new_myfile
                    }
                    set myline $new_myline
                    unset new_myline
                    set new_lines 0
                }

                if {$kept_pi_dirs} {
                    prexml_flush_blank
                    append new_data $m $pi ?>
                } else {
                    incr blank_lines $new_lines
                    set new_lines 0
                }
            }

            <!ENTITY {
                if {![regexp -indices -start $b -- {>} $stream x]} {
                    prexml_error "missing close to $m"
                }
                set c [lindex $x 0]
                set entdecl [string range $stream $b [expr $c - 1]]
                set n [num_eols $entdecl]
                set start [incr c]
                if {![regexp -- ^$wsp $entdecl]} {
                    append new_data $m $entdecl >
                    incr new_lines $n
                    continue
                }
                if {$n} {
                    prexml_flush_pi
                }
                # These are _new_ blank lines.
                incr blank_lines $n
                set entdecl [string trimleft $entdecl]

                if {[string first "%" $entdecl] == 0} {
                    set entdecl [string trimleft [string range $entdecl 1 end]]
                    unexpected warning "treating parameter entity as parsed (remove % in entity declaration)"
                }
                if {![regexp -- ^$nme$rem $entdecl x entity entdef]} {
                    prexml_error "expecting $m entity-name ..."
                }
                append new_data "<!-- xml2rfc-processed-entity " $entity " -->"

                if {   [regexp -- ^$wsp+$dqev$rem $entdef x arg1 y]
                    || [regexp -- ^$wsp+$sqev$rem $entdef x arg1 y]} {
                    set fnum $myfnum
                    set include [prexml_cdata $arg1]
                    set line [expr $myline + $new_lines + $blank_lines \
                                   - [num_eols $include$y]]
                    set intentities($entity) [prexml_prep_entity]
                    continue
                }

                if {![regexp -nocase -- \
                             ^$wsp*(SYSTEM|PUBLIC)$rem \
                             $entdef x idtype entid]} {
                    prexml_error \
  "expecting $m $entity SYSTEM, PUBLIC, 'def', or \"def\""
                }
                if {   ![regexp -- ^$wsp+$dqev$rem $entid x arg1 arg2]
                    && ![regexp -- ^$wsp+$sqev$rem $entid x arg1 arg2]} {
                    prexml_error "expecting literal after $m $entity $idtype"
                }
                set idtype [string toupper $idtype]
                switch -- $idtype {
                    SYSTEM {
                        set l [prexml_find $arg1]
                    }

                    PUBLIC {
                        if {   ![regexp -- ^$wsp+$dqev $arg2 z arg2]
                            && ![regexp -- ^$wsp+$sqev $arg2 z arg2]} {
                            prexml_error "expecting literal after $m $entity $idtype"
                        }
                        set l [prexml_find $arg2]
                    }
                }
                foreach {fnum include charset} $l {break}
                set include [prexml_tweak_include $include $fnum $charset]
                set line 1
                set extentities($entity) [prexml_prep_entity]
            }

            & {
                set start $b
                if {![regexp -indices -start $b -- {;} $stream x]} {
                    append new_data &
                    continue
                }
                set c [lindex $x 0]
                set entity [string trim [string range $stream $b [expr $c - 1]]]
                if {[info exists intentities($entity)]} {
                    set l $intentities($entity)
                } elseif {[info exists extentities($entity)]} {
                    set l $extentities($entity)
                } else {
                    append new_data &
                    continue
                }
                foreach {inc_fnum inc_line include end_fnum} $l {break}
                if {[string compare $include ""]} {
                    append includes [linefile::make_pi $inc_fnum $inc_line]
                    append includes $include
                    linefile::set_fake_fnum $end_fnum
                }
                set start [incr c]
            }
        }
    }

    prexml_flush_blank
    if {$start < [string length $stream]} {
        prexml_flush_pi
        append data [string range $stream $start end]
    }

    return $data
}

#       }}}2 XML preprocessor stream (file) handling
#       {{{2 Uplevel procs meant for use by prexml_stream

proc prexml_error {e} {
    upvar myfnum myfnum myline myline

    error "$e around input line $myline in \"[linefile::get_fake_file $myfnum]\""
}

proc prexml_flush_blank {} {
    uplevel 1 {
        if {$blank_lines} {
            incr myline $blank_lines
            append data <!-- [string repeat "\n" $blank_lines] -->
            set blank_lines 0
        }
    }
}

proc prexml_flush_new {} {
    uplevel 1 {
        if {[string compare $new_data ""]} {
            prexml_flush_blank
            prexml_flush_pi
            incr myline $new_lines
            append data $new_data
            set new_data ""
            set new_lines 0
        }
    }
}

proc prexml_flush_pi {} {
    uplevel 1 {
        if {$pending_pi} {
            prexml_flush_blank
            append data [linefile::make_pi $myfnum $myline]
            set pending_pi 0
        }
    }
}

proc prexml_flush_includes {} {
    uplevel 1 {
        if {[string compare $includes ""]} {
            prexml_flush_blank
            append data $includes
            set includes ""
            set pending_pi 1
        }
    }
}

proc prexml_prep_entity {} {
    uplevel 1 {
        if {[string compare $include ""]} {
            linefile::push_fnum $fnum
            set include [prexml_stream $include $line 1]
            set end_fnum [linefile::pop_fake_fnum]
        } else {
            set end_fnum $myfnum
        }
        return [list $fnum $line $include $end_fnum]
    }
}

#       }}}2 Uplevel procs meant for use by prexml_stream
#       {{{2 Regular, non-uplevel, support procs for prexml_stream.

proc prexml_find {uf} {
    # Remote absolute path.
    if {[string first "http://" $uf] == 0} {
        return [prexml_find_uri $uf $uf]
    }

    # Local absolute path.
    if {![string compare [file pathtype $uf] absolute]} {
        set f [file_normalize $uf]
        return [prexml_find_file $uf $f]
    }

    set fulldir [linefile::get_real_fulldir]

    # Local fulldir + relative path.
    if {[string first "://" $fulldir] < 0} {
        set f [file_normalize [file join $fulldir $uf]]
        if {![catch { set v [prexml_find_file $uf $f] }]} {
            return $v
        }
    }

    # Scan XML_LIBRARY directories.
    global xml_library_path
    foreach dir $xml_library_path {
        set f [file_normalize [file join $dir $uf]]
        if {![catch { set v [prexml_find_file $uf $f] }]} {
            return $v
        }
    }

    # Remote fulldir + relative path.  (Go to network last.)
    if {[string first "http://" $fulldir] == 0} {
        set u $fulldir/$uf
        while {[regsub -- {^([^?#]*[^/?#])/\./} $u {\1/} u]} {}
        while {[regsub -expanded -- {^([^?#]*[^/?#])
                                     /([^/?#]
                                      |[^/?#][^/?#.]
                                      |[^/?#.][^/?#]
                                      |[^/?#]{3,})
                                     /\.\./} $u {\1/} u]} {}
        while {[regsub -- {^([^?#]*[^/?#])/\.\./} $u {\1/} u]} {}
        return [prexml_find_uri $uf $u]
    }

    error "unable to find external file \"$uf\" or \"$uf.xml\""
}

proc file_normalize {path} {
    if {![catch { file normalize $path } result]} {
        return $result
    }

# we could do a lot of work here, but we won't...

    switch -- [string range $path 0 0] {
        "/" {
        }

        "~" {
            set comps [file split $path]
            set path [eval file join [glob [lindex $comps 0]] \
                                     [lrange $comps 1 end]]
        }

        default {
            set path [file join [pwd] $path]
        }
    }

    set result {}
    foreach comp [set comps [file split $path]] {
        switch -- $comp {
            "." {
            }

            ".." {
                set result [lrange $result 0 end-1]
            }

            "/" {
            }

            default {
                lappend result $comp
            }
        }
    }

    return [eval file join "/" $result]
}

proc prexml_find_file {s f} {
    global extfiles

    if {   [info exists extfiles([set fx $f])]
        || [info exists extfiles([set fx $f.xml])]} {
        set fnum [linefile::new_file $s $fx]
        return [concat $fnum $extfiles($fx)]
    }

    set foundP 0
    catch {
        if {   ![file exists [set file [set fx $f    ]]]
            && ![file exists [set file [set fx $f.xml]]]} {
            break
        }
        set fd ""
        catch {
            set fd [open $file { RDONLY }]
            catch { fconfigure $fd -encoding binary -translation lf }
            set content [prexml_cdata [read $fd]]
            set foundP 1
        }
        catch { close $fd }
    }
    if {!$foundP} {
        error "unable to find external file \"$s\" or \"$s.xml\""
    }

    set fnum [linefile::new_file $s $fx]
    set extfiles($fx) [list $content UTF-8]

    return [list $fnum $content UTF-8]
}

proc prexml_find_uri {s u} {
    global exturis
    global httpP

    if {   [info exists exturis([set ux $u    ])]
        || [info exists exturis([set ux $u.xml])]} {
        set fnum [linefile::new_file $s $ux]
        return [concat $fnum $exturis($ux)]
    }

    if {!$httpP} {
        error "unable to find http package"
    }
    # Note that, as of writing, the http package still does not grasp
    # that IANA charset names and Tcl encoding names are generally
    # incompatible (e.g., "iso8859-1" is a Tcl encoding name but not an
    # IANA charset name), so it cannot be trusted with these conversions.
    set httpV [package present http]
    regexp -- {^[0-9]+\.[0-9]+} $httpV httpV
    set code "http package failed"
    catch {
        if {$httpV >= 2.4} {
            set httpT [http::geturl $u -binary true]
        } else {
            set httpT [http::geturl $u]
        }
        set code [http::code $httpT]
        if {![string compare [lindex $code 1] 404]} {
            set u $u.xml
            if {$httpV >= 2.4} {
                set httpT [http::geturl $u -binary true]
            } else {
                set httpT [http::geturl $u]
            }
            set code [http::code $httpT]
        }
    }
    if {[string compare [lindex $code 1] 200]} {
        error "$u: $code"
    }
    upvar #0 $httpT httpS
    set content [http::data $httpT]
    # An XMLDecl or TextDecl can still override this.
    set default_charset UTF-8
    if {$httpV >= 2.4} {
        if {[string compare $httpS(charset) unknown]} {
            set default_charset $httpS(charset)
        } elseif {[regexp -nocase -- {^text([\t /;]|$)} $httpS(type)]} {
            set default_charset ISO-8859-1
        }
    } elseif {[regexp -nocase -- ^text $httpS(type)]} {
        # Undo the systematic utf-8 encoding conversion done by this
        # old http package.  We already lost before this point if it
        # wasn't originally utf-8 content because the conversion
        # massaged anything that didn't look like well-formed utf-8!
        catch { set content [encoding convertto utf-8 $content] }
    }
    set content [prexml_cdata $content]
    http::cleanup $httpT

    set fnum [linefile::new_file $s $u]
    set exturis($u) [list $content $default_charset]

    return [list $fnum $content $default_charset]
}

proc prexml_tweak_include {include {convert_fnum -1} {default_charset UTF-8}} {
    set start 0
    set XMLDecl ""
    set body [string trimleft $include]
    if {   [regexp -nocase -- {^<\?xml[ \t\r\n]} $body]
        && [set len [string first "?>" $body]] >= 0} {

        set start [expr [string length $include] - [string length $body]]
        set end [expr $start + $len + 1]
        set XMLDecl [string range $include $start $end]
        set len [string length $include]
        set include [streplace $include $start $end "" 2]
        incr end [expr [set len2 [string length $include]] - $len]
        set include [streplace $include 0 $start \
                               [str_norm_eol [string range $include 0 $start]]]
        incr end [expr [string length $include] - $len2]

        set start [expr $end + 1]
    }
    if {$convert_fnum >= 0} {
        set include [prexml_convert $XMLDecl $include \
                                    [linefile::get_fake_file $convert_fnum] \
                                    $default_charset]
    }
    # Now that we are in UTF-8.
    set xml11 [expr   [regexp -- {[ \t\r\n]version="1\.[1-9][0-9]*"} $XMLDecl] \
                   || [regexp -- {[ \t\r\n]version='1\.[1-9][0-9]*'} $XMLDecl]]
    set include [str_norm_eol $include $xml11]
    set body [string trimleft [string range $include $start end]]
    if {   [regexp -nocase -- {^<!DOCTYPE[ \t\r\n]} $body]
        && [set len [string first ">" $body]] >= 0} {

        set start [expr [string length $include] - [string length $body]]
        if {   [set len2 [string first {[} $body]] < $len
            && [string first {]} $body] > $len} {

            set include [streplace $include $start [expr $start + $len2] "" 2]

            set start [string first {]} $include]
            set len [string first ">" [string range $include $start end]]
            set include [streplace $include $start [expr $start + $len] "" 2]
        } else {
            set end [expr $start + $len]
            set include [streplace $include $start $end "" 2]
        }
    }

    return $include
}


#       }}}2 Regular, non-uplevel, support procs for prexml_stream.
#   }}}1 XML preprocessor

#   {{{1 Utility functions

proc sum_list {list} {
    set total 0
    foreach i $list {
        if {[string compare $i ""]} {
            incr total $i
        }
    }

    return $total
}

proc add_lists {lx ly} {
    set lz {}
    foreach x $lx y $ly {
        if {![string is integer $x]} {
            set x 0
        }
        if {![string is integer $y]} {
            set y 0
        }
        lappend lz [expr $x + $y]
    }

    return $lz
}

proc subtract_lists {lx ly} {
    set lz {}
    foreach x $lx y $ly {
        if {![string is integer $x]} {
            set x 0
        }
        if {![string is integer $y]} {
            set y 0
        }
        lappend lz [expr $x - $y]
    }

    return $lz
}

proc num_eols {text} {
    # Number of "\n" in $text, even if last line unterminated.
    return [regexp -all -- "\n" $text]
}

proc around2fl {result} {
    global pcdata_line_offset
    global ifile

    set y [regexp -nocase -- { around line ([1-9][0-9]*)} \
                  $result x lineno]
    if {$y > 1} {
        return $result
    } elseif {$y == 0} {
        if {[set lineno $::xdv::lineno] < 0} {
            return $result
        }
        append result [set x " around line $lineno"]
    }

    set file [linefile::get_fake_file]
    set line [linefile::get_line [expr $lineno + $pcdata_line_offset]]

    set tail " around input line $line"
    if {[string compare $file $ifile]} {
        append tail " in \"$file\""
    }
    regsub -- $x $result $tail result

    return $result
}

#   }}}1 Utility functions

#   {{{1 The linefile stuff in its own namespace

namespace eval linefile {
    variable  offset 1  fncache {{}}  real_stack {0}  fake_stack {0}
}

proc linefile::init {} {
    variable offset
    variable real_stack
    variable fake_stack

    set offset 1
    set real_stack {0}
    set fake_stack {0}
}

proc linefile::get_line {{lineno -1}} {
    variable offset

    if {$lineno < 0} {
        set lineno $::xdv::lineno
    }

    return [expr $lineno + $offset]
}

proc linefile::set_line {line} {
    variable offset

    set offset [expr $line - $::xdv::lineno]
}

proc linefile::new_file {file {fullpath ""}} {
    variable fncache

    set fn [list $file $fullpath]

    if {[set fnum [lsearch -exact $fncache $fn]] < 0} {
        set fnum [llength $fncache]
        lappend fncache $fn
    }

    return $fnum
}

proc linefile::get_real_fnum {} {
    variable real_stack

    lindex $real_stack end
}

proc linefile::get_fake_fnum {} {
    variable fake_stack

    lindex $fake_stack end
}

proc linefile::get_real_key {{fnum -1}} {
    variable fncache

    if {$fnum < 0} {
        set fnum [get_real_fnum]
    }

    lindex $fncache $fnum
}

proc linefile::get_fake_key {{fnum -1}} {
    variable fncache

    if {$fnum < 0} {
        set fnum [get_fake_fnum]
    }

    lindex $fncache $fnum
}

proc linefile::get_fake_file {{fnum -1} {basename 0}} {
    set file [lindex [get_fake_key $fnum] 0]

    set sep "[file join \[/ \]]"
    if {$basename > 0} {
        # Only keep base name of file.
        regsub -- "^.*$sep" $file {} file
    }

    return $file
}

proc linefile::get_real_fullpath {{fnum -1}} {
    lindex [get_real_key $fnum] 1
}

proc linefile::get_real_fulldir {{fnum -1}} {
    set fullpath [lindex [get_real_key $fnum] 1]

    if {[string first :// $fullpath] >= 0} {
        set sep {[/]}
    } else {
        set sep "[file join \[/ \]]"
    }
    set fulldir ""
    regexp -- "^(.*)$sep" $fullpath x fulldir
    if {   ![string compare $fulldir ""]
        && ![regexp -- "^${sep}+" $fullpath fulldir]} {
        global tcl_platform
        switch -- $tcl_platform(platform) {
            macintosh { set dir : }
            default   { set dir . }
        }
    }

    return $fulldir
}

proc linefile::set_real_fnum {fnum} {
    variable real_stack

    set real_stack [lreplace real_stack end end $fnum]

    return $fnum
}

proc linefile::set_fake_fnum {fnum} {
    variable fake_stack

    set fake_stack [lreplace fake_stack end end $fnum]

    return $fnum
}

proc linefile::set_file {file {fullpath ""}} {
    set fnum [new_file $file $fullpath]
    if {[string compare $fullpath ""]} {
        set_real_fnum $fnum
    } else {
        set_fake_fnum $fnum
    }
}

proc linefile::push_fnum {fnum} {
    variable real_stack
    variable fake_stack

    lappend real_stack $fnum
    lappend fake_stack $fnum

    return $fnum
}

proc linefile::push_file {file {fullpath ""}} {
    push_fnum [new_file $file $fullpath]
}

proc linefile::pop_fake_fnum {} {
    variable real_stack
    variable fake_stack

    set fnum [lindex $fake_stack end]
    set real_stack [lreplace $real_stack end end]
    set fake_stack [lreplace $fake_stack end end]

    return $fnum
}

proc linefile::make_pi {fnum line {force_file 0}} {
    if {$force_file || $fnum != [get_fake_fnum]} {
        set_fake_fnum $fnum
        set file [get_fake_file $fnum]
        regsub -all -- & $file {\&amp;} file
        if {[string first \" $file] < 0} {
            set lcf \"$line:$file\"
        } elseif {[string first \' $file] < 0} {
            set lcf \'$line:$file\'
        } else {
            regsub -all -- \" $file {\&quot;} file
            set lcf \"$line:$file\"
        }
    } else {
        set lcf \"$line\"
    }

    return "<?rfc linefile=$lcf?>"
}

#   }}}1 The linefile stuff in its own namespace

#   {{{1 XML linkage
#       {{{2 Main function

# globals used in parsing
#
#     counter - used for generating reference numbers
#       depth -  ..
#       elemN - index of current element
#        elem - array, indexed by elemN, having:
#               list of element attributes,
#               plus in pass 1
#                   .ANCHOR
#                   .CHILDREN
#                   .COUNTER
#                   .CTEXT
#                   .EDITNO
#                   .FMTCOUNTER
#                   .LONGEST_ROMAN
#                   .MAX
#                   .MIN
#                   .NAME
#               plus in further passes
#                   .ANNOTATIONS
#                   .FMTTOKEN
#                   .FORMAT
#                   .STYLE
#                   .WIDTH
#      passno - 1 or 2 (or maybe 3, if generating a TOC)
#       stack - the stack of elements, each frame having:
#               { element-name "elemN" elemN "children" { elemN... }
#                 "ctext" yes-or-no }
#        xref - array, indexed by anchor, having:
#               { "type" element-name "elemN" elemN "value" reference-number }

proc pass {tag} {
    global options
    global counter depth elemN elem stack xref
    global passno passmax pass_was_stable
    global anchorN
    global elemZ
    global crefs erefs
    global root

    switch -- $tag {
        start {
            unexpected notice "pass $passno..."
            set pass_was_stable 1
            if {$passno == 1} {
                set pass_was_stable 0
                catch { array unset counter }
                set counter(firstxref) {}
                catch { array unset depth }
                catch { array unset elem }
                catch { array unset xref }
                catch { array unset crefs }
                catch { array unset erefs }
                set anchorN 0
                set root [list {}]
            } else {
                catch { unset counter(references) }
                array unset counter list/*
            }
            set elemN 0
            catch { array unset options }

            # In order to allow defaulting based on rfcedstyle,
            # "compact" and "subcompact" must not be on this list.
            # In order to allow warning about the changed default,
            # "symrefs" must not be on this list.
            array set options [list artworkdelimiter    ""            \
                                    artworklines        0             \
                                    authorship          yes           \
                                    autobreaks          yes           \
                                    background          ""            \
                                    colonspace          no            \
                                    comments            no            \
                                    docmapping          no            \
                                    editing             no            \
                                    emoticonic          no            \
                                    footer              ""            \
                                    header              ""            \
                                    inline              no            \
                                    iprnotified         no            \
                                    linkmailto          yes           \
                                    notedraftinprogress yes           \
                                    private             ""            \
                                    refparent           "References"  \
                                    rfcedstyle          no            \
                                    rfcprocack          no            \
                                    slides              no            \
                                    sortrefs            no            \
                                    strict              no            \
                                    text-list-symbols   "o*+-"        \
                                    toc                 no            \
                                    tocappendix         yes           \
                                    tocdepth            3             \
                                    tocindent           yes           \
                                    tocnarrow           yes           \
                                    tocompact           yes           \
                                    topblock            yes           \
                                    useobject           no]
            normalize_options

            set stack 0; unset stack
            linefile::init
        }

        end {
            set elemZ $elemN

            if {$passno == 1} {
                # We can only see line numbers from the preprocessed XML.
                # linefile::get_line won't work once we hit the first include.
                linefile::init
                linefile::set_file "internally-preprocessed XML"
                xdv::validate_tree [lindex [lindex $root 0] 0] \
                     rfc2629.cmodel  rfc2629.rattrs rfc2629.oattrs \
                     rfc2629.anchors rfc2629.pcdata
            }
            if {$passno == $passmax && !$pass_was_stable} {
                incr passmax
            }
        }
    }
}

#       }}}2 Main function
#       {{{2 Some globals

global required ctexts categories

# This must be kept in lexicographical order for string compare.
set required {
               appendix   { title  }
               eref       { target }
               format     { type }
               iref       { item }
               note       { title  }
               section    { title  }
# backwards-compatibility... (the attributes are actually mandatory)
#              seriesInfo { name value }
               xref       { target }
             }

set ctexts   { area artwork city code country cref email eref facsimile
               keyword organization phone postamble preamble region seriesInfo
               spanx street t title ttcol uri workgroup xref }

#       }}}2 Some globals
#       {{{2 Categories and IPR status texts

# From the rfc-editor/instructions2authors.txt file, Appendix A, Subsection A.1.
# Currently draft-rfc-editor-rfc2223bis-08, which is expired.
# It says "This memo does not..." but the RFC Editor uses "It does not...".
# Authoritative source of "Historic" text unknown.
set categories \
             { {std  "Standards Track" STD
"This document specifies an Internet standards track protocol for the Internet
community, and requests discussion and suggestions for improvements.
Please refer to the current edition of the &ldquo;Internet Official Protocol
Standards&rdquo; (STD&nbsp;1) for the standardization state and status of this
protocol.
Distribution of this memo is unlimited."}

               {bcp      "Best Current Practice" BCP
"This document specifies an Internet Best Current Practices for the Internet
Community, and requests discussion and suggestions for improvements.
Distribution of this memo is unlimited."}

               {info     "Informational" FYI
"This memo provides information for the Internet community.
It does not specify an Internet standard of any kind.
Distribution of this memo is unlimited."}

               {exp      "Experimental" EXP
"This memo defines an Experimental Protocol for the Internet community.
It does not specify an Internet standard of any kind.
Discussion and suggestions for improvement are requested.
Distribution of this memo is unlimited."}

               {historic "Historic" ""
"This memo describes a historic protocol for the Internet community.
It does not specify an Internet standard of any kind.
Distribution of this memo is unlimited."} }

# From
#     RFC 2026 (BCP 9)
#         ?
#     RFC 3667 (obsolete version of BCP 78)
#         Section 5.1  IPR Disclosure Acknowledgement
#         Section 5.2  Derivative Works Limitation
#             Notices a and b
#             Extracted Material appendage
#     RFC 3978 (obsolete version of BCP 78)
#         Section 5.1  IPR Disclosure Acknowledgement
#         Section 5.2  Derivative Works Limitation
#             Notices a and b
#             Extracted Material appendage
#     IETF Trust's Legal Provisions Relating to IETF Documents
#             (referred to from current version of BCP 78)
#         Section 6.a Submission Compliance
#         Section 6.c Derivative Works and Publication Limitations
#     February, 2009 update to Trust's Legal Provisions
#         trust200902 and noDerivativesTrust200902 have the same text
#         as the respective 200811 values.  noModificationTrust200902
#         is slightly modified from the 200811 wording, and
#         pre5378Trust200902 is new in this revision.
set iprstatus \
             { {full2026
"This document is an Internet-Draft and is
in full conformance with all provisions of Section&nbsp;10 of RFC&nbsp;2026."}

               {noDerivativeWorks2026
"This document is an Internet-Draft and is
in full conformance with all provisions of Section&nbsp;10 of RFC&nbsp;2026
except that the right to produce derivative works is not granted."}

               {noDerivativeWorksNow
"This document is an Internet-Draft and is
in full conformance with all provisions of Section&nbsp;10 of RFC&nbsp;2026
except that the right to produce derivative works is not granted.
(If this document becomes part of an IETF working group activity,
then it will be brought into full compliance with Section&nbsp;10 of RFC&nbsp;2026.)"}

               {none
"This document is an Internet-Draft and is
NOT offered in accordance with Section&nbsp;10 of RFC&nbsp;2026,
and the author does not provide the IETF with any rights other
than to publish as an Internet-Draft."}

               {full3667
"This document is an Internet-Draft and is subject to all provisions
of Section&nbsp;3 of RFC&nbsp;3667.
By submitting this Internet-Draft,
each author represents that any applicable patent or other IPR claims of which
he or she is aware have been or will be disclosed,
and any of which he or she become aware will be disclosed,
in accordance with RFC&nbsp;3668."}

               {noModification3667
"This document is an Internet-Draft and is subject to all provisions
of Section&nbsp;3 of RFC&nbsp;3667.
By submitting this Internet-Draft,
each author represents that any applicable patent or other IPR claims of which
he or she is aware have been or will be disclosed,
and any of which he or she become aware will be disclosed,
in accordance with RFC&nbsp;3668.
This document may not be modified,
and derivative works of it may not be created,
except to publish it as an RFC and to translate it into languages other
than English%IPREXTRACT%."}

               {noDerivatives3667
"This document is an Internet-Draft and is subject to all provisions
of Section&nbsp;3 of RFC&nbsp;3667 except for the right to produce derivative works.
By submitting this Internet-Draft,
each author represents that any applicable patent or other IPR claims of which
he or she is aware have been or will be disclosed,
and any of which he or she become aware will be disclosed,
in accordance with RFC&nbsp;3668.
This document may not be modified,
and derivative works of it may not be created%IPREXTRACT%."}

               {full3978
"By submitting this Internet-Draft,
each author represents that any applicable patent or other IPR claims of which
he or she is aware have been or will be disclosed,
and any of which he or she becomes aware will be disclosed,
in accordance with Section&nbsp;6 of BCP&nbsp;79."}

               {noModification3978
"By submitting this Internet-Draft,
each author represents that any applicable patent or other IPR claims of which
he or she is aware have been or will be disclosed,
and any of which he or she becomes aware will be disclosed,
in accordance with Section&nbsp;6 of BCP&nbsp;79.
This document may not be modified,
and derivative works of it may not be created,
except to publish it as an RFC and to translate it into languages other
than English%IPREXTRACT%."}

               {noDerivatives3978
"By submitting this Internet-Draft,
each author represents that any applicable patent or other IPR claims of which
he or she is aware have been or will be disclosed,
and any of which he or she becomes aware will be disclosed,
in accordance with Section&nbsp;6 of BCP&nbsp;79.
This document may not be modified,
and derivative works of it may not be created%IPREXTRACT%."}

               {trust200811
"This Internet-Draft is submitted to IETF in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79."}

               {noModificationTrust200811
"This Internet-Draft is submitted to IETF in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79.
This document may not be modified, and derivative works of it may
not be created, except to format it for publication as an RFC and
to translate it into languages other than English."}

               {noDerivativesTrust200811
"This Internet-Draft is submitted to IETF in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79.
This document may not be modified, and derivative works of it may
not be created, and it may not be published except as an Internet-Draft."}

               {trust200902
"This Internet-Draft is submitted %TOIETF% in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79."}

               {noModificationTrust200902
"This Internet-Draft is submitted %TOIETF% in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79.
This document may not be modified, and derivative works of it may
not be created, except to format it for publication as an RFC or
to translate it into languages other than English."}

               {noDerivativesTrust200902
"This Internet-Draft is submitted %TOIETF% in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79.
This document may not be modified, and derivative works of it may
not be created, and it may not be published except as an Internet-Draft."}

               {pre5378Trust200902
"This Internet-Draft is submitted %TOIETF% in full
conformance with the provisions of BCP&nbsp;78 and BCP&nbsp;79.
This document may contain material from IETF Documents or IETF
Contributions published or made publicly available before November
10, 2008. The person(s) controlling the copyright in some of this
material may not have granted the IETF Trust the right to allow
modifications of such material outside the IETF Standards Process.
Without obtaining an adequate license from the person(s) controlling
the copyright in such materials, this document may not be modified
outside the IETF Standards Process, and derivative works of it may
not be created outside the IETF Standards Process, except to format
it for publication as an RFC or to translate it into languages other
than English."}

 }

set rfc5741StatusOfMemo_ietf_std {
"This is an Internet Standards Track document."
}
set rfc5741StatusOfMemo_ietf_bcp {
"This memo documents an Internet Best Current Practice."
}
set rfc5741StatusOfMemo_ietf_exp {
"This document is not an Internet Standards Track specification; it is published for examination, experimental implementation, and evaluation."
}
set rfc5741StatusOfMemo_ietf_historic {
"This document is not an Internet Standards Track specification; it is published for the historical record."
}
set rfc5741StatusOfMemo_ietf_info {
"This document is not an Internet Standards Track specification; it is published for informational purposes."
}
set rfc5741StatusOfMemo_iab_exp {
"This document is not an Internet Standards Track specification; it is published for examination, experimental implementation, and evaluation."
}
set rfc5741StatusOfMemo_iab_historic {
"This document is not an Internet Standards Track specification; it is published for the historical record."
}
set rfc5741StatusOfMemo_iab_info {
"This document is not an Internet Standards Track specification; it is published for informational purposes."
}
set rfc5741StatusOfMemo_irtf_exp {
"This document is not an Internet Standards Track specification; it is published for examination, experimental implementation, and evaluation."
}
set rfc5741StatusOfMemo_irtf_historic {
"This document is not an Internet Standards Track specification; it is published for the historical record."
}
set rfc5741StatusOfMemo_irtf_info {
"This document is not an Internet Standards Track specification; it is published for informational purposes."
}
set rfc5741StatusOfMemo_ind_exp {
"This document is not an Internet Standards Track specification; it is published for examination, experimental implementation, and evaluation."
}
set rfc5741StatusOfMemo_ind_historic {
"This document is not an Internet Standards Track specification; it is published for the historical record."
}
set rfc5741StatusOfMemo_ind_info {
"This document is not an Internet Standards Track specification; it is published for informational purposes."
}
set rfc5741StatusOfMemo2_ietf_std {
"This document is a product of the Internet Engineering Task Force (IETF). It represents the consensus of the IETF community. It has received public review and has been approved for publication by the Internet Engineering Steering Group (IESG). Further information on Internet Standards is available in Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_bcp {
"This document is a product of the Internet Engineering Task Force (IETF). It represents the consensus of the IETF community. It has received public review and has been approved for publication by the Internet Engineering Steering Group (IESG). Further information on BCPs is available in Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_exp_consensus {
"This document defines an Experimental Protocol for the Internet community. This document is a product of the Internet Engineering Task Force (IETF). It represents the consensus of the IETF community. It has received public review and has been approved for publication by the Internet Engineering Steering Group (IESG). Not all documents approved by the IESG are a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_exp_noconsensus {
"This document defines an Experimental Protocol for the Internet community. This document is a product of the Internet Engineering Task Force (IETF). It has been approved for publication by the Internet Engineering Steering Group (IESG). Not all documents approved by the IESG are a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_historic_consensus {
"This document defines a Historic Document for the Internet community. This document is a product of the Internet Engineering Task Force (IETF). It represents the consensus of the IETF community. It has received public review and has been approved for publication by the Internet Engineering Steering Group (IESG). Not all documents approved by the IESG are a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_historic_noconsensus {
"This document defines a Historic Document for the Internet community. This document is a product of the Internet Engineering Task Force (IETF). It has been approved for publication by the Internet Engineering Steering Group (IESG). Not all documents approved by the IESG are a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_info_consensus {
"This document is a product of the Internet Engineering Task Force (IETF). It represents the consensus of the IETF community. It has received public review and has been approved for publication by the Internet Engineering Steering Group (IESG). Not all documents approved by the IESG are a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ietf_info_noconsensus {
"This document is a product of the Internet Engineering Task Force (IETF). It has been approved for publication by the Internet Engineering Steering Group (IESG). Not all documents approved by the IESG are a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_iab_exp {
"This document defines an Experimental Protocol for the Internet community. This document is a product of the Internet Architecture Board (IAB) and represents information that the IAB has deemed valuable to provide for permanent record. Documents approved for publication by the IAB are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_iab_historic {
"This document defines a Historic Document for the Internet community. This document is a product of the Internet Architecture Board (IAB) and represents information that the IAB has deemed valuable to provide for permanent record. Documents approved for publication by the IAB are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_iab_info {
"This document is a product of the Internet Architecture Board (IAB) and represents information that the IAB has deemed valuable to provide for permanent record. Documents approved for publication by the IAB are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_exp_consensus {
"This document defines an Experimental Protocol for the Internet community. This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. This RFC represents the consensus of the %WORKGROUPNAME% Research Group of the Internet Research Task Force (IRTF). Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_exp_noconsensus {
"This document defines an Experimental Protocol for the Internet community. This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. This RFC represents the individual opinion(s) of one or more members of the %WORKGROUPNAME% Research Group of the Internet Research Task Force (IRTF). Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_exp_nogroup {
"This document defines an Experimental Protocol for the Internet community. This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_historic_consensus {
"This document defines a Historic Document for the Internet community. This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. This RFC represents the consensus of the %WORKGROUPNAME% Research Group of the Internet Research Task Force (IRTF). Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_historic_noconsensus {
"This document defines a Historic Document for the Internet community. This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. This RFC represents the individual opinion(s) of one or more members of the %WORKGROUPNAME% Research Group of the Internet Research Task Force (IRTF). Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_historic_nogroup {
"This document defines a Historic Document for the Internet community. This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_info_consensus {
"This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. This RFC represents the consensus of the %WORKGROUPNAME% Research Group of the Internet Research Task Force (IRTF). Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_info_noconsensus {
"This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. This RFC represents the individual opinion(s) of one or more members of the %WORKGROUPNAME% Research Group of the Internet Research Task Force (IRTF). Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_irtf_info_nogroup {
"This document is a product of the Internet Research Task Force (IRTF). The IRTF publishes the results of Internet-related research and development activities. These results might not be suitable for deployment. Documents approved for publication by the IRSG are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ind_exp {
"This document defines an Experimental Protocol for the Internet community. This is a contribution to the RFC Series, independently of any other RFC stream. The RFC Editor has chosen to publish this document at its discretion and makes no statement about its value for implementation or deployment. Documents approved for publication by the RFC Editor are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ind_historic {
"This document defines a Historic Document for the Internet community. This is a contribution to the RFC Series, independently of any other RFC stream. The RFC Editor has chosen to publish this document at its discretion and makes no statement about its value for implementation or deployment. Documents approved for publication by the RFC Editor are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo2_ind_info {
"This is a contribution to the RFC Series, independently of any other RFC stream. The RFC Editor has chosen to publish this document at its discretion and makes no statement about its value for implementation or deployment. Documents approved for publication by the RFC Editor are not a candidate for any level of Internet Standard; see Section 2 of RFC 5741."
}
set rfc5741StatusOfMemo3 {
"Information about the current status of this document, any errata, and how to provide feedback on it may be obtained at http://www.rfc-editor.org/info/rfc%RFC%."
}

#       }}}2 Categories and IPR status texts
#       {{{2 Start and end tag callbacks

proc begin {name {av {}} } {
    global counter depth elemN elem passno stack xref
    global anchorN
    global options
    global required ctexts categories iprstatus
    global root

    # because TclXML... quotes attribute values containing "]"
    set kv ""
    foreach {k v} $av {
        lappend kv $k
        regsub -all -- {\\\[}  $v {[} v
        regsub -all -- "\\\\{" $v "{" v
        regsub -all -- "\\\\}" $v "}" v
        lappend kv $v
    }
    set av $kv

    incr elemN

    if {$passno == 1} {
        set elem($elemN) $av
        array set attrs $av

        set attrs(.lineno) $::xdv::lineno
        lappend root [list $name [array get attrs]]
        unset attrs(.lineno)

        foreach { n a } $required {
            switch -- [string compare $n $name] {
                -1 { continue }

                0 {
                    foreach v $a {
                        if {[catch { set attrs($v) }]} {
                            unexpected error \
                                "missing $v attribute in #$elemN:<$name> element"
                        }
                    }
                    break
                }

                1 { break }
            }
        }

        switch -- [set type $name] {
            rfc {
                if {![catch { set attrs(category) }]} {
                    if {[lsearch0 $categories $attrs(category)] < 0} {
                        unexpected error \
                            "category=\"$attrs(category)\" attribute unknown in #$elemN:<rfc>"
                    }
                    if {(![string compare $attrs(category) historic]) \
                            && (![catch { set attrs(seriesNo) }])} {
                        unexpected error \
                            "historic documents have no document series in #$elemN:<rfc>"
                    }
                }
                if {![catch { set attrs(ipr) }]} {
                    #regsub -- {BCP78$} $attrs(ipr) 3978 ipr
                    if {[lsearch0 $iprstatus $attrs(ipr)] < 0} {
                        unexpected error \
                            "ipr=\"$attrs(ipr)\" attribute unknown in #$elemN:<rfc>"
                   }
                    if {   [regexp -- {[0-9]$} $attrs(ipr)]
                        && ![regexp -- {trust200902$} [string tolower $attrs(ipr)]]} {
                        unexpected warning \
                            "ipr=\"$attrs(ipr)\" attribute value is outdated compared to Trust Legal Provisions of 2/2009"
                    }
                    #if {[string compare $attrs(ipr) $ipr]} {
                    #    set attrs(ipr) $ipr
                    #    set elem($elemN) [array get attrs]
                    #}
                }
                if {![catch { set attrs(submissionType) }]} {
                    switch -- $attrs(submissionType) {
                        IETF - IRTF - IAB - independent {}
                        default {
                            unexpected error \
                                "submissionType=\"$attrs(submissionType)\" attribute unknown in #$elemN:<rfc>"
                        }
                    }
                }
                if {![catch { set attrs(consensus) }]} {
                    switch -- $attrs(consensus) {
                        yes - no {}
                        default {
                            unexpected error \
                                "consensus=\"$attrs(consensus)\" attribute unknown in #$elemN:<rfc>"
                        }
                    }
                }
                global entities oentities xentities uentities
                global prog prog_version
                if {[catch { set number $attrs(number) }]} {
                    set number XXXX
                }
                set entities  [linsert $oentities 0 {&rfc\.number;} $number]
                set xentities [linsert $xentities 0 {&rfc\.number;} $number]
                set uentities [linsert $uentities 0 {&rfc\.number;} $number]
            }

            back {
                set depth(section) 0; unset depth(section)
            }

            abstract {
                if {[lsearch0 $stack back] < 0} {
                    set counter(abstract) 1
                }
            }

            section - appendix {
                if {[lsearch0 $stack back] >= 0} {
                    set type appendix
                }
                if {![string compare $type section]} {
                    if {[catch { set depth(section) }]} {
                        set depth(section) 0
                        set counter(section) 0
                    }
                    incr depth(section)
                } else {
                    if {[catch { set depth(appendix) }]} {
                        set depth(appendix) 0
                        set counter(appendix) 0
                    }
                    incr depth(appendix)
                }
                set counter($type) \
                         [counting $counter($type) $depth($type)]
                set l [split $counter($type) .]
                if {![string compare $type appendix]} {
                    set type appendix
                    set l [lreplace $l 0 0 \
                                [string index " ABCDEFGHIJKLMNOPQRSTUVWXYZ" \
                                    [lindex $l 0]]]
                }
                set attrs(.COUNTER) [set value [join $l .]]
                if {[catch { set attrs(anchor) }]} {
                    set attrs(anchor) anchor[incr anchorN]
                }
                set attrs(.ANCHOR) $attrs(anchor)
                if {[catch { set attrs(toc) }]} {
                    set attrs(toc) default
                }
                set elem($elemN) [array get attrs]
                switch -- [set t [string tolower $attrs(title)]] {
                    "iana considerations" - "security considerations" {
                        set counter($t) 1
                    }
                }
            }

            list {
                if {[catch { set depth(list) }]} {
                    set depth(list) 0
                    set counter(list) 0
                }
                incr depth(list)

                if {   [info exists attrs(counter)]
                    && [string compare [set c $attrs(counter)] ""]} {
                    if {![info exists counter(list/$c)]} {
                        set counter(list/$c) 0
                        set counter(list-max/$c) 0
                        set counter(list-longest-roman/$c) 1
                    }
                    set attrs(.MIN) [expr $counter(list-max/$c) + 1]
                } else {
                    set attrs(.MIN) 1
                }
                set attrs(.MAX) 0
                set attrs(.LONGEST_ROMAN) 1
                set elem($elemN) [array get attrs]
            }

            t {
                if {[catch { set counter(editno) }]} {
                    set counter(editno) 0
                }
                incr counter(editno)

                set attrs(.EDITNO) $counter(editno)
                if {[set l [llast0 $stack list]] >= 0} {
                    set counter(list) [counting $counter(list) $depth(list)]
                    set attrs(.COUNTER) $counter(list)
                    set value $attrs(.COUNTER)

                    set le [lindex [lindex $stack $l] 2]
                    array set lv $elem($le)
                    if {   [info exists lv(counter)]
                        && [string compare [set c $lv(counter)] ""]} {
                        set x [incr counter(list/$c)]
                        set z 1
                    } else {
                        set x [lindex [split $attrs(.COUNTER) .] end]
                        set z 0
                    }
                    set attrs(.FMTCOUNTER) $x

                    # Also update counter(list*/$c) values now, not in end,
                    # in case someone decides to reuse the $c counter
                    # in an inner list (which would be weird, but hey).
                    if {$x > $lv(.MAX)} {
                        set lv(.MAX) $x
                        if {$z} {
                            if {$x > $counter(list-max/$c)} {
                                set counter(list-max/$c) $x
                            }
                        }
                    }

                    set y $lv(.LONGEST_ROMAN)
                    if {   $x != $y
                        && [string length [offset2romans $x]] >
                           [string length [offset2romans $y]]} {
                        set lv(.LONGEST_ROMAN) $x
                        if {$z} {
                            set y $counter(list-longest-roman/$c)
                            if {   $x != $y
                                && [string length [offset2romans $x]] >
                                   [string length [offset2romans $y]]} {
                                set counter(list-longest-roman/$c) $x
                            }
                        }
                    }

                    set elem($le) [array get lv]
                } else {
                    set frame [lindex $stack end]
                    set value 1
                    foreach child [lindex $frame 4] {
                        array set c $elem($child)
                        if {![string compare $c(.NAME) t]} {
                            incr value
                        }
                    }
                }
                set elem($elemN) [array get attrs]
            }

            figure {
                if {[info exists attrs(anchor)]} {
                    if {[catch { set counter(figure) }]} {
                        set counter(figure) 0
                    }
                    incr counter(figure)

                    set attrs(.COUNTER) [set value $counter(figure)]
                    set elem($elemN) [array get attrs]
                }
            }

            preamble - postamble {
                if {[catch { set counter(editno) }]} {
                    set counter(editno) 0
                }
                incr counter(editno)

                set attrs(.EDITNO) $counter(editno)
                set elem($elemN) [array get attrs]
            }

            texttable {
                if {[info exists attrs(anchor)]} {
                    if {[catch { set counter(table) }]} {
                        set counter(table) 0
                    }
                    incr counter(table)

                    set attrs(.COUNTER) [set value $counter(table)]
                    set elem($elemN) [array get attrs]
                }
            }

            references {
                if {[catch { set depth(references) }]} {
                    set depth(references) 0
                    if {[catch { set counter(section) }]} {
                        set counter(section) 0
                    }
                    set counter(section) [counting $counter(section) 1]
                }
                incr depth(references)

                set counter(section) [counting $counter(section) 2]
                set l [split $counter(section) .]
                set attrs(.COUNTER) [set value [join $l .]]
                if {[catch { set attrs(anchor) }]} {
                    set attrs(anchor) anchor[incr anchorN]
                }
                set attrs(.ANCHOR) $attrs(anchor)
                if {[catch { set attrs(toc) }]} {
                    set attrs(toc) default
                }
                set elem($elemN) [array get attrs]
                if {[info exists attrs(title)]} {
                    switch -- [set t [string tolower $attrs(title)]] {
                        "normative reference" - "normative references" {
                            set counter(normative) 1
                        }

                        "informative reference" - "informative references" {
                            set counter(informative) 1
                        }
                    }
                }
            }

            reference {
                if {$options(.SYMREFS)} {
                    if {![info exists attrs(anchor)]} {
                        unexpected error "anchor required when using symrefs"
                    }
                    set value $attrs(anchor)
                } else {
                    if {[catch { set counter(reference) }]} {
                        set counter(reference) 0
                    }
                    incr counter(reference)

                    set value $counter(reference)
                }
                set attrs(.COUNTER) $value
                set elem($elemN) [array get attrs]
            }

            eref {
                if {($options(.STRICT)) && ([lsearch0 $stack abstract] >= 0)} {
                    unexpected error "eref element in abstract"
                }
            }

            xref {
                if {($options(.STRICT)) && ([lsearch0 $stack abstract] >= 0)} {
                    unexpected error "xref element in abstract"
                }
                set target $attrs(target)
                if {(![info exists counter(firstxref)]) \
                        || [lsearch -exact $counter(firstxref) $target] < 0} {
                    lappend counter(firstxref) $target
                }
            }

            cref {
                if {[catch { set attrs(anchor) }]} {
                    set attrs(anchor) anchor[incr anchorN]
                }
                if {$options(.SYMREFS)} {
                    set value $attrs(anchor)
                } else {
                    if {[catch { set counter(comment) }]} {
                        set counter(comment) 0
                    }
                    incr counter(comment)

                    set value Comment.$counter(comment)
                }
                set attrs(.COUNTER) $value
                set elem($elemN) [array get attrs]
            }
        }

        if {![catch { set anchor $attrs(anchor) }]} {
            if {![catch { set xref($anchor) }]} {
                array set x $xref($anchor)
                unexpected error \
  "anchor=\"$anchor\" attribute currently points to #$x(elemN):<$x(type)> and cannot be redefined in new #$elemN:<$name>"
            }
            set xref($anchor) [list type $type elemN $elemN value $value]
        }

        if {$elemN > 1} {
            set frame [lindex $stack end]
            set children [lindex $frame 4]
            lappend children $elemN
            set frame [lreplace $frame 4 4 $children]
            set stack [lreplace $stack end end $frame]
        }
    } else {
        # passno > 1
        if {0 && (![string compare $passno/$name 2/eref])} {
            array set attrs $elem($elemN)

            if {[catch { set counter(reference) }]} {
                set counter(reference) 0
            }
            incr counter(reference)

            set attrs(.COUNTER) $counter(reference)
            set elem($elemN) [array get attrs]
        }
        switch -- $name {
            rfc - reference - annotation {
                pass2begin_$name $elemN
            }

            front - abstract - note - section - appendix - t - list
                  - figure - artwork - preamble - postamble
                  - texttable - ttcol - c - iref - vspace - back {
                if {[lsearch0 $stack references] < 0} {
                    pass2begin_$name $elemN
                }
            }

            xref - eref - cref - spanx {
                if {([lsearch0 $stack references] < 0) \
                        || ([lsearch0 $stack annotation] >= 0)} {
                    pass2begin_$name $elemN
                }
            }
        }
    }

    if {[lsearch -exact $ctexts $name] >= 0} {
        set ctext yes
        if {$passno == 1} {
            set attrs(.CTEXT) ""
            set elem($elemN) [array get attrs]
        }
    } else {
        set ctext no
    }
    lappend stack [list $name elemN $elemN children "" ctext $ctext av $av \
                        line [linefile::get_line] \
                        fnum [linefile::get_fake_fnum]]
}

proc counting {tcount tdepth} {
    set x [llength [set l [split $tcount .]]]

    if {$x > $tdepth} {
        set l [lrange $l 0 [expr $tdepth-1]]
        set x $tdepth
    } elseif {$x < $tdepth} {
        lappend l 0
        incr x
    }
    incr x -1
    set l [lreplace $l $x $x [expr [lindex $l $x]+1]]
    return [join $l .]
}

# end element

proc end {name} {
    global counter depth elem passno stack xref
    global root

    set frame [lindex $stack end]
    set stack [lreplace $stack end end]

    array set av [lrange $frame 1 end]
    set elemX $av(elemN)

    if {$passno == 1} {
        set f2 [lindex $root end]
        set root [lreplace $root end end]
        set parent [lindex $root end]
        lappend parent $f2
        set root [lreplace $root end end $parent]

        array set attrs $elem($elemX)

        set attrs(.CHILDREN) $av(children)
        set attrs(.NAME) $name
        set elem($elemX) [array get attrs]

        switch -- $name {
            section - appendix {
                if {[lsearch0 $stack back] >= 0} {
                    set name appendix
                }
                incr depth($name) -1
            }

            list {
                if {[incr depth(list) -1] == 0} {
                    set counter(list) 0
                }
            }

            back {
                if {[llength [set c [find_element references \
                                                     $attrs(.CHILDREN)]]] \
                        == 1} {
                    array set cv $elem($c)
                    set cv(.COUNTER) [lindex [split $cv(.COUNTER) .] 0]
                    set elem($c) [array get cv]
                }
            }
        }

        return
    }

    # passno > 1
    switch -- $name {
        rfc - front - t - list - figure - artwork
            - preamble - postamble - texttable - c - back {
            if {[lsearch0 $stack references] < 0} {
                pass2end_$name $elemX
            }
        }

        references - annotation {
            pass2end_$name $elemX
        }
    }
}

#       }}}2 Start and end tag callbacks
#       {{{2 Character data (PCDATA) callback

proc pcdata {text} {
    global depth elem passno stack xref
    global mode
    global root
    global page_width page_basic_indent

    if {[string length $text] <= 0} {
        # Really empty.
        return
    }

    set chars [string trim $text]

    set text [str_norm_eol $text]

    set frame [lindex $stack end]

    set spans {}
    set divs  {}
    if {([lsearch0 $stack references] >= 0) \
            && ([lsearch0 $stack annotation] < 0)} {
        set pre -1
    } else {
        switch -- [lindex $frame 0] {
            artwork {
                if {$passno == 1} {
                    set pre 1
                } else {
                    # Will end up positive by incrementation and checks.
                    set pre [current_align_bias]
                    set elemX [lindex $frame 2]
                    # It won't work to get attrs from $frame.
                    array set attrs $elem($elemX)
                    if {[info exists attrs(.TEXTWIDTH)]} {
                        set align [current_align]
                        set tw $attrs(.TEXTWIDTH)
                        set rw [expr $page_width - $page_basic_indent - $tw]
                        switch -- $align {
                            left - "" {}
                            center { incr pre [expr ($rw + 1) / 2] }
                            right  { incr pre [expr $rw] }

                            default {
                                unexpected error \
                                    "align=\"$align\" attribute is invalid"
                            }
                        }
                        if {$pre > $rw} {
                            set pre $rw
                        }
                        switch -- $align {
                            center - right {
                                if {$pre < 0} {
                                    set pre 0
                                }
                            }
                        }
                    }
                    if {$pre < [current_align_bias]} {
                        unexpected warning "artwork outdented [expr [current_align_bias] - $pre] characters to avoid overrunning right margin"
                    }
                    incr pre $page_basic_indent
                    if {$pre < 0} {
                        set pre 0
                    }
                    # pre = 1 + total indent
                    incr pre

                    # Typed-<artwork> validation.
                    set type ""
                    catch { set type $attrs(type) }
                    if {[info exists attrs(.VALID)]} {
                        set valid $attrs(.VALID)
                        catch { set spans $attrs(.SPANS) }
                        catch { set divs  $attrs(.DIVS)  }
                        catch { set data  $attrs(.SDATA) }
                    } else {
                        set data [ent_expand $text]
                        foreach {valid spans divs} [ \
                            artwork::validate_highlight $type $data \
                        ] {break}
                        set attrs(.VALID) $valid
                        if {[llength $spans] > 0 || [llength $divs] > 0} {
                            set attrs(.SPANS) $spans
                            set attrs(.DIVS)  $divs
                            set attrs(.SDATA) $data
                        }
                        set elem($elemX) [array get attrs]
                    }
                }
            }

            t - preamble - postamble - c - annotation {
                set pre 0
            }

            default {
                set pre -1
            }
        }
    }

    if {$passno == 1} {
        if {$pre < 0 && [string length $chars] <= 0} {
            # Just white space.  Pass 1 doesn't want to see
            # PCDATA in the wrong places, but further passes
            # *need* some among it to generate correct output.
            return
        }
        array set attrs [lindex [set f2 [lindex $root end]] 1]
        set attrs(.pcdata) 1
        set root [lreplace $root end end \
                           [lreplace $f2 1 1 [array get attrs]]]
        catch { array unset attrs }

        array set av [lrange $frame 1 end]

        set elemX $av(elemN)
        array set attrs $elem($elemX)
        if {![string compare $av(ctext) yes]} {
            if {[lsearch0 $stack spanx] < 0} {
                append attrs(.CTEXT) $chars
            } else {
                append attrs(.CTEXT) $text
            }
        }
        set elem($elemX) [array get attrs]

        return
    }

    if {$pre < 0} {
        return
    }

    if {[info exists data] && ([llength $spans] > 0 || [llength $divs] > 0)} {
        set text $data
    }

    pcdata_$mode $text $pre 0 $spans $divs

    # Complain after having generated the output in case of hard error.
    if {[info exists valid] && !$valid} {
        if {[info exists spans]} {
            set x 0
            set p 0
            set l 0
            while {[set x [lsearch0 $spans err $x]] >= 0} {
                set i [lindex [lindex $spans $x] 1]
                # This line number will be 0-based,
                # but most people start their <artwork>
                # with a blank line (this being XML, not SGML).
                incr l [num_eols [string range $data $p [expr $i - 1]]]
                set p $i
                regexp -start $i -- {[^\n]*} $data token
                regsub -all -- \" $token {\"} token
                unexpected [unex_condtype] \
  "content is not valid type=\"$type\" near \"$token\" at line-offset $l within <artwork>"
                incr x
            }
        } else {
            unexpected [unex_condtype] \
                "<artwork> content is not valid type=\"$type\""
        }
    }
}

#       }}}2 Character data (PCDATA) callback
#       {{{2 Processing instructions (PIs)

proc pi {args} {
    global options
    global passno stack
    global mode

    switch -- [lindex $args 0]/[llength $args] {
        xml/2 {
            if {([string first "version=\"1.0\"" [lindex $args 1]] < 0) \
                    && ([string first "version='1.0'" [lindex $args 1]] < 0)} {
                unexpected error "unexpected <?xml ...?>"
            }
        }

        rfc/2 {
            set n 0
            set text [lindex $args 1]
            set lines [num_eols $text]
            while {1} {
                set l [pi_rfc_next $text]
                set key  [lindex $l 0]
                set val  [lindex $l 1]
                set text [lindex $l 2]
                if {![string compare $key ""]} {
                    if {[string compare $val ""]} {
                        unexpected error \
                            "stopped processing faulty rfc-PI at \"$val\""
                    }
                    break
                }
                switch -- $key {
                    include { continue }

                    linefile {
                        if {![regexp -- {^([0-9]+)(:(.*))?$} \
                                     $val a b c d]} {
                            unexpected warning \
  "ignoring invalid rfc-PI linefile-directive value \"$val\""
                            continue
                        }
                        if {[string length $c]} {
                            # May be empty.  User's choice!
                            set new_file $d
                        }
                        set new_line $b
                        continue
                    }
                }
                if {   [info exists options($key)]
                    || (   [string is lower $key]
                        && [info exists options(.[string toupper $key])])} {
                    set options($key) $val
                    incr n
                } elseif {$passno > 1} {
                    if {([catch { pi_$mode $key $val }]) && ($options(.STRICT))} {
                        regsub -all -- \" $val {\"} val
                        unexpected error \
                            "invalid rfc-PI directive: $key=\"$val\""
                    }
                }
            }
            if {$n > 0} {
                normalize_options
            }
            # Do this at the end so that intermixed
            # error or warning messages are not affected.
            if {[info exists new_line]} {
                if {[info exists new_file]} {
                    linefile::set_file $new_file
                }
                linefile::set_line [expr $new_line - $lines]
            }
        }

        default {
            if {![string compare [lindex $args 0] xml-stylesheet]} {
                return
            }
            set text [string trim [join $args " "]]
            unexpected warning "unknown PI: $text"
        }
    }
}

proc pi_rfc_next {text} {
    set text [string trimleft $text]
    set key ""
    set val $text

    # Some useful regexp literals.
    set wsp  {[ \t\r\n]}
    set dqev \"(\[^\"\]*)\"
    set sqev \'(\[^\'\]*)\'
    set nme  {([A-Za-z_:][A-Za-z0-9._:-]*)}
    set rem  (.*)

    if {   [regexp -- ^$nme=$dqev$rem$ $text x k v rest]
        || [regexp -- ^$nme=$sqev$rem$ $text x k v rest]
        || [regexp -- ^$nme=${nme}($|$wsp)$rem$ $text x k v y rest]} {
        set key $k
        set val [chars_expand $v]
        set text [string trimleft $rest]
    }

    return [list $key $val $text]
}

#       }}}2 Processing instructions (PIs)
#       {{{2 Options (rfc-PI directives) processing

proc normalize_options {} {
    global passmax
    global options
    global mode
    global remoteP

    if {$remoteP} {
        set options(slides) no
    }
    foreach {o O} [list authorship          .AUTHORSHIP           \
                        autobreaks          .AUTOBREAKS           \
                        colonspace          .COLONSPACE           \
                        comments            .COMMENTS             \
                        compact             .COMPACT              \
                        docmapping          .DOCMAPPING           \
                        editing             .EDITING              \
                        emoticonic          .EMOTICONIC           \
                        inline              .INLINE               \
                        iprnotified         .IPRNOTIFIED          \
                        linkmailto          .LINKMAILTO           \
                        notedraftinprogress .NOTEDRAFTINPROGRESS  \
                        rfcedstyle          .RFCEDSTYLE           \
                        rfcprocack          .RFCPROCACK           \
                        slides              .SLIDES               \
                        sortrefs            .SORTREFS             \
                        strict              .STRICT               \
                        subcompact          .SUBCOMPACT           \
                        symrefs             .SYMREFS              \
                        toc                 .TOC                  \
                        tocappendix         .TOCAPPENDIX          \
                        tocindent           .TOCINDENT            \
                        tocnarrow           .TOCNARROW            \
                        tocompact           .TOCOMPACT            \
                        topblock            .TOPBLOCK             \
                        useobject           .USEOBJECT]          {
        if {![info exists options($o)]} {
            continue
        }
        switch -- $options($o) {
            yes - true - 1 {
                set options($O) 1
            }

            default {
                set options($O) 0
            }
        }
    }

    foreach {o O} [list artworklines .ARTWORKLINES \
                        tocdepth     .TOCDEPTH] {
        if {[catch { incr options($o) 0 }]} {
            unexpected error "invalid $o value '$options($o)'"
        }
        set options($O) $options($o)
    }

    foreach {o O} [list footer  .FOOTER \
                        header  .HEADER  \
                        private .PRIVATE] {
        set options($O) 0
        if {[string compare $options($o) ""]} {
            set options($O) 1
        }
    }
    switch -- $mode {
        nr - txt {
            set options(.SLIDES) 0
            # needed for annotations with mark-up to work correctly...
            set passmax 3
        }

        html {
            if {$options(.SLIDES)} {
                set options(.TOC) 0
            }
            if {$options(.SLIDES)} {
                set passmax 3
            }
        }
    }
    if {!$options(.COMMENTS)} {
        set options(.INLINE) 0
    }
    if {![info exists options(symrefs)]} {
        # 2 triggers warning of changed default
        set options(.SYMREFS) 2
    }
    if {![info exists options(compact)]} {
        set options(.COMPACT) $options(.RFCEDSTYLE)
    }
    if {![info exists options(subcompact)]} {
        if {$options(.RFCEDSTYLE)} {
            set options(.SUBCOMPACT) 0
        } else {
            set options(.SUBCOMPACT) $options(.COMPACT)
        }
    }
    if {$options(.PRIVATE)} {
        set options(.HEADER) 1
        set options(.FOOTER) 1
    }
    if {$options(.DOCMAPPING)} {
        set options(.TOPTAG) "h1"
    } else {
        set options(.TOPTAG) "h3"
    }
}

#       }}}2 Options (rfc-PI directives) processing
#       {{{2 XML and DTD declaration callbacks

proc xmldecl {version encoding standalone} {
    if {[string compare $version 1.0]} {
        unexpected error "invalid XML version: $version"
    }
}


proc doctype {element public system internal} {
    global stack
    global intentities extentities

    if {[info exists stack]} {
        return
    }

    if {   [string compare $element rfc]
        || (   [string compare $public ""]
            && ![regexp -- {-//IETF//DTD RFC 2629.*//EN} $public])
        || ![regexp -- {^(|.*/)rfc.*\.dtd$} $system]} {
        unexpected error "invalid DOCTYPE: $element+$public+$system+$internal"
    }
    for {set start 0} \
        {[regexp -indices -start $start -- \
          {<!-- xml2rfc-processed-entity ([A-Za-z_:][A-Za-z0-9._:-]*) -->} \
          $internal x entity]} \
        {set start $b} {
        set a [lindex $x 0]
        set b [lindex $x 1]
        set ea [lindex $entity 0]
        set eb [lindex $entity 1]
        set entity_proper([string range $internal $ea $eb]) 1
    }
    foreach e {int ext} {
        foreach entity [array names ${e}entities] {
            if {![info exists entity_proper($entity)]} {
                unexpected warning \
                    "${e}ernal entity $entity defined outside DOCTYPE, so is invalid XML"
            }
        }
    }
}

#       }}}2 XML and DTD declaration callbacks
#       {{{2 The unexpected (error printing)

global already_warned
catch { array unset already_warned }

proc unex_init {} {
    global already_warned

    catch { array unset already_warned }
}

proc unexpected {args} {
    global prog
    global guiP

    set text [join [lrange $args 1 end] " "]

    switch -- [set type [lindex $args 0]] {
        error {
            global errorP

            set errorP 1
            if {$guiP != 1} {
                set text "$prog: error: $text"
            }
            return -code error $text
        }

        notice {
            if {$guiP == -1} {
                puts stdout $text
            }
        }

        default {
            global already_warned

            append text [around2fl ""]
            if {[info exists already_warned($text)]} {
                return
            }
            set already_warned($text) 1
            #append text [around2fl ""]
            switch -- $guiP {
                1 { tk_dialog .unexpected "$prog: $type" $text $type 0 OK }

                0 {
                    global env

                    if {[llength [array names env REQUEST_METHOD]] <= 0} {
                        # Not under CGI.
                        puts stderr "$prog: $type: $text"
                    } else {
                        lappend xml2rfc_warnings "$prog: $type: $text"
                    }
                }

                -1 { puts stdout "$type: $text" }
            }
        }
    }
}

proc unex_condtype {} {
    global options

    if {$options(.STRICT)} {
        return error
    } else {
        return warning
    }
}

#       }}}2 The unexpected (error printing)
#       {{{2 Other IPR texts

global validity1 validity2

# From RFC 3978 (BCP 78), Section 5.5.
set validity1 {
"This document and the information contained herein are provided
on an &ldquo;AS IS&rdquo; basis and THE CONTRIBUTOR,
THE ORGANIZATION HE/SHE REPRESENTS OR IS SPONSORED BY (IF ANY),
THE INTERNET SOCIETY AND THE INTERNET ENGINEERING TASK FORCE DISCLAIM
ALL WARRANTIES,
EXPRESS OR IMPLIED,
INCLUDING BUT NOT LIMITED TO ANY WARRANTY THAT THE USE OF THE
INFORMATION HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY IMPLIED
WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE."
}

# draft-ietf-ipr-ietf-trust-update to validity1
set validity2 {
"This document and the information contained herein are provided
on an &ldquo;AS IS&rdquo; basis and THE CONTRIBUTOR,
THE ORGANIZATION HE/SHE REPRESENTS
OR IS SPONSORED BY (IF ANY), THE INTERNET SOCIETY, THE IETF TRUST
AND THE INTERNET ENGINEERING TASK FORCE DISCLAIM ALL WARRANTIES,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTY THAT
THE USE OF THE INFORMATION HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY
IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR
PURPOSE."
}

global copylong1 copylong2 copylong3 copylong4 copylong5 copyurl

# From RFC 2026 (BCP 9), Section 10.4, Notice C;
# Section 10 is now replaced by BCPs 78 and 79.
set copylong1 {
"Copyright &copy; The Internet Society (%YEAR%). All Rights Reserved."

"This document and translations of it may be copied and furnished to
others, and derivative works that comment on or otherwise explain it
or assist in its implementation may be prepared, copied, published and
distributed, in whole or in part, without restriction of any kind,
provided that the above copyright notice and this paragraph are
included on all such copies and derivative works. However, this
document itself may not be modified in any way, such as by removing
the copyright notice or references to the Internet Society or other
Internet organizations, except as needed for the purpose of
developing Internet standards in which case the procedures for
copyrights defined in the Internet Standards process must be
followed, or as required to translate it into languages other than
English."

"The limited permissions granted above are perpetual and will not be
revoked by the Internet Society or its successors or assigns."

"This document and the information contained herein is provided on an
&ldquo;AS IS&rdquo; basis and THE INTERNET SOCIETY AND THE INTERNET ENGINEERING
TASK FORCE DISCLAIMS ALL WARRANTIES, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO ANY WARRANTY THAT THE USE OF THE INFORMATION
HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY IMPLIED WARRANTIES OF
MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE."
}

# From RFC 3978 (BCP 78), Section 5.4.
# For independent submissions, as opposed to IETF ones,
# there is an additional " and at www.rfc-editor.org/copyright.html"
# right after "BCP 78";
# this additional text is at the RFC Editor's discretion.

# <ftp://ftp.isi.edu/in-notes/rfc-editor/boilerplate.ietfsub.1Mar05.txt>
# <ftp://ftp.isi.edu/in-notes/authors/lastpage.ietfsub.nroff>
set copylong2 {
"Copyright &copy; The Internet Society (%YEAR%)."

"This document is subject to the rights,
licenses and restrictions contained in BCP&nbsp;78,
and except as set forth therein,
the authors retain all their rights."
}

# <ftp://ftp.isi.edu/in-notes/rfc-editor/boilerplate.indsub.1Mar05.txt>
# <ftp://ftp.isi.edu/in-notes/authors/lastpage.indsub.nroff>
set copylong3 {
"Copyright &copy; The Internet Society (%YEAR%)."

"This document is subject to the rights,
licenses and restrictions contained in BCP&nbsp;78
and at %COPYURL%, and except as set forth therein,
the authors retain all their rights."
}

# RFC 4748 modification to copylong2
set copylong4 {
"Copyright &copy; The IETF Trust (%YEAR%)."

"This document is subject to the rights,
licenses and restrictions contained in BCP&nbsp;78,
and except as set forth therein,
the authors retain all their rights."
}

# RFC 4748 modification to copylong3
set copylong5 {
"Copyright &copy; The IETF Trust (%YEAR%)."

"This document is subject to the rights,
licenses and restrictions contained in BCP&nbsp;78
and at %COPYURL%, and except as set forth therein,
the authors retain all their rights."
}

set copyurl "http://www.rfc-editor.org/copyright.html"

global iprlong1 iprlong2 iprurl ipremail

set iprurl "http://www.ietf.org/ipr"
set ipremail "ietf-ipr@ietf.org"

# From RFC 2026 (BCP 9), Section 10.4, Notices A and B;
# Section 10 is now replaced by BCPs 78 and 79.
set iprlong1 {
"The IETF takes no position regarding the validity or scope of
any intellectual property or other rights that might be claimed
to  pertain to the implementation or use of the technology
described in this document or the extent to which any license
under such rights might or might not be available; neither does
it represent that it has made any effort to identify any such
rights. Information on the IETF's procedures with respect to
rights in standards-track and standards-related documentation
can be found in BCP&nbsp;11. Copies of claims of rights made
available for publication and any assurances of licenses to
be made available, or the result of an attempt made
to obtain a general license or permission for the use of such
proprietary rights by implementors or users of this
specification can be obtained from the IETF Secretariat."

"The IETF invites any interested party to bring to its
attention any copyrights, patents or patent applications, or
other proprietary rights which may cover technology that may be
required to practice this standard. Please address the
information to the IETF Executive Director."
}

# From RFC 3979 (BCP 79), Section 5.
set iprlong2 {
"The IETF takes no position regarding the validity or scope of any
Intellectual Property Rights or other rights that might be claimed
to pertain to the implementation or use of the technology
described in this document or the extent to which any license
under such rights might or might not be available; nor does it
represent that it has made any independent effort to identify any
such rights.
Information on the procedures with respect to
rights in RFC documents can be found in BCP&nbsp;78 and BCP&nbsp;79."

"Copies of IPR disclosures made to the IETF Secretariat and any
assurances of licenses to be made available,
or the result of an attempt made to obtain a general license or
permission for the use of such proprietary rights by implementers or
users of this specification can be obtained from the IETF on-line IPR
repository at %IPRURL%."

"The IETF invites any interested party to bring to its attention
any copyrights,
patents or patent applications,
or other
proprietary rights that may cover technology that may be required
to implement this standard.
Please address the information to the IETF at %IPREMAIL%."
}

global iprextra

# From RFC 2026 (BCP 9), Section 10.4, Notice D;
# Section 10 is now replaced by BCPs 78 and 79,
# which don't feature such text.
set iprextra {
"The IETF has been notified of intellectual property rights
claimed in regard to some or all of the specification contained
in this document. For more information consult the online list
of claimed rights."
}

global funding funding1 funding2

# Appears in all rfc-editor/boilerplate*.txt files.
# Something the RFC Editor adds at his/her discretion.
# (Authoritative) source:  this email
#     From: Brian E Carpenter <brian@hursley.ibm.com>
#     Organization: IBM Internet Division
#     To: jkrey@ISI.EDU
#     CC: iab@ISI.EDU, iesg@ISI.EDU, rfc-ed@ISI.EDU
#     Subject: Re: RFC Editor Contract signed...
#     ...
#     Secondly, I don't think this is such a big deal, but let's
#     deem that the conclusion of the discussion is to put this
#     small acknowledgment at the end rather than at the beginning.
#
# The RFC Editor stopped adding this boilerplate as of
# 21 August 2007.  See http://www.rfc-editor.org/news.html .
set funding1 \
"Funding for the RFC Editor function is currently provided by
the Internet Society."

set funding2 \
"Funding for the RFC Editor function is provided by
the IETF Administrative Support Activity (IASA)."


# get the publication date in seconds; returns 0 when not available

proc get_publication_date_seconds {date} {
    global elem

    array set dv $elem($date)

    set three [clock format [clock seconds] -format "%B %Y %d"]

    if {[catch { set dv(year) }]} {
        set dv(year) [lindex $three 1]
    }
    if {[catch { set dv(month) }]} {
        if {(![string compare $dv(year) [lindex $three 1]])} {
            set dv(month) [lindex $three 0]
            set dv(day) [string trimleft [lindex $three 2] 0]
        } else {
            unexpected error "I can't synthesize a date in $dv(year)"
        }
    } elseif {[catch { set dv(day) }]} {
        if {(![string compare $dv(month) [lindex $three 0]]) \
                && (![string compare $dv(year) [lindex $three 1]])} {
            set dv(day) [string trimleft [lindex $three 2] 0]
        }
    }
    set elem($date) [array get dv]
    
    if {[catch { set day $dv(day) }]} {
        set day 1
    }
    if {[catch {set secs [clock scan "$dv(month) $day, $dv(year)" -gmt true]}]} {
        set secs 0
    }
    
    return $secs
}


#       }}}2 Other IPR texts
#       {{{2 Pass 2 (and subsequent) stuff for the whole document

proc pass2begin_rfc {elemX} {
    global counter elem passno xref
    global options copyrightP iprP
    global copyshort copyshort1 copyshort2 copyshort3 copyshortTrust200811 \
           copyshortTrust200909 copyshortTrust200902 \
           codeComponents200909 pre5378escapeClause
    global funding funding1 funding2
    global backP

    set backP 0

    array set attrs [list number     ""   obsoletes      ""   updates   "" \
                          seriesNo   ""   ipr            "" \
                          iprExtract ""   submissionType IETF xml:lang  en \
                          consensus  ""]
    array set attrs $elem($elemX)
    set elem($elemX) [array get attrs]

    set front [find_element front $attrs(.CHILDREN)]
    array set fv $elem($front)

    if {(!$options(.PRIVATE)) \
            && (![string compare $attrs(number) ""]) \
            && (![string compare $attrs(ipr) ""])} {
        unexpected error \
                   "rfc element needs either a number or an ipr attribute"
    }
    if {![string compare $attrs(ipr) none]} {
        set copyrightP 0
    } else {
        set copyrightP 1
        set iprP 1
    }

    set newP 9
    if {![info exists fv(.PARSEDDATE)]} {
        set date [find_element date $fv(.CHILDREN)]
        set secs [get_publication_date_seconds $date]
        set fv(.PARSEDDATE) $secs
        set elem($front) [array get fv]
    }
    if {[catch { clock format $fv(.PARSEDDATE) -format "%Y%m%d" -gmt true } \
               ymd]} {
        # Should differentiate between PARSEDATE not set (e.g., early pass)
        # vs. PARSEDATE set to 0 (i.e., couldn't parse date)
        set ymd ""
    }

    # newP=9 is the latest.
    # See if it needs to be dropped back to an earlier version.
    if {[string compare $attrs(number) ""]} {
        if {$attrs(number) <= 2499} {
            set newP 0
        } elseif {$attrs(number) <= 3707} {
            set newP 1
        } elseif {$attrs(number) <= 4321} {
            set newP 2
        } elseif {$attrs(number) <= 4671} {
            # 4671 is a guess
            set newP 3
        } elseif {($attrs(number) < 5000) ||
            ([lsearch {5020 5021 5034 5052 5065 5094} $attrs(number)] > -1)} {
            set newP 4
        } elseif {$ymd < "20081101"} {
            set newP 5
        } elseif {$ymd < "20090201"} {
            set newP 6
        } elseif {$ymd < "20090901" ||
            ([lsearch {5582 5621 5632 5645 5646 5681} $attrs(number)] > -1)} {
            # TLP 2009 09 copyright notice beginning with Sep 2009, except
            # for the RFCs listed above
            set newP 7
        } elseif {$ymd < "20100101"} {
            set newP 8
        }
    } elseif {[string compare $attrs(ipr) ""]} {
        if {   [string first "3667" $attrs(ipr)] >= 0
            || [string first "3978" $attrs(ipr)] >= 0} {
            set newP 5
        } elseif {[string first "trust" [string tolower $attrs(ipr)]] < 0} {
            set newP 1
        } elseif {$ymd < "20091101"} {
            # TLP 2009 09 copyright notice beginning with Nov 2009
            set newP 7
        } elseif {$ymd < "20100401"} {
            # TLP 2010 01 copyright notice beginning with Apr 2010
            set newP 8
        }
        # note: no support for 2008 11 TLP text in IDs
    }

    if {$newP == 9} {
        set copyshort $copyshortTrust200909

        if {![catch { set attrs(submissionType) }]} {
          switch -- $attrs(submissionType) {
            IETF {
              regsub -all -- %CODECOMPONENTS% $copyshort $codeComponents200909 copyshort
              # in the code components statement, say "Simplied BSD License"
              regsub -all -- %SIMPLIFIED% $copyshort "Simplified " copyshort
            }
            default {
              regsub -all -- %CODECOMPONENTS% $copyshort "" copyshort
            }
          }
        }
          
        # RFCs: include escape clause in Copyright Notice
        # IDs: include in Status Of This Memo (produced elsewhere), for date before Nov 2009
        if {![string compare $attrs(ipr) "pre5378Trust200902"] && \
            ([string compare $attrs(number) ""] || $ymd >= "20091101")} {
            lappend copyshort $pre5378escapeClause
        }
        set funding ""
        set copyrightP -1
        set iprP 0
    } elseif {$newP == 8} {
        set copyshort $copyshortTrust200909
        # pre-201004: append code component clause unconditionally
        regsub -all -- %CODECOMPONENTS% $copyshort $codeComponents200909 copyshort
        # in the code components statement, say "BSD License"
        regsub -all -- %SIMPLIFIED% $copyshort "" copyshort
          
        # RFCs: include escape clause in Copyright Notice
        # IDs: include in Status Of This Memo (produced elsewhere), for date before Nov 2009
        if {![string compare $attrs(ipr) "pre5378Trust200902"] && \
            ([string compare $attrs(number) ""] || $ymd >= "20091101")} {
            lappend copyshort $pre5378escapeClause
        }
        set funding ""
        set copyrightP -1
        set iprP 0
    } elseif {$newP == 7} {
        set copyshort $copyshortTrust200902
        # RFCs: include escape clause in Copyright Notice
        # IDs: include in Status Of This Memo (produced elsewhere)
        if {![string compare $attrs(ipr) "pre5378Trust200902"] && \
            [string compare $attrs(number) ""]} {
            lappend copyshort $pre5378escapeClause
        }
        set funding ""
        set copyrightP -1
        set iprP 0
    } elseif {$newP == 6} {
        set copyshort $copyshortTrust200811
        set funding ""
        set copyrightP -1
        set iprP 0
    } elseif {$newP == 5} {
        set copyshort ""
        set funding ""
    } elseif {$newP == 4} {
        set copyshort $copyshort3
        set funding $funding2
    } elseif {$newP == 3} {
        set copyshort $copyshort2
        set funding $funding2
    } elseif {$newP == 2} {
        set copyshort $copyshort2
        set funding $funding1
    } elseif {$newP == 1} {
        set copyshort $copyshort1
        set funding $funding1
    } else {
        set copyshort $copyshort1
        set funding ""
    }

    if {   $passno == 2
        && [info exists counter(firstxref)]
        && [llength [set back [find_element back $attrs(.CHILDREN)]]] == 1} {

        set warnonly [expr !$options(.SORTREFS) || $options(.SYMREFS)]

        catch { array unset bv }
        array set bv $elem($back)

        set firstxref [list ""]
        foreach target $counter(firstxref) {
            if {   ![catch { array set av $xref($target) }]
                && ![string compare $av(type) reference]} {
                lappend firstxref $target
            }
        }

        set offset 0
        foreach refs [find_element references $bv(.CHILDREN)] {
            catch { array unset sv }
            array set sv $elem($refs)

            foreach ref [find_element reference $sv(.CHILDREN)] {
                catch { array unset rv }
                array set rv $elem($ref)
                if {![info exists rv(anchor)]} {
                    continue
                }
                if {[set x [lsearch $firstxref $rv(anchor)]] < 0} {
                    set x [llength $firstxref]
                    lappend firstxref $rv(anchor)
                    unexpected warning "no <xref> in <rfc> targets <reference anchor='$rv(anchor)'>"
                }
                if {!$warnonly} {
                    set rv(.COUNTER) $x
                    set elem($ref) [array get rv]
                }
            }

            if {$warnonly} {
                continue
            }

            foreach ref [lsort -command sort_references \
                                [find_element reference $sv(.CHILDREN)]] {
                catch { array unset rv }
                array set rv $elem($ref)
                set rv(.COUNTER) [incr offset]
                set elem($ref) [array get rv]

                set target $rv(anchor)
                catch { array unset xv }
                array set xv $xref($target)
                set xv(value) $offset
                set xref($target) [array get xv]
            }
        }
    }
}

# Sort irefs by:
#  $elem(item)
#  $elem(subitem)
#  $elem(flags)
# Use lsort -dictionary to get dictionary comparison if we're
# comparing item and subitem; just use string compare on flags.
proc iref_sort {elemA elemB} {
    global elem

    array set a $elem($elemA)
    array set b $elem($elemB)
    set aval $a(item)
    set bval $b(item)
    if {[string compare $aval $bval] == 0} {
        set aval $a(subitem)
        set bval $b(subitem)
        if {[string compare $aval $bval] == 0} {
            return [string compare $a(flags) $b(flags)]
        }
    }
    # use lsort to get dictionary order on items
    set result [lindex [lsort -dictionary [list $aval $bval]] 0]
    if {[string compare $aval $result] == 0} {
        return -1
    } else {
        return 1
    }
}

proc pass2end_rfc {elemX} {
    global elem
    global elemZ
    global mode
    global options
    global pageno
    global copyurl

    array set attrs $elem($elemX)

    set front [find_element front $attrs(.CHILDREN)]
    array set fv $elem($front)
    if {[catch { clock format $fv(.PARSEDDATE) -format "%Y%m%d" -gmt true } \
               ymd]} {
        # Should differentiate between PARSEDATE not set (e.g., early pass)
        # vs. PARSEDATE set to 0 (i.e., couldn't parse date)
        set ymd ""
    }

    set date [find_element date $fv(.CHILDREN)]
    array set dv $elem($date)

    if {$options(.SYMREFS) == 2} {
        unexpected warning "<?rfc symrefs=?> now defaults to \"yes\""
    }


    ###########
    # Authors #
    ###########

    set authors ""
    foreach child [find_element author $fv(.CHILDREN)] {
        array set av [list initials "" surname "" fullname "" role ""]
        array set av $elem($child)

        set organization [find_element organization $av(.CHILDREN)]
        if {[llength $organization] == 1} {
          array set ov [list abbrev ""]
          if {[string compare $organization ""]} {
              array set ov $elem($organization)
          }
        }

        set block1 ""
        if {[string compare $av(fullname) ""]} {
            if {![string compare $av(role) editor]} {
                append av(fullname) " (editor)"
            }
            lappend block1 $av(fullname)
        }
        if {[llength $organization] == 1 && [string compare $ov(.CTEXT) ""]} {
            lappend block1 $ov(.CTEXT)
        }

        set address [find_element address $av(.CHILDREN)]
        set block2 ""
        if {[llength $address] == 1} {
            array set zv $elem($address)

            set postal [find_element postal $zv(.CHILDREN)]
            if {[llength $postal] == 1} {
                array set pv $elem($postal)

                foreach street [find_element street $pv(.CHILDREN)] {
                    array set sv $elem($street)

                    if {[string compare $sv(.CTEXT) ""]} {
                        lappend block1 $sv(.CTEXT)
                    }
                }

                set s ""
                foreach e {city region code} t {"" ", " "  "} {
                    set f [find_element $e $pv(.CHILDREN)]
                    if {[llength $f] == 1} {
                        catch { array unset fv }
                        array set fv $elem($f)

                        if {[string compare $s ""]} {
                            append s $t
                        }
                        append s $fv(.CTEXT)
                    }
                }
                if {[string compare $s ""]} {
                    lappend block1 $s
                }
                set f [find_element country $pv(.CHILDREN)]
                if {[llength $f] == 1} {
                    catch { array unset fv }
                    array set fv $elem($f)

                    lappend block1 $fv(.CTEXT)
                }
            }

            set block2 ""
            foreach e {phone facsimile email uri} {
                set f [find_element $e $zv(.CHILDREN)]
                if {[llength $f] == 1} {
                    catch { array unset fv }
                    array set fv $elem($f)

                    lappend block2 [list $e $fv(.CTEXT)]
                }
            }
        }

        lappend authors [list $block1 $block2]
    }

    if {($options(.STRICT)) && ([set l [llength $authors]] > 5)} {
        unexpected error "$l authors, maximum of 5 allowed. Remove strict='yes' to proceed."
    }


    #######
    # IPR #
    #######

    set newP 3
    if {[string compare $attrs(number) ""]} {
        # TODO: set newP using PARSEDDATE for all the options
        if {$attrs(number) <= 3707} {
            set newP 0
        } elseif {$attrs(number) <= 4671} {
            # 4671 is a guess
            set newP 1
        } elseif {$ymd < "20081101"} {
            set newP 2
        }
    } elseif {[string compare $attrs(ipr) ""]} {
        if {   [string first "3667" $attrs(ipr)] >=0
            || [string first "3978" $attrs(ipr)] >=0} {
            set newP 2
        } elseif {[string first "trust" [string tolower $attrs(ipr)]] < 0} {
            set newP 0
        }
    }
    # set copylong to the proper value
    if {$newP} {
        global copylong2 copylong3 copylong4 copylong5 validity1 validity2

        if {$newP == 1} {
                switch -- $attrs(submissionType) {
                    IETF {
                        set copylong $copylong2
                    }
                    independent {
                        set copylong $copylong3
                    }
                    default {
                        unexpected error \
                            "submissionType=\"$attrs(submissionType)\" unexpected for this boilerplate (1)"
                    }
                }
                set validity $validity1
        } elseif {$newP == 2} {
                switch -- $attrs(submissionType) {
                    IETF {
                        set copylong $copylong4
                    }
                    independent {
                        set copylong $copylong5
                    }
                    default {
                        unexpected error \
                            "submissionType=\"$attrs(submissionType)\" unexpected for this boilerplate (2)"
                    }
                }
                set validity $validity2
        } else {
                # IETF Trust removed these statements at the back
                set copylong ""
                set validity ""
        }
    } else {
        global copylong1

        set copylong $copylong1
        set validity ""
    }
    regsub -all -- %YEAR% $copylong $dv(year) copying
    if {![string compare $mode html]} {
        regsub -all -- %COPYURL% $copying "<a href='$copyurl'>$copyurl</a>" copying
    } else {
        regsub -all -- %COPYURL% $copying $copyurl copying
    }

    if {![catch { set who $attrs(disclaimant) }]} {
        # This is an undocumented non-IETF extension.
        lappend copying \
"%WHO% expressly disclaims any and all warranties regarding this
contribution including any warranty that (a) this contribution does
not violate the rights of others, (b) the owners, if any, of other
rights in this contribution have been informed of the rights and
permissions granted to IETF herein, and (c) any required
authorizations from such owners have been obtained.
This document and the information contained herein is provided on
an &ldquo;AS IS&rdquo; basis and %UWHO% DISCLAIMS ALL WARRANTIES, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTY THAT THE USE
OF THE INFORMATION HEREIN WILL NOT INFRINGE ANY RIGHTS OR ANY
IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR
PURPOSE." \
 \
"IN NO EVENT WILL %UWHO% BE LIABLE TO ANY OTHER PARTY INCLUDING
THE IETF AND ITS MEMBERS FOR THE COST OF PROCURING SUBSTITUTE GOODS
OR SERVICES, LOST PROFITS, LOSS OF USE, LOSS OF DATA, OR ANY
INCIDENTAL, CONSEQUENTIAL, INDIRECT, OR SPECIAL DAMAGES WHETHER
UNDER CONTRACT, TORT, WARRANTY, OR OTHERWISE, ARISING IN ANY WAY
OUT OF THIS OR ANY OTHER AGREEMENT RELATING TO THIS DOCUMENT,
WHETHER OR NOT SUCH PARTY HAD ADVANCE NOTICE OF THE POSSIBILITY OF
SUCH DAMAGES."

        regsub -all -- %WHO% $copying $who copying
        regsub -all -- %UWHO% $copying [string toupper $who] copying
    }

    # determine the value of iprstmt
    if {$newP} {
        global iprlong2

        set iprstmt $iprlong2
    } else {
        global iprlong1

        set iprstmt $iprlong1
        if {$options(.IPRNOTIFIED)} {
            global iprextra

            set iprstmt [concat $iprstmt $iprextra]
        }
    }


    #########
    # Index #
    #########

    set elems ""
    # use \uFFFD REPLACEMENT CHARACTER to separate items in the key of $index,
    # assuming that never legitimately appears in iref elements.
    array set index ""
    for {set elemY 1} {$elemY <= $elemZ} {incr elemY} {
        catch { array unset iv }
        array set iv $elem($elemY)

        if {[string compare $iv(.NAME) iref]} {
            continue
        }
        lappend elems $elemY
        lappend index($iv(item)\uFFFD$iv(subitem)\uFFFD$iv(flags)) $iv(.ANCHOR)
    }
    set elems [lsort -command iref_sort $elems]

    set irefs ""
    set L ""
    set K ""
    set previtem ""
    foreach elemY $elems {
        catch { array unset iv }
        array set iv $elem($elemY)
        set key $iv(item)
        set subkey $iv(subitem)
        set flags $iv(flags)
        set curitem "$key\uFFFD$subkey\uFFFD$flags"
        if {$curitem == $previtem} {
            continue
        }
        set previtem $curitem
        set iref ""
        if {[string compare [set c [string toupper [string index $key 0]]] \
                    $L]} {
            lappend iref [set L $c]
            set K ""
        } else {
            lappend iref ""
        }
        if {[string compare $key $K]} {
            lappend iref [set K $key]
        } else {
            lappend iref ""
        }
        lappend iref $subkey
        lappend iref $flags
        lappend iref $index($curitem)
        lappend irefs $iref
    }

    set attrs(.ANCHOR) [rfc_$mode $irefs $authors $iprstmt $copying $newP $validity]
    set elem($elemX) [array get attrs]

    if {([string compare $mode html]) \
            && ($options(.STRICT)) && (!$options(.TOC)) \
            && ($pageno > 15)} {
        unexpected error "no table of contents, but $pageno pages"
    }
}

#       }}}2 Pass 2 (and subsequent) stuff for the whole document
#       {{{2 Front texts (either for the rfc or a reference)

global copyshort copyshort1 copyshort2 idinfo idinfo2 idaburl idshurl

set idaburl "http://www.ietf.org/ietf/1id-abstracts.txt"
set idshurl "http://www.ietf.org/shadow.html"

# From RFC 2223, Section 6.
set copyshort1 \
{"Copyright &copy; The Internet Society (%YEAR%). All Rights Reserved."}

# From the rfc-editor/instructions2authors.txt file, Section 4.3.
# Currently draft-rfc-editor-rfc2223bis-08, which is expired.
set copyshort2 \
{"Copyright &copy; The Internet Society (%YEAR%)."}

# RFC 4748 modification to copyshort2
set copyshort3 \
{"Copyright &copy; The IETF Trust (%YEAR%)."}

# Trust Copyright and License
# various dates, some incl pre5378 escape clause

set copyshortTrust200811 \
{"Copyright (c) %YEAR% IETF Trust and the persons identified as the
document authors.  All rights reserved."

"This document is subject to BCP 78 and the IETF Trust's Legal
Provisions Relating to IETF Documents
(http://trustee.ietf.org/license-info) in effect on the date of
publication of this document.  Please review these documents
carefully, as they describe your rights and restrictions with respect
to this document."}

set copyshortTrust200902 \
{"Copyright (c) %YEAR% IETF Trust and the persons identified as the
document authors.  All rights reserved."

"This document is subject to BCP 78 and the IETF Trust's Legal
Provisions Relating to IETF Documents in effect on the date of
publication of this document (http://trustee.ietf.org/license-info).
Please review these documents carefully, as they describe your
rights and restrictions with respect to this document."}

set pre5378escapeClause \
"This document may contain material from IETF Documents or IETF
Contributions published or made publicly available before November
10, 2008.  The person(s) controlling the copyright in some of this
material may not have granted the IETF Trust the right to allow
modifications of such material outside the IETF Standards Process.
Without obtaining an adequate license from the person(s) controlling
the copyright in such materials, this document may not be modified
outside the IETF Standards Process, and derivative works of it may
not be created outside the IETF Standards Process, except to format
it for publication as an RFC or to translate it into languages other
than English."

set copyshortTrust200909 \
{"Copyright (c) %YEAR% IETF Trust and the persons identified as the
document authors.  All rights reserved."

"This document is subject to BCP 78 and the IETF Trust's Legal
Provisions Relating to IETF Documents
(http://trustee.ietf.org/license-info) in effect on the date of
publication of this document.  Please review these documents
carefully, as they describe your rights and restrictions with respect
to this document.%CODECOMPONENTS%"}

set codeComponents200909 \
" Code Components extracted from this document must
include Simplified BSD License text as described in Section 4.e of
the Trust Legal Provisions and are provided without warranty as
described in the %SIMPLIFIED%BSD License."

# From the ietf/1id-guidelines.txt file, Section 5.
set idinfo {
"%IPR%"

"Internet-Drafts are working documents of the Internet Engineering
Task Force (IETF), its areas, and its working groups.
Note that other groups may also distribute working documents as
Internet-Drafts."

"Internet-Drafts are draft documents valid for a maximum of six months
and may be updated, replaced, or obsoleted by other documents at any time.
It is inappropriate to use Internet-Drafts as reference material or to cite
them other than as &ldquo;work in progress.&rdquo;"

"The list of current Internet-Drafts can be accessed at
%IDABURL%."

"The list of Internet-Draft Shadow Directories can be accessed at
%IDSHURL%."

"This Internet-Draft will expire on %EXPIRES%."
}

# Shorter idinfo approved as an alternative by the IESG on 2010-1-5 and
# announced on 2010-2-8:
# http://www.ietf.org/mail-archive/web/ietf-announce/current/msg07008.html
set idinfo2 {
"%IPR%"

"Internet-Drafts are working documents of the Internet Engineering
Task Force (IETF).  Note that other groups may also distribute
working documents as Internet-Drafts.  The list of current
Internet-Drafts is at http://datatracker.ietf.org/drafts/current/."

"Internet-Drafts are draft documents valid for a maximum of six months
and may be updated, replaced, or obsoleted by other documents at any time.
It is inappropriate to use Internet-Drafts as reference material or to cite
them other than as &ldquo;work in progress.&rdquo;"

"This Internet-Draft will expire on %EXPIRES%."
}

#       }}}2 Front texts (either for the rfc or a reference)
#       {{{2 Remaining pass 2 (and subsequent) stuff


proc pass2begin_front {elemX} {
    global counter elem xref
    global options
    global mode ofile
    global categories copyshort idinfo idinfo2 idaburl idshurl iprstatus
    global page_width center_fill_width
    global depth

    if {$options(.COLONSPACE)} {
        set colonspace " "
    } else {
        set colonspace ""
    }

    array set attrs $elem($elemX)

    set title [find_element title $attrs(.CHILDREN)]
    array set tv [list abbrev ""]
    array set tv $elem($title)
    set title [list $tv(.CTEXT)]

    set date [find_element date $attrs(.CHILDREN)]
    array set dv $elem($date)

    array set rv $elem(1)
    catch { set ofile $rv(docName) }

    if {![info exists attrs(.PARSEDDATE)]} {
        set secs [get_publication_date_seconds $date]
        set attrs(.PARSEDDATE) $secs
    }
    
    if {[catch { clock format $attrs(.PARSEDDATE) -format "%Y%m%d" -gmt true } \
               ymd]} {
        # Should differentiate between PARSEDATE not set (e.g., early pass)
        # vs. PARSEDATE set to 0 (i.e., couldn't parse date)
        set ymd ""
    }
    
    # determine the value of consensus (default yes), and
    # remember whether it was specified
    set consensus "yes"
    set consensusConsumed "no"
    set consensusSpecified "no"
    if {![catch { set rv(consensus) }]} {
        set consensus $rv(consensus)
        set consensusSpecified "yes"
        if {![string compare $consensus ""]} {
            set consensus "yes"
            set consensusSpecified "no"
        }
    }
    
    if {$options(.PRIVATE)} {
        lappend left $options(private)

        set status ""
    } else {

        # do we need the 2010 header format?
        set boilerplateformat ""
        if {$ymd >= "20100101" ||
            ([lsearch {5741 5742 5743} $rv(number)] >= 0)} {
            set boilerplateformat "2010"
        }
        
        set first ""
        if {(![string compare $rv(number) ""]) \
                && ([string compare \
                             [set workgroup [lindex [find_element workgroup \
                                 $attrs(.CHILDREN)] 0]] ""])} {
            array set wv $elem($workgroup)
            set first [string trim $wv(.CTEXT)]
        }
        if {([string compare $rv(number) ""]) && 
             ![string compare $first ""] &&
             ![string compare $boilerplateformat "2010"]} {
            # starting in 2010, put the submission type into the top left corner
            if {![catch { set rv(submissionType) }]} {
                switch -- $rv(submissionType) {
                    independent {
                        set first "Independent Submission"
                    }
                    IETF {
                        set first "Internet Engineering Task Force (IETF)"
                    }
                    IRTF {
                        set first "Internet Research Task Force (IRTF)"
                    }
                    IAB {
                        set first "Internet Architecture Board (IAB)"
                    }
                    default {
                        unexpected error \
                            "submissionType=\"$rv(submissionType)\" unexpected for this boilerplate (3)"
                    }
                }
            }
        }
        if {![string compare $first ""]} {
            set first "Network Working Group"
        }
        lappend left $first

        if {[catch { set day $dv(day) }]} {
            set day 1
        }
        set secs $attrs(.PARSEDDATE)

        if {[info exists rv(category)]} {
            set cindex [lsearch0 $categories $rv(category)]
        } else {
            set cindex -1
        }
        if {[string compare $rv(number) ""]} {
            if {$cindex == -1} {
                unexpected error "category attribute is mandatory for RFC"
            }
            lappend left "Request for Comments:$colonspace $rv(number)"

            if {[string compare $rv(seriesNo) ""]} {
                lappend left \
                        "[lindex [lindex $categories $cindex] 2]:$colonspace $rv(seriesNo)"
            }

            if {[string compare $rv(obsoletes) ""]} {
                lappend left "Obsoletes:$colonspace $rv(obsoletes)"
            }
            if {[string compare $rv(updates) ""]} {
                lappend left "Updates:$colonspace $rv(updates)"
            }

            set category [lindex [lindex $categories $cindex] 1]
            lappend left "Category:$colonspace $category"
            
            if {![string compare $boilerplateformat "2010"]} {
                # starting in 2010, add the ISSN
                lappend left "ISSN:$colonspace 2070-1721"
                
                # and use a new variant of "Status of this Memo"
                global rfc5741StatusOfMemo3

                set statusOfMemo3 $rfc5741StatusOfMemo3
                regsub -all -- %RFC% $statusOfMemo3 $rv(number) statusOfMemo3

                # below used for debugging unhandled case
                set status "FIND ME"
              
                if {![catch { set rv(submissionType) }]} {
                    switch -- $rv(submissionType) {
                        IAB {
                            if {![catch { set rv(category) }]} {
                                switch -- $rv(category) {
                                    exp {
                                        global rfc5741StatusOfMemo_iab_exp rfc5741StatusOfMemo2_iab_exp 
                                        set status "$rfc5741StatusOfMemo_iab_exp $rfc5741StatusOfMemo2_iab_exp $statusOfMemo3"
                                    }
                                    historic {
                                        global rfc5741StatusOfMemo_iab_historic rfc5741StatusOfMemo2_iab_historic
                                        set status "$rfc5741StatusOfMemo_iab_historic $rfc5741StatusOfMemo2_iab_historic $statusOfMemo3"
                                    }
                                    info {
                                        global rfc5741StatusOfMemo_iab_info rfc5741StatusOfMemo2_iab_info
                                        set status "$rfc5741StatusOfMemo_iab_info $rfc5741StatusOfMemo2_iab_info $statusOfMemo3"
                                    }
                                    default {
                                        unexpected_error "invalid combination of submissionType=\$rv(submissionType\" and category=\"$rv(category)\""
                                    }
                                }
                            }
                        }
                        IETF {
                            if {![catch { set rv(category) }]} {
                                switch -- $rv(category) {
                                    bcp {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                global rfc5741StatusOfMemo_ietf_bcp rfc5741StatusOfMemo2_ietf_bcp
                                                set status "$rfc5741StatusOfMemo_ietf_bcp $rfc5741StatusOfMemo2_ietf_bcp $statusOfMemo3"
                                            }
                                            default {
                                                # "no" not allowed here
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    exp {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                global rfc5741StatusOfMemo_ietf_exp rfc5741StatusOfMemo2_ietf_exp_consensus
                                                set status "$rfc5741StatusOfMemo_ietf_exp $rfc5741StatusOfMemo2_ietf_exp_consensus $statusOfMemo3"
                                            }
                                            no {
                                                global rfc5741StatusOfMemo_ietf_exp rfc5741StatusOfMemo2_ietf_exp_noconsensus
                                                set status "$rfc5741StatusOfMemo_ietf_exp $rfc5741StatusOfMemo2_ietf_exp_noconsensus $statusOfMemo3"
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    historic {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                global rfc5741StatusOfMemo_ietf_historic rfc5741StatusOfMemo2_ietf_historic_consensus
                                                set status "$rfc5741StatusOfMemo_ietf_historic $rfc5741StatusOfMemo2_ietf_historic_consensus $statusOfMemo3"
                                            }
                                            no {
                                                global rfc5741StatusOfMemo_ietf_historic rfc5741StatusOfMemo2_ietf_historic_noconsensus
                                                set status "$rfc5741StatusOfMemo_ietf_historic $rfc5741StatusOfMemo2_ietf_historic_noconsensus $statusOfMemo3"
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    info {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                global rfc5741StatusOfMemo_ietf_info rfc5741StatusOfMemo2_ietf_info_consensus
                                                set status "$rfc5741StatusOfMemo_ietf_info $rfc5741StatusOfMemo2_ietf_info_consensus $statusOfMemo3"
                                            }
                                            no {
                                                global rfc5741StatusOfMemo_ietf_info rfc5741StatusOfMemo2_ietf_info_noconsensus
                                                set status "$rfc5741StatusOfMemo_ietf_info $rfc5741StatusOfMemo2_ietf_info_noconsensus $statusOfMemo3"
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    std {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                global rfc5741StatusOfMemo_ietf_std rfc5741StatusOfMemo2_ietf_std
                                                set status "$rfc5741StatusOfMemo_ietf_std $rfc5741StatusOfMemo2_ietf_std $statusOfMemo3"
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    default {
                                        unexpected_error "invalid combination of submissionType=\$rv(submissionType\" and category=\"$rv(category)\""
                                    }
                                }
                            }
                        }
                        independent {
                            if {![catch { set rv(category) }]} {
                                switch -- $rv(category) {
                                    exp {
                                        global rfc5741StatusOfMemo_ind_exp rfc5741StatusOfMemo2_ind_exp 
                                        set status "$rfc5741StatusOfMemo_ind_exp $rfc5741StatusOfMemo2_ind_exp $statusOfMemo3"
                                    }
                                    historic {
                                        global rfc5741StatusOfMemo_ind_historic rfc5741StatusOfMemo2_ind_historic
                                        set status "$rfc5741StatusOfMemo_ind_historic $rfc5741StatusOfMemo2_ind_historic $statusOfMemo3"
                                    }
                                    info {
                                        global rfc5741StatusOfMemo_ind_info rfc5741StatusOfMemo2_ind_info
                                        set status "$rfc5741StatusOfMemo_ind_info $rfc5741StatusOfMemo2_ind_info $statusOfMemo3"
                                    }
                                    default {
                                        unexpected_error "invalid combination of submissionType=\$rv(submissionType\" and category=\"$rv(category)\""
                                    }
                                }
                            }
                        }
                        IRTF {
                            set workgroupname ""
                            if {([string compare \
                                           [set workgroup [lindex [find_element workgroup \
                                                     $attrs(.CHILDREN)] 0]] ""])} {
                                array set wv $elem($workgroup)
                                # jre: this escapes angle brackets; why?
                                set workgroupname [string trim $wv(.CTEXT)]
                            }

                            if {![catch { set rv(category) }]} {
                                switch -- $rv(category) {
                                    exp {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                if {[string compare $workgroupname ""]} {
                                                    global rfc5741StatusOfMemo_irtf_exp rfc5741StatusOfMemo2_irtf_exp_consensus
                                                    set status "$rfc5741StatusOfMemo_irtf_exp $rfc5741StatusOfMemo2_irtf_exp_consensus $statusOfMemo3"
                                                    regsub -all -- %WORKGROUPNAME% $status "$workgroupname" status
                                                } else {
                                                    global rfc5741StatusOfMemo_irtf_exp rfc5741StatusOfMemo2_irtf_exp_nogroup
                                                    set status "$rfc5741StatusOfMemo_irtf_exp $rfc5741StatusOfMemo2_irtf_exp_nogroup $statusOfMemo3"
                                                }
                                            }
                                            no {
                                                if {[string compare $workgroupname ""]} {
                                                    global rfc5741StatusOfMemo_irtf_exp rfc5741StatusOfMemo2_irtf_exp_noconsensus
                                                    set status "$rfc5741StatusOfMemo_irtf_exp $rfc5741StatusOfMemo2_irtf_exp_noconsensus $statusOfMemo3"
                                                    regsub -all -- %WORKGROUPNAME% $status "$workgroupname" status
                                                } else {
                                                    global rfc5741StatusOfMemo_irtf_exp rfc5741StatusOfMemo2_irtf_exp_nogroup
                                                    set status "$rfc5741StatusOfMemo_irtf_exp $rfc5741StatusOfMemo2_irtf_exp_nogroup $statusOfMemo3"
                                                }
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    historic {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                if {[string compare $workgroupname ""]} {
                                                    global rfc5741StatusOfMemo_irtf_historic rfc5741StatusOfMemo2_irtf_historic_consensus
                                                    set status "$rfc5741StatusOfMemo_irtf_historic $rfc5741StatusOfMemo2_irtf_historic_consensus $statusOfMemo3"
                                                    regsub -all -- %WORKGROUPNAME% $status "$workgroupname" status
                                                } else {
                                                    global rfc5741StatusOfMemo_irtf_historic rfc5741StatusOfMemo2_irtf_historic_nogroup
                                                    set status "$rfc5741StatusOfMemo_irtf_historic $rfc5741StatusOfMemo2_irtf_historic_nogroup $statusOfMemo3"
                                                }
                                            }
                                            no {
                                                if {[string compare $workgroupname ""]} {
                                                    global rfc5741StatusOfMemo_irtf_historic rfc5741StatusOfMemo2_irtf_historic_noconsensus
                                                    set status "$rfc5741StatusOfMemo_irtf_historic $rfc5741StatusOfMemo2_irtf_historic_noconsensus $statusOfMemo3"
                                                    regsub -all -- %WORKGROUPNAME% $status "$workgroupname" status
                                                } else {
                                                    global rfc5741StatusOfMemo_irtf_historic rfc5741StatusOfMemo2_irtf_historic_nogroup
                                                    set status "$rfc5741StatusOfMemo_irtf_historic $rfc5741StatusOfMemo2_irtf_historic_nogroup $statusOfMemo3"
                                                }
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        }
                                    }
                                    info {
                                        set consensusConsumed "yes"
                                        switch -- $consensus {
                                            yes {
                                                if {[string compare $workgroupname ""]} {
                                                    global rfc5741StatusOfMemo_irtf_info rfc5741StatusOfMemo2_irtf_info_consensus
                                                    set status "$rfc5741StatusOfMemo_irtf_info $rfc5741StatusOfMemo2_irtf_info_consensus $statusOfMemo3"
                                                    regsub -all -- %WORKGROUPNAME% $status "$workgroupname" status
                                                } else {
                                                    global rfc5741StatusOfMemo_irtf_info rfc5741StatusOfMemo2_irtf_info_nogroup
                                                    set status "$rfc5741StatusOfMemo_irtf_info $rfc5741StatusOfMemo2_irtf_info_nogroup $statusOfMemo3"
                                                }
                                            }
                                            no {
                                                if {[string compare $workgroupname ""]} {
                                                    global rfc5741StatusOfMemo_irtf_info rfc5741StatusOfMemo2_irtf_info_noconsensus
                                                    set status "$rfc5741StatusOfMemo_irtf_info $rfc5741StatusOfMemo2_irtf_info_noconsensus $statusOfMemo3"
                                                    regsub -all -- %WORKGROUPNAME% $status "$workgroupname" status
                                                } else {
                                                    global rfc5741StatusOfMemo_irtf_info rfc5741StatusOfMemo2_irtf_info_nogroup
                                                    set status "$rfc5741StatusOfMemo_irtf_info $rfc5741StatusOfMemo2_irtf_info_nogroup $statusOfMemo3"
                                                }
                                            }
                                            default {
                                                unexpected_error "invalid combination of submissionType=\$rv(submissionType\", category=\"$rv(category)\" and consensus=\"$rv(consensus)\""
                                            }
                                        } 
                                    }
                                    default {
                                        unexpected_error "invalid combination of submissionType=\$rv(submissionType\" and category=\"$rv(category)\""
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                # pre-2010 (RFC 5741) "Status Of This Memo"
                set status [list [lindex [lindex $categories $cindex] 3]]
            }
        } else {
            if {$options(.STRICT)} {
                if {$cindex == -1} {
                    unexpected error "category attribute is mandatory when submitting for publication as RFC"
                }
                foreach t [list Abstract "Security Considerations"] {
                    if {![info exists counter([string tolower $t])]} {
                        unexpected error "missing $t"
                    }
                }
                if {([info exists depth(references)]) \
                        && ($depth(references))} {
                    set hitP 0
                    foreach t [list normative informative] {
                        if {[info exists counter([string tolower $t])]} {
                            set hitP 1
                        }
                    }
                    if {!$hitP} {
                        unexpected error \
                                   "missing Normative/Informative References"
                    }
                }
            }

            lappend left "Internet-Draft"

            if {[string compare $rv(obsoletes) ""]} {
                lappend left "Obsoletes:$colonspace $rv(obsoletes) (if&nbsp;approved)"
            }
            if {[string compare $rv(updates) ""]} {
                lappend left "Updates:$colonspace $rv(updates) (if&nbsp;approved)"
            }

            if {$cindex != -1} {
                switch -- $rv(category) {
                    bcp {
                        set tindex 2
                    }

                    default {
                        set tindex 1
                    }
                }
                lappend left "Intended status:$colonspace [lindex [lindex $categories $cindex] $tindex]"
            }

            if {$secs == 0} {
                unexpected error "Can't parse date to generate expires"
            }
            incr secs [expr (185*86400)]
            set day [string trimleft \
                            [clock format $secs -format "%d" -gmt true] 0]
            set expires [clock format $secs -format "%B $day, %Y" -gmt true]
            lappend left "Expires:$colonspace $expires"
            set category "Expires $expires"
            set ipreal $rv(ipr)
            set ymd [clock format $attrs(.PARSEDDATE) -format "%Y%m%d" \
                           -gmt true]
            if {($ymd >= "20091101") \
                    && ![string compare $ipreal pre5378Trust200902]} {
                set ipreal trust200902
            }
            # Use the shorter alternative for the ID info for new IDs
            # starting April 1, 2010.
            if {$ymd >= 20100401} {
                    set status $idinfo2
            } else {
                    set status $idinfo
            }
            regsub -all -- "&" [lindex [lindex $iprstatus \
                                              [lsearch0 $iprstatus \
                                                        $ipreal]] 1] \
                        "\\\\\\&" ipr
            
            if {($ymd < "20100401")} {
              # insert "to IETF" for documents before Apr 01 2010
              regsub -all -- %TOIETF% $ipr "to IETF" ipr
            } else {
              regsub -all -- %TOIETF% $ipr "" ipr
            }

            regsub -all -- %IPR% $status $ipr status
            if {![string compare $mode html]} {
                regsub -all -- %IDABURL% $status "<a href='$idaburl'>$idaburl</a>" status
                regsub -all -- %IDSHURL% $status "<a href='$idshurl'>$idshurl</a>" status
            } else {
                regsub -all -- %IDABURL% $status $idaburl status
                regsub -all -- %IDSHURL% $status $idshurl status
            }
            if {[string compare [set anchor $rv(iprExtract)] ""]} {
                set extract ", other than to extract "
                append extract [xref_$mode "" $xref($anchor) $anchor "" 1]
                regsub -all -- {&nbsp;} $extract {%NBSP%} extract
                append extract " as-is for separate use"
                if {[string first "%IPREXTRACT%" $status] < 0} {
                    unexpected error "iprExtract attribute not compatible with ipr $rv(ipr)"
                }
            } else {
                set extract ""
            }
            regsub -all -- %IPREXTRACT% $status $extract status
            regsub -all -- %NBSP% $status {\&nbsp;} status
            regsub -all -- %EXPIRES% $status $expires status
        }
    }

    # check consensus usage
    if {![string compare $consensusSpecified "yes"]} {
        if {![string compare $consensusConsumed "no"]} {
            unexpected warning "a consensus attribute was specified, but not applicable for the generated boilerplate"
        }
    }
        
    set authors ""
    set names ""
    foreach child [find_element author $attrs(.CHILDREN)] {
        array set av [list initials "" surname "" fullname "" role ""]
        array set av $elem($child)

        switch -- $av(role) {
            editor - "" {}

            default {
                unexpected error "invalid role attribute: $av(role)"
            }
        }

        set organization [find_element organization $av(.CHILDREN)]
        array set ov [list abbrev ""]
        if {[llength $organization] == 1} {
          if {[string compare $organization ""]} {
              array set ov $elem($organization)
          }
          if {![string compare $ov(abbrev) ""]} {
              set ov(abbrev) $ov(.CTEXT)
          }
        }

        if {[string compare $av(initials) ""]} {
            set av(initials) [lindex [split $av(initials) .] 0].
        }
        set av(abbrev) "$av(initials) $av(surname)"
        if {[string length $av(abbrev)] == 1} {
            set av(abbrev) ""
            lappend names $ov(abbrev)
        } else {
            lappend names $av(surname)
            if {![string compare $av(role) editor]} {
                append av(abbrev) ", Ed."
            }
        }
        set authors [linsert $authors 0 [list $av(abbrev) $ov(abbrev)]]
    }

    set lastO ""
    set right ""
    foreach author $authors {
        if {[string compare [set value [lindex $author 1]] $lastO]} {
            set right [linsert $right 0 [set lastO $value]]
        }
        if {[string compare [set value [lindex $author 0]] ""]} {
            set right [linsert $right 0 $value]
        }
    }
    set day ""
    if {(![string compare $rv(number) ""]) \
            && (![catch { set day $dv(day) }])} {
        set day "$day, "
    }
    lappend right "$dv(month) $day$dv(year)"

    if {$options(.HEADER)} {
        lappend top $options(header)
    } elseif {[string compare $rv(number) ""]} {
        lappend top "RFC&nbsp;$rv(number)"
    } else {
        lappend top "Internet-Draft"
        lappend title $ofile
    }
    set l [string length [lindex $top end]]
    lappend top "$dv(month) $dv(year)"
    set l2 [string length [lindex $top end]]
    if {$l < $l2} {
        set l $l2
    }
    set l [expr $page_width - 2 * ($l + $center_fill_width) + ($l2 < $l)]
    if {[set l2 [string length $tv(abbrev)]] <= 0} {
        if {[string length $tv(.CTEXT)] > $l} {
            unexpected error "<title> element needs an abbrev attribute of at most $l characters"
        } else {
            set tv(abbrev) $tv(.CTEXT)
        }
    } elseif {$l2 > $l} {
        unexpected error "abbrev attribute of <title> element is still too long ($l2 > $l)"
    }
    set top [linsert $top 1 $tv(abbrev)]

    switch -- [llength $names] {
        1       { lappend bottom [lindex $names 0] }
        2       { lappend bottom "[lindex $names 0] &amp; [lindex $names 1]" }
        default { lappend bottom "[lindex $names 0], et al." }
    }
    if {$options(.FOOTER)} {
        lappend bottom $options(footer)
    } else {
        lappend bottom $category
    }

    regsub -all -- %YEAR% $copyshort $dv(year) copying

    set keywords {}
    foreach child [find_element keyword $attrs(.CHILDREN)] {
        array set kv $elem($child)
        lappend keywords $kv(.CTEXT)
    }

    front_${mode}_begin $left $right $top $bottom $title $keywords $rv(xml:lang)

    # make boilerplate ordering change on 20090701 for RFCs and 
    # on 20091101 otherwise
    if {[string compare $rv(number) ""]} {
      set cutoff 20090701
    } else {
      set cutoff 20091101
    }
    if {($ymd < "$cutoff")} {
        set options(.ABSTRACT1ST) 0
        write_status_${mode} $status $copying 0
    } else {
        set options(.ABSTRACT1ST) 1
        set attrs(.STATUS) $status
        set attrs(.COPYING) $copying
        set elem($elemX) [array get attrs]
    }
}

proc pass2end_front {elemX} {
    global elem
    global elemZ
    global options copyrightP
    global mode
    global crefs

    array set attrs $elem($elemX)
    if {[info exists attrs(.STATUS)]} {
        write_status_${mode} $attrs(.STATUS) $attrs(.COPYING) 1
    }

    set toc ""
    if {$options(.TOC)} {
        set refs 0
        set irefP 0
        set backP 0
        set author ""
        set back ""
        set ipr ""
        for {set elemY 1} {$elemY <= $elemZ} {incr elemY} {
            catch { array unset cv }
            array set cv $elem($elemY)

            switch -- $cv(.NAME) {
                rfc {
                    if {!$options(.PRIVATE) && ($copyrightP > 0) && !$options(.RFCEDSTYLE)} {
                        set title "Intellectual Property and Copyright Statements"
                        set anchor ""
                        if {![string compare $mode html]} {
                            set anchor rfc.copyright
                            set label "&#167;"
                        } else {
                            catch { set anchor $cv(.ANCHOR) }
                            set label ""
                        }
                        set ipr [list 0 $label $title $anchor]
                    }
                }

                front {
                    if {$elemY > 2 || $options(.RFCEDSTYLE)} {
                        # <reference>s have a <front> too!
                        continue
                    }
                    set n [llength [find_element author $cv(.CHILDREN)]]
                    if {$n == 0} {
                        continue
                    } elseif {$n == 1} {
                        set title "Author's Address"
                    } else {
                        set title "Authors' Addresses"
                    }
                    set anchor ""
                    if {![string compare $mode html]} {
                        set anchor rfc.authors
                        set label "&#167;"
                    } else {
                        global authorspg

                        set anchor $authorspg
                        set label ""
                    }
                    if {$options(.AUTHORSHIP)} {
                        set author [list 0 $label $title $anchor]
                    }
                }

                section - appendix {
                    if {[string compare $back ""]} {
                        lappend toc $back
                        set back ""
                    }
                    set x [llength [split [set label $cv(.COUNTER)] .]]
                    incr x -1
                    switch -- $cv(toc) {
                        include {}
                        exclude { continue }

                        default {
                            if {$x >= $options(.TOCDEPTH)} {
                                continue
                            }
                        }
                    }
                    if {   (!$x && $backP)
                        || ![string compare $cv(.NAME) "appendix"]} {
                        set x -1
                    }
                    append label .
                    lappend toc [list $x $label $cv(title) $cv(.ANCHOR)]
                }

                back {
                    set backP 1
                    if {(!$options(.INLINE)) && ([array size crefs] > 0)} {
                        set anchor ""
                        if {![string compare $mode html]} {
                            set anchor rfc.comments
                            set label "&#167;"
                        } else {
                            catch { set anchor $cv(.ANCHOR) }
                            set label ""
                        }
                        set back [list 0 $label "Editorial Comments" $anchor]
                    }
                }

                references {
                    set anchor ""
                    if {![string compare $mode html]} {
                        set anchor rfc.references[incr refs]
                    } else {
                        catch { set anchor $cv(.ANCHOR) }
                    }
                    set label $cv(.COUNTER)
                    if {[catch { set title $cv(title) }]} {
                        set title References
                    }
                    set l [split $label .]
                    set x [expr [llength $l] - 1]
                    if {$x == 1 && ![string compare [lindex $l 1] 1]} {
                        lappend toc [list 0 [lindex $l 0]. $options(refparent) \
                                          $anchor]
                    }
                    append label .
                    lappend toc [list $x $label $title $anchor]
                }

                iref {
                    set irefP 1
                }
            }
        }
        if {[string compare $back ""]} {
            lappend toc $back
        }
        if {$irefP} {
            global indexpg

            if {![string compare $mode html]} {
                set label "&#167;"
            } else {
                set label ""
            }

            lappend toc [list 0 $label Index $indexpg]
        }
        if {[string compare $author ""]} {
            lappend toc $author
        }
        if {[string compare $ipr ""]} {
            lappend toc $ipr
        }
    }

    front_${mode}_end $toc
}

# the abstract/note elements

proc pass2begin_abstract {elemX} {
    global mode
    abstract_$mode
}

proc pass2begin_note {elemX} {
    global elem stack
    global mode

    set d 0
    foreach frame $stack {
        if {![string compare [lindex $frame 0] note]} {
            incr d
        }
    }

    array set attrs $elem($elemX)

    note_$mode $attrs(title) $d
}

# the section element

proc pass2begin_section {elemX {appendP 0}} {
    global elem stack
    global mode

    # In case we're in <back> and this hasn't been done yet.
    pass2middle_back

    array set attrs [list anchor ""]
    array set attrs $elem($elemX)

    if {([lsearch0 $stack appendix] < 0) && ([lsearch0 $stack section] < 0)} {
        set top 1
    } else {
        set top 0
    }

    set prefix ""
    set s $attrs(.COUNTER)
    append s .
    if {($appendP) || (([lsearch0 $stack back] >= 0) && ($top))} {
        set prefix "Appendix "
    }
    set title $attrs(title)

    set lines 1
    if {[llength $attrs(.CHILDREN)] > 0} {
        set elemY [lindex $attrs(.CHILDREN) 0]
        array set cv $elem($elemY)

        switch -- $cv(.NAME) {
            figure - texttable {
                incr lines [pass2begin_$cv(.NAME) $elemY 1]
            }

            default { incr lines 2 }
        }
    }

    set attrs(.ANCHOR) \
        [section_$mode $prefix$s $top $title $lines $attrs(anchor)]

    set elem($elemX) [array get attrs]
}

proc pass2begin_appendix {elemX {appendP 0}} {
    global appendixW

    if {[catch { set appendixW }]} {
        set appendixW 1
        unexpected warning \
                   "<appendix/> element is deprecated, use <section/> instead"
    }
    pass2begin_section $elemX 1
}

proc section_title {elemX} {
    global elem

    array set attrs [list anchor "" title ""]
    array set attrs $elem($elemX)

    return $attrs(title)
}


# the t element

proc pass2begin_t {elemX} {
    global counter elem stack
    global mode

    array set attrs [list .COUNTER "" style "" hangText "" \
                          hangIndent "" anchor   ""]
    array set attrs $elem($elemX)
    set elem($elemX) [array get attrs]

    if {[string compare $attrs(.COUNTER) ""]} {
        # Get <list>.
        set frame [lindex $stack end]
        array set av [lrange $frame 1 end]

        set elemY $av(elemN)
        array set av $elem($elemY)

        if {![info exists av(.STYLE)]} {
            unexpected error "<list> element not subordinate to <t> element"
        }
        set attrs(hangIndent) $av(hangIndent)
        if {![string compare [set attrs(style) $av(.STYLE)] format]} {
            set attrs(style) hanging

            if {![string compare $attrs(hangText) ""]} {
                # $format has already been validated.
                set format $av(.FORMAT)
                set attrs(hangText) [apply_list_style_format \
                                     $format $attrs(.FMTCOUNTER)]
            }
        }
        set elem($elemX) [array get attrs]
    }

    t_$mode begin $attrs(.COUNTER) $attrs(style) $attrs(hangText) \
            $attrs(.EDITNO)
}

proc pass2end_t {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)

    t_$mode end $attrs(.COUNTER) $attrs(style) $attrs(hangText) ""
}

proc validate_list_style_format {fmt {errstr "<list style='format ...'> spec"}} {
    set p 0
    set n 0
    while {[regexp -start $p -indices -- % $fmt x]} {
        set p [lindex $x 0]
        incr p
        switch -- [set c [string index $fmt $p]] {
            % {}
            d - C - c - I - i - o - X - x {
                set fmttoken %$c
                incr n
            }
            "" {
                unexpected error "truncated % token at end of $errstr"
            }
            default {
                unexpected error "invalid %$c token in $errstr"
            }
        }
        incr p
    }
    set tokens "%d/%C/%c/%I/%i/%o/%X/%x"
    if {$n == 0} {
        unexpected error "missing one of $tokens in $errstr"
    } elseif {$n > 1} {
        unexpected error "more than one $tokens in $errstr"
    }

    return $fmttoken
}

proc apply_list_style_format {fmt c} {
    # This assumes that $fmt has already been validated.  No errors are thrown.
    set s ""
    set p 0
    while {[regexp -start $p -indices -- {%.} $fmt x]} {
        append s [string range $fmt $p [expr [lindex $x 0] - 1]]
        set p [lindex $x 1]
        switch -- [string index $fmt $p] {
            d { set v $c }
            C { set v [offset2letters $c 0] }
            c { set v [offset2letters $c 1] }
            I { set v [offset2romans $c 0] }
            i { set v [offset2romans $c 1] }
            o { set v [format %o $c] }
            X { set v [format %X $c] }
            x { set v [format %x $c] }
            % { set v % }
            default { set v "" }
        }
        append s $v
        incr p
    }
    append s [string range $fmt $p end]

    return $s
}

# the list element

proc pass2begin_list {elemX} {
    global elem stack
    global mode

    # Default values (to be inherited and overridden).
    set style empty
    set hangIndent 0

    # Inherit defaults for innermost ancestor <list>, if any.
    if {[set x [llast0 $stack list]] >= 0} {
        array set fv [lrange [lindex $stack $x] 1 end]
        array set av $elem($fv(elemN))

        # Outer lists have been normalized, so no need for a catch {}.
        set style      $av(style)
        set hangIndent $av(hangIndent)
    }

    # Current element is not yet in stack nor normalized.
    array set attrs [list counter ""]
    array set attrs $elem($elemX)
    array set attrs [list  FORMAT ""  FMTTOKEN ""]
    catch { set style      $attrs(style)      }
    catch { set hangIndent $attrs(hangIndent) }
    set fmtcountername $attrs(counter)
    set longestHangText ""

    # Validate and process style attribute.
    set errstr "style=\"$style\" attribute of <list> element"
    if {[regexp -- {^format[ \t]+(.*)$} $style x format]} {
        if {[string compare $format ""]} {
            set attrs(.STYLE) format

            set fmttoken [validate_list_style_format $format $errstr]
            switch -glob -- $fmttoken {
                *I - *i { set x $attrs(.LONGEST_ROMAN) }
                default { set x $attrs(.MAX) }
            }
            set longestHangText [apply_list_style_format $format $x]

            set attrs(.FORMAT) $format
            set attrs(.FMTTOKEN) $fmttoken
        } else {
            set attrs(.STYLE) hanging
        }
    } else {
        switch -- $style {
            empty - letters - numbers - symbols - hanging {}
            letter - number - symbol {
                unexpected error \
  "did you mean style=\"${style}s\" (plural) instead of the invalid $errstr"
            }
            default {
                unexpected error "invalid $errstr"
            }
        }
        set attrs(.STYLE) $style
    }

    # Save systematically-defined and normalized values for this <list>.
    array set attrs [list style $style  hangIndent $hangIndent]
    set elem($elemX) [array get attrs]

    list_$mode begin $attrs(.MIN) $attrs(.MAX) $attrs(.STYLE) \
               $attrs(hangIndent) $longestHangText \
               [expr ([lsearch0 $stack list] >= 0) ? -1 : [lsearch0 $stack t]]
}

proc pass2end_list {elemX} {
    global elem stack
    global mode

    array set attrs $elem($elemX)

    list_$mode end $attrs(.MIN) $attrs(.MAX) $attrs(.STYLE) \
               "" "" \
               [expr ([lsearch0 $stack list] >= 0) ? -1 : [lsearch0 $stack t]]
}


# the figure and artwork elements

proc pass2begin_figure {elemX {internal 0}} {
    global elem
    global mode

    array set attrs [list anchor "" title "" suppress-title false]
    array set attrs $elem($elemX)

    set lines 0
    foreach p {preamble postamble} {
        if {[llength [find_element $p $attrs(.CHILDREN)]] == 1} {
            incr lines 3
        }
    }
    if {$lines > 5} {
        set lines 5
    }

    set artwork [find_element artwork $attrs(.CHILDREN)]
    array set av $elem($artwork)

    # <artwork> may be empty!
    catch { incr lines [llength [split $av(.CTEXT) "\n"]] }

    if {$internal} {
        return $lines
    }

    catch { push_align $attrs(align) }

    figure_$mode begin $lines $attrs(anchor) $attrs(title) [array get attrs]
}

proc pass2end_figure {elemX} {
    global elem
    global mode

    array set attrs [list anchor "" title "" suppress-title false]
    array set attrs $elem($elemX)
    switch -- [string tolower $attrs(suppress-title)] {
        yes - true - 1 {
            set suppressP 1
        }

        default {
            set suppressP 0
        }
    }

    figure_$mode end "" $attrs(anchor) $attrs(title) [array get attrs] \
                 $suppressP

    if {[info exists attrs(align)]} {
        pop_align
    }
}

proc pass2begin_artwork {elemX} {
    global elem
    global options
    global mode

    array set attrs $elem($elemX)

    switch -- $mode {
        nr - txt {
            if {([string compare $options(artworkdelimiter) ""]) \
                    && ([info exists attrs(.SDATA)])} {
                set attrs(.SDATA) "$options(artworkdelimiter)\n$attrs(.SDATA)\n$options(artworkdelimiter)"
                set elem($elemX) [array get attrs]
            }
            if {($options(.ARTWORKLINES) > 0) \
                    && ([info exists attrs(.SDATA)])} {
                set extra ""
                for {set i $options(.ARTWORKLINES)} {$i > 0} {incr i -1} {
                    append extra "\n"
                }
                set attrs(.SDATA) $extra$attrs(.SDATA)$extra
                set elem($elemX) [array get attrs]
            }
        }
    }

    catch { push_align $attrs(align) }
    set align [current_align]

    catch {
        set lines 0
        # <artwork> may be empty!
        set ctext [split $attrs(.CTEXT) "\n"]
        set lines [llength $ctext]
        if {   ![string compare $mode html]
            || ![catch {set x $attrs(.TEXTWIDTH)}]} {
            # break from catch
            error ""
        }
        set textwidth 0
        foreach l $ctext {
            set ll [string length [string trimright [chars_expand $l]]]
            if {$ll > $textwidth} {
                set textwidth $ll
            }
        }
        set attrs(.TEXTWIDTH) $textwidth
        set elem($elemX) [array get attrs]
    }

    artwork_$mode begin $lines [array get attrs]
}

proc pass2end_artwork {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)

    artwork_$mode end 0 [array get attrs]

    if {[info exists attrs(align)]} {
        pop_align
    }
}


# the preamble/postamble elements

proc pass2begin_preamble {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)

    preamble_$mode begin $attrs(.EDITNO)
}

proc pass2end_preamble {elemX} {
    global mode

    preamble_$mode end
}

proc pass2begin_postamble {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)

    postamble_$mode begin $attrs(.EDITNO)
}

proc pass2end_postamble {elemX} {
    global mode

    postamble_$mode end
}


# the texttable element

proc pass2begin_texttable {elemX {internal 0}} {
    global elem
    global mode
    global options
    global cellR

    array set attrs [list anchor "" title "" suppress-title false style full \
                          align center]
    array set attrs $elem($elemX)

    # Assume tables cannot be nested.
    set cellR $attrs(style)

    set lines 0
    foreach p {preamble postamble} {
        if {[llength [find_element $p $attrs(.CHILDREN)]] == 1} {
            incr lines 3
        }
    }
    if {$lines > 5} {
        set lines 5
    }

    set cols {}
    set ttcols [find_element ttcol $attrs(.CHILDREN)]
    foreach ttcol $ttcols {
        catch { array unset cv }
        array set cv [list width ""]
        array set cv $elem($ttcol)

        if {![regexp -- {^0*(|(100|[1-9][0-9]|[0-9])%|[0-9]*\*|[0-9]+em)$} $cv(width)]} {
            unexpected error "invalid width attribute in <ttcol>: $cv(width)"
        }
        lappend cols $cv(width)
    }

    set colmax [llength $cols]
    set children [find_element c $attrs(.CHILDREN)]
    set rowmax [expr [llength $children]/$colmax]
    if {0 && [info exists attrs(.HEIGHT)]} {
        # Would be usable if there was detection
        # of output stability before the last pass.
        incr lines $attrs(.HEIGHT)
    } else {
        incr lines [expr 4 + $rowmax + ($options(.COMPACT) ? 0 : ($rowmax - 1))]
    }

    if {$internal} {
        return $lines
    }

    catch { push_align $attrs(align) }

    set attrs(.COLS) $cols
    set elem($elemX) [array get attrs]

    set colno 0
    set aligns {}
    foreach ttcol $ttcols {
        catch { array unset cv }
        array set cv [list width "" align left .CWIDTH -1]
        array set cv $elem($ttcol)

        set cv(.WIDTH) [lindex $cols $colno]
        if {   [info exists attrs(.CWIDTHS)]
            && [string compare [set cw [lindex $attrs(.CWIDTHS) $colno]] ""]} {
            set cv(.CWIDTH) $cw
        }
        lappend aligns $cv(align)
        set cv(.COLNO) [list [incr colno] $colmax]

        set elem($ttcol) [array get cv]
    }

    set colno 0
    set rowno 1
    foreach c $children {
        catch { array unset cv }
        array set cv $elem($c)

        set cv(.WIDTH) [lindex $cols   $colno]
        set cv(.ALIGN) [lindex $aligns $colno]
        set cv(.ROWNO) [list      $rowno  $rowmax]
        set cv(.COLNO) [list [incr colno] $colmax]
        if {$colno >= $colmax} {
            set colno 0
            incr rowno
        }

        set elem($c) [array get cv]
    }

    texttable_$mode begin $lines $attrs(anchor) $attrs(title)
}

proc pass2end_texttable {elemX} {
    global elem
    global mode

    array set attrs [list anchor "" title "" suppress-title false]
    array set attrs $elem($elemX)
    switch -- [string tolower $attrs(suppress-title)] {
        yes - true - 1 {
            set suppressP 1
        }

        default {
            set suppressP 0
        }
    }

    set rc [texttable_$mode end "" $attrs(anchor) $attrs(title) $suppressP]
    set attrs(.HEIGHT)  [lindex $rc 0]
    set attrs(.CWIDTHS) [lindex $rc 1]
    set elem($elemX) [array get attrs]

    if {[info exists attrs(align)]} {
        pop_align
    }
}

proc pass2begin_ttcol {elemX} {
    global elem
    global mode

    array set attrs [list width "" align left]
    array set attrs $elem($elemX)
    switch -- $attrs(align) {
        left - center - right {}

        default {
            unexpected error \
                "invalid value for align attribute: $attrs(align)"
        }
    }

    ttcol_$mode $attrs(.CTEXT) $attrs(align) $attrs(.COLNO) $attrs(.WIDTH) $attrs(.CWIDTH)
}

proc pass2begin_c {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)
    c_$mode begin $attrs(.ROWNO) $attrs(.COLNO) $attrs(.ALIGN) $attrs(.WIDTH)
}

proc pass2end_c {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)
    c_$mode end $attrs(.ROWNO) $attrs(.COLNO) $attrs(.ALIGN) $attrs(.WIDTH)
}


# the xref element

proc pass2begin_xref {elemX} {
    global elem xref
    global mode

    # pageno is ignored for now...
    array set attrs [list pageno false format default]
    array set attrs $elem($elemX)

    set anchor $attrs(target)
    if {![info exists xref($anchor)]} {
        return -code error "Can't resolve xref target $anchor"
    }
    xref_$mode $attrs(.CTEXT) $xref($anchor) $anchor $attrs(format)
}


# the eref element

proc pass2begin_eref {elemX} {
    global counter elem passno
    global mode

    array set attrs $elem($elemX)
    set t $attrs(target)

    if {$passno == 2} {
        if {![info exists counter(reference)]} {
            set counter(reference) 0
        }

        set c -1

        if {([string first "#" $t] < 0) \
                && ([string compare $attrs(.CTEXT) ""]) \
                && ([string compare $attrs(.CTEXT) $t])} {
            switch -- $mode {
                nr - txt {
                    global erefs

                    foreach {n tn} [array get erefs] {
                        if {![string compare $t $tn]} {
                            set c $n
                            break
                        }
                    }
                    if {$c < 0} {
                        set c [incr counter(reference)]
                    }
                }
            }
        }
        set attrs(.COUNTER) $c
        set elem($elemX) [array get attrs]
    }

    eref_$mode $attrs(.CTEXT) $attrs(.COUNTER) $t
}


# the cref element

proc pass2begin_cref {elemX} {
    global elem
    global mode
    global options

    array set attrs [list anchor "" source ""]
    array set attrs $elem($elemX)

    if {!$options(.COMMENTS)} {
        return
    }

    set text ""
    set attrs(.CTEXT) [string trim $attrs(.CTEXT)]
    while {[set x [string first "\n" $attrs(.CTEXT)]] >= 0} {
        if {$x > 0} {
            append text [string range $attrs(.CTEXT) 0 [expr $x-1]]
        }
        set attrs(.CTEXT) [string trimleft \
                                  [string range $attrs(.CTEXT) $x end]]
        if {[string length $attrs(.CTEXT)] > 0} {
            append text " "
        }
    }
    append text $attrs(.CTEXT)

    cref_$mode $text $attrs(.COUNTER) $attrs(source) $attrs(anchor)
}

proc cref_title {elemX} {
    global elem

    array set attrs [list anchor "" source ""]
    array set attrs $elem($elemX)

    return $attrs(.CTEXT)
}



# the iref element

proc pass2begin_iref {elemX} {
    global elem
    global mode

    array set attrs [list subitem "" primary false]
    array set attrs $elem($elemX)
    set flags [list primary $attrs(primary)]
    unset attrs(primary)
    set attrs(flags) $flags

    set attrs(.ANCHOR) [iref_$mode $attrs(item) $attrs(subitem) $flags]

    set elem($elemX) [array get attrs]
}


# the vspace element

proc pass2begin_vspace {elemX} {
    global elem
    global mode

    array set attrs [list blankLines 0]
    array set attrs $elem($elemX)
    set elem($elemX) [array get attrs]

    vspace_$mode $attrs(blankLines)
}


# the spanx element

proc pass2begin_spanx {elemX} {
    global elem
    global mode

    array set attrs [list style emph]
    array set attrs $elem($elemX)
    set elem($elemX) [array get attrs]

    spanx_$mode $attrs(.CTEXT) $attrs(style)
}


# the references/reference elements

# we intercept the back element so we can put the Author's addresses
# after the References section (if any) and before any Appendices

proc pass2begin_back {elemX} {
    global elem
    global mode
    global crefs erefs
    global options
    global erefP backP

    array set attrs $elem($elemX)

    set backP 1
    set children [find_element references $attrs(.CHILDREN)]
    set erefP [expr [llength $children] == 1]

    # Compute width over all references, not just per-section.
    set width 0
    foreach child $children {
        array set references $elem($child)
        set refchildren [find_element reference $references(.CHILDREN)]
        foreach refchild $refchildren {
            array set x $elem($refchild)
            if {[set y [string length $x(.COUNTER)]] > $width} {
                set width $y
            }

            unset x
        }
    }
    foreach child $children {
        array set references $elem($child)
        set refchildren [find_element reference $references(.CHILDREN)]
        foreach refchild $refchildren {
            array set x $elem($refchild)
            set x(.WIDTH) $width
            set elem($refchild) [array get x]
            unset x
        }
    }
}

proc pass2middle_back {} {
    global mode
    global crefs erefs
    global options
    global erefP backP

    if {!$backP} {
        return
    }

    if {!$erefP && [array size erefs] > 0} {
        erefs_$mode URIs
    }
    if {!$options(.INLINE) && [array size crefs] > 0} {
        crefs_$mode "Editorial Comments"
    }

    back_$mode

    set backP 0
}

proc pass2end_back {elemX} {
    pass2middle_back
}

proc pass2end_references {elemX} {
    global elem
    global mode
    global options
    global erefP

    array set attrs [list title References]
    array set attrs $elem($elemX)

    set prefix $attrs(.COUNTER)
    append prefix .
    set attrs(.ANCHOR) [references_$mode begin $prefix $attrs(title)]
    set elem($elemX) [array get attrs]
    set children [find_element reference $attrs(.CHILDREN)]
    if {$options(.SORTREFS)} {
        set children [lsort -command sort_references $children]
    }
    foreach child $children {
        pass2end_reference $child
    }
    references_$mode end $erefP
}

proc sort_references {elemX elemY} {
    global elem
    global options

    array set attrX $elem($elemX)
    array set attrY $elem($elemY)
    if {$options(.SYMREFS)} {
        return [string compare $attrX(anchor) $attrY(anchor)]
    } else {
        return [expr $attrX(.COUNTER) - $attrY(.COUNTER)]
    }
}

proc pass2begin_reference {elemX} {
    global elem
    global mode

    array set attrs [list anchor "" target "" target2 ""]
    array set attrs $elem($elemX)
    set attrs(.ANNOTATIONS) {}
    set elem($elemX) [array get attrs]
}

proc pass2end_reference {elemX} {
    global elem
    global mode

    array set attrs $elem($elemX)

    set front [find_element front $attrs(.CHILDREN)]
    array set fv $elem($front)

    set names [ref_names $elemX]
    set title [ref_title $elemX]

    set series ""
    foreach child [find_element seriesInfo $attrs(.CHILDREN)] {
        # backwards-compatibility... (the attributes are actually mandatory)
        catch { array unset sv }
        array set sv $elem($child)
        if {([info exists sv(name)]) && ([info exists sv(value)])} {
            lappend series "$sv(name)&nbsp;$sv(value)"
        } else {
            lappend series $sv(.CTEXT)
        }
    }

    set formats {}
    foreach child [find_element format $attrs(.CHILDREN)] {
        lappend formats $elem($child)
    }

    set date [ref_date $elemX]

    reference_$mode $attrs(.COUNTER) $names $title $series $formats $date \
                    $attrs(anchor) $attrs(target) $attrs(target2) $attrs(.WIDTH) \
                    $attrs(.ANNOTATIONS)
}

proc ref_names {elemX} {
    global elem

    array set attrs [list anchor "" target "" target2 ""]
    array set attrs $elem($elemX)

    set front [find_element front $attrs(.CHILDREN)]
    array set fv $elem($front)

    set childN [llength [set children [find_element author $fv(.CHILDREN)]]]

    set childA 0
    set names {}
    foreach child [find_element author $fv(.CHILDREN)] {
        incr childA

        array set av [list initials "" surname "" fullname "" role ""]
        array set av $elem($child)

        set organization [find_element organization $av(.CHILDREN)]
        array set ov [list .CTEXT "" abbrev ""]
        if {[string compare $organization ""]} {
            array set ov $elem($organization)
            if {![string compare $ov(abbrev) ""]} {
                set ov(abbrev) $ov(.CTEXT)
            }
        }

        set mref ""
        set uref ""
        set address [find_element address $av(.CHILDREN)]
        if {[llength $address] == 1} {
            array set bv $elem($address)

            foreach {k v p} {email mref mailto: uri uref ""} {
                set u [find_element $k $bv(.CHILDREN)]
                if {[llength $u] == 1} {
                    catch { array unset uv }
                    array set uv $elem($u)

                    set $v $p$uv(.CTEXT)
                }
            }
        }
        if {![string compare $mref ""]} {
            set mref $uref
        } elseif {![string compare $uref ""]} {
            set uref $mref
        }

        if {[string compare $av(initials) ""]} {
            set av(initials) [lindex [split $av(initials) .] 0].
        }
        if {($childA > 1) && ($childA == $childN)} {
            set av(abbrev) [string trimleft "$av(initials) $av(surname)"]
        } elseif {[string compare $av(initials) ""]} {
            set av(abbrev) "$av(surname), $av(initials)"
        } else {
            set av(abbrev) $av(surname)
        }
        if {[string length $av(abbrev)] == 0} {
            lappend names [list $ov(.CTEXT) $uref]
        } else {
            if {![string compare $av(role) editor]} {
                append av(abbrev) ", Ed."
            }
            lappend names [list $av(abbrev) $mref]
        }
    }
    set hack $names

    set names {}
    foreach name $hack {
        if {[string compare [lindex $name 0] ""]} {
            lappend names $name
        }
    }

    return $names
}

proc ref_title {elemX} {
    global elem

    array set attrs [list anchor "" target "" target2 ""]
    array set attrs $elem($elemX)

    set front [find_element front $attrs(.CHILDREN)]
    array set fv $elem($front)

    set title [find_element title $fv(.CHILDREN)]
    array set tv [list abbrev ""]
    array set tv $elem($title)

    return $tv(.CTEXT)
}

proc ref_date {elemX} {
    global elem

    array set attrs [list anchor "" target "" target2 ""]
    array set attrs $elem($elemX)

    set front [find_element front $attrs(.CHILDREN)]
    array set fv $elem($front)

    set date [find_element date $fv(.CHILDREN)]
    array set dv [list year "" month ""]
    if {[catch { array set dv $elem($date) }]} {
        return ""
    }
    if {[string compare $dv(month) ""]} {
        set date "$dv(month)&nbsp;$dv(year)"
    } else {
        set date $dv(year)
    }

    return $date
}

proc pass2begin_annotation {elemX} {
    global mode

    annotation_$mode begin
}

proc pass2end_annotation {elemX} {
    global elem stack
    global mode

    set frame [lindex $stack end]
    array set av [lrange $frame 1 end]
    set elemY $av(elemN)
    unset av
    array set av $elem($elemY)

    lappend av(.ANNOTATIONS) [annotation_$mode end]

    set elem($elemY) [array get av]
}

#       }}}2 Remaining pass 2 (and subsequent) stuff
#       {{{2 Utility functions

proc find_element {name children} {
    global elem

    set result ""
    foreach child $children {
        array set attrs $elem($child)

        if {![string compare $attrs(.NAME) $name]} {
            lappend result $child
        }
    }

    return $result
}

# could use "lsearch -glob" followed by a "string compare", but there are
# some amusing corner cases with that...

proc lsearch0 {list exact {y 0}} {
    set x 0
    foreach elem $list {
        if {$x >= $y && ![string compare [lindex $elem 0] $exact]} {
            return $x
        }
        incr x
    }

    return -1
}

proc llast0 {list exact} {
    set x [llength $list]
    while {$x > 0} {
        set elem [lindex $list [incr x -1]]
        if {![string compare [lindex $elem 0] $exact]} {
            return $x
        }
    }

    return -1
}

#       }}}2 Utility functions
#   }}}1 XML linkage

#   {{{1 Rendering engines
#       {{{2 Page model for both the txt and nr rendering engines

#
# Each line has at most 72 columns from the left edge, including any
# left margin, but excluding the line terminator.  Every output character
# is from the ASCII repertoire and the only control character used is
# the line-feed (LF); the character-tabulation (HT) character is never
# used.
#
# Each page has the following lines (0-based lineno variable):
#    0:  header line (blank line on first page)
#    1:  blank line
#    2:  blank line
#    3:  1st line of content
#   ...
#   50:  48th line of content
#   51:  blank line
#   52:  blank line
#   53:  blank line
#   54:  footer line
#   55:  form-feed (FF) character (followed by line terminator)
# Once processed through nroff and the fix.sh script (from
# 2-nroff.template), the nr output differs from this in two ways. It
# has three extra blank lines (that could be numbered -3, -2, and -1,
# for a total of six) at the very beginning of the document (so the first
# page is that much longer). It also has no line terminator following the
# very last form-feed character of the file. These differences originate
# in the design of the fix.sh script.
#
# Header and footer lines each have three parts:  left, center, and right.
#
# Output line numbers, when reported to the user, should be 1-based.
#

global page_width
set page_width 72
# Head/foot height = 1-line header/footer + blank lines (excluding FF line)
global page_head_height page_body_height page_foot_height
set page_head_height  3
set page_body_height 48
set page_foot_height  4
global page_basic_indent
set page_basic_indent 3
global center_fill_width
set center_fill_width 2
global max_ref_width
set max_ref_width 7

#       }}}2 Page model for both the txt and nr rendering engines
#       {{{2 txt rendering engine


proc rfc_txt {irefs authors iprstmt copying newP validity} {
    global options copyrightP iprP
    global funding
    global pageno
    global indexpg
    global page_basic_indent

    if {[llength $irefs] > 0} {
        if {!$options(.COMPACT) || ![have_lines 4]} {
            end_page_txt
        } else {
            write_line_txt ""
        }
        if {!$options(.RFCEDSTYLE)} {
            write_line_txt "" -1
        }
        set indexpg $pageno

        write_line_txt "Index"

        push_indent 9
        foreach iref $irefs {
            foreach {L item subitem flags pages} $iref { break }

            if {[string compare $L ""]} {
                write_line_txt ""
                push_indent -9
                write_text_txt $L
                flush_text
                pop_indent
            }

            set subitem [chars_expand $subitem]
            if {[string compare $item ""]} {
                push_indent -6
                write_text_txt [chars_expand $item]
                if {[string compare $subitem ""]} {
                    flush_text
                    pop_indent
                    push_indent [expr -($page_basic_indent)]
                    write_text_txt $subitem
                }
            } else {
                push_indent [expr -($page_basic_indent)]
                write_text_txt $subitem
            }
            pop_indent

            write_text_txt "  [collapsed_num_list $pages]"
            flush_text
        }
        pop_indent
    }

    authors_txt $authors

    if {(!$options(.PRIVATE)) && $copyrightP > 0} {
        end_page_txt
        if {!$options(.RFCEDSTYLE)} {
            write_line_txt "" -1
        }
        set result $pageno

        # There isn't really an authoritative source for the order of
        # the next few paragraphs or the names of the headings under
        # which they are put.  But what's used here corresponds to what
        # can be found in the in-notes/rfc-editor/boilerplate*.txt files.

        if {0 && $newP} {
            write_line_txt "Copyright Statement"
        } else {
            if {$newP < 3} {
                write_line_txt "Full Copyright Statement"
            }
        }

        foreach para $copying {
            write_line_txt ""
            pcdata_txt $para
        }

        if {$newP && $newP < 3} {
            #if {![have_lines 4]} {
            #    end_page_txt
            #}

            #write_line_txt "Disclaimer of Validity"

            foreach para $validity {
                write_line_txt ""
                pcdata_txt $para
            }
        }
        write_line_txt "" -1
        if {!$options(.RFCEDSTYLE)} {
            write_line_txt "" -1
        }

        if {$iprP} {
            global iprurl ipremail

            if {![have_lines 4]} {
                end_page_txt
            }

            write_line_txt "Intellectual Property"

            regsub -all -- %IPRURL% $iprstmt $iprurl iprstmt
            regsub -all -- %IPREMAIL% $iprstmt $ipremail iprstmt

            foreach para $iprstmt {
                write_line_txt ""
                pcdata_txt $para
            }
            write_line_txt "" -1
            if {!$options(.RFCEDSTYLE)} {
                write_line_txt "" -1
            }
        }

        if {![have_lines 4]} {
            end_page_txt
        }

        if {$options(.RFCEDSTYLE)} {
            set ack "Acknowledgement"
        } else {
            set ack "Acknowledgment"
        }
        set acks 0
        if {[string length $funding]} {
            incr acks 1
        }
        if {$options(.RFCPROCACK)} {
            incr acks 1
        }
        if {$acks > 1} {
            append ack s
        }
        if {$acks} {
            write_line_txt $ack
            write_line_txt ""
        }
        if {[string length $funding]} {
            pcdata_txt $funding
        }
        if {$options(.RFCPROCACK)} {
            global prog_ack prog_url

            regsub -all -- %PROGURL% $prog_ack $prog_url xml2rfc_ack
            if {[string length $funding]} {
                pcdata_txt "  "
            }
            pcdata_txt $xml2rfc_ack
        }
    } else {
        set result ""
    }

    end_page_txt

    return $result
}

proc front_txt_begin {left right top bottom title keywords lang} {
    global options copyrightP
    global header footer lineno pageno blankP
    global eatP
    global passno indexpg authorspg
    global indent
    global page_width page_basic_indent

    set header [three_parts $top]
    set footer [string trimright [three_parts $bottom]]
    write_it ""
    set lineno 1
    set pageno 1
    set blankP 1
    set eatP 0

    if {$passno == 2} {
        set indexpg 0
        set authorspg 0
    }

    for {set i 0} {$i < 2} {incr i} {
        write_line_txt "" -1
    }

    set indent 0

    if {$options(.TOPBLOCK)} {
        set left [munge_long $left 1]
        set right [munge_long $right 0]
        foreach l $left r $right {
            set l [chars_expand $l]
            set r [chars_expand $r]
            set len [expr $page_width - [string length $l]]
            write_line_txt [format %s%*.*s $l $len $len $r]
        }
        write_line_txt "" -1
        write_line_txt "" -1
    }

    foreach line $title {
        write_text_txt [chars_expand $line] c
    }

    write_line_txt "" -1

    set indent $page_basic_indent
}

proc write_status_txt {status copying afterP} {
    global options copyrightP iprP

    if {$afterP} {
        write_line_txt "" -1
    }

    if {!$options(.PRIVATE)} {
        if {$options(.RFCEDSTYLE)} {
            write_line_txt "Status of This Memo"
        } else {
            write_line_txt "Status of this Memo"
        }
        foreach para $status {
            write_line_txt ""
            pcdata_txt $para
        }
    }

    if {(!$options(.PRIVATE)) && $copyrightP && [string length $copying]} {
        write_line_txt "" -1
        write_line_txt "Copyright Notice"
        foreach para $copying {
            write_line_txt "" -1
            pcdata_txt $para
        }
    }
}

proc three_parts {stuff} {
    global page_width center_fill_width

    set result [nbsp_expand_txt [chars_expand [lindex $stuff 0]]]
    set len [string length $result]

    set text [nbsp_expand_txt [chars_expand [lindex $stuff 1]]]
    set len [expr ($page_width - [string length $text] + 1) / 2 - $len]
    if {$len < $center_fill_width} {
        set len $center_fill_width
    }
    append result [format %*s%s $len "" $text]
    set len [string length [set text [nbsp_expand_txt [chars_expand [lindex $stuff 2]]]]]
    set len [expr ($page_width - [string length $result]) - $len]
    append result [format %*s%s $len "" $text]

    return $result
}

proc front_txt_end {toc} {
    global options
    global mode
    global unpaginated
    global lineno
    global page_width page_head_height page_body_height page_basic_indent

    if {$options(.TOC)} {
        if {   (![have_lines [expr [llength $toc] + 3]])
            || (!$options(.RFCEDSTYLE) && ($lineno >= $page_head_height + $page_body_height / 3))} {
            end_page_$mode
        } else {
            write_line_$mode ""
        }
        if {!$options(.RFCEDSTYLE)} {
            write_line_$mode "" -1
        }
        if {![string compare $mode nr]} {
            global indents

            condwrite_in_nr 0 1
            set indents {}
        }
        write_line_$mode "Table of Contents"
        write_line_$mode "" -1
        if {![string compare $mode nr]} {
            condwrite_nf_nr
        }

        set len1 0
        set len2 0
        foreach c $toc {
            set label [lindex $c 1]
            if {[string compare $label ""]} {
                set x [string length $label]
                set y [lindex $c 0]
                if {$y == -1} {
                    if {$options(.TOCAPPENDIX)} {
                        incr x 9
                    }
                    if {!$options(.TOCINDENT)} {
                        set y 0
                    }
                }
                if {[info exists a($y)]} {
                    if {$x >= $a($y)} {
                        set a($y) [expr $x + 1]
                    }
                } else {
                    set a($y) [expr $x + 2]
                }
                if {$a($y) > $len1} {
                    set len1 $a($y)
                }
            }
            if {!$unpaginated && [set x [string length [lindex $c 3]]] > $len2} {
                set len2 $x
            }
        }
        set len3 [expr 5 - $len2]
        if {$len3 < 0} {
            set len3 0
        }
        set len2 5
        set mid [expr ($page_width - 4) - ($len1 + $len2)]

        set lenX $len1
        set midX $mid
        set z 0
        set s0 [format "%*s" $page_basic_indent ""]
        foreach c $toc {
            set label [lindex $c 1]
            if {   !$options(.TOCOMPACT)
                && [lindex $c 0] <= 0} {
                set z1 [expr [string compare $label ""] ? 1 : 2]
                if {$z && ($z == 1 || $z1 == 1)} {
                    write_line_$mode ""
                }
                set z $z1
            }
            if {   !$options(.TOCOMPACT)
                && [lindex $c 0] == 0
                && [string compare $label ""]} {
            }
            set y [lindex $c 0]
            if {$y == -1 && $options(.TOCAPPENDIX)} {
                set label "Appendix $label"
            }
            if {$options(.TOCINDENT)} {
                if {[string compare $label ""]} {
                    set len1 $a($y)
                    set x 0
                    while {[incr y -1] >= 0} {
                        incr x [expr $options(.TOCNARROW) ? 2 : $a($y)]
                    }
                    set label [format "%*s" $x ""]$label
                    incr len1 $x
                } else {
                    set len1 0
                }
                set mid [expr $midX + $lenX - $len1]
            }
            set s1 [format "%-*.*s" $len1 $len1 $label]
            set s2 [format " %*.*s" $len2 $len2 [lindex $c 3]]
            set title [chars_expand [string trim [lindex $c 2]]]
            while {[string length $title] > $mid} {
                set phrase [string range $title 0 [expr $mid - 1]]
                if {[set x [string last " " $phrase]] < 0} {
                    if {[set x [string first " " $title]] < 0} {
                        break
                    }
                }
                write_toc_$mode $s0$s1 [string range $title 0 [expr $x - 1]] \
                        [format " %*s" $len2 ""] $mid 0
                set s1 [format "%*s" $len1 ""]
                set title [string trimleft [string range $title $x end]]
            }
            if {$len3 > 0} {
                set s2 [string range $s2 $len3 end]
            }
            write_toc_$mode $s0$s1 $title $s2 [expr $mid + $len3] 1
        }
    }

    if {$options(.TOC) || !$options(.COMPACT)} {
        end_page_$mode
    }
}

proc write_toc_txt {s1 title s2 len dot} {
    global mode unpaginated

    set x [string length $title]
    if {$unpaginated} {
        set len $x
        set s2 ""
    } elseif {$dot && ($x < $len)} {
        if {($len - $x) & 1} {
            append title " "
            incr x
        }
        while {$x < $len} {
            append title " ."
            incr x 2
        }
    }

    write_line_$mode [format "%s%-*.*s%s" $s1 $len $len $title $s2]
}

proc abstract_txt {} {
    global options

    if {(!$options(.COMPACT) && !$options(.ABSTRACT1ST)) || ![have_lines 4]} {
        end_page_txt
    } else {
        write_line_txt ""
    }
    write_line_txt "Abstract"
    write_line_txt "" -1
}

proc note_txt {title depth} {
    global options

    if {!$options(.COMPACT) || ![have_lines 4]} {
        end_page_txt
    } else {
        write_line_txt ""
    }
    write_line_txt [chars_expand $title]
    write_line_txt "" -1
}

proc section_txt {prefix top title lines anchor} {
    global options
    global pageno
    global page_basic_indent

    if {($top && !$options(.COMPACT)) || (![have_lines [expr $lines + 2]])} {
        end_page_txt
    } else {
        write_line_txt ""
    }
    if {$top && !$options(.RFCEDSTYLE)} {
        write_line_txt "" -1
    }

    push_indent [expr -($page_basic_indent)]
    write_text_txt "$prefix  "
    push_indent [expr [string length $prefix] + 2]
    write_text_txt [chars_expand $title]
    flush_text
    pop_indent
    pop_indent

    return $pageno
}

proc t_txt {tag counter style hangText editNo} {
    global options
    global eatP
    global mode

    if {$eatP < 0} {
        set eatP 1
    }
    if {![string compare $tag end]} {
        return
    }

    if {[string compare $counter ""]} {
        set pos [pop_indent]
        set l [split $counter .]
        set left -1
        set lines 3
        switch -- $style {
            letters {
                set counter [offset2letters [lindex $l end] [llength $l]]
                append counter "."
            }

            numbers {
                set counter "[lindex $l end]."
            }

            symbols {
                set counter "[string index $options(text-list-symbols) [expr [expr [llength $l] - 1] % [string length $options(text-list-symbols)]]]"
            }

            hanging {
                global page_basic_indent

                set counter [chars_expand $hangText]
                set x [string length $counter]
                if {[set x [string length $counter]]} {
                    if {$x >= $pos} {
                        # Prevent two_spaces from kicking in.
                        append counter "\xA0"
                    }
                    append counter " "
                }
                if {$pos <= $page_basic_indent} {
                    set left ""
                } else {
                    set left -1
                }
                set lines 5
            }

            default {
                set counter "  "
                set left -2
            }
        }
        if {![have_lines $lines]} {
            end_page_$mode
        }
        if {$options(.EDITING)} {
            write_editno_$mode $editNo
        } elseif {!$options(.SUBCOMPACT)} {
            write_line_$mode ""
        }
        set c [format "%-[expr $pos-0]s" $counter]
        switch -- $mode {
            txt {
                write_text_txt $c
            }
            nr {
                indent_text_nr $c $left
                pop_indent
            }
        }
        push_indent $pos
    } else {
        if {$options(.EDITING)} {
            write_editno_$mode $editNo
        } else {
            write_line_$mode ""
        }
    }

    set eatP 1
}

proc offset2letters {offset {depth 0}} {
    set alpha "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

    set letters ""
    for {} {$offset > 0} {set offset [expr $offset / 26]} {
        incr offset -1
        set letters [string index $alpha [expr $offset % 26]]$letters
    }

    if {$depth & 1} {
        set letters [string tolower $letters]
    }

    return $letters
}

proc offset2romans {offset {depth 0}} {
    if {$offset <= -5000 || $offset == 0 || $offset >= 5000} {
        # You've been silently upgraded.
        return [expr $offset]
    } elseif {$offset < 0} {
        set offset [expr -($offset)]
        set sign -
    } else {
        set sign ""
    }

    set r {{"" I II III IV V VI VII VIII IX}
           {"" X XX XXX XL L LX LXX LXXX XC}
           {"" C CC CCC CD D DC DCC DCCC CM}}

    set romans ""
    for {set d 0} {$d < 3 && $offset} {incr d; set offset [expr $offset / 10]} {
        set romans [lindex [lindex $r $d] [expr $offset % 10]]$romans
    }

    if {$offset} {
        # This could be a really long string, were it not for the limit above.
        set romans [string repeat M $offset]$romans
    }

    if {$depth & 1} {
        set romans [string tolower $romans]
    }

    return $sign$romans
}

proc list_txt {tag min max style hangIndent longestHangText suprT} {
    global options
    global eatP
    global mode

    switch -- $tag {
        begin {
            switch -- $style {
                letters {
                    set i [expr [string length [offset2letters $max]] + 1]
                }

                numbers {
                    set i [expr [string length $max] + 1]
                }

                format {
                    set i [string length [chars_expand $longestHangText]]
                }

                default { set i 1 }
            }
            if {[incr i 2] > $hangIndent} {
                push_indent $i
            } else {
                push_indent [expr $hangIndent]
            }
        }

        end {
            flush_text
            if {!$options(.SUBCOMPACT)} {
                write_line_$mode ""
            }
            pop_indent

            set eatP 1

            switch -- $mode {
                nr {
                    global indent
                    condwrite_in_nr $indent
                }
            }
        }
    }
}

proc figure_txt {tag lines anchor title av {suppressP 0}} {
    global xref
    global page_width page_basic_indent
    global eatP
    global mode

    switch -- $tag {
        begin {
            if {[string compare $anchor ""]} {
                array set av2 $xref($anchor)
                set x [string length $av2(value)]
                incr x 7
                if {[string compare $title ""]} {
                    incr x [string length [chars_expand $title]]
                    incr x 2
                }
                # Approximation based on a line length of 69 with a
                # weighted average of half-word lengths of 3.7 (4).
                set y [expr $page_width - $page_basic_indent - 4]
                incr lines [expr 1 + ($x + $y - 1) / $y]
            }
            if {![have_lines $lines]} {
                end_page_$mode
            }
            flush_text
        }

        end {
            set eatP 1
            if {[string compare $anchor ""]} {
                array set av2 $xref($anchor)
                set prefix "Figure\xA0$av2(value)"
                if {[string compare $title ""]} {
                    set title "$prefix: [chars_expand $title]"
                } elseif {!$suppressP} {
                    set title $prefix
                }
            }
            if {[string compare $title ""]} {
                write_line_$mode ""
                write_text_$mode $title c
                write_line_$mode ""
            }
        }
    }
}

proc artwork_txt {tag lines {av {}} } {
    global mode

    switch -- $tag {
        begin {
            # This was done for the whole figure, but let's
            # try it for the artwork alone, just in case.
            if {![have_lines $lines]} {
                end_page_$mode
            }
        }
    }
}

proc preamble_txt {tag {editNo ""}} {
    global options
    global eatP
    global mode

    switch -- $tag {
        begin {
            set eatP 1
            if {$options(.EDITING)} {
                write_editno_$mode $editNo
            } else {
                write_line_$mode ""
            }
        }
    }
}

proc postamble_txt {tag {editNo ""}} {
    global options
    global eatP
    global mode

    switch -- $tag {
        begin {
            cellE
            set eatP 1
            if {$options(.EDITING)} {
                write_editno_$mode $editNo
            }
        }
    }
}

proc texttable_txt {tag lines anchor title {suppressP 0}} {
    global xref
    global page_width page_basic_indent
    global eatP
    global mode
    global cellH cellK

    switch -- $tag {
        begin {
            if {[string compare $anchor ""]} {
                array set av $xref($anchor)
                set x [string length $av(value)]
                incr x 6
                if {[string compare $title ""]} {
                    incr x [string length [chars_expand $title]]
                    incr x 2
                }
                # Approximation based on a line length of 69 with a
                # weighted average of half-word lengths of 3.7 (4).
                set y [expr $page_width - $page_basic_indent - 4]
                incr lines [expr 1 + ($x + $y - 1) / $y]
            }
            if {![have_lines $lines]} {
                end_page_$mode
            }
            flush_text

            cellB
        }

        end {
            cellE
            set eatP 1
            if {[string compare $anchor ""]} {
                array set av $xref($anchor)
                set prefix "Table\xA0$av(value)"
                if {[string compare $title ""]} {
                    set title "$prefix: [chars_expand $title]"
                } elseif {!$suppressP} {
                    set title $prefix
                }
            }
            if {[string compare $title ""]} {
                write_line_$mode ""
                write_text_$mode $title c
                write_line_$mode ""
            }
        }
    }
    return [list $cellH $cellK]
}

proc ttcol_txt {text align col width cwidth} {
    cellP $text 0 [lindex $col 0] $width $cwidth $align
}

proc c_txt {tag row col align width} {
    switch -- $tag {
        begin { cellP "" [lindex $row 0] [lindex $col 0] }
    }
}

proc cellB {} {
    global cellH cellK

    set cellH 0
    set cellK {}
}

proc cellE {} {
    global options
    global mode
    global cells cellR cellH cellK
    global page_width page_basic_indent

    if {[llength [array names cells]] == 0} {
        return
    }

    if {![string compare $cellR all]} {
        set rowsepP 1
        set cellR full
    } else {
        set rowsepP 0
    }
    # Assess space taken by table frame.
    set num_rows $cells(maxrow)
    set num_cols $cells(maxcol)
    switch -- $cellR {
        none - headers { set overhead [expr     $num_cols - 1] }
        full           { set overhead [expr 3 * $num_cols + 1] }
    }
    incr overhead $page_basic_indent
    set avail [expr $page_width - $overhead]

    set left_margin [current_align_bias]
    switch -- [current_align] {
        left {
            if {$left_margin < 0} {
                if {$left_margin < -($page_basic_indent)} {
                    set left_margin [expr -($page_basic_indent)]
                }
                incr avail [expr -($left_margin)]
            }
        }
    }

    if {$avail < 0} {
        unexpected error "too many <ttcol>s to even build <texttable> frame"
    }

    # Compute basic statistics on the data.
    set min {}
    set max {}
    set specs $cells(width)
    foreach col $specs {
        lappend min 0
        lappend max 0
    }
    for {set i 0} {$i <= $num_rows} {incr i} {
        for {set j 1} {$j <= $num_cols} {incr j} {
            if {![info exists cells($i,$j)]} {
                set data ""
            } else {
                set data [two_spaces $cells($i,$j) 1]
            }
            set cells($i,$j) $data
            set x [string length $data]
            set y [expr $j - 1]
            if {$x > [lindex $max $y]} {
                set max [lreplace $max $y $y $x]
            }
            set z 0
            foreach word [split $data] {
                set x [string length $word]
                if {$x > $z} {
                    set z $x
                }
            }
            if {$z > [lindex $min $y]} {
                set min [lreplace $min $y $y $z]
            }
        }
    }
    set max_width [sum_list $max]
    set min_width [sum_list $min]
    set inf {}
    set inf_width 0
    foreach col $min {
        set col [expr $col != 0]
        lappend inf $col
        incr inf_width $col
    }
    if {$avail < $inf_width} {
        unexpected error "too many non-empty columns in <texttable> to fit in page width"
    }

    # Translate width specs given available space.
    set cols {}
    set rel_total 0
    set unspec {}
    foreach col $specs {
        # What to do with the unspecified ones is touchy.
        set u 0
        switch -- $col {
            {}      { set x [lindex $min [llength $cols]]; set u 1 }
            *       { incr rel_total [set x -1] }
            default {
                regexp -- {^0*([0-9]+)(|em|[%*])$} $col x num units
                switch -- $units {
                    em      { set x $num }
                    %       { set x [expr ($num * $avail + 99) / 100]}
                    *       { incr rel_total [set x [expr -($num)]] }
                    default { set x 0 }
                }
            }
        }
        lappend cols $x
        lappend unspec $u
    }
    set specs $cols

    # Compute final cell widths (and their total).
    set width $avail
    if {$avail == $min_width} {
        set cols $min
    } elseif {$avail == $inf_width} {
        set cols $inf
    } elseif {$avail < $min_width} {
        unexpected warning "so many <ttcol>s in <texttable> that some words need to be split"

        set excess [expr $min_width - $avail]

        # First, try the mins that are greater than their specs.
        set tol {}
        set tol_width 0
        set fnum [expr ($rel_total > 0) ? 1000 : 0]
        set fden 1
        foreach s $specs n $min {
            set t 0
            if {$s >= 0} {
                incr s [expr $s == 0]
                set y [expr $n - $s]
                if {$y > 0} {
                    set t $y
                }
            } elseif {$fnum > 0} {
                # Prepare in case we need to try the relative widths.
                incr n -1
                set s [expr -($s)]
                # We keep the smallest acceptable factor to all as a mixed number.
                if {$n <= 0} {
                    set fnum 0
                } elseif {$n * $fden < $s * $fnum} {
                    set fnum $n
                    set fden $s
                }
            }
            lappend tol $t
            incr tol_width $t
        }
        foreach {excess cols} [shave_cols_excess $min $excess $tol $tol_width] {break}

        # Second, try the unspecified widths.
        if {$excess > 0} {
            set tol {}
            set tol_width 0
            foreach w $cols u $unspec {
                set t [expr ($u && $w > 0) ? ($w - 1) : 0]
                lappend tol $t
                incr tol_width $t
            }
            foreach {excess cols} [shave_cols_excess $cols $excess $tol $tol_width] {break}
        }

        # Third, try the relative widths (to shrink, not expand).
        if {$excess > 0 && $fnum > 0} {
            if {$excess * $fden < $rel_total * $fnum} {
                set fnum $excess
                set fden $rel_total
            }
            set tol {}
            set tol_width 0
            foreach s $specs {
                set t [expr ($s < 0) ? (($fnum * -($s)) / $fden) : 0]
                lappend tol $t
                incr tol_width $t
            }
            foreach {excess cols} [shave_cols_excess $cols $excess $tol $tol_width] {break}
        }

        # Finally, try anything that's left, leaving as little as one column.
        # Start with largest.
        set p 1
        foreach w $cols {
            if {$w > $p} {
                set p $w
            }
        }
        while {$excess > 0} {
            if {$p == 1} {
                unexpected error "bug in reducing <texttable> column widths"
            }
            # Find second largest.
            set q 1
            foreach w $cols {
                if {$w > $q && $w < $p} {
                    set q $w
                }
            }
            set tol {}
            set tol_width 0
            foreach w $cols {
                set t [expr ($w > $q) ? ($w - $q) : 0]
                lappend tol $t
                incr tol_width $t
            }
            foreach {excess cols} [shave_cols_excess $cols $excess $tol $tol_width] {break}
            set p $q
        }
    } else {
        # There is room beyond minimum space.
        # First, try to give everyone what they want or need.
        #   min + specs + max(all)
        set cols {}
        set cols_width 0
        # min + specs
        set mnsa {}
        set mnsa_width 0
        # min + specs + max(rel)
        set mnsb {}
        set mnsb_width 0
        # min + specs + max(rel + unspec)
        set mnsc {}
        set mnsc_width 0
        foreach m $max n $min s $specs u $unspec {
            set t $n
            if {$t < $s} {
                set t $s
            }
            lappend mnsa $t
            incr mnsa_width $t
            if {$s < 0} {
                set t $m
            }
            lappend mnsb $t
            incr mnsb_width $t
            if {$u} {
                set t $m
            }
            lappend mnsc $t
            incr mnsc_width $t
            if {$t < $m} {
                set t $m
            }
            lappend cols $t
            incr cols_width $t
        }
        # In decreasing order by width...
        if {$avail >= $cols_width} {
            set width $cols_width
        } elseif {$avail > $mnsc_width} {
            # Partially expand columns with greater maximal width from mnsc.
            set target [expr $avail - $mnsc_width]
            foreach {target cols} [expand_cols_by_height $mnsc $target $cols] {break}
        } elseif {$avail == $mnsc_width} {
            set cols $mnsc
        } elseif {$avail > $mnsb_width} {
            # Partially expand columns with unspecified width from mnsb.
            set target [expr $avail - $mnsb_width]
            foreach {target cols} [expand_cols_by_height $mnsb $target $mnsc] {break}
        } elseif {$avail == $mnsb_width} {
            set cols $mnsb
        } elseif {$avail > $mnsa_width} {
            # Partially expand columns with relative width from mnsa.
            set cols $mnsa
            set target [expr $avail - $mnsa_width]
            while {$target > 0} {
                set rel {}
                set num_rel 0
                set rel_total 0
                set fnum 1000
                set fden 1
                foreach m $max s $specs w $cols {
                    set x 0
                    if {$s < 0} {
                        set d [expr $m - $w]
                        if {$d > 0} {
                            set x [expr -($s)]
                            if {$d * $fden < $x * $fnum} {
                                set fnum $d
                                set fden $x
                            }
                            incr num_rel
                            incr rel_total $x
                        }
                    }
                    lappend rel $x
                }
                if {$target * $fden < $rel_total * $fnum} {
                    set fnum $target
                    set fden $rel_total
                }
                set plus_width 0
                if {$num_rel > 0 && $fnum > 0} {
                    set kols {}
                    foreach r $rel w $cols {
                        set p [expr ($r * $fnum) / $fden]
                        lappend kols [expr $w + $p]
                        incr plus_width $p
                    }
                }
                if {$plus_width > 0} {
                    set cols $kols
                    incr target [expr -($plus_width)]
                } elseif {$num_rel > 0} {
                    set dd $target
                    set kols {}
                    foreach r $rel w $cols {
                        if {$r > 0} {
                            # Prefer expanding the rightmost ones.
                            if {$dd >= $num_rel} {
                                incr w
                                incr target -1
                            }
                            incr dd
                        }
                        lappend kols $w
                    }
                    set cols $kols
                } else {
                    unexpected error "bug in expanding <texttable> columns with relative widths"
                }
            }
        } elseif {$avail == $mnsa_width} {
            set cols $mnsa
        } else {
            # Partially expand columns with greater specified width from min.
            set target [expr $avail - $min_width]
            set plus [subtract_lists $mnsa $min]
            foreach {target cols} [expand_cols $min $target $plus] {break}
        }
    }

    # Adjust $left_margin from $width and current align (for whole table).
    set x [expr $avail - $width]
    switch -- [current_align] {
        left {
            if {$left_margin < 0} {
                set x -1
            }
        }
        center {
            incr left_margin [expr $x / 2]
        }
        right {
            incr left_margin $x
        }
    }
    if {$x >= 0} {
        if {$left_margin > $x} {
            set left_margin $x
        }
        if {$left_margin < 0} {
            set left_margin 0
        }
    }
    incr left_margin $page_basic_indent

    # At this point, we have the $cols list, $num_cols, and $left_margin.
    set prefix [format "%*s" $left_margin ""]
    if {![string compare $mode nr]} {
        condwrite_nf_nr
    }

    # Building blocks.
    switch -- $cellR {
        none    { set vars "0 0 {} { } {} {}  {} { } { }" }
        headers { set vars "0 1 {} { } {} {}  {} { } -  " }
        full    { set vars "1 0 |  |   -  { } +  +   -  " }
    }
    foreach {allP halfP sideC colC sepC padC rowC crxC dashC} $vars {break}

    # Format each cell given final $cols list values.
    set cellK $cols
    foreach cell [array names cells *,*] {
        set column [expr [lindex [split $cell ,] 1] - 1]
        set cells($cell) [cellF $cells($cell) \
                                [lindex $cells(align) $column] \
                                [lindex $cols $column]]
    }

    # Precompute number of lines in each row.
    set row_lines {}
    for {set row 0} {$row <= $num_rows} {incr row} {
        set lines 0
        foreach cell [array name cells $row,*] {
            if {[set x [llength [split $cells($cell) "\n"]]] > $lines} {
                set lines $x
            }
        }
        lappend row_lines $lines
    }

    write_line_$mode ""

    # Attempt to fit header (row 0) and row 1 in same page.
    if {$num_rows >= 1} {
        set lines [lindex $row_lines 0]
        incr lines [expr $allP && $lines > 0]
        incr lines [expr   (   !$options(.COMPACT) \
                            ||  [string compare $cellR none]) \
                         + (   ($num_rows == 1) \
                            && ![string compare $cellR full])]
        incr lines [lindex $row_lines 1]

        if {![have_lines $lines]} {
            end_page_$mode
        }
    }

    # Precompute separator line.
    set hit_image $prefix
    set c $rowC
    foreach col $cols {
        append hit_image "$c$sepC[::textutil::strRepeat $dashC $col]$sepC"
        set c $crxC
    }
    append hit_image $rowC

    if {$rowsepP} {
        # No blank lines - use separator line.
        set blank_image $hit_image
    } else {
        # Precompute blank line.
        set blank_image $prefix
        set c $sideC
        foreach col $cols {
            append blank_image [format "$c$padC%*s$padC" $col ""]
            set c $colC
        }
        append blank_image $sideC
    }

    # Write top line.
    if {$allP && [lindex $row_lines 0] > 0} {
        write_line_$mode $hit_image
        incr cellH
    }

    # Generate each row of cells.
    for {set row 0} {$row <= $num_rows} {incr row} {
        set lines [lindex $row_lines $row]

        set hitP 0
        switch -- $cellR {
            none    { if {$row == 0 && !$options(.COMPACT)} { set hitP 1 } }
            headers { if {$row == 0}                        { set hitP 1 } }
            full    { if {$row == 0 || $row == $num_rows}      { set hitP 1 } }
        }

        if {![is_at_page_start]} {
            set blkP [expr ($row > 1) && (!$options(.COMPACT) || $rowsepP)]
            if {![have_lines [expr $blkP + $lines + $hitP]]} {
                if {$blkP && [have_lines 1]} {
                    # Totally optional.  Only if a line is available.
                    write_line_$mode $blank_image
                }
                end_page_$mode
                if {$rowsepP} {
                    write_line_$mode $blank_image
                }
            } elseif {$blkP} {
                write_line_$mode $blank_image
            }
            incr cellH $blkP
        }

        for {set line 0} {$line < $lines} {incr line} {
            set image $prefix
            set c $sideC
            for {set column 1} {$column <= $num_cols} {incr column} {
                set width [lindex $cols [expr $column - 1]]
                set data [format "%-*.*s" $width $width \
                                 [lindex [split $cells($row,$column) "\n"] \
                                         $line]]
                append image "$c$padC$data$padC"
                set c $colC
            }
            append image $sideC
            write_line_$mode $image
            incr cellH
        }

        if {$hitP} {
            write_line_$mode $hit_image
            incr cellH
        }
    }
    write_line_$mode ""

    unset cells
}

proc shave_cols_excess {cols excess give {give_width -1}} {
    if {$give_width < 0} {
        set give_width [sum_list $give]
    }
    if {$excess <= 0 || $give_width <= 0} {
        # Nothing to do.
    } elseif {$excess >= $give_width} {
        # Take everything; it may still not be enough.
        set cols [subtract_lists $cols $give]
        incr excess [expr -($give_width)]
    } else {
        # Take only what we need, in relative proportion.
        set dd 0
        set kols {}
        foreach c $cols g $give {
            if {$g > 0} {
                set d [expr ($g * $excess) / $give_width]
                incr c [expr -($d)]
                incr dd $d
            }
            lappend kols $c
        }
        incr excess [expr -($dd)]

        # Do the ones we missed because of integer division.
        if {$excess > 0} {
            set cols {}
            foreach k $kols g $give {
                # Prefer shaving the leftmost ones.
                if {$excess > 0 && $g > 0} {
                    incr k -1
                    incr excess -1
                }
                lappend cols $k
            }
        } else {
            set cols $kols
        }
    }

    return [list $excess $cols]
}

proc expand_cols {cols target plus {plus_width -1}} {
    if {$plus_width < 0} {
        set plus_width [sum_list $plus]
    }
    if {$target <= 0 || $plus_width <= 0} {
        # Nothing to do.
    } elseif {$target >= $plus_width} {
        # Take everything; it may still not be enough.
        set cols [add_lists $cols $plus]
        incr target [expr -($plus_width)]
    } else {
        # Take only what we need, in relative proportion.
        set dd 0
        set dr 0
        set kols {}
        foreach c $cols p $plus {
            if {$p > 0} {
                set d [expr ($p * $target) / $plus_width]
                incr c $d
                incr dd $d
                incr dr
            }
            lappend kols $c
        }
        incr target [expr -($dd)]

        # Do the ones we missed because of integer division.
        if {$target > 0} {
            set dd $target
            set cols {}
            foreach k $kols p $plus {
                if {$p > 0} {
                    # Prefer expanding the rightmost ones.
                    if {$dd >= $dr} {
                        incr k
                        incr target -1
                    }
                    incr dd
                }
                lappend cols $k
            }
        } else {
            set cols $kols
        }
    }

    return [list $target $cols]
}

proc expand_cols_by_height {cols target bound} {
    while {$target > 0} {
        set m_width 0
        set w_width 0
        foreach m $bound w $cols {
            if {$m > $w} {
                # Only cover those columns below the bound.
                incr m_width $m
                incr w_width $w
            }
        }
        # This mixed number is the average height we could achieve.
        set fnum $m_width
        set fden [expr $w_width + $target]
        set plus_num 0
        set plus {}
        set plus_width 0
        set kols {}
        foreach m $bound w $cols {
            set p 0
            set k $w
            if {$m > $w} {
                set x [expr $m * $fden]
                set y [expr $w * $fnum]
                # Seek columns of above average height.
                if {$x >= $y} {
                    # Nearly reduce height to average by augmenting width.
                    set p 1
                    # Round height up at this point to avoid overshoot.
                    set k [expr $x / ($fnum + $fden - 1)]
                    if {$k < $w} {
                        # But do no smaller than before.
                        set k $w
                    }
                    if {$k > [expr $w + $target]} {
                        # overshot anyway
                        set k [expr $w + $target]
                    }
                    set q [expr $k - $w]
                    incr plus_num
                    incr plus_width $q
                }
            }
            lappend plus $p
            lappend kols $k
        }
        if {$plus_width > 0} {
            set cols $kols
            incr target [expr -($plus_width)]
        } elseif {$plus_num > 0} {
            # No progress due to integer division.  Make some.
            set dd $target
            set cols {}
            foreach p $plus w $kols {
                if {$p > 0} {
                    # Prefer expanding the rightmost ones.
                    if {$dd >= $plus_num} {
                        incr w
                        incr target -1
                    }
                    incr dd
                }
                lappend cols $w
            }
        } else {
            # Should not happen, but just in case we were given a bad target.
            set cols $kols
            break
        }
    }

    return [list $target $cols]
}

proc cellF {text align width} {
    set text [::textutil::adjust::adjust $text \
                           -justify      $align \
                           -length       $width \
                           -full         true \
                           -strictlength true]
    # ...adjust really needs some work
    set pad [format %*s $width ""]
    while {[string first "$pad\n" $text] == 0} {
        set text [string range $text [expr $width + 1] end]
    }

    # this will work only for left-justified errors...
    if {[set nlines [llength [set lines [split $text "\n"]]]] \
            > 1} {
        set pre ""
        set post ""
        for {set lineno 0} {$lineno < $nlines} {incr lineno} {
            set line $post[lindex $lines $lineno]
            set post ""
            if {[string length $line] > $width} {
                append pre [string range $line 0 [expr $width - 1]]
                set post [string range $line $width end]
            } else {
                append pre $line
            }
            append pre "\n"
        }
        if {[string compare $post ""]} {
            append pre "$post\n"
        }
        set text [string trimright $pre]
    }

    return $text
}

proc cellP {data {row -1} {col -1} {width -1} {cwidth -1} {align ""}} {
    global cell_row cell_col cells
    global mode
    global annoP

    if {[info exists annoP]} {
        # <annotation>s within <reference>s.
        switch -- $mode {
            html {}
            default { set data [chars_expand $data 0] }
        }
        append cells(0,0) $data
        return 1
    }

    if {$row == -1} {
        if {[llength [array names cells]] == 0} {
            # No current cell_row,cell_col to append to.
            return 0
        }
    } else {
        # We were called for a <ttcol> or a <c>.
        set cells(maxrow) $row
        set cell_row $row
        set cell_col $col
        if {![string compare $width ""] || $width >= 0} {
            # We were called for a <ttcol>.
            lappend cells(width) $width
            lappend cells(align) $align
            set cells(maxcol) $col
        }
        if {![string compare $cwidth ""] || $cwidth >= 0} {
            # We were called for a <ttcol> and cwidths are known.
            lappend cells(cwidth) $cwidth
        }
    }

    append cells($cell_row,$cell_col) [chars_expand $data 0]
    return 1
}


proc xref_txt {text av target format {hackP 0}} {
    global elem
    global eatP
    global mode

    array set attrs $av

    set elemY $attrs(elemN)
    array set tv [list title "" suppress-title false]
    array set tv $elem($elemY)
    switch -- [string tolower $tv(suppress-title)] {
        yes - true - 1 {
            set suppressP 1
        }

        default {
            set suppressP 0
        }
    }

    # Turn any hyphens in value into non-breaking hyphens.
    regsub -all -- "-" $attrs(value) "\u2011" attrs(value)

    switch -- $attrs(type) {
        section   { set line   "Section\xA0$attrs(value)"   }
        appendix  { set line  "Appendix\xA0$attrs(value)"   }
        figure    { set line    "Figure\xA0$attrs(value)"   }
        texttable { set line     "Table\xA0$attrs(value)"   }
        cref      { set line   "Comment\xA0$attrs(value)"   }
        t         { set line "Paragraph\xA0$attrs(value)"   }
        default   { set line            "\[$attrs(value)\]" }
    }
    if {$hackP} {
        return $line
    }

    if {![string compare $format none]} {
        if {![string compare [set line [chars_expand $text]] ""]} {
            set eatP -1
            return
        }
    } elseif {[string compare $text ""]} {
        switch -- $attrs(type) {
            section - appendix - figure - texttable {
                if {$suppressP} {
                    set line [chars_expand $text]
                } else {
                    set line "[chars_expand $text] ($line)"
                }
            }

            default {
                set line "[chars_expand $text] $line"
            }
        }
    } else {
        switch -- $format {
            counter { set line $attrs(value) }
            title   { set line [chars_expand $tv(title)] }
            default {}
        }
    }

    if {![cellP $line]} {
        set eatP 0
        write_text_$mode $line
    }

    set eatP -1
}

proc eref_txt {text counter target} {
    global eatP
    global erefs
    global mode

    if {![string compare $text ""]} {
        set line "<$target>"
    } elseif {([string first "#" $target] < 0) \
                  && ([string compare $text $target])} {
        set erefs($counter) $target
        set line "$text\xA0\[$counter\]"
    } else {
        set line $text
    }
    if {![cellP $line]} {
        set eatP 0
        write_text_$mode [chars_expand $line]
    }

    set eatP -1
}

proc cref_txt {text counter source anchor} {
    global options
    global eatP
    global crefs
    global mode

    set comments ""
    if {[string compare $source ""]} {
        set comments "${source}: "
    }
    append comments $text
    set crefs($counter) [list $anchor $source $text $comments]

    if {$options(.INLINE)} {
        set line "\[\[$counter: $text"
        if {[string compare $source ""]} {
            append line " --$source"
        }
        append line "\]\]"
    } else {
        set line "\[$counter\]"
    }
    if {![cellP $line]} {
        set eatP 0
        pcdata_$mode $line
    }

    set eatP -1
}

proc iref_txt {item subitem flags} {
    global pageno

    return $pageno
}

proc vspace_txt {lines} {
    global lineno
    global eatP
    global mode
    global unpaginated
    global page_head_height page_body_height

    set eatP 1
    if {[is_at_page_start]} {
        return
    }
    if {   !$unpaginated
        && ($lineno + $lines >= $page_head_height + $page_body_height)} {
        # l+l == h+b would fit, but leave nothing.
        end_page_$mode
    } else {
        switch -- $mode {
            txt {
                while {[incr lines -1] >= 0} {
                    write_it ""
                    incr lineno
                }
            }

            nr {
                if {$lines > 0} {
                    write_it ".sp $lines"
                    incr lineno $lines
                } else {
                    write_it ".br"
                }
            }
        }
    }
}

# Can be reset in rc file to override or add styles; e.g.,
#   global spanx_txt_styles
#   set spanx_txt_styles [linsert $spanx_txt_styles 0 {verb "<" ">"}]
global spanx_txt_styles
set spanx_txt_styles {
    {emph "_"}      # as in makeinfo(1)
    {vemph "_"}
    {strong "*"}    # as in makeinfo(1)
    {vstrong "*"}
    {verb "\""}
    {vbare ""}
    {vdeluxe "*_" "_*"}
    {nobreak ""}
}

proc spanx_txt {text style} {
    global spanx_txt_styles
    global mode
    global eatP

    set i [lsearch0 $spanx_txt_styles $style]
    if {$i < 0} {
        set c1 ""
        set c2 ""
    } else {
        set sts [lindex $spanx_txt_styles $i]
        set c1 [lindex $sts 1]
        if {[llength $sts] >= 3} {
            set c2 [lindex $sts 2]
        } else {
            set c2 $c1
        }
    }

    set text [chars_expand $text]
    switch -- $style {
        vemph - vstrong - verb - vbare - vdeluxe - nobreak {
            set text [break_protect $text]
        }
    }
    set line $c1$text$c2

    if {![cellP $line]} {
        set eatP 0
        write_pcdata_$mode $line
    }

    set eatP -1
}

proc references_txt {tag args} {
    global mode
    global counter depth
    global pageno
    global page_basic_indent

    switch -- $tag {
        begin {
            set prefix [lindex $args 0]
            set title  [lindex $args 1]
            if {   $depth(references) > 1
                && ![info exists counter(references)]} {
                set counter(references) 0
                section_$mode [lindex [split $prefix .] 0]. 1 References 0 ""
            }

            return [section_$mode $prefix [expr $depth(references) <= 1] $title 3 ""]
        }

        end {
            set erefP [lindex $args 0]
            if {$erefP} {
                erefs_$mode
            } else {
                flush_text
            }
        }
    }
}

proc erefs_txt {{title ""}} {
    global erefs
    global options

    if {[string compare $title ""]} {
        if {$options(.COMPACT)} {
            write_line_txt ""
        } else {
            end_page_txt
        }
        write_line_txt $title
    }

    set names  [lsort -integer [array names erefs]]
    set width [expr [string length [lindex $names end]]+2]
    foreach eref $names {
        write_line_txt ""

        set i [expr [string length \
                            [set prefix \
                                 [format %-*.*s $width $width \
                                         "\[$eref\]"]]+2]]
        write_text_txt $prefix

        push_indent $i

        write_text_txt "  "
        write_url $erefs($eref)

        pop_indent
    }

    flush_text
}

proc crefs_txt {title} {
    global crefs
    global options

    if {[string compare $title ""]} {
        if {$options(.COMPACT)} {
            write_line_txt ""
        } else {
            end_page_txt
        }
        write_line_txt $title
    }

    set names  [lsort -dictionary [array names crefs]]
    set width 0
    foreach cref $names {
        set x [string length $cref]
        if {$x > $width} {
            set width $x
        }
    }
    incr width 2
    foreach cref $names {
        write_line_txt ""

        set i [expr [string length \
                            [set prefix \
                                 [format %-*.*s $width $width \
                                         "\[$cref\]"]]+2]]
        write_text_txt $prefix

        push_indent $i

        write_text_txt "  "
        write_text_txt [chars_expand [lindex $crefs($cref) 3]]
        pop_indent
    }

    flush_text
}

proc reference_txt {prefix names title series formats date anchor target
                    target2 width annotations} {
    global options
    global max_ref_width

    write_line_txt ""

    if {($width > $max_ref_width) && !$options(.RFCEDSTYLE)} {
        set width $max_ref_width
    }
    set i [string length $prefix]
    set prefix [format %-*s [expr $width + 2] "\[$prefix\]"]
    write_text_txt $prefix

    if {$i > $width} {
        set s ""
        flush_text
    } else {
        set s "  "
    }

    push_indent [expr $width + 4]

    set nameA 1
    set nameN [llength $names]
    foreach name $names {
        incr nameA
        write_text_txt $s[chars_expand [lindex $name 0]]
        set s [list_sep_str $nameA $nameN]
    }
    write_text_txt "$s\"[chars_expand $title]\""
    foreach serial $series {
        if {$options(.NOTEDRAFTINPROGRESS)} {
          if {[regexp -nocase -- "internet-draft&nbsp;(draft-.*)" $serial x n] == 1} {
              set serial "$n (work in progress)"
          }
        }
        write_text_txt ", [chars_expand $serial]"
    }
    if {[string compare $date ""]} {
        write_text_txt ", [chars_expand $date]"
    }
    if {[string compare $target ""]} {
        write_text_txt ", "
        write_url $target
    }
    write_text_txt .

    while {[llength $annotations] > 0} {
        write_line_txt ""
        pcdata_txt [lindex $annotations 0]
        set annotations [lrange $annotations 1 end]
    }

    pop_indent
}

proc annotation_txt {tag} {
    global mode
    global annoP
    global cells

    switch -- $tag {
        begin {
            set annoP 1
        }

        end {
            unset annoP

            set text [string trim $cells(0,0)]
            unset cells
            switch -- $mode {
                html {}
                default { set text [two_spaces $text 1] }
            }

            return $text
        }
    }
}

proc authors_txt {authors} {
    global options
    global lineno pageno
    global contacts
    global authorspg
    global page_basic_indent

    if {!$options(.AUTHORSHIP)} {
        return
    }
    switch -- [llength $authors] {
        0       { return }
        1       { set s1 "'s"; set s2 ""   }
        default { set s1 "s'"; set s2 "es" }
    }
    set s "Author$s1 Address$s2"

    if {!$options(.COMPACT) || ![have_lines 4]} {
        end_page_txt
    } else {
        write_line_txt ""
    }
    if {!$options(.RFCEDSTYLE)} {
        write_line_txt "" -1
    }
    set authorspg $pageno

    set bi [format "%*s" $page_basic_indent ""]
    set firstP 1
    foreach author $authors {
        set block1 [lindex $author 0]
        set block2 [lindex $author 1]

        set lines 4
        incr lines [llength $block1]
        incr lines [llength $block2]
        if {![have_lines $lines]} {
            end_page_txt
        }

        if {[string compare $s ""]} {
            write_line_txt $s
            set s ""
        } else {
            write_line_txt "" -1
        }
        write_line_txt "" -1

        foreach line $block1 {
            write_line_txt $bi[chars_expand $line]
        }

        if {[llength $block2] > 0} {
            write_line_txt ""
            foreach contact $block2 {
                set key [lindex $contact 0]
                set value [lindex [lindex $contacts \
                                          [lsearch0 $contacts $key]] 1]
                if {$options(.RFCEDSTYLE) && ![string compare $key email]} {
                    regsub -- m $value M value
                }
                set value [format %-6s $value:]
                if {$options(.COLONSPACE)} {
                    append value " "
                }
                write_line_txt "$bi$value [chars_expand [lindex $contact 1]]"
            }
        }
    }
}

proc back_txt {} {
}

global pcdata_line_offset
set pcdata_line_offset 0

proc pcdata_txt {text {pre 0} {nowrite 0} {spans {}} {divs {}} } {
    global eatP
    global options
    global pcdata_line_offset

    if {[llength $spans] > 0 || [llength $divs] > 0} {
        set text [html_quote $text]
    }

    if {(!$pre) && ($eatP > 0)} {
        set text [string trimleft $text]
    }
    if {[string length $text] <= 0} {
        # Was only white space, but got trimmed.
        return
    }
    set eatP 0

    if {!$pre} {
        regsub -all -- "\n\[ \t\n\]*" $text "\n" text
        regsub -all -- "\[ \t\]*\n\[ \t\]*" $text "\n" text
        set prefix ""

        if {$options(.EMOTICONIC)} {
            set text [emoticonic_txt $text]
        }
    }

    if {[cellP $text]} {
        return
    }

    set pcdata_line_offset 0
    foreach line [split $text "\n"] {
        set line [chars_expand $line]
        if {$pre} {
            set x 0
            while {[set x [lsearch0 $divs $pcdata_line_offset $x]] >= 0} {
                if {![have_lines [lindex [lindex $divs $x] 1]]} {
                    end_page_txt
                    break
                }
                incr x
            }
            write_line_txt [string trimright $line] $pre
        } else {
            write_pcdata_txt $prefix$line
            set prefix " "
        }
        incr pcdata_line_offset
    }
    set pcdata_line_offset 0

    if {[regexp -- {[ \t\n]$} $text]} {
        set eatP 1
    }
}

proc emoticonic_txt {text} {
    foreach {ei begin end} [list  *   *   * \
                                  '   '   ' \
                                 {"} {"} {"}] {
        set body ""
        while {[set x [string first "|$ei" $text]] >= 0} {
            if {$x > 0} {
                append body [string range $text 0 [expr $x-1]]
            }
            append body "$begin"
            set text [string range $text [expr $x+2] end]
            if {[set x [string first "|" $text]] < 0} {
                error "missing close for |$ei"
            }
            if {$x > 0} {
                set inline [string range $text 0 [expr $x-1]]
                if {[string first $begin $inline] == 0} {
                    set inline [string range $inline [string length $begin] \
                                       end]
                }
                set tail [expr [string length $inline]-[string length $end]]
                if {[string last $end $inline] == $tail} {
                    set inline [string range $inline 0 [expr $tail-1]]
                }

                append body $inline
            }
            append body "$end"
            set text [string range $text [expr $x+1] end]
        }
        append body $text
        set text $body
    }

    return $text
}

proc start_page_txt {} {
    global header lineno blankP
    global page_head_height

    write_it $header
    write_it ""
    write_it ""
    set lineno $page_head_height
    set blankP 1
}

proc end_page_txt {} {
    global footer lineno pageno unpaginated
    global page_width page_head_height page_body_height page_foot_height
    global guiP

    flush_text

    if {$lineno <= $page_head_height} {
        return
    }
    if {$unpaginated} {
        write_line_txt ""
        return
    }
    set lim [expr $page_head_height + $page_body_height + $page_foot_height - 1]
    while {$lineno < $lim} {
        write_it ""
        incr lineno
    }

    set text [format "\[Page %d\]" $pageno]
    if {$guiP == 1} {
        wm title . $text ; update 
    }
    incr pageno
    set len [string length $text]
    set len [expr ($page_width - [string length $footer]) - $len]
    if {$len < 4} {
        set len 4
    }
    write_it [format %s%*s%s $footer $len "" $text]
    write_it "\f"

    set lineno 0
}

proc write_pcdata_txt {text} {
    global buffer buffer_align
    global indent
    global mode

    if {![string compare $buffer ""]} {
        set buffer [format %*s $indent ""]
        set buffer_align [current_align]
    }
    append buffer $text
    set buffer [two_spaces $buffer]

    write_text_$mode ""
}

proc write_editno_txt {editNo} {
    global buffer

    flush_text
    set buffer <$editNo>
    flush_text
}

global break_chars
set break_chars {/ @ & | - + # % :}

proc break_protect {s} {
    global break_chars

    foreach c $break_chars {
        # Unicode reserves U+E000..U+F8FF for private use.
        set cx [format %c [expr 0xF000 + [scan $c %c]]]
        regsub -all -- "\[$c\]" $s $cx s
    }

    return $s
}

proc break_preprocess {s} {
    # As long as we only try breaking lines *after* recognized characters.
    # U+2060 WORD JOINER
    while {[regexp -- "(\[!-~\])\[\u2060\]" $s x cx]} {
        # Unicode reserves U+E000..U+F8FF for private use.
        set c [format %c [expr 0xF000 + [scan $cx %c]]]
        regsub -all -- "\[$cx\]\[\u2060\]" $s $c s
    }
    regsub -all -- "\[\u2060\]" $s "" s

    return $s
}

proc break_unprotect {s} {
    global break_chars

    # Unicode reserves U+E000..U+F8FF for private use.
    while {[regexp -- "\[\uF000-\uF0FF\]" $s cx]} {
        set c [format %c [expr [scan $cx %c] - 0xF000]]
        if {![string compare $c &]} {
            set c "\\&"
        }
        regsub -all -- "\[$cx\]" $s $c s
    }

    # U+2011 NON-BREAKING HYPHEN
    regsub -all -- "\[\u2011\]" $s "-" s
    # U+2060 WORD JOINER
    regsub -all -- "\[\u2060\]" $s "" s

    return $s
}

global buffer_rest buffer_align
set buffer_rest ""
set buffer_align ""

proc fold_text_txt {} {
    global buffer buffer_rest
    global break_chars
    global indent
    global page_width

    set buflen [string length $buffer]
    if {$buflen > $page_width} {
        set x [string last " " [string range $buffer 0 $page_width]]
        if {   $x != $page_width
            && [regexp -indices -start [expr $x + 1] \
                       -- { *([^ ]+)} $buffer y wi]
            && [set w0 [lindex $wi 0]] < $page_width} {

            # Get word across edge.
            set w1 [lindex $wi 1]
            set word [string range $buffer $w0 $w1]
            set wlen [expr $w1 - $w0 + 1]
            set ww [string range $word 0 [expr $page_width - 1 - $w0]]

            set must_break [expr (   ($w0 <= $indent) \
                                  || ($indent + $wlen > $page_width))]

            # Don't bother with short words that cannot possibly
            # produce a good break.
            # Don't break a URI (or other things that are nice to
            # copy&paste in their entirety) if it would entirely
            # fit in its own line (the next line).
            # Don't bother wasting our time on frequent purely
            # alphanumerical non-opportunities.
            if {   $must_break
                || (   ($w0 < ($page_width - 2))
                    && ($wlen >= 6)
                    && ![regexp -- {^[A-Za-z0-9_\xA0]+$} $ww]
                    && ![regexp -expanded -- { ://
                                              |\m(mailto|urn|news|tel):
                                              |\mdraft-[a-z0-9]+-
                                              |\m[A-Za-z0-9._-]+@[a-z0-9.-]+\M
                                             } $word]
                   )} {

                set best_left -1
                set best_middle -1
                set best_right $wlen

                # Bad:       a-zzzzzzz
                # Ok:       aa-zzzzzzz
                # Bad:  aaaaaa-zz
                # Ok:   aaaaaa-zzz
                foreach d $break_chars {
                    set y [string last $d $ww]
                    while {   $y >= 0
                           && [regexp -start $y -- "\\A.\[\])>\}'\"/@+:&|#%-\]" $word]} {
                        # Not a good break based on first character after it.
                        set y [string last $d [string range $ww 0 [expr $y - 1]]]
                    }

                    if {$y < 0 || $w0 + $y < $indent} {
                        # Not usable.
                    } elseif {   $y < 2
                              || [regexp -all -- {[A-Za-z0-9_]} \
                                         [string range $word \
                                                 0 [expr $y - 1]]] < 2} {
                        # Keep best of the indesirable left cuts.
                        if {$y > $best_left} {
                            set best_left $y
                        }
                    } elseif {   $y > $wlen - 4
                              || [regexp -all -- {[A-Za-z0-9_]} \
                                         [string range $word \
                                                 [expr $y + 1] end]] < 3} {
                        # Keep best of the indesirable right cuts.
                        if {$y < $best_right} {
                            set best_right $y
                        }
                    } else {
                        # The first good middle position gets it,
                        # because it's a better character.
                        if {$best_middle < 0} {
                            set best_middle $y
                            # Bonus early break.
                            break
                        }

                        ## The best middle position gets it,
                        ## even if it's a worst character.
                        #if {$y > $best_middle} {
                        #    set best_middle $y
                        #}
                    }
                }

                if {$best_middle >= 0} {
                    set x [expr $w0 + $best_middle + 1]
                } elseif {$must_break} {
                    # All undesirable, so start at right.
                    if {$best_right < $wlen} {
                        set x [expr $w0 + $best_right + 1]
                    } elseif {$best_left >= 0} {
                        set x [expr $w0 + $best_left + 1]
                    } else {
                        set x $page_width
                    }

                    global lineno pageno
                    regsub -all -- \" [string range $buffer $w0 [expr $x - 1]] {\"} wa
                    regsub -all -- \" [string range $buffer $x  $w1]           {\"} wz
                    unexpected warning \
 "output line $lineno (on page $pageno) breaks badly between \"$wa\" and \"$wz\""
                }
                # Else, we keep the first x we found
                # so we don't break the word.
            }
        }
        set text [string range $buffer 0 [expr $x-1]]
        set rest [string trimleft [string range $buffer $x end]]
    } else {
        set text $buffer
        set rest ""
    }
    # This would be done anyway by flush_text,
    # which is now (and must be) a no-op.
    set buffer ""

    # It is up to the caller to restore buffer with $buffer_rest,
    # after having printed text with write_line_$mode.
    if {[string compare $rest ""]} {
        set buffer_rest [format %*s%s $indent "" $rest]
    } else {
        set buffer_rest ""
    }

    return [string trimright $text]
}

proc justify_text_txt {text direction} {
    global indent
    global page_width

    set t [string trim $text]

    switch -- $direction {
        c - center {
            # Attempt to match (g)nroff formula.
            set len [expr ($page_width + $indent - [string length $t]) / 2]
        }

        r - right {
            set len [expr $page_width - [string length $t]]
        }

        default { return $text }
    }

    return [format %*s%s $len "" $t]
}

proc write_text_txt {text {direction l}} {
    global buffer buffer_rest buffer_align
    global indent
    global page_width
    global eatP

    if {($eatP < 0) && ![regexp -- {^[.,?!]} $text]} {
        set text " $text"
    }

    if {![string compare $buffer ""]} {
        set buffer [format %*s $indent ""]
        set buffer_align [current_align]
    }
# print_stack_trace
    append buffer $text

    set flush [string compare $direction l]
    while {([string length $buffer] > $page_width) || ($flush)} {
        set text [fold_text_txt]

        switch -- $direction {
            c - r { set buffer_align $direction }
        }
        set text [justify_text_txt $text $buffer_align]
        write_line_txt $text

        if {![string compare [set buffer $buffer_rest] ""]} {
            set buffer_align ""
            break
        }
    }
}

# grab the current function name. Useful in debugging like this:
# puts stderr "[get_current_function_name] your message goes here"
proc get_current_function_name {} {
    return [info level -1];
}

# print the current stack trace
proc print_stack_trace {} {
    set stack ""
    set level -1
    for { set x [expr {[info level] + $level}] } { $x > 0 } { incr x -1 } {
        append stack "    called from [info level $x]\n"
    }
    puts stderr $stack
}

proc write_line_txt {line {pre 0}} {
    global lineno blankP
    global unpaginated
    global page_width
    global page_head_height page_body_height page_basic_indent

    flush_text
    if {$lineno == 0} {
        start_page_txt
    }
    if {![set x [string compare $line ""]]} {
        set blankO $blankP
        set blankP 1
        if {($blankO) && (!$pre || $lineno == $page_head_height)} {
            return
        }
    } else {
        set blankP 0
    }
    if {($pre) && ($x)} {
        if {$pre < 0} {
            set prefix [format "%*s" $page_basic_indent ""]
        } else {
            # pre = 1 + total indent
            set prefix [format %*s [expr $pre - 1] ""]
            set line [tabs_expand_pre $line]
        }
    } else {
        set prefix ""
    }
    set line [nbsp_expand_txt [break_unprotect $line]]
    write_it [set line [string trimright $prefix$line]]
    incr lineno
    if {[set len [string length $line]] > $page_width} {
        global pageno

        regsub -all -- \" [string range $line $page_width end] {\"} excess
        unexpected [unex_condtype] \
            "output line $lineno (on page $pageno) has $len > $page_width characters (excess string is \"$excess\")"
    }
    if {!$unpaginated && ($lineno >= $page_head_height + $page_body_height)} {
        end_page_txt
    }
}

proc nbsp_expand_txt {s} {
    regsub -all -- "\xA0" [string trimright $s] " " s
    return $s
}

proc two_spaces {glop {flatten 0}} {
    global options
    global indent

    # Work around a bug in tcl-8.4.9 and possibly others.
    # Don't ask, it's a mystery anyway.
    set foo "x$glop"

    if {$flatten} {
        set post ""
        set glop [string trim $glop]
        regsub -all -- {[\t\n ]+} $glop { } glop
    } else {
        set post [string range $glop 0 [expr $indent -1]]
        set glop [string range $glop $indent end]
        regsub -all -- {([^ ])[\t ]+} $glop {\1 } glop
    }

    if {$options(.COLONSPACE)} {
        set re {([.?!][])'"]*|:) }
    } else {
        set re {[.?!][])'"]* }
    }

    while {[string length $glop] > 0} {
        # The double quotes will also match the end of a spanx-verb, which
        # may not be the end of a sentence.  Impossible to tell apart.  :-(
        if {![regexp -indices -- $re $glop x]} {
            append post $glop
            break
        }

        set pre [string range $glop 0 [lindex $x 1]]
        set glop [string trimleft [string range $glop [expr [lindex $x 1] + 1] end]]
        append post $pre

        # Get rid of the colon case quickly.
        if {   $options(.COLONSPACE)
            && [regexp -- {: $} $pre]} {
            append post " "
            continue
        }

        # A special case.  Author wouldn't normally put a period after that.
        if {[regexp -- {[Aa](nne|ppendi)x[ \xA0][A-Z][])'"]*[.?!][])'"]* $} $pre]} {
            append post " "
            continue
        }

        # Check for likely abbreviation.  Do not insert two spaces in
        # this case.
        # "e.g." and "i.e." are never directly followed by spaces.
        # "etc. " and "et al. " will often be the end of the sentence anyway.
        if {[regexp -expanded -- {(^|[^A-Za-z\xA0-])
                                  (  [A-Z]\.[])'"]*
                                   | (  [A-Z][a-z][a-z]
                                      | Fig | Tbl | Eq
                                      | [Cc]f | vs | resp
                                      | [JS]r | M[rs] | Messrs | Mrs | Mmes
                                      | Drs? | Profs?
                                      | Rep | Sen | Gov
                                      | St | Rev
                                      | Gen | Col | Maj | Cap | Lt)
                                     \.)
                                  \ $} $pre]} {
            continue
        }

        # Check if what follows doesn't look like the beginning of a sentence.
        if {[regexp -- {^["'([]*[^A-Z"'([]} $glop]} {
            continue
        }

        # Otherwise, we assume that we are in between two sentences.
        append post " "
    }

    return $post
}

proc pi_txt {key value} {
    global mode
    global passno

    switch -- $key {
        needLines {
            global buffer

            set x [string compare $buffer ""]
            if {![have_lines $value]} {
                end_page_$mode
            } elseif {$x && ![string compare $mode nr]} {
                # We might have flushed early, so now make it stick.
                write_it ".br"
            }
        }

        typeout {
            if {$passno == 2} {
                puts stdout $value
            }
        }

        default { error "" }
    }
}

#       }}}2 txt rendering engine
#       {{{2 html rendering engine
#           {{{3 Main html mode

# don't need to return anything even though rfc_txt does...
proc rfc_html {irefs authors iprstmt copying newP validity} {
    global options copyrightP iprP
    global funding
    global indexpg

    if {$options(.SLIDES) && [end_rfc_slides]} {
        return
    }

    if {[llength $irefs] > 0} {
        set indexpg rfc.index
        toc_html rfc.index
        write_html "<$options(.TOPTAG)>Index</$options(.TOPTAG)>"

        write_html "<table>"
        foreach iref $irefs {
            foreach {L item subitem flags pages} $iref { break }

            if {[string compare $L ""]} {
                write_html "<tr><td><strong>$L</strong></td><td>&nbsp;</td></tr>"
            }

            if {[string compare $subitem ""]} {
                if {[string compare $item ""]} {
                    write_html "<tr><td>&nbsp;</td><td>$item</td></tr>"
                }
                set key $subitem
                set t "&nbsp;&nbsp;"
            } else {
                set key $item
                set t ""
            }

            array set iflags $flags
            if {![string compare $iflags(primary) true]} {
                set key "<b>$key</b>"
            }

            if {[llength $pages] == 1} {
                set key "<a href=\"#[lindex $pages 0]\">$key</a>"
            } else {
                set i 0
                set s "  "
                foreach page $pages {
                    append key "$s<a href=\"#$page\">[incr i]</a>"
                    set s ", "
                }
            }

            write_html "<tr><td>&nbsp;</td><td>$t$key</td></tr>"
        }
        write_html "</table>"
    }

    authors_html $authors

#!# puts "html copyrightP $copyrightP"
    if {(!$options(.PRIVATE)) && $copyrightP > 0} {
        toc_html rfc.copyright

        # See comment in "proc rfc_txt" about this content.

        if {0 && $newP} {
            write_html "<$options(.TOPTAG)>Copyright Statement</$options(.TOPTAG)>"
        } else {
            write_html "<$options(.TOPTAG)>Full Copyright Statement</$options(.TOPTAG)>"
        }

        foreach para $copying {
            write_html "<p class='copyright'>"
            pcdata_html $para
            write_html "</p>"
        }

        if {$newP} {
            #write_html "<$options(.TOPTAG)>Disclaimer of Validity</$options(.TOPTAG)>"

            foreach para $validity {
                write_html "<p class='copyright'>"
                pcdata_html $para
                write_html "</p>"
            }
        }

        if {$iprP} {
            global iprurl ipremail

            write_html "<$options(.TOPTAG)>Intellectual Property</$options(.TOPTAG)>"

            regsub -all -- %IPRURL% $iprstmt "<a href='$iprurl'>$iprurl</a>" iprstmt
            if {$options(.LINKMAILTO)} {
                regsub -all -- %IPREMAIL% $iprstmt "<a href='mailto:$ipremail'>$ipremail</a>" iprstmt
            } else {
                regsub -all -- %IPREMAIL% $iprstmt $ipremail iprstmt
            }

            foreach para $iprstmt {
                write_html "<p class='copyright'>"
                pcdata_html $para
                write_html "</p>"
            }
        }

        if {$options(.RFCEDSTYLE)} {
            set ack "Acknowledgement"
        } else {
            set ack "Acknowledgment"
        }
        set acks 0
        if {[string length $funding]} {
            incr acks 1
        }
        if {$options(.RFCPROCACK)} {
            incr acks 1
        }
        if {$acks > 1} {
            append ack s
        }
        if {$acks} {
            write_html "<$options(.TOPTAG)>$ack</$options(.TOPTAG)>"
            write_html "<p class='copyright'>"
        }
        if {[string length $funding]} {
            pcdata_html $funding
        }
        if {$options(.RFCPROCACK)} {
            global prog_ack prog_url

            regsub -all -- %PROGURL% $prog_ack \
                   "<a href='$prog_url'>$prog_url</a>" xml2rfc_ack
            if {[string length $funding]} {
                pcdata_html "  "
            }
            pcdata_html $xml2rfc_ack
        }
        if {$acks} {
            write_html "</p>"
        }
    }

    write_html "</body></html>"

    return ""
}

#               {{{4 CSS style-sheet
global htmlstyle

set htmlstyle \
"<style type='text/css'><!--
        body {
                font-family: verdana, charcoal, helvetica, arial, sans-serif;
                font-size: small; color: #000; background-color: #FFF;
                margin: 2em;
        }
        h1, h2, h3, h4, h5, h6 {
                font-family: helvetica, monaco, \"MS Sans Serif\", arial, sans-serif;
                font-weight: bold; font-style: normal;
        }
        h1 { color: #900; background-color: transparent; text-align: right; }
        h3 { color: #333; background-color: transparent; }

        td.RFCbug {
                font-size: x-small; text-decoration: none;
                width: 30px; height: 30px; padding-top: 2px;
                text-align: justify; vertical-align: middle;
                background-color: #000;
        }
        td.RFCbug span.RFC {
                font-family: monaco, charcoal, geneva, \"MS Sans Serif\", helvetica, verdana, sans-serif;
                font-weight: bold; color: #666;
        }
        td.RFCbug span.hotText {
                font-family: charcoal, monaco, geneva, \"MS Sans Serif\", helvetica, verdana, sans-serif;
                font-weight: normal; text-align: center; color: #FFF;
        }

        table.TOCbug { width: 30px; height: 15px; }
        td.TOCbug {
                text-align: center; width: 30px; height: 15px;
                color: #FFF; background-color: #900;
        }
        td.TOCbug a {
                font-family: monaco, charcoal, geneva, \"MS Sans Serif\", helvetica, sans-serif;
                font-weight: bold; font-size: x-small; text-decoration: none;
                color: #FFF; background-color: transparent;
        }

        td.header {
                font-family: arial, helvetica, sans-serif; font-size: x-small;
                vertical-align: top; width: 33%;
                color: #FFF; background-color: #666;
        }
        td.author { font-weight: bold; font-size: x-small; margin-left: 4em; }
        td.author-text { font-size: x-small; }

        /* info code from SantaKlauss at http://www.madaboutstyle.com/tooltip2.html */
        a.info {
                /* This is the key. */
                position: relative;
                z-index: 24;
                text-decoration: none;
        }
        a.info:hover {
                z-index: 25;
                color: #FFF; background-color: #900;
        }
        a.info span { display: none; }
        a.info:hover span.info {
                /* The span will display just on :hover state. */
                display: block;
                position: absolute;
                font-size: smaller;
                top: 2em; left: -5em; width: 15em;
                padding: 2px; border: 1px solid #333;
                color: #900; background-color: #EEE;
                text-align: left;
        }

        a { font-weight: bold; }
        a:link    { color: #900; background-color: transparent; }
        a:visited { color: #633; background-color: transparent; }
        a:active  { color: #633; background-color: transparent; }

        p { margin-left: 2em; margin-right: 2em; }
        p.copyright { font-size: x-small; }
        p.toc { font-size: small; font-weight: bold; margin-left: 3em; }
        table.toc { margin: 0 0 0 3em; padding: 0; border: 0; vertical-align: text-top; }
        td.toc { font-size: small; font-weight: bold; vertical-align: text-top; }

        ol.text { margin-left: 2em; margin-right: 2em; }
        ul.text { margin-left: 2em; margin-right: 2em; }
        li      { margin-left: 3em; }

        /* RFC-2629 <spanx>s and <artwork>s. */
        em     { font-style: italic; }
        strong { font-weight: bold; }
        dfn    { font-weight: bold; font-style: normal; }
        cite   { font-weight: normal; font-style: normal; }
        tt     { color: #036; }
        tt, pre, pre dfn, pre em, pre cite, pre span {
                font-family: \"Courier New\", Courier, monospace; font-size: small;
        }
        pre {
                text-align: left; padding: 4px;
                color: #000; background-color: #CCC;
        }
        pre dfn  { color: #900; }
        pre em   { color: #66F; background-color: #FFC; font-weight: normal; }
        pre .key { color: #33C; font-weight: bold; }
        pre .id  { color: #900; }
        pre .str { color: #000; background-color: #CFF; }
        pre .val { color: #066; }
        pre .rep { color: #909; }
        pre .oth { color: #000; background-color: #FCF; }
        pre .err { background-color: #FCC; }

        /* RFC-2629 <texttable>s. */
        table.all, table.full, table.headers, table.none {
                font-size: small; text-align: center; border-width: 2px;
                vertical-align: top; border-collapse: collapse;
        }
        table.all, table.full { border-style: solid; border-color: black; }
        table.headers, table.none { border-style: none; }
        th {
                font-weight: bold; border-color: black;
                border-width: 2px 2px 3px 2px;
        }
        table.all th, table.full th { border-style: solid; }
        table.headers th { border-style: none none solid none; }
        table.none th { border-style: none; }
        table.all td {
                border-style: solid; border-color: #333;
                border-width: 1px 2px;
        }
        table.full td, table.headers td, table.none td { border-style: none; }

        hr { height: 1px; }
        hr.insert {
                width: 80%; border-style: none; border-width: 0;
                color: #CCC; background-color: #CCC;
        }
--></style>"
#               }}}4 CSS style-sheet

proc front_html_begin {left right top bottom title keywords lang} {
    global prog prog_version prog_url
    global options copyrightP
    global htmlstyle
    global doingP hangP needP
    global imgP
    global indexpg authorspg

    set doingP 0
    set hangP 0
    set needP 0
    set imgP 0

    if {$options(.SLIDES) \
            && [front_slides_begin $left $right $top $bottom $title]} {
        return
    }

    set indexpg rfc.index
    set authorspg rfc.authors

    write_html "<\!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">"
    write_html -nonewline "<html lang=\"$lang\"><head><title>"
    if {($options(.PRIVATE)) \
            && ([string compare [string trim $options(private)] ""])} {
        pcdata_html "$options(private): "
    }
    pcdata_html [lindex $title 0]
    write_html "</title>"

    # Begin new meta tags.
    write_html "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">"
    write_html -nonewline "<meta name=\"description\" content=\""
    regsub -all -- \" [lindex $title 0] {\&quot;} t0
    pcdata_html $t0
    write_html "\">"

    # Write out meta tag with keywords if they exist.
    if {[llength $keywords] > 0} {
        write_html -nonewline "<meta name=\"keywords\" content=\""
        set s ""
        foreach kw $keywords {
            pcdata_html $s$kw
            set s ", "
        }
        write_html "\">"
    }

     write_html -nonewline "<meta name=\"generator\" content=\"$prog $prog_version "
     write_html "($prog_url)\">"
    # End new meta tags.

    write_html "$htmlstyle\n</head>"
    write_html -nonewline "<body"
    if {[string compare $options(background) ""]} {
        write_html -nonewline " background=\"$options(background)\""
    }
    write_html ">"

    xxxx_html

    if {$options(.TOPBLOCK)} {
        write_html "<table summary=\"layout\" width=\"66%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\"><tr><td><table summary=\"layout\" width=\"100%\" border=\"0\" cellpadding=\"2\" cellspacing=\"1\">"
        set left [munge_long $left 1]
        set right [munge_long $right 0]
        set lc ""
        set rc ""
        foreach l $left r $right {
            if {[string compare $l ""]} {
                set l $l
            } else {
                set l "&nbsp;"
            }
            if {[string compare $r ""]} {
                set r $r
            } else {
                set r "&nbsp;"
            }
            write_html "<tr><td class=\"header\">$l</td><td class=\"header\">$r</td></tr>"
        }
        write_html "</table></td></tr></table>"
    }

    write_html -nonewline "<h1>"
    foreach line $title {
        write_html -nonewline "<br />"
        pcdata_html $line
    }
    write_html "</h1>"
}

proc write_status_html {status copying afterP} {
    global options copyrightP iprP

    if {!$options(.PRIVATE)} {
        write_html ""
        if {$options(.RFCEDSTYLE)} {
            write_html "<$options(.TOPTAG)>Status of This Memo</$options(.TOPTAG)>"
        } else {
            write_html "<$options(.TOPTAG)>Status of this Memo</$options(.TOPTAG)>"
        }
        foreach para $status {
            write_html "<p>"
            pcdata_html $para
            write_html "</p>"
        }
    }

    if {(!$options(.PRIVATE)) && $copyrightP && [string length $copying]} {
        write_html ""
        write_html "<$options(.TOPTAG)>Copyright Notice</$options(.TOPTAG)>"
        foreach para $copying {
            write_html "<p>"
            pcdata_html $para
            write_html "</p>"
        }
    }
}

proc front_html_end {toc} {
    global options

    if {!$options(.TOC)} {
        return
    }

    xxxx_html toc

    write_html "<$options(.TOPTAG)>Table of Contents</$options(.TOPTAG)>"
    if {$options(.TOCNARROW)} {
        write_html "<p class=\"toc\">"
    } else {
        write_html "<table class=\"toc\">"
    }
    set z 0
    foreach c $toc {
        set label [lindex $c 1]
        if {   !$options(.TOCOMPACT)
            && [lindex $c 0] <= 0} {
            set z1 [expr [string compare $label "&#167;"] ? 1 : 2]
            if {$z && ($z == 1 || $z1 == 1)} {
                if {$options(.TOCNARROW)} {
                    write_html "<br />"
                } else {
                    write_html "<tr><td class=\"toc\">&nbsp;</td></tr>"
                }
            }
            set z $z1
        }
        if {!$options(.TOCNARROW)} {
            write_html -nonewline "<tr><td class=\"toc\">"
        }
        set x [lindex $c 0]
        if {$options(.TOCINDENT)} {
            while {$x > 0} {
                if {$options(.TOCNARROW)} {
                    write_html -nonewline "&nbsp;&nbsp;&nbsp;&nbsp;"
                } else {
                    write_html -nonewline "</td><td class=\"toc\">"
                }
                incr x -1
            }
        }
        if {$x < 0 && $options(.TOCAPPENDIX)} {
            set label "Appendix&nbsp;$label"
        }
        write_html -nonewline "<a href=\"#[lindex $c 3]\">"
        pcdata_html $label
        write_html "</a>&nbsp;"
        if {!$options(.TOCNARROW)} {
            write_html -nonewline "</td><td class=\"toc\" colspan=\"[expr $options(.TOCDEPTH) - [lindex $c 0]]\">"
        }
        pcdata_html [lindex $c 2]
        if {$options(.TOCNARROW)} {
            write_html "<br />"
        } else {
            write_html "</td></tr>"
        }
    }
    if {$options(.TOCNARROW)} {
        write_html "</p>"
    } else {
        write_html "</table>"
    }
    write_html "<br clear=\"all\" />"
}

proc abstract_html {} {
    global options

    if {$options(.SLIDES) && [end_page_slides]} {
        start_page_slides Abstract
    } else {
        write_html ""
        write_html "<$options(.TOPTAG)>Abstract</$options(.TOPTAG)>"
    }
}

proc note_html {title depth} {
    global options

    if {$options(.SLIDES) && [end_page_slides]} {
        start_page_slides $title
    } else {
        incr depth 3

        write_html ""
        write_html -nonewline "<h$depth>"
        pcdata_html $title
        write_html "</h$depth>"
    }
}

proc section_html {prefix top title {lines 0} anchor} {
    global options

    if {$options(.SLIDES) && [end_page_slides]} {
        start_page_slides $title

        return $anchor
    }

    set anchor2 [string trimright $prefix .]
    if {[string first "Appendix " $anchor2] == 0} {
        set anchor2 [string range $anchor2 9 end]
    }
    set anchor2 rfc.section.$anchor2

    if {$options(.DOCMAPPING)} {
        if {[set x [expr [llength [split $prefix .]]-1]] \
                > $options(.TOCDEPTH)} {
            set x $options(.TOCDEPTH)
        }
        set htag "h$x"
    } elseif {[string match *. $prefix]} {
        set htag "h3"
    } else {
        set htag "h4"
    }
    write_html ""
    if {[string match *. $prefix]} {
        toc_html $anchor
        write_html -nonewline "<a name=\"$anchor2\"></a>"
        write_html "<$htag>$prefix&nbsp;"
        pcdata_html $title
        write_html "</$htag>"
    } else {
        write_html -nonewline "<a name=\"$anchor2\"></a>"
        write_html "<$htag><a name=\"$anchor\">$prefix</a>&nbsp;"
        pcdata_html $title
        write_html "</$htag>"
    }

    return $anchor
}

proc t_html {tag counter style hangText editNo} {
    global options
    global doingP hangP needP

    if {[string compare $tag begin]} {
        set s /
        set needP 0
    } else {
        set s ""
    }
    write_html ""
    if {![string compare $style "hanging"]} {
        if {![string compare $tag begin]} {
            write_html "<dt>$hangText</dt>"
        }
        write_html -nonewline "<${s}dd>"

        set hangP 1
    } elseif {![string compare $style "letters"]} {
        if {![string compare $tag begin]} {
            set l [split $counter .]
            write_html "<dt>[offset2letters [lindex $l end] [llength $l]].</dt>"
        }
        write_html -nonewline "<${s}dd>"

        set hangP 1
    } elseif {([string compare $counter ""]) \
                    && ([string compare $style empty])} {
        write_html -nonewline "<${s}li>"

        set hangP 0
    } else {
        set sta ""
        if {[string compare $tag end]} {
            set doingP 1
            switch -- [set a [current_align]] {
                left - center - right {
                   set sta " style='text-align: $a'"
                }
            }
        }
        if {$doingP} {
            set doingP [string compare $tag end]
            write_html -nonewline "<${s}p${sta}>"
        }

        set hangP 0
    }
    if {$options(.EDITING) \
            && (![string compare $tag begin]) \
            && ([string compare $editNo ""])} {
        write_html -nonewline "<sup><small>$editNo</small></sup>"
    }
}

proc list_html {tag min max style hangIndent longestHangText suprT} {
    global doingP hangP needP

    if {[string compare $tag begin]} {
        set s /
        set c ""
    } else {
        set s ""
        set c " class=\"text\""
        if {$doingP} {
            write_html -nonewline "</p>"
            set doingP 0
        }
    }
    write_html ""
    switch -- $style {
        letters - hanging - format {
            if {[string compare $tag begin]} {
                write_html -nonewline "</dl></blockquote>"
            } else {
                write_html -nonewline "<blockquote$c><dl>"
            }
        }

        numbers { write_html -nonewline "<${s}ol$c>" }
        symbols { write_html -nonewline "<${s}ul$c>" }
        default { write_html -nonewline "<${s}blockquote$c>" }
    }

    if {($suprT >= 0) && ([string compare $tag begin])} {
        set needP 1
    }
    set hangP 0
}

proc figure_html {tag lines anchor title av {suppressP 0}} {
    global xref

    set hr {<hr class="insert" />}
    switch -- $tag {
        begin {
            if {[string compare $title ""] || [string compare $anchor ""]} {
                write_html "<br />$hr"
            }
            if {[string compare $anchor ""]} {
                write_html "<a name=\"$anchor\"></a>"
            }
            img_html begin 1 $av
        }

        end {
            img_html end 1 $av
            if {[string compare $anchor ""]} {
                array set av2 $xref($anchor)
                set prefix "Figure&nbsp;$av2(value)"
                if {[string compare $title ""]} {
                    set title "$prefix: $title"
                } elseif {!$suppressP} {
                    set title $prefix
                }
            }
            if {[string compare $title ""]} {
                #switch -- [set a [current_align]] {
                #    left - center - right { set al " align=\"$a\"" }
                #    default { set al "" }
                #}
                set al " align=\"center\""
                write_html "<table border=\"0\" cellpadding=\"0\" cellspacing=\"2\"$al><tr><td align=\"center\"><font face=\"monaco, MS Sans Serif\" size=\"1\"><b>&nbsp;$title&nbsp;</b></font><br /></td></tr></table>$hr"
            }
        }
    }
}

proc artwork_html {tag lines {av {}} } {
    img_html $tag 2 $av
}

proc img_html {tag bit {av {}} } {
    global imgP
    global options

    if {[set x [lsearch -exact $av src]] < 0 || $x & 1} {
        return
    }

    switch -- $tag {
        begin {
            if {$imgP} {
                return
            }
            set line "<div"
            set attrs ""
            set seen_alt 0
            foreach {k v} $av {
                # "name": file name to use for storing the content.
                # "type": not a MIME type; e.g., "abnf".
                regsub -all -- \" $v {\&quot;} v
                switch -- $k {
                    width - height {
                        append attrs " $k=\"$v\""
                    }

                    src {
                        if {$options(.USEOBJECT)} {
                            append attrs " data=\"$v\""
                        } else {
                            append attrs " src=\"$v\""
                        }
                    }

                    alt {
                        if {!$options(.USEOBJECT)} {
                            append attrs " alt=\"$v\""
                            set seen_alt 1
                        }
                    }

                    align {
                        regsub -- {[-+][0-9]+em$} $v "" vv
                        switch -- $vv {
                            left - center - right {
                                append line " style='text-align: $vv'"
                            }

                            default {
                                unexpected error \
                                    "align=\"$v\" attribute is invalid"
                            }
                        }
                    }
                }
            }
            if {$options(.USEOBJECT)} {
                append line "><object"
            } else {
                append line "><img"
            }
            append line $attrs
            if {$options(.USEOBJECT)} {
                append line ">"
            } else {
                if {!$seen_alt} {
                    if {$options(.STRICT)} {
                        unexpected error \
                            "use of the \"src\" attribute in img graphics also requires \"alt\" attribute"
                    } else {
                        unexpected warning \
                            "also showing text content for img graphics with \"src\" but not \"alt\" attribute"
                        append line { alt="[graphic image equivalent to the textual content below]"}
                    }
                } else {
                    set imgP [expr $imgP | $bit]
                }
                append line " /></div>"
            }
            write_html $line
        }

        end {
            if {[set imgP [expr $imgP & ~$bit]]} {
                return
            }
            set line ""
            if {$options(.USEOBJECT)} {
                append line "</object>"
            }
            append line "</div>"
            write_html $line
        }
    }
}

proc preamble_html {tag {editNo ""}} {
    t_html $tag "" "" "" $editNo
}

proc postamble_html {tag {editNo ""}} {
    t_html $tag "" "" "" $editNo
}

proc texttable_html {tag lines anchor title {suppressP 0}} {
    global xref

    set hr {<hr class="insert" />}
    switch -- $tag {
        begin {
            if {[string compare $title ""] || [string compare $anchor ""]} {
                write_html "<br />$hr"
            }
            if {[string compare $anchor ""]} {
                write_html "<a name=\"$anchor\"></a>"
            }
        }

        end {
            if {[string compare $anchor ""]} {
                array set av $xref($anchor)
                set prefix "Table $av(value)"
                if {[string compare $title ""]} {
                    set title "$prefix: $title"
                } elseif {!$suppressP} {
                    set title $prefix
                }
            }
            if {[string compare $title ""]} {
                #switch -- [set a [current_align]] {
                #    left - center - right { set al " align=\"$a\"" }
                #    default { set al "" }
                #}
                set al " align=\"center\""
                write_html "<table border=\"0\" cellpadding=\"0\" cellspacing=\"2\"$al><tr><td align=\"center\"><font face=\"monaco, MS Sans Serif\" size=\"1\"><b>&nbsp;$title&nbsp;</b></font><br /></td></tr></table>$hr"
            }
        }
    }
    return [list 0 {}]
}

proc ttcol_html {text align col width cwidth} {
    global cellR
    global ttcol_html_cols ttcol_html_colsP ttcol_html_head ttcol_html_headP

    if {[set x [lindex $col 0]] == 1} {
        switch -- [set a [current_align]] {
            left - center - right { set al " align=\"$a\"" }
            default { set al "" }
        }
        write_html "<table class=\"$cellR\"$al border=\"0\" cellpadding=\"2\" cellspacing=\"2\">"

        # This assumes that <texttable>s cannot nest.
        set ttcol_html_cols ""
        set ttcol_html_colsP 0
        set ttcol_html_head ""
        set ttcol_html_headP 0
    }
    if {$x == 1} {
        append ttcol_html_head "<tr>"
    }
    set text [pcdata_html $text 0 1]
    if {[string compare [string trim $text] ""]} {
        set ttcol_html_headP 1
    }
    set attrs ""
    if {[string compare $align ""]} {
        append attrs " align=\"$align\""
    }
    # We shouldn't have to add an align attribute to <th> since it's
    # already in <col>, but Mozilla isn't standards-compliant.
    append ttcol_html_head "<th$attrs>$text</th>"
    if {[string compare $width ""]} {
        # We interpret our em to be a width (one character large).
        # CSS1, however, supports both em and ex but interprets
        # them both as _heights_ relative to the current font size
        # (full height and height of the letter x, respectively).
        # CSS2 is more normal.
        # There is no such thing as a CSS en.
        # Using a CSS em is usually too large, but using a CSS ex
        # is usually too narrow; what else to do?

        switch -regexp -- $width {
            {^0+$}       { set attr " width=\"0\"" }
            {^[0-9]+%$}  { set attr " width=\"$width\"" }
            {^[0-9]*\*$} { set attr " width=\"$width\"" }
            {^[0-9]+em$} { set attr " style=\"width: $width\"" }
            default      { set attr "" }
        }
        append attrs $attr
    }
    append ttcol_html_cols "<col$attrs>"
    if {[string compare $attrs ""]} {
        set ttcol_html_colsP 1
    }
    if {$x == [lindex $col 1]} {
        if {$ttcol_html_colsP} {
            write_html $ttcol_html_cols
        }
        append ttcol_html_head "</tr>"
        if {$ttcol_html_headP} {
            write_html $ttcol_html_head
        }
    }
}

proc c_html {tag row col align width} {
    global emptyP

    switch -- $tag {
        begin {
            if {[lindex $col 0] == 1} {
                write_html "<tr>"
            }
            set attrs ""
            if {[string compare $align ""]} {
                append attrs " align=\"$align\""
            }
            # We shouldn't have to add an align attribute to <td> since it's
            # already in <col>, but Mozilla isn't standards-compliant.
            write_html -nonewline "<td$attrs>"
            set emptyP 1
        }

        end {
            if {$emptyP} {
                write_html -nonewline "&nbsp;"
            }
            write_html "</td>"
            if {[lindex $col 0] == [lindex $col 1]} {
                write_html "</tr>"
                if {[lindex $row 0] == [lindex $row 1]} {
                    write_html "</table>"
                    write_html "<br clear=\"all\" />"
                }
            }
        }
    }
}

proc xref_html {text av target format {hackP 0}} {
    global elem
    global options

    array set attrs $av

    set elemY $attrs(elemN)
    array set tv [list title ""]
    array set tv $elem($elemY)

    # Turn any hyphens in value into non-breaking hyphens.
    regsub -all -- "-" $attrs(value) {\&#8209;} attrs(value)

    set title ""
    switch -- $attrs(type) {
        section {
            set line "Section&nbsp;$attrs(value)"
            set title [section_title $elemY]
        }

        appendix {
            set line "Appendix&nbsp;$attrs(value)"
            set title [section_title $elemY]
        }

        figure {
            set line "Figure&nbsp;$attrs(value)"
            set title [section_title $elemY]
        }

        texttable {
            set line "Table&nbsp;$attrs(value)"
            set title [section_title $elemY]
        }

        cref {
            set line "Comment&nbsp;$attrs(value)"
            set title [cref_title $elemY]
        }

        t {
            set line "Paragraph&nbsp;$attrs(value)"
            set title ""
        }

        reference {
            set line "\[$attrs(value)\]"

            set s ""
            set nameA 1
            set nameN [llength [set names [ref_names $elemY]]]
            foreach name $names {
                incr nameA
                set name [lindex $name 0]
                append title $s$name
                set s [list_sep_str $nameA $nameN]
            }
            append title ", &ldquo;[ref_title $elemY],&rdquo; [ref_date $elemY]."
        }

        default {
            set line "\[$attrs(value)\]"
        }
    }
    regsub -all -- \"   $title {\&quot;} title
    regsub -all -- "\r" $title { }       title
    regsub -all -- "\n" $title { }       title
    #set title " title=\"$title\""

    if {![string compare $format none]} {
        if {![string compare $text ""]} {
            return
        }
    } elseif {![string compare $text ""]} {
        switch -- $format {
            counter { set text $attrs(value) }
            title   { set text $tv(title)    }
            default { }
        }
    } elseif {$options(.EMOTICONIC)} {
        set text [emoticonic_html $text]
    }

    set post ""
    if {[string compare $text ""]} {
        switch -- $attrs(type) {
            section - appendix - figure - texttable {}

            default {
                if {![string compare $format default]} {
                    set post " $line"
                }
            }
        }
    } else {
        set text $line
    }

    #set line "<a href=\"#$target\"$title>$text</a>$post"
    set line "<a class='info' href='#$target'>$text"
    if {[string compare $title ""]} {
        append line "<span> (</span><span class='info'>$title</span><span>)</span>"
    }
    append line "</a>$post"

    if {$hackP} {
        return $line
    }
    if {![cellP $line]} {
        global emptyP

        write_html -nonewline $line
        set emptyP 0
    }
}

proc eref_html {text counter target} {
    global options

    if {![string compare $text ""]} {
        set text $target
    } elseif {$options(.EMOTICONIC)} {
        set text [emoticonic_html $text]
    }

    set line "<a href='$target'>$text</a>"
    if {![cellP $line]} {
        global emptyP

        write_html -nonewline $line
        set emptyP 0
    }
}

proc cref_html {text counter source anchor} {
    global crefs

    set comments ""
    if {[string compare $source ""]} {
        set comments "${source}: "
    }
    append comments $text
    set crefs($counter) [list $anchor $source $text $comments]

    regsub -all -- \"   $comments {\&quot;} comments
    regsub -all -- "\r" $comments { }       comments
    regsub -all -- "\n" $comments { }       comments

    #set line "<a href='#comment.$counter' title='$comments'>\[$counter\]</a>"
    set line "<a class='info' href='#comment.$counter'>\[$counter\]<span> (</span><span class='info'>$comments</span><span>)</span></a>"
    append line "<a name='$anchor'></a>"

    if {![cellP $line]} {
        global emptyP

        write_html -nonewline $line
        set emptyP 0
    }
}

proc iref_html {item subitem flags} {
    global anchorN

    set anchor anchor[incr anchorN]

    write_html -nonewline "<a name='$anchor'></a>"

    return $anchor
}

proc vspace_html {lines} {
    global options
    global hangP

    if {$lines > 5} {
        if {$options(.SLIDES) && [end_page_slides]} {
            start_page_slides
        }

        return
    }
    incr lines [expr -($hangP)]
    while {$lines >= 0} {
        incr lines -1
        write_html "<br />"
    }

    set hangP 0
}

proc spanx_html {text style} {
    set p 1
    switch -- $style {
        verb
        - vbare { set e tt              }
        vemph   { set e {tt em}         }
        vstrong { set e {tt strong}     }
        vdeluxe { set e {tt strong em}  }
        emph    { set e em;     set p 0 }
        strong  { set e strong; set p 0 }
        default { set e {};     set p 0 }
    }
    #if {$p} {
    #    regsub -all -- { } $text {\&nbsp;} text
    #}

    set s ""
    set t ""
    foreach x $e {
        append s "<$x>"
        set    t "</$x>$t"
    }

    write_html -nonewline "$s$text$t"
}

# Don't need to return anything even though txt/nr versions do...

proc references_html {tag args} {
    global counter depth
    global options

    if {$options(.SLIDES) \
            && (![string compare $tag begin]) \
            && [end_page_slides]} {
        start_page_slides $options(refparent)
        return
    }

    switch -- $tag {
        begin {
            set prefix [lindex $args 0]
            set title  [lindex $args 1]
            if {($depth(references) > 1) \
                    && (![info exists counter(references)])} {
                set counter(references) 0
                section_html [lindex [split $prefix .] 0]. 1 \
                             $options(refparent) 0 rfc.references
            }

            write_html ""
            if {![info exists counter(references)]} {
                set suffix 1
            } else {
                set suffix [incr counter(references)]
            }
            toc_html rfc.references$suffix
            write_html -nonewline "<$options(.TOPTAG)>$prefix&nbsp;"
            pcdata_html $title
            write_html "</$options(.TOPTAG)>"

            write_html "<table width=\"99%\" border=\"0\">"
        }

        end {
            write_html "</table>"
        }
    }
}

proc reference_html {prefix names title series formats date anchor target
                     target2 width annotations} {
    global options
    global rfcTxtHome rfcHtmlHome idTxtHome idHtmlHome

    if {[string compare $target2 ""]} {
        set prefix "<a href=\"$target2\">$prefix</a>"
    }
    if {[string compare $anchor ""]} {
        set prefix "<a name=\"$anchor\">\[$prefix\]</a>"
    }
    write_html "<tr><td class=\"author-text\" valign=\"top\">$prefix</td>"

    set text ""

    set s ""
    set nameA 1
    set nameN [llength $names]
    foreach name $names {
        incr nameA
        if {[string compare [set eref [lindex $name 1]] ""]} {
            set name "<a href=\"$eref\">[lindex $name 0]</a>"
        } else {
            set name [lindex $name 0]
        }
        append text $s$name
        set s [list_sep_str $nameA $nameN]
    }

    if {![string compare $target ""]} {
        foreach serial $series {
            if {[regexp -nocase -- "rfc&nbsp;(\[0-9\]*)" $serial x n] == 1} {
#               set target $rfcTxtHome/rfc$n.txt
                set target $rfcHtmlHome/rfc$n
                break
            }
            if {[regexp -nocase -- "internet-draft&nbsp;(draft-.*)" $serial x n] \
                    == 1} {
#                set target $idTxtHome/$n.txt
                set target $idHtmlHome/$n
                break
            }
        }
    }
    if {(![string compare $target ""]) && ([llength $formats] == 1)} {
        array set fv [lindex $formats 0]
        if {[info exists fv(target)]} {
            set target $fv(target)
            set formats {}
        }
    }

    if {[string compare $target ""]} {
        set title "<a href=\"$target\">$title</a>"
    }
    append text "$s&ldquo;$title"
    set r "&rdquo;"
    foreach serial $series {
        if {$options(.NOTEDRAFTINPROGRESS)} {
          if {[regexp -nocase -- "internet-draft&nbsp;(draft-.*)" $serial x n] == 1} {
              set serial "$n (work in progress)"
          }
        }
        append text ",$r $serial"
        set r ""
    }
    if {[string compare $date ""]} {
        append text ",$r $date"
        set r ""
    }

    set s "$r ("
    set t ".$r"
    foreach format $formats {
        catch { array unset fv }
        array set fv $format
        if {[info exists fv(target)]} {
            append text "$s<a href=\"$fv(target)\">$fv(type)</a>"
            set s ", "
            set t ")."
        }
    }
    append text $t

    write_html -nonewline "<td class=\"author-text\">"
    pcdata_html $text

    while {[llength $annotations] > 0} {
        write_html "<p>"
        write_html [lindex $annotations 0]
        write_html "</p>"
        set annotations [lrange $annotations 1 end]
    }

    write_html "</td></tr>"
}

proc crefs_html {title} {
    global crefs
    global options

    write_html ""
    toc_html rfc.comments
    write_html -nonewline "<$options(.TOPTAG)>"
    pcdata_html $title
    write_html "</$options(.TOPTAG)>"

    write_html "<table border=\"0\">"

    set names [lsort -dictionary [array names crefs]]
    foreach cref $names {
        write_html "<tr><td class=\"author-text\" valign=\"top\">"
        #write_html "<a href=\"#[lindex $crefs($cref) 0]\" title=\"$cref\">"
        #pcdata_html [lindex $crefs($cref) 1]
        #write_html "</a><a name=\"comment.$cref\"></a>:"
        #write_html "</td><td class=\"author-text\">"
        write_html "<a class=\"info\" href=\"#[lindex $crefs($cref) 0]\">"
        write_html "$cref</a><a name=\"comment.$cref\"></a>:"
        write_html "</td><td class=\"author-text\">"
        if {[string compare [set source [lindex $crefs($cref) 1]] ""]} {
            write_html -nonewline "${source}: "
        }
        pcdata_html [lindex $crefs($cref) 2]
        write_html "</td></tr>"
    }

    write_html "</table>"
}

proc annotation_html {tag} {
    annotation_txt $tag
}

proc authors_html {authors} {
    global contacts
    global options
    global authorspg

    set authorspg rfc.authors

    if {!$options(.AUTHORSHIP)} {
        return
    }
    switch -- [llength $authors] {
        0       { return }
        1       { set s1 "'s"; set s2 ""   }
        default { set s1 "s'"; set s2 "es" }
    }
    write_html ""

    toc_html rfc.authors
    write_html "<$options(.TOPTAG)>Author$s1 Address$s2</$options(.TOPTAG)>"

    write_html \
         "<table width=\"99%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\">"
    set s ""
    foreach author $authors {
        set block1 [lindex $author 0]
        set block2 [lindex $author 1]

        if {[string compare $s ""]} {
            write_html $s
        }
        foreach line $block1 {
            write_html "<tr><td class=\"author-text\">&nbsp;</td>"
            write_html "<td class=\"author-text\">$line</td></tr>"
        }
        foreach contact $block2 {
            set key [lindex $contact 0]
            set value [lindex [lindex $contacts \
                                      [lsearch0 $contacts $key]] 1]
            if {$options(.RFCEDSTYLE) && ![string compare $key email]} {
                regsub -- m $value M value
            }
            write_html "<tr><td class=\"author\" align=\"right\">$value:&nbsp;</td>"
            set value [lindex $contact 1]
            switch -- $key {
                email {
                    if {$options(.LINKMAILTO)} {
                        set value "<a href=\"mailto:$value\">$value</a>"
                    }
                }

                uri {
                    set value "<a href=\"$value\">$value</a>"
                }
            }
            write_html "<td class=\"author-text\">$value</td></tr>"
        }
        set s "<tr cellpadding=\"3\"><td>&nbsp;</td><td>&nbsp;</td></tr>"
    }
    write_html "</table>"
}

proc back_html {} {
}

proc xxxx_html {{anchor {}} } {
    global elem
    global options

    if {$options(.PRIVATE)} {
        toc_html $anchor
        return
    } else {
        array set rv $elem(1)
        if {![string compare [set number $rv(number)] ""]} {
            toc_html $anchor
            return
        }
    }

    if {[string compare $anchor ""]} {
        write_html "<a name=\"$anchor\"></a><hr />"
    }

    write_html "
<table border=\"0\" cellpadding=\"0\" cellspacing=\"2\" width=\"30\" align=\"right\">
    <tr>
        <td class=\"RFCbug\">
                <span class=\"RFC\">&nbsp;RFC&nbsp;</span><br /><span class=\"hotText\">&nbsp;$number&nbsp;</span>
        </td>
    </tr>"

    if {$options(.TOC)} {
        write_html "    <tr><td class=\"TOCbug\"><a href=\"#toc\">&nbsp;TOC&nbsp;</a><br /></td></tr>"
    }
    write_html "</table>"
}

proc toc_html {anchor} {
    global options

    if {[string compare $anchor ""]} {
        write_html "<a name=\"$anchor\"></a><br /><hr />"
    }

    if {!$options(.TOC)} {
        return
    }

    if {[string compare $anchor toc]} {
        write_html "<table summary=\"layout\" cellpadding=\"0\" cellspacing=\"2\" class=\"TOCbug\" align=\"right\"><tr><td class=\"TOCbug\"><a href=\"#toc\">&nbsp;TOC&nbsp;</a></td></tr></table>"
    }
}

proc pcdata_html {text {pre 0} {nowrite 0} {spans {}} {divs {}} } {
    global options
    global doingP needP
    global imgP

    if {$imgP} {
        return
    }

    # Do colorization first because spans are indexed from the original text.
    if {[llength $spans] > 0} {
        set data $text
        set text ""
        set pos 0

        foreach span $spans {
            foreach {t p l} $span {break}
            if {$pos < $p} {
                append text [html_quote [string range $data $pos [expr $p - 1]]]
            } elseif {$pos >= $p + $l} {
                continue
            } elseif {$pos > $p} {
                incr l [expr $p - $pos]
                set p $pos
            }
            set pos [expr $p + $l]
            if {$l > 0} {
                switch -- $t {
                    def      { set e dfn }
                    com      { set e em }
                    key - id { set e cite; set c $t }
                    default  { set e span; set c $t }
                }
                set spn "<$e"
                if {[info exists c]} {
                    append spn " class='$c'"
                    unset c
                }
                append spn ">"
                append spn [html_quote [string range $data $p [expr $pos - 1]]]
                append spn "</$e>"
                append text $spn
            }
        }
        append text [html_quote [string range $data $pos end]]
    } elseif {[llength $divs] > 0} {
        set text [html_quote $text]
    }

    set lines ""

    regsub -all -nocase -- {&apos;} $text {\&#039;} text
    set text [html_expand $text]
    if {$pre} {
        set needP 0
        regsub -line -all -- {[ \t]*$} $text "" text
        if {![slide_pre $text]} {
            if {$doingP} {
                append lines "</p>\n"
            }
            append lines [pre_tag_html begin]
            append lines $text
            append lines [pre_tag_html end]
            if {$doingP} {
                append lines "<p>\n"
            }
        }
    } else {
        if {$options(.EMOTICONIC)} {
            set text [emoticonic_html $text]
        }

        append lines $text
    }
    if {$nowrite} {
        return $lines
    }
    if {![cellP $lines]} {
        global emptyP

        if {$needP} {
            set doingP 1
            set needP 0
            write_html -nonewline "<p>"
        }
        write_html -nonewline $lines
        set emptyP 0
    }
}

proc emoticonic_html {text} {
    foreach {ei begin end} [list *  <strong> </strong> \
                                 '  <b>      </b>      \
                                {"} <b>      </b>] {
        set body ""
        while {[set x [string first "|$ei" $text]] >= 0} {
            if {$x > 0} {
                append body [string range $text 0 [expr $x-1]]
            }
            append body "$begin"
            set text [string range $text [expr $x+2] end]
            if {[set x [string first "|" $text]] < 0} {
                error "missing close for |$ei"
            }
            if {$x > 0} {
                append body [string range $text 0 [expr $x-1]]
            }
            append body "$end"
            set text [string range $text [expr $x+1] end]
        }
        append body $text
        set text $body
    }

    return $text
}

#           }}}3 Main html mode
#           {{{3 Slides sub-mode

catch {
    package require Trf
}

set leftGif \
"R0lGODlhFAAWAKEAAP///8z//wAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRoZSBwdWJsaWMgZG9t
YWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIgMTk5NQAh+QQBAAAB
ACwAAAAAFAAWAAACK4yPqcvN4h6MSViK7MVBb+p9TihKZERqaDqNKfbCIdd5dF2CuX4fbQ9kFAAA
Ow=="

set rightGif \
"R0lGODlhFAAWAKEAAP///8z//wAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRoZSBwdWJsaWMgZG9t
YWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIgMTk5NQAh+QQBAAAB
ACwAAAAAFAAWAAACK4yPqcsd4pqAUU1az8V58+h9UtiFomWeSKpqZvXCXvZsdD3duF7zjw/UFQAA
Ow=="

set upGif \
"R0lGODlhFAAWAKEAAP///8z//wAAAAAAACH+TlRoaXMgYXJ0IGlzIGluIHRoZSBwdWJsaWMgZG9t
YWluLiBLZXZpbiBIdWdoZXMsIGtldmluaEBlaXQuY29tLCBTZXB0ZW1iZXIgMTk5NQAh+QQBAAAB
ACwAAAAAFAAWAAACI4yPqcvtD6OcTQgarJ1ax949IFiNpGKaSZoeLIvF8kzXdlAAADs="

proc end_rfc_slides {} {
    global ifile
    global passno
    global slideno slidewd slidemx

    if {$passno != 2} {
        end_page_slides
        return 1
    }

    set slidemx $slideno
    set slidewd [expr int(log10($slideno))+1]
    foreach file [glob -nocomplain [file rootname $ifile]-*.html] {
        catch { file delete -force $file }
    }

    if {![string compare [info commands base64] base64]} {
        set inputD [file dirname $ifile]

        foreach gif {left right up} {
            global ${gif}Gif

            if {![file exists [set file [file join $inputD ${gif}.gif]]]} {
                set fd [open $file {WRONLY CREAT TRUNC}]
                fconfigure $fd -translation binary

                puts -nonewline $fd [base64 -mode decode -- [set ${gif}Gif]]

                catch { close $fd }
            }
        }
    }

    return 0
}

proc front_slides_begin {left right top bottom title} {
    global passno
    global out_fd
    global slideno slideft

    set slideno 0
    start_page_slides [set slideft [lindex $title 0]]

    if {$passno == 2} {
        return 0
    }

    set size 4
    puts $out_fd "<br /><br /><br /><br /><p align=\"right\">"
    puts $out_fd "<table width=\"75%\" border=\"0\" cellpadding=\"0\" cellspacing=\"0\">"
    puts $out_fd "<tr><td>"
    puts $out_fd "<table width=\"100%\" border=\"0\" cellpadding=\"2\" cellspacing=\"1\">"
    set left [munge_long $left 1]
    set right [munge_long $right 0]
    set lc ""
    set rc ""
    foreach l $left r $right {
        if {[string compare $l ""]} {
            set l $l
        } else {
            set l "&nbsp;"
        }
        if {[string compare $r ""]} {
            set r $r
        } else {
            set r "&nbsp;"
        }
        puts $out_fd "<tr valign=\"top\">"
        puts $out_fd "<td width=\"33%\"><font color=\"#006600\" size=\"+$size\">$l</font></td>"
        puts $out_fd "<td width=\"33%\"><font color=\"#006600\" size=\"+$size\">$r</font></td>"
        puts $out_fd "</tr>"

        set size 3
    }
    puts $out_fd "</table>"
    puts $out_fd "</td></tr>"
    puts $out_fd "</table>"
    puts $out_fd "</p>"

    return 1
}

proc start_page_slides {{title ""}} {
    global passno
    global ifile
    global out_fd
    global slideno slidenm

    if {$passno < 3} {
        return
    }

    if {$slideno == 0} {
        catch { close $out_fd }
        set out_fd ""
        catch { file delete -force [file rootname].html }
    }

    set out_fd [open [file rootname $ifile]-[set p [slide_foo $slideno]].html \
                     { WRONLY CREAT TRUNC }]
    catch { fconfigure $out_fd -encoding utf-8 }

    if {[string compare $title ""]} {
        set slidenm $title
    } else {
        set title "$slidenm (continued)"
    }
    if {$slideno != 0} {
        append p ": "
    } else {
        set p ""
    }
    write_html "<\!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\" \"http://www.w3.org/TR/html4/loose.dtd\">"
    puts $out_fd "<html><head><title>"
    pcdata_html $p$title
    puts $out_fd "</title></head>"
    puts $out_fd "<body text=\"#000000\" vlink=\"#006600\" alink=\"#ccddcc\" link=\"#006600\"\n      bgcolor=\"#ffffff\">"
    puts $out_fd "<font face=\"arial, helvetica, sans-serif\">"
    puts $out_fd "<table height=\"100%\" cellspacing=\"0\" cellpadding=\"0\" width=\"100%\" border=\"0\">"
    puts $out_fd "<tbody><tr><td valign=\"top\">"

    puts $out_fd "<table height=\"100%\" cellspacing=\"0\" cellpadding=\"0\" width=\"100%\" border=\"0\">"
    puts $out_fd "<tbody><tr><td valign=\"top\">"
    puts $out_fd "<p><font color=\"#006600\" size=\"+5\">$title</font></p>"

    puts $out_fd "<br /><br />"
    puts $out_fd "<font size=\"+3\">"
}

proc end_page_slides {} {
    global passno
    global ifile
    global out_fd
    global slideno slidemx slideft

    if {$passno < 3} {
        incr slideno
        return 0
    }

    set up [file rootname [file tail $ifile]]-[slide_foo 0].html
    if {[set left [expr $slideno-1]] < 0} {
        set left $slidemx
    }
    set left [file rootname [file tail $ifile]]-[slide_foo $left].html
    if {[set right [expr $slideno+1]] > $slidemx} {
        set right 0
    }
    set right [file rootname [file tail $ifile]]-[slide_foo $right].html

    puts $out_fd "</font>"
    puts $out_fd "</td></tr></tbody>"
    puts $out_fd "</table>"
    puts $out_fd "</td><td valign=\"bottom\" align=\"right\">"
    puts -nonewline \
         $out_fd "<p align=\"right\"><nobr>"
    puts -nonewline \
         $out_fd "<a href=\"$left\"><img src=\"left.gif\" border=\"0\" width=\"20\" height=\"22\" /></a>"
    puts -nonewline \
         $out_fd "<a href=\"$up\"><img src=\"up.gif\" border=\"0\" width=\"20\" height=\"22\" /></a>"
    puts -nonewline \
         $out_fd "<a href=\"$right\"><img src=\"right.gif\" border=\"0\" /></a>"
    puts $out_fd "</nobr></p>"
    puts $out_fd "</td></tr>"
    puts $out_fd "<tr><td align=\"right\" colspan=\"2\">"
    puts $out_fd "<font color=\"#006600\" size=\"-3\">"
    pcdata_html $slideft
    pcdata_html "</font>"
    puts $out_fd "</td></tr></tbody>"
    puts $out_fd "</table>"
    puts $out_fd "</font></body></html>"

    catch { close $out_fd }
    set out_fd ""

    incr slideno
    return 1
}

proc slide_pre {text} {
    global passno
    global out_fd
    global doingP needP

    if {$passno < 3} {
        return 0
    }

    set needP 0
    set t ""
    if {$doingP} {
        append t "</p>\n"
    }
    append t [pre_tag_html begin]
    append t $text
    append t [pre_tag_html end]
    if {$doingP} {
        append t "<p>\n"
    }
    puts -nonewline $out_fd $t

    return 1
}

proc slide_foo {n} {
    global slidewd

    return [format %*.*d $slidewd $slidewd $n]
}


#           }}}3 Slides sub-mode
#           {{{3 Other html mode stuff

proc pre_tag_html {tag} {
    set str ""

    switch -- $tag {
        begin {
            set ml auto
            set mr auto
            append str "<div style='display: table; width: 0; "
            set b [current_align_bias]
            switch -- [current_align] {
                center  {}
                right   {
                    if {$b < 0} {
                        set mr [expr -($b)]em
                    } else {
                        set mr 0
                    }
                }
                default {
                    incr b 3
                    if {$b > 0} {
                        set ml [expr $b]em
                    } else {
                        set ml 0
                    }
                }
            }
            append str "margin-left: $ml; margin-right: $mr'>"
            append str "<pre>"
        }

        end {
            append str "</pre></div>"
        }
    }

    return $str
}

proc pi_html {key value} {
    switch -- $key {
        needLines {}

        typeout {
            global passno

            if {$passno == 2} {
                puts stdout $value
            }
        }

        default { error "" }
    }
}

proc write_html {a1 {a2 ""}} {
    global options
    global passno
    global out_fd

    if {$options(.SLIDES) || $passno >= 2} {
        set command [list puts]
        if {![string compare $a1 -nonewline]} {
            lappend command -nonewline
            set a1 $a2
        }
        eval $command [list $out_fd $a1]
    }
}

#           }}}3 Other html mode stuff
#       }}}2 html rendering engine
#       {{{2 nr(off) rendering engine

proc rfc_nr {irefs authors iprstmt copying newP validity} {
    global options copyrightP iprP
    global funding
    global pageno
    global indexpg
    global page_basic_indent

    if {[llength $irefs] > 0} {
        if {!$options(.COMPACT) || ![have_lines 4]} {
            end_page_nr
        } else {
            write_line_nr ""
        }
        if {!$options(.RFCEDSTYLE)} {
            write_line_nr "" -1
        }
        set indexpg $pageno

        condwrite_in_nr 0 1
        write_line_nr "Index"

        condwrite_in_nr 12 1
        foreach iref $irefs {
            foreach {L item subitem flags pages} $iref { break }

            if {[string compare $L ""]} {
                write_it ".br"
                write_line_nr ""
                write_it ".ti $page_basic_indent"
                write_line_nr $L
            }

            set subitem [chars_expand $subitem]
            if {[string compare $item ""]} {
                write_it ".br"
                do_indent_text_nr [chars_expand $item] 6
                if {[string compare $subitem ""]} {
                    flush_text
                    write_it ".br"
                    do_indent_text_nr $subitem 9
                }
            } else {
                write_it ".br"
                do_indent_text_nr $subitem 9
            }

            write_text_nr "  [collapsed_num_list $pages]"
            flush_text
        }

        #condwrite_in_nr 0 1
    }

    authors_nr $authors

    if {(!$options(.PRIVATE)) && $copyrightP > 0} {
        end_page_nr
        if {!$options(.RFCEDSTYLE)} {
            write_line_nr "" -1
        }
        set result $pageno

        condwrite_in_nr $page_basic_indent 1

        # See comment in "proc rfc_txt" about this content.

        write_it ".ti 0"
        if {0 && $newP} {
            write_line_nr "Copyright Statement"
        } else {
            write_line_nr "Full Copyright Statement"
        }

        foreach para $copying {
            write_line_nr ""
            pcdata_nr $para
        }

        if {$newP} {
            #if {![have_lines 4]} {
            #    end_page_nr
            #}

            #write_it ".ti 0"
            #write_line_nr "Disclaimer of Validity"

            foreach para $validity {
                write_line_nr ""
                pcdata_nr $para
            }
        }
        write_line_nr "" -1
        if {!$options(.RFCEDSTYLE)} {
            write_line_nr "" -1
        }

        if {$iprP} {
            global iprurl ipremail

            if {![have_lines 4]} {
                end_page_nr
            }

            write_it ".ti 0"
            write_line_nr "Intellectual Property"

            regsub -all -- %IPRURL% $iprstmt $iprurl iprstmt
            regsub -all -- %IPREMAIL% $iprstmt $ipremail iprstmt

            foreach para $iprstmt {
                write_line_nr ""
                pcdata_nr $para
            }
            write_line_nr "" -1
            if {!$options(.RFCEDSTYLE)} {
                write_line_nr "" -1
            }
        }

        if {![have_lines 4]} {
            end_page_nr
        }

        write_it ".ti 0"
        if {$options(.RFCEDSTYLE)} {
            set ack "Acknowledgement"
        } else {
            set ack "Acknowledgment"
        }
        set acks 0
        if {[string length $funding]} {
            incr acks 1
        }
        if {$options(.RFCPROCACK)} {
            incr acks 1
        }
        if {$acks > 1} {
            append ack s
        }
        if {$acks} {
            write_line_nr $ack
            write_line_nr ""
        }
        if {[string length $funding]} {
            pcdata_nr $funding
        }
        if {$options(.RFCPROCACK)} {
            global prog_ack prog_url

            regsub -all -- %PROGURL% $prog_ack $prog_url xml2rfc_ack
            if {[string length $funding]} {
                pcdata_nr "  "
            }
            pcdata_nr $xml2rfc_ack
        }
    } else {
        set result ""
    }

    flush_text

    return $result
}

proc front_nr_begin {left right top bottom title keywords lang} {
    global prog prog_version
    global options copyrightP
    global lineno pageno blankP
    global eatP nofillP indent lastin
    global passno indexpg authorspg
    global page_width page_basic_indent

    set lineno 1
    set pageno 1
    set blankP 0
    set eatP 0
    set lastin -1

    write_it [clock format [clock seconds] \
                    -format ".\\\" automatically generated by $prog $prog_version on %Y-%m-%dT%H:%M:%SZ" \
                    -gmt true]
    set wi [expr $page_width / 10.0]i
    write_it ".\\\" "
    write_it ".pl 10.0i"
    write_it ".po 0"
    write_it ".ll $wi"
    write_it ".lt $wi"
    write_it ".nr LL $wi"
    write_it ".nr LT $wi"
    write_it ".ds LF [nbsp_expand_nr [chars_expand [lindex $bottom 0]]]"
    write_it ".ds RF FORMFEED\[Page %]"
    write_it ".ds CF [nbsp_expand_nr [chars_expand [lindex $bottom 1]]]"
    write_it ".ds LH [nbsp_expand_nr [chars_expand [lindex $top 0]]]"
    write_it ".ds RH [nbsp_expand_nr [chars_expand [lindex $top 2]]]"
    write_it ".ds CH [nbsp_expand_nr [chars_expand [lindex $top 1]]]"
    write_it ".hy 0"
    write_it ".nh"
    write_it ".ad l"
    set nofillP -1
    condwrite_nf_nr

    if {$passno == 2} {
        set indexpg 0
        set authorspg 0
    }

    incr lineno 2

    condwrite_in_nr 0 1

    if {$options(.TOPBLOCK)} {
        set left [munge_long $left 1]
        set right [munge_long $right 0]
        foreach l $left r $right {
            set l [chars_expand $l]
            set r [chars_expand $r]
            set len [expr $page_width - [string length $l]]
            write_line_nr [format %s%*.*s $l $len $len $r]
        }
        write_line_nr "" -1
        write_line_nr "" -1
    }

    foreach line $title {
        write_text_nr [chars_expand $line] c
    }

    write_line_nr "" -1

    condwrite_in_nr $page_basic_indent 1
}

proc write_status_nr {status copying afterP} {
    global options copyrightP iprP
    global page_basic_indent

    if {$afterP} {
        write_line_nr "" -1

        condwrite_in_nr $page_basic_indent 1
    }

    if {!$options(.PRIVATE)} {
        write_it ".ti 0"
        if {$options(.RFCEDSTYLE)} {
            write_line_nr "Status of This Memo"
        } else {
            write_line_nr "Status of this Memo"
        }
        foreach para $status {
            write_line_nr ""
            pcdata_nr $para
        }
    }

    if {(!$options(.PRIVATE)) && $copyrightP && [string length $copying]} {
        write_line_nr "" -1
        write_it ".ti 0"
        write_line_nr "Copyright Notice"
        foreach para $copying {
            write_line_nr "" -1
            pcdata_nr $para
        }
    }
}

proc front_nr_end {toc} {
    front_txt_end $toc
}

proc write_toc_nr {s1 title s2 len dot} {
    write_toc_txt $s1 $title $s2 $len $dot
}

proc abstract_nr {} {
    global options

    if {(!$options(.COMPACT) && !$options(.ABSTRACT1ST)) || ![have_lines 4]} {
        end_page_nr
    } else {
        write_line_nr ""
    }
    write_it ".ti 0"
    write_line_nr "Abstract"
    write_line_nr "" -1
}

proc note_nr {title depth} {
    global options

    if {!$options(.COMPACT) || ![have_lines 4]} {
        end_page_nr
    } else {
        write_line_nr ""
    }
    write_it ".ti 0"
    write_line_nr [chars_expand $title]
    write_line_nr "" -1
}

proc section_nr {prefix top title lines anchor} {
    global options
    global pageno
    global page_basic_indent

    if {($top && !$options(.COMPACT)) || (![have_lines [expr $lines + 2]])} {
        end_page_nr
    } else {
        write_line_nr ""
    }
    if {$top && !$options(.RFCEDSTYLE)} {
        write_line_nr "" -1
    }

    indent_text_nr "$prefix  " 0
    write_text_nr [chars_expand $title]
    flush_text
    pop_indent

    condwrite_in_nr $page_basic_indent 1

    return $pageno
}

proc t_nr {tag counter style hangText editNo} {
    t_txt $tag $counter $style $hangText $editNo
}

proc list_nr {tag min max style hangIndent longestHangText suprT} {
    list_txt $tag $min $max $style $hangIndent $longestHangText $suprT
}

proc figure_nr {tag lines anchor title av {suppressP 0}} {
    figure_txt $tag $lines $anchor $title $av $suppressP
}

proc artwork_nr {tag lines {av {}} } {
    artwork_txt $tag $lines $av
}

proc preamble_nr {tag {editNo ""}} {
    preamble_txt $tag $editNo
}

global tblindent
set tblindent 0

proc postamble_nr {tag {editNo ""}} {
    global tblindent

    postamble_txt $tag $editNo

    if {![string compare $tag "begin"] && ($tblindent > 0)} {
        condwrite_in_nr $tblindent
    }
    set tblindent 0
}

proc texttable_nr {tag lines anchor title {suppressP 0}} {
    global tblindent

    set rc [texttable_txt $tag $lines $anchor $title $suppressP]
    if {![string compare $tag "end"] && ($tblindent > 0)} {
        condwrite_in_nr $tblindent
    }
    set tblindent 0
    return rc
}

proc ttcol_nr {text align col width cwidth} {
    global tblindent indent

    if {$tblindent == 0} {
        flush_text
        set tblindent $indent
        condwrite_in_nr 0
    }
    ttcol_txt $text $align $col $width $cwidth
}

proc c_nr {tag row col align width} {
    c_txt $tag $row $col $align $width
}

proc xref_nr {text av target format {hackP 0}} {
    condwrite_fi_nr
    xref_txt $text $av $target $format $hackP
}

proc eref_nr {text counter target} {
    condwrite_fi_nr
    eref_txt $text $counter $target
}

proc cref_nr {text counter source anchor} {
    condwrite_fi_nr
    cref_txt $text $counter $source $anchor
}

proc iref_nr {item subitem flags} {
    global pageno

    return $pageno
}

proc vspace_nr {lines} {
    vspace_txt $lines
}

proc spanx_nr {text style} {
    condwrite_fi_nr
    spanx_txt $text $style
}

proc references_nr {tag arg0 {arg1 ""}} {
    references_txt $tag $arg0 $arg1
}

proc erefs_nr {{title ""}} {
    global erefs
    global options

    if {[string compare $title ""]} {
        if {$options(.COMPACT)} {
            write_line_nr ""
        } else {
            end_page_nr
        }
        condwrite_fi_nr
        write_it ".ti 0"
        write_line_nr $title
    }

    set names  [lsort -integer [array names erefs]]
    set width [expr [string length [lindex $names end]]+2]
    foreach eref $names {
        write_line_nr ""

        indent_text_nr "[format %-*.*s $width $width "\[$eref\]"]  " -1

        write_url $erefs($eref)
        flush_text

        pop_indent
    }

    flush_text
}

proc crefs_nr {title} {
    global crefs
    global options

    if {[string compare $title ""]} {
        if {$options(.COMPACT)} {
            write_line_nr ""
        } else {
            end_page_nr
        }
        condwrite_fi_nr
        write_it ".ti 0"
        write_line_nr $title
    }

    set names  [lsort -dictionary [array names crefs]]
    set width 0
    foreach cref $names {
        set x [string length $cref]
        if {$x > $width} {
            set width $x
        }
    }
    incr width 2
    foreach cref $names {
        write_line_nr ""

        indent_text_nr "[format %-*.*s $width $width "\[$cref\]"]  " -1

        write_text_nr [chars_expand [lindex $crefs($cref) 3]]
        flush_text

        pop_indent
    }

    flush_text
}

proc reference_nr {prefix names title series formats date anchor target
                   target2 width annotations} {
    global options
    global max_ref_width
    global page_basic_indent

    write_line_nr ""

    if {($width > $max_ref_width) && !$options(.RFCEDSTYLE)} {
        set width $max_ref_width
    }
    set i [string length $prefix]
    set prefix [format %-*s [expr $width + 2] "\[$prefix\]"]

    if {$i > $width} {
        # The indent_text_nr abstraction isn't robust enough to figure this out...
        global indent

        flush_text
        condwrite_fi_nr

        push_indent [expr $page_basic_indent + $width + 4 - $indent]

        condwrite_in_nr $indent
        write_it ".ti $page_basic_indent"
        write_line_nr $prefix
        write_it ".br"
    } else {
        indent_text_nr "$prefix  " $page_basic_indent
    }

    set s ""
    set nameA 1
    set nameN [llength $names]
    foreach name $names {
        incr nameA
        write_text_nr $s[chars_expand [lindex $name 0]]
        set s [list_sep_str $nameA $nameN]
    }
    write_text_nr "$s\"[chars_expand $title]\""
    foreach serial $series {
        if {$options(.NOTEDRAFTINPROGRESS)} {
          if {[regexp -nocase -- "internet-draft&nbsp;(draft-.*)" $serial x n] == 1} {
              set serial "$n (work in progress)"
          }
        }
        write_text_nr ", [chars_expand $serial]"
    }
    if {[string compare $date ""]} {
        write_text_nr ", [chars_expand $date]"
    }
    if {[string compare $target ""]} {
        write_text_nr ", "
        write_url $target
    }
    write_text_nr .

    while {[llength $annotations] > 0} {
        write_line_nr ""
        pcdata_nr [lindex $annotations 0]
        set annotations [lrange $annotations 1 end]
    }

    pop_indent
}

proc annotation_nr {tag} {
    annotation_txt $tag
}

proc authors_nr {authors} {
    global options
    global lineno pageno
    global contacts
    global authorspg
    global page_basic_indent

    if {!$options(.AUTHORSHIP)} {
        return
    }
    switch -- [llength $authors] {
        0       { return }
        1       { set s1 "'s"; set s2 ""   }
        default { set s1 "s'"; set s2 "es" }
    }
    set s "Author$s1 Address$s2"

    if {!$options(.COMPACT) || ![have_lines 4]} {
        end_page_nr
    } else {
        write_line_nr ""
    }
    if {!$options(.RFCEDSTYLE)} {
        write_line_nr "" -1
    }
    set authorspg $pageno

    condwrite_in_nr $page_basic_indent 1
    condwrite_nf_nr

    set firstP 1
    foreach author $authors {
        set block1 [lindex $author 0]
        set block2 [lindex $author 1]

        set lines 4
        incr lines [llength $block1]
        incr lines [llength $block2]
        if {![have_lines $lines]} {
            end_page_nr
        }

        if {[string compare $s ""]} {
            write_it ".ti 0"
            write_line_nr $s
            set s ""
        } else {
            write_line_nr "" -1
        }
        write_line_nr "" -1

        foreach line $block1 {
            write_line_nr [chars_expand $line]
        }

        if {[llength $block2] > 0} {
            write_line_nr ""
            foreach contact $block2 {
                set key [lindex $contact 0]
                set value [lindex [lindex $contacts \
                                          [lsearch0 $contacts $key]] 1]
                if {$options(.RFCEDSTYLE) && ![string compare $key email]} {
                    regsub -- m $value M value
                }
                set value [format %-6s $value:]
                if {$options(.COLONSPACE)} {
                    append value " "
                }
                write_line_nr "$value [chars_expand [lindex $contact 1]]"
            }
        }
    }
}

proc back_nr {} {
}

proc pcdata_nr {text {pre 0} {nowrite 0} {spans {}} {divs {}} } {
    global eatP
    global options
    global pcdata_line_offset
    global page_basic_indent

    if {[llength $spans] > 0 || [llength $divs] > 0} {
        set text [html_quote $text]
    }

    if {(!$pre) && ($eatP > 0)} {
        set text [string trimleft $text]
    }
    if {[string length $text] <= 0} {
        # Was only white space, but got trimmed.
        return
    }
    set eatP 0

    if {!$pre} {
        regsub -all -- "\n\[ \t\n\]*" $text "\n" text
        regsub -all -- "\[ \t\]*\n\[ \t\]*" $text "\n" text
        set prefix ""

        if {$options(.EMOTICONIC)} {
            set text [emoticonic_txt $text]
        }
    }

    if {$pre} {
        condwrite_nf_nr
    } else {
        condwrite_fi_nr
    }
    if {[cellP $text]} {
        return
    }

    set pcdata_line_offset 0
    foreach line [split $text "\n"] {
        set line [chars_expand $line]
        if {$pre} {
            set x 0
            while {[set x [lsearch0 $divs $pcdata_line_offset $x]] >= 0} {
                if {![have_lines [lindex [lindex $divs $x] 1]]} {
                    end_page_nr
                    break
                }
                incr x
            }
            write_line_nr [string trimright $line] $pre
        } else {
            write_pcdata_nr $prefix$line
            set prefix " "
        }
        incr pcdata_line_offset
    }
    if {$pre} {
        condwrite_in_nr $page_basic_indent
    }
    set pcdata_line_offset 0

    if {[regexp -- {[ \t\n]$} $text]} {
        set eatP 1
    }
}


proc start_page_nr {} {
    global lineno blankP
    global page_head_height

    set lineno $page_head_height
    set blankP 1
}

proc end_page_nr {} {
    global lineno pageno
    global page_head_height

    flush_text

    if {$lineno <= $page_head_height} {
        return
    }

    incr pageno
    set lineno 0

    write_it ".bp"
}

proc indent_text_nr {prefix {left ""}} {
    global indent
    global page_basic_indent

    flush_text
    condwrite_fi_nr

    if {![string compare $left ""]} {
        set left $indent
        while {![string compare [string index $prefix 0] " "]} {
            incr left
            set prefix [string range $prefix 1 end]
        }
        push_indent $page_basic_indent
    } elseif {$left < 0} {
        if {$left == -1} {
            set left $indent
        }
        push_indent [string length $prefix]
        if {$left == -2} {
            set left $indent
            set prefix ""
        }
    } else {
        push_indent [expr $left + [string length $prefix] - $indent]
    }
    condwrite_in_nr $indent
    do_indent_text_nr $prefix $left
}

proc do_indent_text_nr {text left} {
    global buffer
    global indent

    write_it ".ti $left"
    # In case $left==0, we have to put $text in buffer ourselves now,
    # otherwise the next write_text_nr will prepend an indent and screw
    # the line-breaking algorithm (nroff can undo that) but more
    # importantly the value of lineno.  The page could end up shorter
    # as a result of an over-inflated lineno.
    set buffer [format %*s%s $left "" $text]
    if {$indent != 0 && [string length $buffer] == 0} {
        unexpected error "internal bug triggered in do_indent_text_nr; report it!"
    }
    write_text_nr ""
}

proc write_pcdata_nr {text} {
    global buffer

    if {![string compare $buffer ""]} {
        setup_align_nr begin [current_align]
    }

    write_pcdata_txt $text
}

proc write_editno_nr {editNo} {
    global buffer

    if {[string compare $buffer ""]} {
        flush_text
    }
    write_it ".ti 0"
    write_it <$editNo>
    write_it ".br"
}

proc write_text_nr {text {direction l} {magic 0}} {
    global buffer buffer_rest buffer_align
    global indent
    global page_width
    global eatP

    if {($eatP < 0) && ![regexp -- {^[.,?!]} $text]} {
        set text " $text"
    }
    switch -- $direction {
        c - r { flush_text }
    }
    if {![string compare $buffer ""]} {
        condwrite_in_nr $indent
        switch -- $direction {
            c - r {}
            default {
                setup_align_nr begin [set buffer_align [current_align]]
            }
        }
        set buffer [format %*s $indent ""]
    }
    append buffer $text

    set flush [string compare $direction l]
    while {([string length $buffer] > $page_width) || ($flush)} {
        set text [fold_text_txt]

        setup_align_nr oneshot $direction
        write_line_nr [string trimleft $text] 0 $magic

        if {![string compare [set buffer $buffer_rest] ""]} {
            setup_align_nr end $buffer_align
            set buffer_align ""
            break
        }
    }
}

proc write_line_nr {line {pre 0} {magic 0}} {
    global lineno blankP
    global page_width page_head_height page_body_height page_basic_indent

    flush_text
    if {$lineno == 0} {
        start_page_nr
    }
    if {![set x [string length [set orig_line $line]]]} {
        set blankO $blankP
        set blankP 1
        if {($blankO) && (!$pre || $lineno == $page_head_height)} {
            return
        }
    } else {
        set blankP 0
    }
    if {($pre) && ($x)} {
        condwrite_in_nr [expr $pre > 0 ? ($pre - 1) : $page_basic_indent]
        if {$pre > 0} {
            set line [tabs_expand_pre $line]
            set x [string length [set orig_line $line]]
        }
    }
    if {!$magic} {
        regsub -all -- "\\\\" $line "\\\\\\" line
    }
    regsub -all -- "'" $line "\\'" line
    set line [nbsp_expand_nr [break_unprotect $line]]
    if {[string first "." $line] == 0} {
        set line "\\&$line"
    }
    if {!($pre)} {
        regsub -all -- "\[^ \t\n\]*-" $line "\\%\&" line
    }
    write_it $line
    incr lineno
    if {$pre > 0 && [set len [expr ($pre - 1) + $x]] > $page_width} {
        global pageno

        regsub -all -- \" [string range $orig_line [expr $page_width - ($pre - 1)] end] {\"} excess
        unexpected [unex_condtype] \
            "output line $lineno (on page $pageno) has $len > $page_width characters (excess string is \"$excess\")"
    }
    if {$lineno >= $page_head_height + $page_body_height} {
        end_page_nr
    }
}

proc nbsp_expand_nr {s} {
    regsub -all -- "\xA0" [string trimright $s] "\\\\0" s
    return $s
}

proc pi_nr {key value} {
    pi_txt $key $value
}

# Only proc allowed to write a ".fi" or set nofillP to zero.
proc condwrite_fi_nr {} {
    global nofillP
    #global lastin

    if {$nofillP != 0} {
        flush_text
        write_it ".fi"
        set nofillP 0
        # Is the next line necessary on some nroff's???
        #set lastin -1
    }
}

# Only proc allowed to write a ".nf" or set nofillP positive.
proc condwrite_nf_nr {} {
    global nofillP

    if {$nofillP <= 0} {
        flush_text
        write_it ".nf"
        set nofillP 1
    }
}

# Only proc allowed to write a ".in" or update lastin.
proc condwrite_in_nr {in {reset 0}} {
    global lastin

    if {$lastin != $in} {
        flush_text
        write_it ".in [set lastin $in]"
        if {$reset} {
            global indents indent

            set indent $in
            set indents {}
        }
    }
}

# Assumes flush has been done.  Must NOT be done again.
proc setup_align_nr {tag dir} {
    switch -- $dir {
        c - center { set xx ce }
        r - right  { set xx rj }
        default    { return }
    }
    switch -- $tag {
        begin    { set v " 8192" }
        oneshot  { set v ""      }
        end      { set v " 0"    }
    }
    write_it ".$xx$v"
}

#       }}}2 nr(off) rendering engine
#   }}}1 Rendering engines

#   {{{1 Low-level formatting
#       {{{2 Some globals


global contacts

set contacts { {phone Phone} {facsimile Fax} {email Email} {uri URI} }


global buffer indent indents

set buffer ""
set indent $page_basic_indent
set indents {}

global rfcTxtHome rfcHtmlHome idTxtHome idHtmlHome

set rfcTxtHome ftp://ftp.isi.edu/in-notes
set rfcHtmlHome http://tools.ietf.org/html
set idTxtHome http://www.ietf.org/internet-drafts
set idHtmlHome http://tools.ietf.org/html

#       }}}2 Some globals
#       {{{2 Characters entities

global xentities oentities entities uentities

# Hex entities (&#x3F;) are first converted to dec entities (&#63;) elsewhere.
# Only put dec entities or (case-sensitive) named entities here.
# &amp; and &#38; must always be last and specified simultaneously.
# &nbsp;, &nbhy;, and &wj; are first converted to actual characters here
#   then handled elsewhere by the txt and nr rendering engines.

set uentities [list {&rfc2629\.processor;} "$prog\\&nbsp;$prog_version"]
# For compatibility with previous versions (really invalid form of mdash).
set xentities [concat $uentities [list "&#(0*151|x0*97);" "\\&mdash;"]]
set oentities $xentities

# Entity names unknown to HTML and XHTML.
foreach {e c t} {
    lpar     0x28 (         rpar     0x29 )
    lsqb     0x5B \[        rsqb     0x5D \]
    lcub     0x7B \{        rcub     0x7D \}
    sol      0x2F /         percnt   0x25 %
    num      0x23 #         dollar   0x24 \$
    ast      0x2A *         hyphen   0x2D -
    plus     0x2B +         equals   0x3D =
    comma    0x2C ,         period   0x2E .
    colon    0x3A :         semi     0x3B ;
    excl     0x21 !         quest    0x3F ?
    commat   0x40 @         lowbar   0x5F _
    circ     0x5E ^         grave    0x60 `
    bsol     0x5C \\        verbar   0x7C |
    Zcaron 0x017D Z         zcaron 0x017E z
    dash   0x2010 -         nbhy   0x2011 "\u2011"
    wj     0x2060 "\u2060"
 } {
    set c [expr $c]
    lappend xentities "&$e;"         "\\&#$c;"
    lappend oentities "&($e|#0*$c);" $t
    lappend uentities "&$e;" [format %c $c]
}

# Some entities known to HTML and XHTML.
# Note that &apos; is (officially) unknown to HTML.
# The second &circ; is a duplicate only useful for its numerical value.
# All arrows are the same width by design.
foreach {e c t} {
    quot     0x22 \"        apos     0x27 '
    lt       0x3C <         gt       0x3E >
    OElig  0x0152 OE        oelig  0x0153 oe
    Scaron 0x0160 S         scaron 0x0161 s
    Yuml   0x0178 Y
    fnof   0x0192 f
    circ   0x02C6 ^
    tilde  0x02DC ~
    ensp   0x2002 { }       emsp   0x2003 { }
    thinsp 0x2009 { }
    ndash  0x2013 -         mdash  0x2014 --
    lsquo  0x2018 '         rsquo  0x2019 '
    sbquo  0x201A '
    ldquo  0x201C \"        rdquo  0x201D \"
    bdquo  0x201E \"
    dagger 0x2020 *!*       Dagger 0x2021 *!!*
    bull   0x2022 o         hellip 0x2026 ...
    permil 0x2030 {[/1000]}
    prime  0x2032 '         Prime  0x2033 \"
    lsaquo 0x2039 <         rsaquo 0x203A >
    frasl  0x2044 /
    euro   0x20AC EUR       trade  0x2122 {[TM]}
    larr   0x2190 <--       lArr   0x21D0 <==
    rarr   0x2192 -->       rArr   0x21D2 ==>
    harr   0x2194 <->       hArr   0x21D4 <=>
    minus  0x2212 -         lowast 0x2217 *
    le     0x2264 <=        ge     0x2265 >=
    lang   0x2329 <         rang   0x232A >
 } {
    set c [expr $c]
    lappend oentities "&($e|#0*$c);" $t
    lappend uentities "&$e;" [format %c $c]
}

# ISO Latin 1 (named and dec) entities (all known to HTML and XHTML).
# &uuml; should be just "u" in French, but it's so rare it can yield to "ue".
set c 160
foreach {e t} {
    nbsp   "\xA0"              iexcl  !          cent   {[cents]}  pound  GBP
    curren {[currency units]}  yen    JPY        brvbar |          sect   S.
    uml    \"                  copy   (C)        ordf   a          laquo  <<
    not    {[not]}             shy    {}         reg    (R)        macr   _
    deg    o                   plusmn +/-        sup2   ^2         sup3   ^3
    acute  '                   micro  {[micro]}  para   P.         middot .
    cedil  ,                   sup1   ^1         ordm   o          raquo  >>
    frac14 1/4                 frac12 1/2        frac34 3/4        iquest ?
    Agrave A                   Aacute A          Acirc  A          Atilde A
    Auml   Ae                  Aring  Ae         AElig  AE         Ccedil C
    Egrave E                   Eacute E          Ecirc  E          Euml   E
    Igrave I                   Iacute I          Icirc  I          Iuml   I
    ETH    {[ETH]}             Ntilde N          Ograve O          Oacute O
    Ocirc  O                   Otilde O          Ouml   Oe         times  x
    Oslash Oe                  Ugrave U          Uacute U          Ucirc  U
    Uuml   Ue                  Yacute Y          THORN  {[THORN]}  szlig  ss
    agrave a                   aacute a          acirc  a          atilde a
    auml   ae                  aring  ae         aelig  ae         ccedil c
    egrave e                   eacute e          ecirc  e          euml   e
    igrave i                   iacute i          icirc  i          iuml   i
    eth    {[eth]}             ntilde n          ograve o          oacute o
    ocirc  o                   otilde o          ouml   oe         divide /
    oslash oe                  ugrave u          uacute u          ucirc  u
    uuml   ue                  yacute y          thorn  {[thorn]}  yuml   y
 } {
    lappend oentities "&($e|#0*$c);" $t
    lappend uentities "&$e;" [format %c $c]
    incr c
}

# ASCII dec entities.
for {set c 32} {$c < 127} {incr c} {
    if {$c == 38} {
        # Must skip ampersand.
        continue
    }
    lappend oentities "&#0*$c;" [format %c $c]
}
lappend oentities     {&(amp|#0*38);} {\&}
set entities $oentities

#       }}}2 Characters entities
#       {{{2 IANA charset and Tcl encodings

global charsets
# We only list those that start with a 1-octet ASCII subset,
# and prefer those registered with the IANA.
# Format:  tcl-encoding {iana-charset...}
set charsets {
    utf-8       {UTF-8 csUTF8}
    ascii       {US-ASCII ASCII ANSI_X3.4-1968 iso-ir-6 ANSI_X3.4-1986 ISO_646.irv:1991 ISO646-US us IBM367 cp367 csASCII}
    iso8859-1   {ISO-8859-1 ISO_8859-1:1987 iso-ir-100 ISO_8859-1 latin1 l1 IBM819 CP819 csISOLatin1}
    iso8859-2   {ISO-8859-2 ISO_8859-2:1987 iso-ir-101 ISO_8859-2 latin2 l2 csISOLatin2}
    iso8859-3   {ISO-8859-3 ISO_8859-3:1988 iso-ir-109 ISO_8859-3 latin3 l3 csISOLatin3}
    iso8859-4   {ISO-8859-4 ISO_8859-4:1988 iso-ir-110 ISO_8859-4 latin4 l4 csISOLatin4}
    iso8859-5   {ISO-8859-5 ISO_8859-5:1988 iso-ir-144 ISO_8859-5 cyrillic csISOLatinCyrillic}
    iso8859-6   {ISO-8859-6 ISO_8859-6:1987 iso-ir-127 ISO_8859-6 arabic ECMA-114 ASMO-708 csISOLatinArabic}
    iso8859-7   {ISO-8859-7 ISO_8859-7:1987 iso-ir-126 ISO_8859-7 greek greek8 ELOT_928 ECMA-118 csISOLatinGreek}
    iso8859-8   {ISO-8859-8 ISO_8859-8:1988 iso-ir-138 ISO_8859-8 hebrew csISOLatinHebrew}
    iso8859-9   {ISO-8859-9 ISO_8859-9:1989 iso-ir-148 ISO_8859-9 latin5 l5 csISOLatin5}
    iso8859-10  {ISO-8859-10 ISO_8859-10:1992 iso-ir-157 latin6 l6 csISOLatin6}
    iso8859-13  {ISO-8859-13 csISO885913}
    iso8859-14  {ISO-8859-14 ISO_8859-14:1998 iso-ir-199 ISO_8859-14 latin8 l8 iso-celtic csISO885914}
    iso8859-15  {ISO-8859-15 ISO_8859-15 Latin-9 csISO885915}
    iso8859-16  {ISO-8859-16 ISO_8859-16:2001 iso-ir-226 ISO_8859-16 latin10 l10 csISO885916}
    iso2022     {JIS_Encoding csJISEncoding}
    iso2022-jp  {ISO-2022-JP csISO2022JP}
    iso2022-kr  {ISO-2022-KR csISO2022KR}
    euc-cn      {}
    euc-jp      {EUC-JP Extended_UNIX_Code_Packed_Format_for_Japanese csEUCPkdFmtJapanese}
    euc-kr      {EUC-KR csEUCKR}
    big5        {Big5 csBig5}
    gb1988      {GB_1988-80 iso-ir-57 cn ISO646-CN csISO57GB1988}
    gb2312      {GB2312 csGB2312}
    jis0201     {JIS_X0201 X0201 csHalfWidthKatakana}
    koi8-r      {KOI8-R csKOI8R}
    koi8-u      {KOI8-U csKOI8U}
    shiftjis    {Shift_JIS MS_Kanji csShiftJIS}
    tis-620     {TIS-620 csTIS620}
    macRoman    {macintosh mac csMacintosh}
    macCentEuro {}
    macCroatian {}
    macCyrillic {}
    macGreek    {}
    macIceland  {}
    macJapan    {}
    macRomania  {}
    macThai     {}
    macTurkish  {}
    macUkraine  {}
    cp437       {IBM437 cp437 437 csPC8CodePage437}
    cp737       {}
    cp775       {IBM775 cp775 csPC775Baltic}
    cp850       {IBM850 cp850 850 csPC850Multilingual}
    cp852       {IBM852 cp852 852 csPCp852}
    cp855       {IBM855 cp855 855 csIBM855}
    cp857       {IBM857 cp857 857 csIBM857}
    cp860       {IBM860 cp860 860 csIBM860}
    cp861       {IBM861 cp861 861 cp-is csIBM861}
    cp862       {IBM862 cp862 862 csPC862LatinHebrew}
    cp863       {IBM863 cp863 863 csIBM863}
    cp864       {IBM864 cp864 csIBM864}
    cp865       {IBM865 cp865 865 csIBM865}
    cp866       {IBM866 cp866 866 csIBM866}
    cp869       {IBM869 cp869 869 cp-gr csIBM869}
    cp874       {}
    cp932       {}
    cp936       {GBK CP936 MS936 windows-936 csGBK}
    cp949       {}
    cp950       {}
    cp1250      {windows-1250 cswindows1250}
    cp1251      {windows-1251 cswindows1251}
    cp1252      {windows-1252 cswindows1252}
    cp1253      {windows-1253 cswindows1253}
    cp1254      {windows-1254 cswindows1254}
    cp1255      {windows-1255 cswindows1255}
    cp1256      {windows-1256 cswindows1256}
    cp1257      {windows-1257 cswindows1257}
    cp1258      {windows-1258 cswindows1258}
}

proc cs2enc {charset} {
    global charsets

    foreach {enc csl} $charsets {
        foreach cs $csl {
            if {![string compare -nocase $charset $cs]} {
                return $enc
            }
        }
        if {![string compare -nocase $charset $enc]} {
            set encx $enc
        }
    }
    if {[info exists encx]} {
        return $encx
    }

    return ""
}

#       }}}2 IANA charset and Tcl encodings
#       {{{2 Indent utility functions

proc push_indent {pos} {
    global indent indents

    lappend indents $pos
    incr indent $pos
}

proc pop_indent {} {
    global indent indents

    set pos [lindex $indents end]
    set indent [expr $indent - $pos]
    set indents [lreplace $indents end end]

    return $pos
}

#       }}}2 Indent utility functions
#       {{{2 Align utility functions

global aligns
set aligns {}

proc push_align {a} {
    global aligns

    if {[regexp -- {^(left[-+]|center[-+]|right-)[0-9]+em$} $a]} {
        lappend aligns $a
        return
    }
    switch -- $a {
        left - center - right { lappend aligns $a }

        default {
            unexpected error \
                "align=\"$a\" attribute is invalid"
        }
    }
}

proc pop_align {} {
    global aligns

    set a [lindex $aligns end]
    set aligns [lreplace $aligns end end]

    return $a
}

proc current_align {} {
    global aligns

    set a ""
    if {[llength $aligns] > 0} {
        set a [lindex $aligns end]
    }
    regsub -- {[-+][0-9]+em$} $a "" a

    return $a
}

proc current_align_bias {} {
    global aligns

    set a ""
    if {[llength $aligns] > 0} {
        set a [lindex $aligns end]
    }
    if {[regexp -- {([-+][0-9]+)em$} $a x b]} {
        set b [expr $b]
    } else {
        set b 0
    }

    return $b
}

#       }}}2 Align utility functions
#       {{{2 Other

proc flush_text {} {
    global buffer buffer_align
    global mode

    if {[string compare $buffer ""]} {
        set rest $buffer
        set buffer ""
        switch -- $mode {
            txt     { set rest [justify_text_txt $rest $buffer_align] }
            default { set rest [string trim $rest] }
        }
        write_line_$mode $rest
        switch -- $mode {
            nr { setup_align_nr end $buffer_align }
        }
        set buffer_align ""
    }
}

proc munge_long {lines isleft} {
    global page_width
    global mode

    set result ""
    
    # as of 2010, need 39 characters in the left column
    # maybe this should be done in a smarter way, taking the width
    # of the text in both columns into account
    
    if {$isleft} {
        set max 39
    } else {
        set max [expr $page_width - 39 - 1]
    }

    foreach buffer $lines {
        set linkP 0
        if {(![string compare $mode html]) \
                && (([string match Obsoletes:* $buffer])
                        || ([string match Updates:* $buffer]))} {
            set linkP 1
        }
        while {[set i [string length $buffer]] > $max} {
            set line [string range $buffer 0 $max]
            if {[set x [string last " " $line]] < 0} {
                if {[set x [string first " " $buffer]] < 0} {
                    break
                }
            }
            set line [string range $buffer 0 [expr $x-1]]
            if {$linkP} {
                set line [munge_line $line]
            }
            lappend result $line
            set buffer [string trimleft [string range $buffer $x end]]
        }

        if {$linkP} {
            set buffer [munge_line $buffer]
        }
        lappend result $buffer
    }

    return $result
}

proc munge_line {line} {
    global rfcTxtHome rfcHtmlHome

    if {[set y [string first : $line]] >= 0} {
        set start [string range $line 0 $y]
        set line [string range $line [expr $y+1] end]
    } else {
        set start ""
    }

    if {[set y [string first " (" $line]] >= 0 ||
        [set y [string first "(" $line]] == 0} {
        set tail [string range $line $y end]
        set line [string range $line 0 [expr $y-1]]
    } else {
        set tail ""
    }

    set s " "
    foreach n [split $line ,] {
        set n [string trim $n]
#       append start $s "<a href='$rfcTxtHome/rfc$n.txt'>$n</a>"
        append start $s "<a href='$rfcHtmlHome/rfc$n'>$n</a>"
        set s ", "
    }

    return $start$tail
}

proc write_url {url} {
    global mode

    write_text_$mode <[chars_expand $url]>
}

proc is_at_page_start {} {
    global lineno
    global mode
    global page_head_height

    flush_text
    if {$lineno == 0} {
        start_page_$mode
    }

    return [expr $lineno <= $page_head_height]
}

proc have_lines {cnt} {
    global lineno
    global options
    global unpaginated
    global page_head_height page_body_height

    if {[is_at_page_start] || !$options(.AUTOBREAKS) || $unpaginated} {
        return 1
    }
    if {   $cnt <= $page_body_height
        && $lineno + $cnt > $page_head_height + $page_body_height} {
        return 0
    }
    return 1
}

proc write_it {line} {
    global passno
    global out_fd

    if {$passno >= 2} {
        puts $out_fd $line
    }
}

#       }}}2 Other
#       {{{2 Textual lists utility functions

proc collapsed_num_list {nums} {
    set r ""
    if {[llength $nums] == 0} {
        return $r
    }
    set s ""

    # Assume nums are non-negative and ordered.
    set i -1

    # Add sentinel.
    lappend nums [expr [lindex $nums end] + 2]

    foreach n $nums {
        if {$i < 0} {
            set j [set i $n]
            continue
        }
        if {$n == $j} {
            continue
        }
        if {$n == $j + 1} {
            set j $n
            continue
        }
        if {$i == $j} {
            append r "$s$i"
        } else {
            append r "$s$i-$j"
        }
        set j [set i $n]
        set s ", "
    }

    return $r
}

proc list_sep_str {i n} {
    if {$i == $n} {
        if {$n > 2} {
            return ", and "
        } else {
            return " and "
        }
    } else {
        return ", "
    }
}

#       }}}2 Textual lists utility functions
#       {{{2 Character expansion

# This expands entities and non-ASCII characters
# into ASCII characters and ASCII-art glyphs.
proc chars_expand {text {flatten 1}} {
    global entities

    if {[regsub -all -- {[\0-\010\013\014\016-\037\177]+} $text {*?*} text]} {
        # DELETE and every C0 control char except \t, \n, and \r.
        unexpected error \
            "illegal use of hardcoded ASCII control character(s) in \"$text\""
    }

    if {[regsub -all -- {[\x80-\x9F]+} $text {*?*} text]} {
        # Every C1 control char.
        unexpected error \
            "illegal use of hardcoded C1 control character(s) (U+0080..U+009F) possibly instead of standard entities (e.g., &mdash; or &rsquo;) in \"$text\""
    }

    # Convert other hardcoded non-ASCII characters (except no-break space,
    # non-breaking hyphen, word joiner, and our protected characters)
    # as dec entities.
    while {[regexp -- {[^\0-\xA0\u2011\u2060\uF000-\uF0FF]} $text x]} {
        regsub -all -- $x $text "\\&#[scan $x %c];" text
    }

    # Process hex here to avoid cluttering $entities, to support
    # leading zeros, and most importantly to have -nocase.
    while {[regexp -nocase -- {&#x([0-9A-Z]+);} $text x y]} {
        # Rewrite hex as dec.
        regsub -all -nocase -- $x $text "\\&#[scan $y %x];" text
    }

    if {[regexp -- {&#0*1(2[89]|[345][0-9]);} $text]} {
        # Possibly just a warning for backward compatibility.
        unexpected [unex_condtype] \
            "non-standard use of entities between &#128; and &#159; as printable characters (really C1 control characters) instead of standard entities (e.g., &mdash; or &rsquo;) in \"$text\""
    }

    if {[regexp -- {&#0+;} $text]} {
        # All versions of XML prohibit this.
        unexpected error \
            "illegal use of &#0; entity in \"$text\""
    }

    # Remaining entities are case sensitive (or just dec).
    foreach {entity chars} $entities {
        regsub -all -- $entity $text $chars text
    }

    set text [break_preprocess $text]

    if {$flatten} {
        regsub -all -- "\n\[ \t\]*" $text " " text
    }

    return $text
}

# This expands all entities into Unicode characters.
# Unknown entities are silently replaced
# by a REPLACEMENT CHARACTER (U+FFFD).
proc ent_expand {text} {
    global uentities

    # Process hex; support leading zeros and -nocase.
    while {[regexp -nocase -- {&#x([0-9A-Z]+);} $text x y]} {
        set y [expr 0x$y]
        if {$y == 38} {
            # Skip ampersand.
            continue
        }
        regsub -all -nocase -- $x $text [format %c $y] text
    }

    # Process dec; support leading zeros.
    while {[regexp -- {&#([0-9]+);} $text x y]} {
        if {$y == 38} {
            # Skip ampersand.
            continue
        }
        regsub -all -- $x $text [format %c $y] text
    }

    # Known named entities are case sensitive.
    foreach {entity uchar} $uentities {
        regsub -all -- $entity $text $uchar text
    }

    # Replace unknown named entities.
    set p 0
    while {[regexp -start $p -indices -- {&[A-Za-z0-9._:-]*;} $text x]} {
        set p [lindex $x 0]
        set q [lindex $x 1]
        set ent [string range $text $p $q]
        if {![string compare $ent "&amp;"]} {
            # Skip ampersand.
            set p [expr $q + 1]
            continue
        }
        regsub -all -- {\.} $ent {\\.} ent
        regsub -all -start $p -- $ent $text "\uFFFD" text
    }

    # Ampersand.
    regsub -all -- {&(amp|#0*38|#[xX]0*26);} $text {\&} text

    # Replace DELETE and every C0 control char except \t, \n, and \r.
    regsub -all -- {[\0-\010\013\014\016-\037\177]+} $text "\uFFFD" text

    # Replace every C1 control char (including if entities between &#128; and
    # &#159; were mistakenly thought to be windows-1252 or something similar).
    regsub -all -- {[\x80-\x9F]+} $text "\uFFFD" text

    return $text
}

# This only replaces named entities that we know about, but that (x)html
# wouldn't, by numerical entities.
proc html_expand {text} {
    global xentities

    foreach {entity chars} $xentities {
        regsub -all -- $entity $text $chars text
    }

    return $text
}

proc html_quote {text} {
    foreach {e c} {amp & lt < gt >} {
        regsub -all -- "\[$c\]" $text "\\&$e;" text
    }

    return $text
}

proc tabs_expand_pre {line} {
    global pageno lineno

    set msg "pre-formatted output line [expr $lineno + 1] (on page $pageno)"

    if {[regexp -- {[\t]} $line]} {
        unexpected warning \
            "$msg contained tab characters which were expanded"

        while {[set x [string first "\t" $line]] >= 0} {
            set new [string range $line 0 [expr $x - 1]]
            append new [string repeat " " [expr 8 - ($x % 8)]]
            set line $new[string range $line [expr $x + 1] end]
        }
    }
    if {[regexp -- {[^ -~\xA0\u2011\u2060]} $line]} {
        # No-break spaces will be expanded later and are OK.
        unexpected error \
            "$msg contains illegal characters (control or otherwise)"
    }

    return $line
}

#       }}}2 Character expansion
#   }}}1 Low-level formatting

#   {{{1 xml2ref support


namespace eval ref {
    variable ref
    array set ref { uid 0 }

    variable parser [xml::parser]

    variable context
    #              element       verbatim        beginF  endF
    set context { {dummy/-1}
                  {rfc/0         no              yes     yes}
                  {front/1}
                  {title/2}
                  {author/2}
                  {organization/3}
                  {address/3}
                  {postal/4}
                  {street/5}
                  {city/5}
                  {region/5}
                  {code/5}
                  {country/5}
                  {phone/4}
                  {facsimile/4}
                  {email/4}
                  {uri/4}
                  {date/2}
                  {area/2}
                  {workgroup/2}
                  {keyword/2}
                  {abstract/2    yes}
                  {note/2        yes}
                }

    namespace export init fin transform
}

proc ref::init {} {
    variable ref

    set token [namespace current]::[incr ref(uid)]

    variable $token
    upvar 0 $token state

    catch { array unset state }

    return $token
}

proc ref::fin {token} {
    variable $token
    upvar 0 $token state

    foreach name [array names state] {
        unset state($name)
    }
    unset $token
}

proc ref::transform {token file {formats {}} } {
    global errorCode errorInfo
    global ifile
    global emptyA

    variable $token
    upvar 0 $token state

    catch { array unset emptyA }

    unex_init

    variable parser
    $parser configure \
            -elementstartcommand    "ref::element_start $token" \
            -elementendcommand      "ref::element_end   $token" \
            -characterdatacommand   "ref::cdata         $token" \
            -entityreferencecommand ""                          \
            -errorcommand           ref::oops                   \
            -entityvariable         emptyA                      \
            -final                  1                           \
            -reportempty            1

    set fd ""
    set data ""
    catch {
        set fd [open $file { RDONLY }]
        catch { fconfigure $fd -encoding binary -translation lf }
        set ifile $file
        set data [read $fd]
    }

    if {[catch { close $fd } result]} {
        log::entry $logT system $result
    }

    set data [prexml $data]

    set state(stack)    ""
    set state(body)     ""
    set state(number)   0
    set state(authors)  0
    set state(keywords) 0
    set state(verbatim) 0
    set state(silent)   0
    set state(formats)  $formats
    set state(info)     ""
    set state(mtime)    0
    set state(tprefix)  ""
    set state(tsuffix)  ""
    set state(descr)    ""

    set code [catch { $parser parse $data } result]
    set ecode $errorCode
    set einfo $errorInfo

    switch -- $code {
        0 {
            set result [list body  $state(body) \
                             info  $state(info) \
                             mtime $state(mtime)]
        }

        1 {
            if {[set i [llength $state(stack)]] > 0} {
                set text "File:    $file\nContext:"
                while {$i > 0} {
                    set frame [lindex $state(stack) [incr i -1]]
                    append text "\n    <[lindex $frame 0]"
                    foreach {k v} [lindex $frame 1] {
                        regsub -all -- \" $v {\&quot;} v
                        append text " $k=\"$v\""
                    }
                    append text ">"
                }
                append result "\n\n$text"
            }
        }
    }

    unset state(stack)    \
          state(body)     \
          state(number)   \
          state(authors)  \
          state(keywords) \
          state(verbatim) \
          state(silent)   \
          state(formats)  \
          state(info)     \
          state(mtime)    \
          state(tprefix)  \
          state(tsuffix)  \
          state(descr)

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

proc ref::element_start {token name {av {}} args} {
    global rfcitems

    variable $token
    upvar 0 $token state

    variable context

    array set options [list -empty 0]
    array set options $args

    set depth [llength $state(stack)]

    if {[set idx [lsearch -glob $context $name/$depth*]] >= 0} {
        set info [lindex $context $idx]
        if {[string compare [lindex $info 0] $name/$depth]} {
            set idx -1
        } elseif {![string compare [lindex $info 1] yes]} {
            set state(verbatim) 1
        }
    }

    set state(silent) 0
    if {($idx < 0) && ($state(verbatim))} {
        set idx 0
        set info ""
        if {[lsearch -exact {xref eref cref iref vspace} $name] >= 0} {
            set state(silent) 1
        }
    }

    # format*
    # is-also: BCP70
    if {$idx >= 0} {
        if {![string compare [lindex $info 2] yes]} {
            ref::start_$name $token $av
        } elseif {!$state(silent)} {
            switch -- $name {
                author {
                    incr state(authors)
                    set k $state(number),author$state(authors)
                    if {[info exists rfcitems($k)]} {
                        array set kv $rfcitems($k)
                        if {[info exists $kv(name)]} {
                            set name $kv(name)
                            # update initials/surname when
                            # rfc-index.xml is more robust...
                        }
                    }

                    array set nv $av
                    if {[info exists nv(fullname)]} {
                        append state(tsuffix) ", " $nv(fullname)
                    }
                }

                date {
                    set k $state(number)
                    array set nv $av
                    foreach n [list day year month] {
                        if {[info exists rfcitems($k,$n)]} {
                            set nv($n) $rfcitems($k,$n)
                        }
                    }
                    set av [array get nv]

                    array set dv [list day 1 year "" month ""]
                    array set dv $av
                    if {[string first "<dc:date>" $state(info)] < 0} {
                        catch {
                            set state(mtime) \
                                [clock scan "$dv(month) $dv(day), $dv(year)"]
                            append state(info) \
                                   "    <dc:date>" \
                                   [clock format $state(mtime) \
                                        -format "%Y-%m-%dT%T-00:00" \
                                        -gmt true] \
                                   "</dc:date>\n"
                        }
                    }
                }

                note {
                    if {[string first "</description>" $state(info)] < 0} {
                        append state(info) "    <description></description>\n"
                    }
                }
            }
            append state(body) "\n<$name"
            foreach {n v} $av {
                regsub -all -- {'} $v {\&apos;} v
                append state(body) " $n='$v'"
            }
            if {$options(-empty)} {
                append state(body) " /"
            }
            append state(body) >

            switch -- $name {
                title {
                    set k $state(number)
                    if {[info exists rfcitems($k,doc-title)]} {
                        append state(body) $rfcitems($k,doc-title)

                        if {[string first "<title>" $state(info)] < 0} {
                            append state(info) "    <title>" \
                                   $state(tprefix) \
                                   $rfcitems($k,doc-title) \
                                   "</title>\n"
                        }
                    }
                }
            }
        }
    }

    lappend state(stack) [list $name $av $idx ""]
}

proc ref::element_end {token name args} {
    variable $token
    upvar 0 $token state

    variable context

    array set options [list -empty 0]
    array set options $args

    set frame [lindex $state(stack) end]
    set state(stack) [lreplace $state(stack) end end]

    if {[set idx [lindex $frame 2]] >= 0} {
        set info [lindex $context $idx]
        if {![string compare [lindex $info 3] yes]} {
            ref::end_$name $token $frame
        } elseif {!$state(silent) && !$options(-empty)} {
            append state(body) </$name>
        }

        if {![string compare [lindex $info 1] yes]} {
            set state(verbatim) 0
        }
    }
    set state(silent) 0

    switch -- $name {
        title {
            if {([string first "<title>" $state(info)] >= 0)
                    && ([string first "</title>" $state(info)] < 0)} {
                append state(info) "</title>\n"
            }
        }

        t {}

        front - abstract {
            if {[string first "</description>" $state(info)] < 0} {
                if {[string first "<description>" $state(info)] >= 0} {
                    append state(info) "</description>\n"
                } else {
                    append state(info) "    <description></description>\n"
                }
            }
        }
    }
}

proc ref::cdata {token text} {
    global rfcitems

    variable $token
    upvar 0 $token state

    if {[string length [string trim $text]] <= 0} {
        return
    }

    set frame [lindex $state(stack) end]
    if {[set idx [lindex $frame 2]] < 0} {
        return
    }

    switch -- [lindex $frame 0] {
        title {
            set k $state(number)
            if {[info exists rfcitems($k,doc-title)]} {
                return
            }
        }
    }

    regsub -all -- "\r" $text "\n" text

    append state(body) $text

    switch -- [lindex $frame 0] {
        title {
            if {![info exists rfcitems($k,doc-title)]} {
                if {[string first "<title>" $state(info)] < 0} {
                    append state(info) "    <title>" $state(tprefix) $text
                } elseif {[string first "</title>" $state(info)] < 0} {
                    append state(info) $text
                }
            }
        }

        t {
            if {[string first "<description>" $state(info)] < 0} {
                append state(info) "    <description>" $text
            } elseif {[string first "</description>" $state(info)] < 0} {
                append state(info) $text
            }
        }
    }
}

proc ref::oops {args} {
    return -code error [join $args " "]
}

proc ref::start_rfc {token av} {
    variable $token
    upvar 0 $token state

    array set rfc [list obsoletes "" updates "" category info seriesNo ""]
    array set rfc $av
    if {[catch { set rfc(number) }]} {
        ref::oops "missing number attribute in rfc element"
    }
    set state(number) $rfc(number)

    set state(body) "<?xml version='1.0' encoding='UTF-8'?>\n\n"
    append state(body) "<reference anchor='RFC[format %04d $rfc(number)]'>\n"

    set state(tprefix) "RFC $rfc(number): "
}

proc ref::end_rfc {token frame} {
    global rfcitems

    variable $token
    upvar 0 $token state

    array set rfc [list obsoletes "" updates "" category info seriesNo ""]
    array set rfc [lindex $frame 1]

    set k $state(number)
    if {[info exists rfcitems($k,is-also)]} {
        array set rfc [list category [string range $rfcitems($k,is-also) 0 2] \
                            seriesNo [string range $rfcitems($k,is-also) 3 end]]
    }

    append state(body) "\n\n"
    if {([string compare [set x $rfc(category)] info]) \
            && ([string compare [set y $rfc(seriesNo)] ""])} {
        append state(body) "<seriesInfo name='[string toupper $x]' "
        append state(body) "value='$y' />\n"
    }
    append state(body) "<seriesInfo name='RFC' value='$rfc(number)' />\n"
    foreach format $state(formats) {
        append state(body) "<format"
        foreach {k v} $format {
            append state(body) " $k='$v'"
        }
        append state(body) " />\n"
    }
    append state(body) "</reference>\n"

    set url ""
    foreach format $state(formats) {
        catch { array unset fv }
        array set fv $format
        set url $fv(target)
        if {![string compare $fv(type) TXT]} {
            break
        }
    }
    if {[string compare $url ""]} {
        regsub -all -- {&} $url {\&amp;} url
        regsub -all -- {'} $url {\&apos;} url
        if {([string compare $state(tsuffix) ""]) \
                && ([set x [string first "</title>" $state(info)]] > 0)} {
            set info [string range $state(info) 0 [expr $x-1]]
            append info $state(tsuffix) [string range $state(info) $x end]
            set state(info) $info
        }
        set state(info) "\n<item rdf:about='$url'>\n    <link>$url</link>\n$state(info)</item>\n"
    } else {
        set state(info) ""
    }
}


#   }}}1 xml2ref support

#   {{{1 Some string manipulations


proc stindex {sindex len} {
    switch -regexp -- $sindex {
        {^[Ee][Nn][Dd]*$} {
            incr len -1

            return [expr $len[string range $sindex 3 end]]
        }

        {^[Ll][Ee][Nn]*$} {
            return [expr $len[string range $sindex 3 end]]
        }

        default {
            return $sindex
        }
    }
}

proc streplace {string first last {newstring ""} {magic 0}} {
    set first [stindex $first [set len [string length $string]]]
    set last [stindex $last $len]
    if {($first > $last) || ($first > $len) || ($last < 0)} {
        return $string
    }

    if {$first > 0} {
        set left [string range $string 0 [expr $first-1]]
    } else {
        set left ""
    }

    if {$magic} {
        set oldstring [string range $string \
                              [expr (($first) >= 0) ? ($first) : 0] \
                              [expr (($last) < $len) ? ($last) : $len-1]]
        if {$magic == 1} {
            regsub -all -- {[^\t\r\n]} $oldstring { } newstring
        } elseif {$magic >= 2} {
            # Remove, but preserve the line count.
            set newstring ""
            # EOL normalization is necessary with XML 1.1.
            set n [num_eols [str_norm_eol $oldstring]]
            if {$n > 0} {
                if {$magic == 2} {
                    append newstring {<!--} [string repeat "\n" $n] {-->}
                } else {
                    # $magic == 3
                    set newstring [string repeat "\n" $n]
                }
            }
        }
    }

    if {$last < $len} {
        set right [string range $string [expr $last+1] end]
    } else {
        set right ""
    }

    return $left$newstring$right
}

proc str_norm_eol {string {xml11 0}} {
    if {$xml11} {
        regsub -all -- "\r\n|\r\x85|\x85|\u2028|\r" $string "\n" string
    } else {
        regsub -all -- "\r\n?" $string "\n" string
    }
    return $string
}

proc str_pad_cmp {s1 s2} {
    set l1 [string length $s1]
    set l2 [string length $s2]
    if {$l1 < $l2} {
        set s1 [string repeat "0" [expr $l2 - $l1]]$s1
    } elseif {$l1 > $l2} {
        set s2 [string repeat "0" [expr $l1 - $l2]]$s2
    }
    set s1 [string toupper $s1]
    set s2 [string toupper $s2]

    return [string compare $s1 $s2]
}

#   }}}1 Some string manipulations

#   {{{1 artwork content processing
#       {{{2 namespace
namespace eval artwork {
    variable grammar
    variable grammar_program

    catch { array unset grammar }
    catch { array unset grammar_program }

    namespace eval tokenize {}
}
#       }}}2 namespace
#       {{{2 procs

proc artwork::validate_highlight {type text} {
    variable grammar
    variable grammar_program

    switch -- $type {
        abnf {
            append text "\n"
        }
        pib {
            # For now.
            set type mib
        }
    }

    if {   !(   [info exists grammar_program($type)]
             || [compile_grammar $type]
             || [info exists grammar($type)])
        || [catch { info body tokenize::$type }]} {
        return {-1 {} [generic_divs]}
    }

    # Through upvar, this read $text and sets $tokens and $spans.
    tokenize::$type

    set max_idx 0
    if {[info exists grammar_program($type)]} {
        foreach {cnt spans1 divs1} [grammar_program_parse $type] {break}
    } else {
        array set rule $grammar($type)

        set rn [lindex $grammar($type) 0]
        foreach {cnt spans1 divs1} [check_rule $rn 0] {break}
    }
    set spans [lsort -index 1 -integer [concat $spans $spans1]]

    # Convert divs from character-oriented to line-oriented.
    set divs {}
    set p0 0
    set d0 0
    foreach div [lsort -index 0 -integer $divs1] {
        incr d0 [num_eols [string range $text $p0 [expr [lindex $div 0] - 1]]]
        set p0 [lindex $div 0]
        set d1 [expr $p0 + [lindex $div 1] - 2]
        set d1 [expr [num_eols [string range $text $p0 $d1]] + 1]
        lappend divs [list $d0 $d1]
    }

    set textlen [string length $text]
    set tokcnt [llength $tokens]
    if {![set valid [expr $cnt >= $tokcnt]]} {
        if {$max_idx >= 0 && $max_idx < $tokcnt} {
            set pos [lindex [lindex $tokens $max_idx] 1]
        } else {
            set pos 0
        }
        while {[llength $spans] > 0 && $pos <= [lindex [lindex $spans end] 1]} {
            set spans [lrange $spans 0 end-1]
        }
        lappend spans [list err $pos [expr $textlen - $pos]]
    } elseif {[lsearch0 $spans err] >= 0} {
        # In case of temporarily ignored kludges.
        set valid 0
    }

    return [list $valid $spans $divs]
}

proc artwork::generic_divs {} {
    # We do not modify $text.
    upvar text text

    # Blank lines delimit each generic div.
    set divs {}
    set pos 0
    set d0 -1
    set l 0
    set z [string length $text]

    while {$pos < $z} {
        if {[regexp -indices -start $pos -- "\n" $text x]} {
            set a [lindex $x 0]
            set x [string range $text $pos $a]
        } else {
            set a $z
            set x [string range $text $pos end]
        }

        if {[string compare [string trim $x] ""]} {
            if {$d0 < 0} {
                set d0 $l
                set d1 1
            } else {
                incr d1
            }
        } elseif {$d0 >= 0} {
            lappend divs [list $d0 $d1]
            set d0 -1
        }
        incr l
        set pos [expr $a + 1]
    }

    if {$d0 >= 0} {
        lappend divs [list $d0 $d1]
    }

    return $divs
}

proc artwork::compile_grammar {type} {
    return 0
}

proc artwork::grammar_program_parse {type} {
    variable grammar_program
    # We use these upvars read-only.
    upvar tokens tokens
    # We use this upvar read-write.
    upvar max_idx max_idx

    array set table $grammar_program($type)
    set spans {}
    set divs {}
    set stack {}
    set state 0
    set i 0

    while {1} {
        set nexti [expr $i + 1]
        set tok [lindex $tokens $i]
        set x [list [lindex $tok 0] $state]
        if {[info exists table($x)]} {
            set do $table($x)
        } else {
            set x [list * $state]
            if {[catch { set do $table($x) }]} {
                set do {{err}}
            }
        }
        foreach d $do {
            set d0 [lindex $d 0]
            switch -- $d0 {
                push {
                    lappend stack [concat $i [lrange $d 1 end]]
                    continue
                }
                pop - span-top - div-top - check - goto-top {
                    if {[llength $stack]} {
                        set top [lindex $stack end]
                        set tok0 [lindex $tokens [lindex $top 0]]
                        set i0 [lindex $tok0 1]
                        set i1 [expr [lindex $tok 1] - $i0 + [lindex $tok 2]]
                    } else {
                        set ret -1
                        break
                    }
                }
                span {
                    lappend spans [concat [lindex $d 1] [lrange $tok 1 2]]
                    continue
                }
                div {
                    set i0 [lindex $tok 1]
                    set i1 [lindex $tok 2]
                    lappend divs [lrange $tok 1 2]
                    continue
                }
                redo {
                    set state [lindex $d 1]
                    set nexti [expr $i - 0[lindex $d 2]]
                    continue
                }
                goto {
                    set state [lindex $d 1]
                    continue
                }
                skip-next {
                    if {[llength $d] > 1} {
                        incr nexti [lindex $d 1]
                    } else {
                        incr nexti
                    }
                    continue
                }
                done    { set ret $i; break }
                default { set ret -1; break }
            }
            switch -- $d0 {
                pop  { set stack [lreplace $stack end end] }
                span-top {
                    lappend spans [list [lindex $d 1] $i0 $i1]
                }
                div-top {
                    lappend divs [list $i0 $i1]
                }
                check {
                    set c [concat [lrange $top 1 end] [lindex $tok0 0]]
                    set k [llength $d]
                    for {set j 1} {$j < $k} {incr j} {
                        if {[lsearch -exact $c [lindex $d $j]] >= 0} {
                            break
                        }
                    }
                    if {$j >= $k} {
                        set ret -1
                        break
                    }
                }
                goto-top { set state [lindex $top 1] }
            }
        }
        if {[info exists ret]} {
            set max_idx $i
            break
        }
        set i $nexti
    }

    return [list $ret $spans $divs]
}

proc artwork::check_rule {rulename idx} {
    # We use these upvars read-only.
    upvar tokens tokens rule rule
    # We use this upvar read-write.
    upvar max_idx max_idx

    set tok [lindex $tokens $idx]
    if {![info exists rule($rulename)]} {
        # Assume it's an implicit terminal with no span.
        if {[string compare $rulename [lindex $tok 0]]} {
            set cnt -1
        } else {
            set cnt  1
            if {$max_idx <= $idx} {
                set max_idx [expr $idx + 1]
            }
        }
        return [list $cnt {} {}]
    }

    foreach {ruletok ruletype ruledef} $rule($rulename) {break}
    switch -- $ruletype {
        * {
            if {$idx < [llength $tokens]} {
                set rulename [lindex $tok 0]
            } else {
                set rulename "{no-such-rule}"
            }
            set ruletype .
        }
    }
    switch -- $ruletype {
        . {
            if {[string compare $rulename [lindex $tok 0]]} {
                return {-1 {} {}}
            }
            if {$max_idx <= $idx} {
                set max_idx [expr $idx + 1]
            }
            set i0 [lindex $tok 1]
            set i1 [lindex $tok 2]
            switch -- $ruletok {
                "" {
                    return {1 {} {}}
                }
                div {
                    # This matches an explicit terminal rule with a div.
                    return [list 1 {} [list [list $i0 $i1]]]
                }
                default {
                    # This matches an explicit terminal rule with a span.
                    return [list 1 [list [list $ruletok $i0 $i1]] {}]
                }
            }
        }
        = { set n  0 }
        | { set n -1 }
    }

    set spans {}
    set divs {}
    set i $idx
    foreach {rn rep} $ruledef {
        while {1} {
            foreach {n s d} [check_rule $rn $i] {break}
            if {$n >= 0} {
                switch -- $rep {
                    ! { return [list -1 {} {}] }
                }
                incr i $n
                set spans [concat $spans $s]
                set divs  [concat $divs  $d]
                switch -- $rep {
                    +     { set rep * }
                    1 - ? { break }
                }
            } else {
                switch -- $rep {
                    ! {
                        switch -- $ruletype {
                            = { set n 0 }
                        }
                    }
                    * - ? { set n 0 }
                }
                break
            }
        }
        switch -- $ruletype {
            = {
                if {$n < 0} {
                    set spans {}
                    set divs  {}
                    break
                }
            }
            | {
                if {$n >= 0} {
                    break
                }
            }
        }
    }
    if {$n >= 0} {
        set cnt [expr $i - $idx]
        if {$max_idx < $i} {
            set max_idx $i
        }
    } else {
        set cnt -1
    }
    if {$cnt > 0 && [string compare $ruletok ""]} {
        set i0 [lindex $tok 1]
        set tok1 [lindex $tokens [expr $idx + $cnt - 1]]
        set i1 [expr [lindex $tok1 1] - $i0 + [lindex $tok1 2]]
        switch -- $ruletok {
            div     { lappend divs        [list          $i0 $i1]  }
            default { set     spans [list [list $ruletok $i0 $i1]] }
        }
    }

    return [list $cnt $spans $divs]
}

#       }}}2 procs
#       {{{2 grammars
#           {{{3 abnf
#               {{{4 proc artwork::tokenize::abnf

# We introduce a tokenizer, because doing everything off of the original
# grammar with a generic parser in Tcl proves to be way too slow.
proc artwork::tokenize::abnf {} {
    # We do not modify $text.
    upvar text text tokens tokens spans spans

    foreach x {
        ALPHA BIT CHAR CR CRLF CTL DIGIT DQUOTE
        HEXDIG HTAB LF LWSP OCTET SP VCHAR WSP
    } {
        # ABNF core rule names.
        set Chash($x) core
    }

    set pos 0
    set tokens {}
    set spans {}
    set z [string length $text]

    # According to RFC 4234, Section 2.2:
    #   For visual ease, rule definitions are left aligned.
    #   When a rule requires multiple lines,
    #   the continuation lines are indented.
    #   The left alignment and indentation are relative to the first lines
    #   of the ABNF rules and need not match the left margin of the document.

    # For some reason, this behavior wasn't itself encoded in ABNF!
    # We will try to maintain a notion of per-rule left margin.
    # Negative means were currently outside of a rule.
    # The nl token mean the end of a rule.
    set margin -1

    while {$pos < $z} {
        if {[regexp -indices -start $pos -- "\[\"<;\]" $text x]} {
            set a [lindex $x 0]
            switch -- [string range $text $a [lindex $x 1]] {
                \" { set cc " !#-~";  set d "\""; set tt char-val  }
                <  { set cc " -=?-~"; set d ">";  set tt prose-val }
                ;  { set cc "\t -~";  set d "\n"; set tt comment   }
            }
        } else {
            set a $z
        }
        while {1} {
            set p0 $pos
            set m [expr ($margin >= 0) ? -1 : 0]
            while {1} {
                if {[regexp -indices -start $pos -- {\A[ \t]+} $text x]} {
                    set pos [expr [lindex $x 1] + 1]
                    if {$m < 0} {
                        # A non-empty line continues with wsp (so far).
                        set nt wsp
                    } else {
                        set s [string range $text [lindex $x 0] [lindex $x 1]]
                        # Accounts for tabs.
                        while {[set x [string first "\t" $s]] >= 0} {
                            incr m $x
                            incr m [expr 8 - ($m % 8)]
                            set s [string range $s [expr $x + 1] end]
                        }
                        incr m [string length $s]
                    }
                }
                if {$margin >= 0} {
                    if {$m > $margin} {
                        # The wsp token is a form of rule continuation.
                        set nt wsp
                    } elseif {$m >= 0} {
                        # Keep nt as nl, if so, but never again wsp.
                        set margin -1
                    }
                }
                if {![regexp -start $pos -- {\A\n} $text]} {
                    break
                }
                # The nl token would mean the end of a rule.
                set nt nl
                incr pos
                set m 0
            }
            if {[info exists nt]} {
                if {![string compare [lindex [lindex $tokens end] 0] wsp]} {
                    # Speed up parsing ("wsp *" can become "wsp ?", "wsp +" can
                    # become "wsp 1", and "wsp *  nl 1" can become "nl 1").
                    set tokens [lreplace $tokens end end]
                }
                # Pretend it's one character long to minimize any current div.
                lappend tokens [list $nt $p0 1]
                unset nt
            }
            if {$margin < 0} {
                set margin $m
            }

            if {$pos >= $a} {
                break
            }
            if {[regexp -start $pos -- {\A[A-Za-z][A-Za-z0-9-]*} $text x]} {
                # RFC 4234, Section 2.1:  Rule names are case-insensitive.
                if {[info exists Chash([string toupper $x])]} {
                    set tok core
                } else {
                    set tok name
                }
            } elseif {[regexp -start $pos -expanded -- \
                              {\A%([bB][01]+((\.[01]+)+|-[01]+)?
                                  |[dD][0-9]+((\.[0-9]+)+|-[0-9]+)?
                                  |[xX][0-9A-Fa-f]+((\.[0-9A-Fa-f]+)+
                                                   |-[0-9A-Fa-f]+)?)} \
                              $text x]} {
                if {   [regexp -- {^%.([^-]+)-([^-]+)$} $x xx yy zz]
                    && [str_pad_cmp $yy $zz] != -1} {
                    set tok err
                } else {
                    set tok num-val
                }
            } elseif {[regexp -start $pos -- {\A=/?} $text x]} {
                set tok eq
            } elseif {[regexp -start $pos -- \
                              {\A([0-9]+|[0-9]*\*[0-9]*)} $text x]} {
                set tok repeat
            } elseif {[regexp -start $pos -- {\A[](/)[]} $text x]} {
                switch -- $x {
                    [ { set tok lsqb  }
                    ] { set tok rsqb  }
                    default { set tok $x }
                }
            } else {
                set tok err
            }
            switch -- $tok {
                err {
                    lappend spans [list err $pos [expr $z - $pos]]
                    set pos $z
                    break
                }
            }
            set len [string length $x]
            lappend tokens [list $tok $pos $len]
            incr pos $len
        }
        if {$pos >= $z} {
            break
        }
        incr pos
        regexp -start $pos -indices -- "\\A\[$cc\]*" $text x
        set len [expr [lindex $x 1] - $pos + 1]
        switch -- $tt {
            comment { lappend spans [list com [expr $pos - 1] [expr $len + 1]] }
            default { lappend tokens [list $tt $pos $len] }
        }
        incr pos $len
        if {$pos >= $z} {
            break
        }
        if {![regexp -start $pos -- "\\A$d" $text]} {
            lappend spans [list err $pos [expr $z - $pos]]
            set pos $z
            break
        }
        switch -- $tt {
            comment {
                # We rely on the next iteration to produces the wsp or nl token.
            }
            default { incr pos }
        }
    }
}

#               }}}4 proc artwork::tokenize::abnf
#               {{{4 artwork::grammar(abnf)

set artwork::grammar(abnf) {
    rulelist {"" = {rule-nl +}}
    rule-nl {
        ""  | {
            rule 1
            nl   1}}
    rule {
        div = {
            ruledef       1
            wsp           ?
            eq            1
            alternation   1
            nl            1}}
    ruledef {
        def | {
            name 1
            core 1}}
    nameuse {id  = {name 1}}
    coreuse {key = {core 1}}
    alternation {
        ""  = {
            concatenation  1
            /concatenation *}}
    /concatenation {
        ""  = {
            /             1
            concatenation 1}}
    concatenation {
        ""  = {
            wsp        ?
            repetition 1
            wsp-rep    *
            wsp        ?}}
    wsp-rep {
        ""  = {
            wsp        1
            repetition 1}}
    repetition {
        ""  = {
            repeat  ?
            element 1}}
    repeat {rep . {}}
    element {
        ""  | {
            char-val  1
            num-val   1
            nameuse   1
            group     1
            option    1
            coreuse   1
            prose-val 1}}
    group {
        ""  = {
            (           1
            alternation 1
            )           1}}
    option {
        ""  = {
            lsqb        1
            alternation 1
            rsqb        1}}
    char-val  {str . {}}
    num-val   {val . {}}
    prose-val {str . {}}
}

# First {token state} pair-items are hash keys and must be in the
# same canonical form as would be produced by [list token state].
set artwork::grammar_program(abnf) {
    {{} 1}  {done}

    {nl 0}  {{goto 1}}
    {nl 1}  {}
    {nl 7}  {{check rule} div-top pop {goto 1}}
    {nl 8}  {{redo 7}}

    {name 0}  {{push rule} {span def} {goto 2}}
    {name 1}  {{redo 0}}
    {name 4}  {{span id} {goto 7}}
    {name 5}  {{redo 4}}
    {name 6}  {{redo 4}}
    {name 8}  {{redo 4}}
    {name 9}  {{redo 4}}

    {core 0}  {{push rule} {span def} {goto 2}}
    {core 1}  {{redo 0}}
    {core 4}  {{span key} {goto 7}}
    {core 5}  {{redo 4}}
    {core 6}  {{redo 4}}
    {core 8}  {{redo 4}}
    {core 9}  {{redo 4}}

    {wsp 2}  {{goto 3}}
    {wsp 4}  {{goto 5}}
    {wsp 7}  {{goto 8}}

    {eq 2}  {{goto 4}}
    {eq 3}  {{goto 4}}

    {repeat 4}  {{span rep} {goto 6}}
    {repeat 5}  {{redo 4}}
    {repeat 8}  {{span rep} {goto 9}}

    {char-val 4}  {{span str} {goto 7}}
    {char-val 5}  {{redo 4}}
    {char-val 6}  {{redo 4}}
    {char-val 8}  {{redo 4}}
    {char-val 9}  {{redo 4}}

    {num-val 4}  {{span val} {goto 7}}
    {num-val 5}  {{redo 4}}
    {num-val 6}  {{redo 4}}
    {num-val 8}  {{redo 4}}
    {num-val 9}  {{redo 4}}

    {prose-val 4}  {{span str} {goto 7}}
    {prose-val 5}  {{redo 4}}
    {prose-val 6}  {{redo 4}}
    {prose-val 8}  {{redo 4}}
    {prose-val 9}  {{redo 4}}

    {( 4}  {push}
    {( 5}  {{redo 4}}
    {( 6}  {{redo 4}}
    {( 8}  {{redo 4}}
    {( 9}  {{redo 4}}

    {lsqb 4}  {push}
    {lsqb 5}  {{redo 4}}
    {lsqb 6}  {{redo 4}}
    {lsqb 8}  {{redo 4}}
    {lsqb 9}  {{redo 4}}

    {/ 7}  {{goto 4}}
    {/ 8}  {{goto 4}}

    {) 7}  {{check (} pop}
    {) 8}  {{redo 7}}

    {rsqb 7}  {{check lsqb} pop}
    {rsqb 8}  {{redo 7}}
}

#               }}}4 artwork::grammar(abnf)
#           }}}3 abnf
#           {{{3 mib
#               {{{4 proc artwork::tokenize::mib

proc artwork::tokenize::mib {} {
    # We do not modify $text.
    upvar text text tokens tokens spans spans

    # Switch statements are not implemented with hashes, so fake it.
    foreach x {
        ALL APPLICATION
        BEGIN
        CHOICE
        DEFINITIONS
        END EXPORTS
        FROM
        IA5String IDENTIFIER IMPLICIT IMPLIED IMPORTS INCLUDES INTEGER
        LAST-UPDATED
        MAX
        NULL
        OBJECT OCTET OF
        SEQUENCE SIZE STRING SYNTAX
        UNIVERSAL

        MACRO
        NOTATION
        TYPE
        Update
        VALUE

        ACCESS AUGMENTS
        CONTACT-INFO CREATION-REQUIRES
        BITS
        DEFVAL DESCRIPTION DISPLAY-HINT
        ENTERPRISE EXTENDS
        GROUP
        INDEX INSTALL-ERRORS
        MANDATORY-GROUPS MAX-ACCESS MIN-ACCESS MODULE
        NOTIFICATIONS
        OBJECTS ORGANIZATION
        PIB-ACCESS PIB-DEFINITIONS PIB-INDEX PIB-MIN-ACCESS
        PIB-REFERENCES PIB-TAG POLICY-ACCESS PRODUCT-RELEASE
        REFERENCE REVISION
        STATUS SUBJECT-CATEGORIES SUPPORTS SYNTAX
        UNIQUENESS UNITS
        VARIABLES VARIATION
        WRITE-SYNTAX
    } {
        # ASN.1 reserved words (current and deprecated)
        # and IETF reserved words.
        set Uhash($x) self
    }

    foreach x {
        Counter32 Counter64
        Gauge32
        Integer32 Integer64 IpAddress
        Opaque
        TimeTicks
        Unsigned32 Unsigned64
    } {
        # IETF application-defined types names.
        set Uhash($x) Itn
    }

    foreach x {
        AGENT-CAPABILITIES
        MODULE-COMPLIANCE MODULE-IDENTITY
        NOTIFICATION-GROUP NOTIFICATION-TYPE
        OBJECT-GROUP OBJECT-IDENTITY OBJECT-TYPE
        TEXTUAL-CONVENTION TRAP-TYPE
    } {
        # IETF macro names.
        set Uhash($x) Imn
    }

    foreach x {
        ABSENT ABSTRACT-SYNTAX ANY AUTOMATIC
        BIT BMPString BOOLEAN BY
        CHARACTER CLASS COMPONENT COMPONENTS CONSTRAINED
        CONTAINING
        DEFAULT DEFINED
        EMBEDDED ENCODED ENCODING-CONTROL ENUMERATED
        EXCEPT EXPLICIT EXTENSIBILITY EXTERNAL
        FALSE
        GeneralizedTime GeneralString GraphicString
        INSTRUCTIONS INTERSECTION ISO646String
        MIN MINUS-INFINITY
        NOT-A-NUMBER NumericString
        ObjectDescriptor OPTIONAL
        PDV PLUS-INFINITY PRESENT PrintableString PRIVATE
        REAL RELATIVE-OID
        SET
        T61String TAGS TeletexString TRUE TYPE-IDENTIFIER
        UNION UNIQUE UniversalString UTCTime UTF8String
        VideotexString VisibleString
        WITH
    } {
        # ASN.1 reserved words (forbidden).
        set Uhash($x) err
    }

    foreach x {
        type
        value

        accessible-for-notify all
        current
        deprecated
        install install-notify
        mandatory
        not-accessible notify not-implemented
        obsolete optional
        read-create read-only read-write report-only
        write-only
    } {
        # ASN.1 type and value (deprecated) and IETF ids.
        set Lhash($x) self
    }

    set pos 0
    set tokens {}
    set spans {}
    set z [string length $text]
    set in_macro 0

    while {$pos < $z} {
        if {[regexp -indices -start $pos -- "--|\"" $text x]} {
            set a [lindex $x 0]
            switch -- [string range $text $a [lindex $x 1]] {
                \" { set tt quoted-string }
                -- { set tt comment       }
            }
        } else {
            set a $z
        }
        while {1} {
            if {[regexp -indices -start $pos -- {\A[ \t\n]+} $text x]} {
                set pos [expr [lindex $x 1] + 1]
            }
            if {$pos >= $a} {
                break
            }
            set p2 -1
            set len -1
            if {[regexp -start $pos -- {\A[A-Z](-?[A-Za-z0-9]+)*} $text x]} {
                set len [string length $x]
                if {[info exists Uhash($x)]} {
                    switch -- $Uhash($x) {
                        self {
                            # ASN.1 reserved words (current and deprecated)
                            # and IETF reserved words.
                            set tok $x
                            # Cheat.
                            lappend spans [list key $pos $len]

                            # XXX
                            switch -- $x {
                                MACRO { incr in_macro }
                                END { if {$in_macro > 0} {incr in_macro -1} }
                            }
                        }
                        Itn { set prefix_tok /Itn; set tok $x }
                        Imn { set prefix_tok /Imn; set tok $x }
                        err { set tok err }
                    }
                } else {
                    set tok type-ref
                }
            } elseif {[regexp -start $pos -- {\A[a-z](-?[A-Za-z0-9]+)*} $text x]} {
                # Hyphens are allowed for backward compatibility with SMIv1.

                # Extra token to avoid considering them all.
                set prefix_tok /id

                set len [string length $x]
                if {[info exists Lhash($x)]} {
                    set tok $x
                } else {
                    set tok id
                }
            } elseif {   [regexp -start $pos -indices -- \
                                 {\A'([01]{8})*'[Bb]} $text x]
                      || [regexp -start $pos -indices -- \
                                 {\A'([0-9A-Fa-f]{2})*'[Hh]} $text x]} {
                set tok radix-string
                incr pos
                set p2 [expr [lindex $x 1] + 1]
                set len [expr $p2 - $pos - 2]
            } elseif {[regexp -start $pos -- {\A::=} $text x]} {
                set tok ::=

                # XXX
                if {$in_macro > 0} {
                    set tx [lindex $tokens end]
                    switch -- [lindex $tx 0] {
                        type-ref {
                            set tokens [lreplace $tokens end end \
                                        [lreplace $tx 0 0 type-ref-macsyn]]
                        }
                    }
                }
            } elseif {[regexp -start $pos -- {\A\.\.} $text x]} {
                set tok ..
            } elseif {[regexp -start $pos -- {\A[0-9]+} $text x]} {
                set len [string length $x]
                if {![string compare [string index $x 0] "0"]} {
                    if {$len == 1} {
                        set tok zero
                    } else {
                        set tok err
                    }
                } elseif {$len < 10} {
                    set tok positive31
                } elseif {$len == 10} {
                    if {[string compare $x "2147483648"] < 0} {
                        set tok positive31
                    } elseif {[string compare $x "4294967296"] < 0} {
                        set tok positive32
                    } else {
                        set tok positive63
                    }
                } elseif {$len < 19} {
                    set tok positive63
                } elseif {$len == 19} {
                    if {[string compare $x "9223372036854775808"] < 0} {
                        set tok positive63
                    } else {
                        set tok positive64
                    }
                } elseif {$len == 20} {
                    if {[string compare $x "18446744073709551616"] < 0} {
                        set tok positive64
                    } else {
                        set tok positive-big
                    }
                } else {
                    set tok positive-big
                }
            } elseif {[regexp -start $pos -- {\A-[0-9]+} $text x]} {
                set len [string length $x]
                if {![string compare [string index $x 1] "0"]} {
                    set tok err
                } elseif {$len < 11} {
                    set tok negative31
                } elseif {$len == 11} {
                    if {[string compare $x "-2147483648"] <= 0} {
                        set tok negative31
                    } else {
                        set tok negative63
                    }
                } elseif {$len < 20} {
                    set tok negative63
                } elseif {$len == 20} {
                    if {[string compare $x "-9223372036854775808"] <= 0} {
                        set tok negative63
                    } else {
                        set tok negative-big
                    }
                } else {
                    set tok negative-big
                }
            } elseif {[regexp -start $pos -- {\A[]{(|,--.;:)}[]} $text x]} {
                switch -- $x {
                    ;  { set tok semi }
                    [  { set tok lsqb }
                    ]  { set tok rsqb }
                    \{ { set tok lcub }
                    \} { set tok rcub }
                    default { set tok $x }
                }
            } else {
                set tok err
            }
            switch -glob -- $tok {
                zero - positive* - negative* {
                    # Cheat.
                    lappend spans [list val $pos $len]
                }
                err {
                    lappend spans [list err $pos [expr $z - $pos]]
                    set pos $z
                    break
                }
            }
            if {$len < 0} {
                set len [string length $x]
            }
            if {[info exists prefix_tok]} {
                lappend tokens [list $prefix_tok $pos $len]
                unset prefix_tok
            }
            lappend tokens [list $tok $pos $len]
            if {$p2 >= 0} {
                set pos $p2
            } else {
                incr pos $len
            }
        }
        if {$pos >= $z} {
            break
        }
        switch -- $tt {
            quoted-string {
                lappend tokens [list quot $pos 1]
                incr pos

                while {1} {
                    regexp -start $pos -indices -- {\A[\t !#-~]*} $text x
                    set p2 [expr [lindex $x 1] + 1]
                    if {$p2 > $pos} {
                        lappend tokens [list qstr $pos [expr $p2 - $pos]]
                        set pos $p2
                    }
                    set x [string index $text $pos]
                    if {![string compare $x \"]} {
                        lappend tokens [list quot $pos 1]
                        incr pos
                        break
                    }
                    if {[string compare $x "\n"]} {
                        lappend spans [list err $pos [expr $z - $pos]]
                        set pos $z
                        break
                    }
                    incr pos
                    if {[regexp -start $pos -indices -- {\A[\t ]+} $text x]} {
                        # Eliminate indentation white-space on subsequent lines.
                        set pos [expr [lindex $x 1] + 1]
                    }
                }
            }
            comment {
                regexp -start $pos -indices -- \
                       {\A--([^-\n]|----|-[^-\n])*} $text x
                set p2 [expr [lindex $x 1] + 1]
                if {   $p2 < $z
                    && ![string compare [string index $text $p2] "-"]} {
                    incr p2
                    if {![string compare [string index $text $p2] "-"]} {
                        incr p2
                    }
                }
                lappend spans [list com $pos [expr $p2 - $pos]]
                set pos $p2
            }
        }
    }
}

#               }}}4 proc artwork::tokenize::mib
#               {{{4 artwork::grammar(mib)

set artwork::grammar(mib) {
    mib-file {"" = {module *}}
    module {
        div = {
            type-ref-def   1
            lcub-oid-rcub  ?
            definitions-kw 1
            ::=            1
            BEGIN          1
            exports-stmt   ?
            imports-stmt   ?
            definition     *
            END            1}}
    definitions-kw {
        ""  | {
            DEFINITIONS     1
            PIB-DEFINITIONS 1}}

    exports-stmt {
        div = {
            EXPORTS  1
            exported ?
            semi     1}}
    exported {
        ""  | {
            ALL            1
            export-id-list 1}}
    export-id-list {
        ""  = {
            export-id  1
            ,export-id *}}
    ,export-id {
        ""  = {
            ,         1
            export-id 1}}
    export-id {
        ""  | {
            id-use              1
            type-ref-use        1
            IpAddress-use       1
            Opaque-use          1
            TimeTicks-use       1
            IETF-macro-name-use 1}}

    imports-stmt {
        div = {
            IMPORTS  1
            imported *
            semi     1}}
    imported {
        ""  = {
            import-id-list 1
            FROM           1
            type-ref-use   1}}
    import-id-list {
        ""  = {
            import-id  1
            ,import-id *}}
    ,import-id {
        ""  = {
            ,         1
            import-id 1}}
    import-id {
        ""  | {
            semi                !
            id-use              1
            type-ref-use        1
            BITS                1
            MANDATORY-GROUPS    1
            IETF-macro-name-use 1
            IETF-type-name-use  1}}

    definition {
        div | {
            END        !
            id-defn1   1
            tr-defn1   1
            macro-defn 1}}

    id-defn1 {
        ""  = {
            id-def   1
            id-defn2 1}}

    id-defn2 {
        ""  | {
            value-defn       1
            obj-type-defn    1
            obj-group-defn   1
            mod-compl-defn   1
            mod-id-defn      1
            obj-id-defn      1
            notif-type-defn  1
            notif-group-defn 1
            trap-type-defn   1
            agent-caps-defn  1}}

    tr-defn1 {
        ""  | {
            type-defn 1
            tr-defn2  1}}

    tr-defn2 {
        ""  = {
            type-ref-err 1
            value-defn   1}}

    mod-id-defn {
        ""  = {
            MODULE-IDENTITY-use 1
            subj-cats-clause    ?
            LAST-UPDATED        1
            quoted-string       1
            ORGANIZATION        1
            quoted-string       1
            CONTACT-INFO        1
            quoted-string       1
            description-clause  1
            revision-clause     *
            ::=                 1
            lcub-oid-rcub       1}}
    subj-cats-clause {
        ""  = {
            SUBJECT-CATEGORIES 1
            lcub               1
            cat-ids            1
            rcub               1}}
    cat-ids {
        ""  | {
            IETF-pib-all-kw   1
            id(positive)-list 1}}
    description-clause {
        div = {
            DESCRIPTION   1
            quoted-string 1}}
    revision-clause {
        div = {
            REVISION           1
            quoted-string      1
            description-clause 1}}

    obj-id-defn {
        ""  = {
            OBJECT-IDENTITY-use 1
            status-clause       1
            description-clause  1
            ref-clause          ?
            ::=                 1
            lcub-oid-rcub       1}}
    status-clause {
        ""  = {
            STATUS            1
            IETF-status-id-kw 1}}
    ref-clause {
        ""  = {
            REFERENCE     1
            quoted-string 1}}

    obj-type-defn {
        ""  = {
            OBJECT-TYPE-use    1
            syntax-clause      1
            units-clause       ?
            access-clause      ?
            sppi-refs-clause   ?
            sppi-tag-clause    ?
            status-clause      1
            description-clause ?
            sppi-errors-clause ?
            ref-clause         ?
            index-clause       ?
            mib-index-clause   ?
            sppi-unique-clause ?
            defval-clause      ?
            ::=                1
            lcub-oid-rcub      1}}
    syntax-clause {
        ""  = {
            SYNTAX 1
            syntax 1}}
    units-clause {
        ""  = {
            UNITS         1
            quoted-string 1}}
    access-clause {
        ""  | {
            max-access-clause 1
            pib-access-clause 1}}
    max-access-clause {
        ""  = {
            max-access-kw     1
            IETF-access-id-kw 1}}
    max-access-kw {
        ""  | {
            MAX-ACCESS 1
            ACCESS     1}}
    pib-access-clause {
        ""  = {
            pib-access-kw         1
            IETF-pib-access-id-kw 1}}
    pib-access-kw {
        ""  | {
            POLICY-ACCESS 1
            PIB-ACCESS    1}}
    sppi-refs-clause {
        ""  = {
            PIB-REFERENCES 1
            lcub-oid-rcub  1}}
    sppi-tag-clause {
        ""  = {
            PIB-TAG       1
            lcub-oid-rcub 1}}
    sppi-errors-clause {
        ""  = {
            INSTALL-ERRORS        1
            lcub                  1
            id(positive)-list     1
            rcub                  1}}
    index-clause {
        ""  | {
            pib-index-clause 1
            augments-clause  1
            extends-clause   1}}
    pib-index-clause {
        ""  = {
            PIB-INDEX     1
            lcub-oid-rcub 1}}
    augments-clause {
        ""  = {
            AUGMENTS      1
            lcub-oid-rcub 1}}
    extends-clause {
        ""  = {
            EXTENDS       1
            lcub-oid-rcub 1}}
    mib-index-clause {
        ""  = {
            INDEX           1
            lcub            1
            index-type-list 1
            rcub            1}}
    index-type-list {
        ""  = {
            index-type  1
            ,index-type *}}
    ,index-type {
        ""  = {
            ,          1
            index-type 1}}
    index-type {
        ""  = {
            IMPLIED ?
            oid     1}}
    sppi-unique-clause {
        ""  = {
            UNIQUENESS 1
            lcub       1
            oid-list   ?
            rcub       1}}
    defval-clause {
        ""  = {
            DEFVAL 1
            lcub   1
            defval 1
            rcub   1}}
    defval {
        ""  | {
            int                  1
            radix-string         1
            quoted-string        1
            id-use               1
            lcub-oid-defval-rcub 1
            lcub-id-list-rcub    1}}
    lcub-oid-defval-rcub {
        ""  = {
            lcub          1
            sub-id-defval +
            rcub          1}}
    lcub-id-list-rcub {
        ""  = {
            lcub    1
            id-list ?
            rcub    1}}

    notif-type-defn {
        ""  = {
            NOTIFICATION-TYPE-use 1
            objs-clause           ?
            status-clause         1
            description-clause    1
            ref-clause            ?
            ::=                   1
            lcub-oid-rcub         1}}
    objs-clause {
        ""  = {
            OBJECTS            1
            lcub-oid-list-rcub 1}}

    trap-type-defn {
        ""  = {
            TRAP-TYPE-use      1
            ENTERPRISE         1
            oid                1
            vars-clause        ?
            description-clause ?
            ref-clause         ?
            ::=                1
            int                1}}
    vars-clause {
        ""  = {
            VARIABLES          1
            lcub-oid-list-rcub 1}}

    value-defn {
        ""  = {
            OBJECT-IDENTIFIER 1
            ::=               1
            lcub-oid-rcub     1}}

    type-defn {
        ""  = {
            type-name-def 1
            ::=           1
            type-decl     1}}
    type-name-def {
        ""  | {
            type-ref-def       1
            IETF-type-name-def 1}}
    type-decl {
        ""  | {
            syntax      1
            tc-stmt     1
            choice-stmt 1}}
    tc-stmt {
        ""  = {
            TEXTUAL-CONVENTION-use 1
            display-hint-clause    ?
            status-clause          1
            description-clause     1
            ref-clause             ?
            syntax-clause          1}}
    display-hint-clause {
        ""  = {
            DISPLAY-HINT  1
            quoted-string 1}}
    choice-stmt {
        ""  = {
            CHOICE          1
            lcub            1
            named-type-list 1
            rcub            1}}
    named-type-list {
        ""  = {
            named-type  1
            ,named-type *}}
    ,named-type {
        ""  = {
            ,          1
            named-type 1}}
    named-type {
        ""  = {
            id-def   1
            n-t-type 1}}
    n-t-type {
        ""  | {
            type-ref-use       1
            IETF-type-name-use 1
            NULL               1
            octet-str          1
            OBJECT-IDENTIFIER  1
            INTEGER(0..MAX)    1
            INTEGER(9)         1
            Integer32(ranges)  1}}
    INTEGER(0..MAX) {
        ""  = {
            INTEGER 1
            (       1
            zero    1
            ..      1
            MAX     1
            )       1}}

    mod-compl-defn {
        ""  = {
            MODULE-COMPLIANCE-use 1
            status-clause         1
            description-clause    1
            ref-clause            ?
            compl-module-clause   +
            ::=                   1
            lcub-oid-rcub         1}}
    compl-module-clause {
        ""  = {
            MODULE           1
            compl-mod-name   ?
            mand-grps-clause ?
            compl            *}}
    compl-mod-name {
        ""  = {
            type-ref-use 1
            oid          ?}}
    mand-grps-clause {
        ""  = {
            MANDATORY-GROUPS   1
            lcub-oid-list-rcub 1}}
    compl {
        ""  | {
            compl-group 1
            compl-obj   1}}
    compl-group {
        ""  = {
            GROUP              1
            oid                1
            description-clause 1}}
    compl-obj {
        ""  = {
            OBJECT              1
            oid                 1
            syntax-clause       ?
            write-syntax-clause ?
            *min-access-clause  ?
            description-clause  1}}
    write-syntax-clause {
        ""  = {
            WRITE-SYNTAX 1
            syntax       1}}
    *min-access-clause {
        ""  | {
            min-access-clause     1
            pib-min-access-clause 1}}
    min-access-clause {
        ""  = {
            MIN-ACCESS        1
            IETF-access-id-kw 1}}
    pib-min-access-clause {
        ""  = {
            PIB-MIN-ACCESS        1
            IETF-pib-access-id-kw 1}}

    obj-group-defn {
        ""  = {
            OBJECT-GROUP-use   1
            objs-clause        1
            status-clause      1
            description-clause 1
            ref-clause         ?
            ::=                1
            lcub-oid-rcub      1}}

    notif-group-defn {
        ""  = {
            NOTIFICATION-GROUP-use 1
            notifs-clause          1
            status-clause          1
            description-clause     1
            ref-clause             ?
            ::=                    1
            lcub-oid-rcub          1}}
    notifs-clause {
        ""  = {
            NOTIFICATIONS      1
            lcub-oid-list-rcub 1}}

    agent-caps-defn {
        ""  = {
            AGENT-CAPABILITIES-use 1
            PRODUCT-RELEASE        1
            quoted-string          1
            status-clause          1
            description-clause     1
            ref-clause             ?
            agent-caps-mod-part    *
            ::=                    1
            lcub-oid-rcub          1}}
    agent-caps-mod-part {
        ""  = {
            SUPPORTS           1
            type-ref-use       1
            oid                ?
            INCLUDES           1
            lcub-oid-list-rcub 1
            variation          *}}
    variation {
        ""  = {
            VARIATION           1
            oid                 1
            syntax-clause       ?
            write-syntax-clause ?
            access-part         ?
            creation-part       ?
            defval-clause       ?
            description-clause  1}}
    access-part {
        ""  = {
            ACCESS            1
            IETF-access-id-kw 1}}
    creation-part {
        ""  = {
            CREATION-REQUIRES  1
            lcub-oid-list-rcub 1}}

    lcub-oid-rcub {
        ""  = {
            lcub 1
            oid  1
            rcub 1}}
    lcub-oid-list-rcub {
        ""  = {
            lcub     1
            oid-list 1
            rcub     1}}
    oid-list {
        ""  = {
            oid  1
            ,oid *}}
    ,oid {
        ""  = {
            ,   1
            oid 1}}
    oid {"" = {sub-id +}}
    sub-id {
        ""  | {
            ,              !
            rcub           !
            uint32         1
            id(uint32)     1
            id-use         1
            mod-id(uint32) 1
            mod-id         1
            type-ref-err   1}}
    mod-id {
        ""  = {
            type-ref-use 1
            .            1
            id-use       1}}
    mod-id(uint32) {
        ""  = {
            type-ref-use 1
            .            1
            id(uint32)   1}}
    sub-id-defval {
        ""  | {
            rcub       !
            id(uint32) 1
            uint32     1}}

    syntax {
        ""  | {
            bits-construct        1
            basic-syntax          1
            type-tag-basic-syntax 1
            type-ref-use          1
            SEQUENCE-OF-syntax    1
            SEQUENCE-syntax       1
            appl-syntax           1}}
    bits-construct {
        ""  = {
            BITS              1
            lcub              1
            id-def(uint)-list 1
            rcub              1}}
    type-tag-basic-syntax {
        ""  = {
            type-tag     1
            basic-syntax 1}}
    type-tag {
        ""  = {
            lsqb     1
            class    1
            uint     1
            rsqb     1
            IMPLICIT 1}}
    class {
        ""  | {
            APPLICATION 1
            UNIVERSAL   1}}
    basic-syntax {
        ""  | {
            INTEGER(9)        1
            Integer32(ranges) 1
            type*(*)          1
            octet-str         1
            obj-id(*)         1}}
    INTEGER(9) {
        ""  = {
            INTEGER 1
            (9)     ?}}
    Integer32(ranges) {
        ""  = {
            Integer32-use 1
            (ranges)      ?}}
    type*(*) {
        ""  = {
            type-ref-use 1
            .IntType     ?
            (*)          1}}
    .IntType {
        ""  = {
            .            1
            type-ref-use 1}}
    octet-str {
        ""  = {
            OCTET-STRING 1
            (SIZE)       ?}}
    obj-id(*) {
        ""  = {
            OBJECT-IDENTIFIER 1
            (*)               ?}}
    SEQUENCE-OF-syntax {
        ""  = {
            SEQUENCE     1
            OF           1
            type-ref-use 1}}
    SEQUENCE-syntax {
        ""  = {
            SEQUENCE      1
            lcub          1
            seq-item-list 1
            rcub          1}}
    seq-item-list {
        ""  = {
            seq-item  1
            ,seq-item *}}
    ,seq-item {
        ""  = {
            ,        1
            seq-item 1}}
    seq-item {
        ""  = {
            id-use     1
            seq-syntax 1
            kludge-(*) ?}}
    seq-syntax {
        ""  | {
            INTEGER            1
            BITS               1
            OCTET-STRING       1
            OBJECT-IDENTIFIER  1
            type-ref-use       1
            IETF-type-name-use 1}}
    kludge-(*) {err = {(*) 1}}
    appl-syntax {
        ""  | {
            IpAddress(*)       1
            Counter32(*)       1
            Gauge32(ranges)    1
            Unsigned32(ranges) 1
            TimeTicks-use      1
            Opaque(SIZE)       1
            Counter64(*)       1
            Integer64(ranges)  1
            Unsigned64(ranges) 1}}
    IpAddress(*) {
        ""  = {
            IpAddress-use 1
            (*)           ?}}
    Counter32(*) {
        ""  = {
            Counter32-use 1
            (*)           ?}}
    Gauge32(ranges) {
        ""  = {
            Gauge32-use 1
            (ranges)    ?}}
    Unsigned32(ranges) {
        ""  = {
            Unsigned32-use 1
            (ranges)       ?}}
    Opaque(SIZE) {
        ""  = {
            Opaque-use 1
            (SIZE)     ?}}
    Counter64(*) {
        ""  = {
            Counter64-use 1
            (*)           ?}}
    Integer64(ranges) {
        ""  = {
            Integer64-use 1
            (ranges)      ?}}
    Unsigned64(ranges) {
        ""  = {
            Unsigned64-use 1
            (ranges)       ?}}

    (*) {
        ""  | {
            (ranges) 1
            (SIZE)   1
            enum     1}}
    (9) {
        ""  | {
            (ranges) 1
            enum     1}}
    (SIZE) {
        ""  = {
            (        1
            SIZE     1
            (ranges) 1
            )        1}}
    (ranges) {
        ""  = {
            (      1
            range  1
            |range *
            )      1}}
    |range {
        ""  = {
            |     1
            range 1}}
    range {
        ""  = {
            bound   1
            ..bound ?}}
    ..bound {
        ""  = {
            ..    1
            bound 1}}
    bound {
        ""  | {
            int          1
            radix-string 1}}
    enum {
        ""  = {
            lcub             1
            id-def(int)-list 1
            rcub             1}}

    macro-defn {
        ""  = {
            IETF-macro-name-def 1
            MACRO               1
            ::=                 1
            BEGIN               1
            TYPE                1
            NOTATION            1
            ::=                 1
            type-notation       +
            VALUE               1
            NOTATION            1
            ::=                 1
            value-notation      1
            macro-syntax        *
            END                 1}}
    type-notation {
        ""  | {
            type-ref-use  1
            VALUE         !
            quoted-string 1
            t-n-type      1
            t-n-value     1}}
    t-n-type {
        ""  = {
            type-kw      1
            (            1
            TYPE         ?
            type-ref-use 1
            )            1}}
    t-n-value {
        ""  = {
            value-kw  1
            (         1
            t-n-v-arg 1
            )         1}}
    t-n-v-arg {
        ""  | {
            value-arg1 1
            value-arg2 1}}
    value-notation {
        ""  = {
            value-kw 1
            (        1
            VALUE    1
            v-n-arg  1
            )        1}}
    v-n-arg {
        ""  | {
            OBJECT-IDENTIFIER 1
            INTEGER           1
            type-ref-use      1}}
    macro-syntax {
        ""  = {
            type-ref-macsyn   1
            ::=               1
            macro-syntax-alt  1
            |macro-syntax-alt *}}
    |macro-syntax-alt {
        ""  = {
            |                1
            macro-syntax-alt 1}}
    macro-syntax-alt {
        ""  = {
            macro-syntax-item +}}
    macro-syntax-item {
        ""  | {
            type-ref-use    1
            END             !
            type-ref-macsyn !
            quoted-string   1
            m-s-a-type      1
            m-s-a-value     1
            id-use          1}}
    m-s-a-type {
        ""  = {
            type-kw       1
            (m-s-a-t-arg) ?}}
    (m-s-a-t-arg) {
        ""  = {
            (      1
            id-use 1
            )      1}}
    m-s-a-value {
        ""  = {
            value-kw    1
            (           1
            m-s-a-v-arg 1
            )           1}}
    m-s-a-v-arg {
        ""  | {
            OBJECT-IDENTIFIER 1
            IA5String         1
            type-ref-use      1
            value-arg1        1
            value-arg3        1}}
    value-arg1 {
        ""  = {
            Update       1
            type-ref-use 1}}
    value-arg2 {
        ""  = {
            id-use            1
            OBJECT-IDENTIFIER 1}}
    value-arg3 {
        ""  = {
            id-use       1
            type-ref-use 1}}


    OBJECT-IDENTIFIER {
        ""  = {
            OBJECT     1
            IDENTIFIER 1}}
    OCTET-STRING {
        ""  = {
            OCTET  1
            STRING 1}}

    type-ref-def {def = {type-ref 1}}
    type-ref-use {id  = {type-ref 1}}
    type-ref-err {err = {type-ref 1}}
    type-ref-macsyn {def . {}}

    id-def {def = {/id 1  * 1}}
    id-use {id  = {/id 1  * 1}}
    id-kw  {key = {/id 1  * 1}}

    id-list {
        ""  = {
            id-use  1
            ,id-use *}}
    ,id-use {
        ""  = {
            ,      1
            id-use 1}}

    quoted-string {
        ""  = {
            quot 1
            qstr *
            quot 1}}
    qstr {str . {}}

    positive {
        ""  | {
            positive31   1
            positive32   1
            positive63   1
            positive64   1
            positive-big 1}}
    negative {
        ""  | {
            negative31   1
            negative63   1
            negative-big 1}}
    uint {
        ""  | {
            zero     1
            positive 1}}
    uint32 {
        ""  | {
            positive31   1
            zero     1
            positive32   1}}
    int {
        ""  | {
            positive31   1
            zero         1
            positive32   1
            negative31   1
            positive63   1
            positive64   1
            negative63   1
            positive-big 1
            negative-big 1}}

    id(positive)-list {
        ""  = {
            id(positive)  1
            ,id(positive) *}}
    ,id(positive) {
        ""  = {
            ,            1
            id(positive) 1}}
    id(positive) {
        ""  = {
            id-use   1
            (        1
            positive 1
            )        1}}
    id-def(uint)-list {
        ""  = {
            id-def(uint)  1
            ,id-def(uint) *}}
    ,id-def(uint) {
        ""  = {
            ,        1
            id-def(uint) 1}}
    id-def(uint) {
        ""  = {
            id-def 1
            (      1
            uint   1
            )      1}}
    id(uint32) {
        ""  = {
            id-use 1
            (      1
            uint32 1
            )      1}}
    id-def(int)-list {
        ""  = {
            id-def(int)  1
            ,id-def(int) *}}
    ,id-def(int) {
        ""  = {
            ,       1
            id-def(int) 1}}
    id-def(int) {
        ""  = {
            id-def 1
            (      1
            int    1
            )      1}}

    radix-string {val . {}}

    IETF-macro-name-def {def = {/Imn 1  * 1}}
    IETF-macro-name-use {id  = {/Imn 1  * 1}}
    AGENT-CAPABILITIES-use {rep = {/Imn 1  AGENT-CAPABILITIES 1}}
    MODULE-COMPLIANCE-use  {rep = {/Imn 1  MODULE-COMPLIANCE  1}}
    MODULE-IDENTITY-use    {rep = {/Imn 1  MODULE-IDENTITY    1}}
    NOTIFICATION-GROUP-use {rep = {/Imn 1  NOTIFICATION-GROUP 1}}
    NOTIFICATION-TYPE-use  {rep = {/Imn 1  NOTIFICATION-TYPE  1}}
    OBJECT-GROUP-use       {rep = {/Imn 1  OBJECT-GROUP       1}}
    OBJECT-IDENTITY-use    {rep = {/Imn 1  OBJECT-IDENTITY    1}}
    OBJECT-TYPE-use        {rep = {/Imn 1  OBJECT-TYPE        1}}
    TEXTUAL-CONVENTION-use {rep = {/Imn 1  TEXTUAL-CONVENTION 1}}
    TRAP-TYPE-use          {rep = {/Imn 1  TRAP-TYPE          1}}

    IETF-type-name-def {def = {/Itn 1  * 1}}
    IETF-type-name-use {id  = {/Itn 1  * 1}}
    Counter32-use  {id = {/Itn 1  Counter32  1}}
    Counter64-use  {id = {/Itn 1  Counter64  1}}
    Gauge32-use    {id = {/Itn 1  Gauge32    1}}
    Integer32-use  {id = {/Itn 1  Integer32  1}}
    Integer64-use  {id = {/Itn 1  Integer64  1}}
    IpAddress-use  {id = {/Itn 1  IpAddress  1}}
    Opaque-use     {id = {/Itn 1  Opaque     1}}
    TimeTicks-use  {id = {/Itn 1  TimeTicks  1}}
    Unsigned32-use {id = {/Itn 1  Unsigned32 1}}
    Unsigned64-use {id = {/Itn 1  Unsigned64 1}}

    type-kw  {key = {/id 1  type  1}}
    value-kw {key = {/id 1  value 1}}
    IETF-status-id-kw {key = {/id 1  IETF-status-id 1}}
    IETF-status-id {
        ""  | {
            current    1
            mandatory  1
            deprecated 1
            obsolete   1
            optional   1}}
    IETF-access-id-kw {key = {/id 1  IETF-access-id 1}}
    IETF-access-id {
        ""  | {
            read-only             1
            not-accessible        1
            read-create           1
            read-write            1
            not-implemented       1
            accessible-for-notify 1
            write-only            1}}
    IETF-pib-access-id-kw {key = {/id 1  IETF-pib-access-id 1}}
    IETF-pib-access-id {
        ""  | {
            not-accessible 1
            install        1
            notify         1
            install-notify 1
            report-only    1}}
    IETF-pib-all-kw {key = {/id 1  IETF-pib-all 1}}
    IETF-pib-all {"" = {all 1}}

    * {"" *}
}

# First {token state} pair-items are hash keys and must be in the
# same canonical form as would be produced by [list token state].
set artwork::grammar_program(mib) {
    {{} 0}  {done}

    {type-ref 0}  {{push module} {span def} {goto m1}}
    {lcub m1}  {{push m1} {redo lor1d}}
    {DEFINITIONS m1}  {{span key} {goto m3}}
    {DEFINITIONS m2}  {{redo m1}}
    {PIB-DEFINITIONS m1}  {{span key} {goto m3}}
    {PIB-DEFINITIONS m2}  {{redo m1}}
    {::= m3}  {{goto m4}}
    {BEGIN m4}  {{goto m5}}
    {END m5}  {{redo m7}}
    {END m6}  {{redo m7}}
    {END m7}  {{check module} div-top pop {goto 0}}
    {EXPORTS m5}  {{push exports} {goto ex1}}
    {IMPORTS m5}  {{push imports} {goto im1}}
    {IMPORTS m6}  {{redo m5}}
    {/id m5}  {{redo m7}}
    {/id m6}  {{redo m7}}
    {/id m7}  {{push defn} {span def} skip-next {goto m9}}
    {type-ref m5}  {{redo m7}}
    {type-ref m6}  {{redo m7}}
    {type-ref m7}  {{push defn} {goto m11}}
    {/Imn m5}  {{redo m7}}
    {/Imn m6}  {{redo m7}}
    {/Imn m7}  {{push defn} {span def} skip-next {goto mac0}}
    {/Itn m5}  {{redo m7}}
    {/Itn m6}  {{redo m7}}
    {/Itn m7}  {{push defn} {span def} skip-next {goto td0}}
    {/Imn m9}  {{goto m10}}
    {OBJECT m9}  {{goto m14}}
    {MODULE-IDENTITY m10}     {{span rep} {goto my1}}
    {OBJECT-IDENTITY m10}     {{span rep} {goto oy1}}
    {OBJECT-TYPE m10}         {{span rep} {goto ot1}}
    {NOTIFICATION-TYPE m10}   {{span rep} {goto nt0}}
    {TRAP-TYPE m10}           {{span rep} {goto tt0}}
    {MODULE-COMPLIANCE m10}   {{span rep} {goto mc0}}
    {OBJECT-GROUP m10}        {{span rep} {goto og0}}
    {NOTIFICATION-GROUP m10}  {{span rep} {goto ng0}}
    {AGENT-CAPABILITIES m10}  {{span rep} {goto ac0}}
    {::= m11}  {{redo m12 1}}
    {OBJECT m11}  {{redo m13 1}}
    {type-ref m12}  {{span def} skip-next {goto td1}}
    {type-ref m13}  {{span err} skip-next {goto m14}}
    {IDENTIFIER m14}  {{goto oi0}}
    {* m99}  {{check defn} div-top pop {goto m7}}

    {semi ex1}  {{redo ex3}}
    {semi ex3}  {{check exports} div-top pop {goto m6}}
    {semi ex4}  {{redo ex3}}
    {ALL ex1}  {{goto ex4}}
    {/id ex1}  {{redo ex2}}
    {/id ex2}  {{span id} skip-next {goto ex3}}
    {type-ref ex1}  {{redo ex2}}
    {type-ref ex2}  {{span id} {goto ex3}}
    {/Itn ex1}  {{redo ex2}}
    {/Itn ex2}  {{span id} skip-next {goto ex3}}
    {/Imn ex1}  {{redo ex2}}
    {/Imn ex2}  {{span id} skip-next {goto ex3}}
    {, ex3}  {{goto ex2}}

    {semi im1}  {{check imports} div-top pop {goto m7}}
    {/id im1}  {{span id} skip-next {goto im3}}
    {/id im2}  {{redo im1}}
    {type-ref im1}  {{span id} {goto im3}}
    {type-ref im2}  {{redo im1}}
    {BITS im1}  {{goto im3}}
    {BITS im2}  {{goto im3}}
    {MANDATORY-GROUPS im1}  {{goto im3}}
    {MANDATORY-GROUPS im2}  {{goto im3}}
    {/Imn im1}  {{span id} skip-next {goto im3}}
    {/Imn im2}  {{redo im1}}
    {/Itn im1}  {{span id} skip-next {goto im3}}
    {/Itn im2}  {{redo im1}}
    {, im3}  {{goto im2}}
    {FROM im3}  {{goto im4}}
    {type-ref im4}  {{span id} {goto im1}}

    {SUBJECT-CATEGORIES my1}  {{goto my2}}
    {lcub my2}  {{goto my3}}
    {/id my3}  {{goto my4}}
    {all my4}  {{span key} {goto my11}}
    {id my4}   {{span id} {goto my5}}
    {* my4}    {{span id} {goto my5}}
    {( my5}  {{goto my6}}
    {positive31 my6}    {{goto my7}}
    {positive32 my6}    {{goto my7}}
    {positive63 my6}    {{goto my7}}
    {positive64 my6}    {{goto my7}}
    {positive-big my6}  {{goto my7}}
    {) my7}  {{goto my8}}
    {rcub my8}  {{goto my20}}
    {, my8}     {{goto my9}}
    {/id my9}  {{goto my10}}
    {all my10}  {{span err} {goto my11}}
    {id my10}   {{span id} {goto my5}}
    {* my10}    {{span id} {goto my5}}
    {rcub my11}  {{goto my20}}
    {LAST-UPDATED my1}   {{redo my20}}
    {LAST-UPDATED my20}   {{push my21} {goto qs1}}
    {ORGANIZATION my21}  {{push my22} {goto qs1}}
    {CONTACT-INFO my22}  {{push my23} {goto qs1}}
    {DESCRIPTION my23}   {{push my24} {goto qs1d}}
    {::= my24}           {{goto lor1d}}
    {REVISION my24}      {{push my25} {goto qs1x}}
    {DESCRIPTION my25}   {{push my24} {goto qs1dd}}

    {STATUS oy1}  {{goto oy2}}
    {/id oy2}  {{goto oy3}}
    {current oy3}     {{span key} {goto oy4}}
    {deprecated oy3}  {{span key} {goto oy4}}
    {obsolete oy3}    {{span key} {goto oy4}}
    {* oy3}           {{span err} {goto oy4}}
    {DESCRIPTION oy4}  {{push oy5} {goto qs1d}}
    {REFERENCE oy5}    {{push oy6} {goto qs1}}
    {::= oy5}  {{goto lor1d}}
    {::= oy6}  {{goto lor1d}}

    {SYNTAX ot1}  {{push ot2} {goto sx0}}
    {UNITS ot2}  {{push ot3} {goto qs1}}
    {MAX-ACCESS ot2}  {{goto ot4}}
    {MAX-ACCESS ot3}  {{goto ot4}}
    {/id ot4}  {{goto ot5}}
    {not-accessible ot5}         {{span key} {goto ot12}}
    {accessible-for-notify ot5}  {{span key} {goto ot12}}
    {read-only ot5}              {{span key} {goto ot12}}
    {read-write ot5}             {{span key} {goto ot12}}
    {read-create ot5}            {{span key} {goto ot12}}
    {* ot5}                      {{span err} {goto ot12}}
    {ACCESS ot2}  {{goto ot6}}
    {ACCESS ot3}  {{goto ot6}}
    {/id ot6}  {{goto ot7}}
    {read-only ot7}       {{span key} {goto ot15}}
    {read-write ot7}      {{span key} {goto ot15}}
    {write-only ot7}      {{span key} {goto ot15}}
    {not-accessible ot7}  {{span key} {goto ot15}}
    {* ot7}               {{span err} {goto ot15}}
    {PIB-ACCESS ot2}  {{goto ot8}}
    {PIB-ACCESS ot3}  {{goto ot8}}
    {/id ot8}  {{goto ot9}}
    {install ot9}         {{span key} {goto ot10}}
    {notify ot9}          {{span key} {goto ot10}}
    {install-notify ot9}  {{span key} {goto ot10}}
    {report-only ot9}     {{span key} {goto ot10}}
    {* ot9}               {{span err} {goto ot10}}
    {PIB-REFERENCES ot2}  {{redo ot10}}
    {PIB-REFERENCES ot3}  {{redo ot10}}
    {PIB-REFERENCES ot10}  {{push ot11} {goto lor1}}
    {PIB-TAG ot2}  {{redo ot11}}
    {PIB-TAG ot3}  {{redo ot11}}
    {PIB-TAG ot10}  {{redo ot11}}
    {PIB-TAG ot11}  {{push ot12} {goto lor1}}
    {STATUS ot2}  {{goto ot13}}
    {STATUS ot3}  {{goto ot13}}
    {STATUS ot10}  {{goto ot13}}
    {STATUS ot11}  {{goto ot13}}
    {STATUS ot12}  {{goto ot13}}
    {/id ot13}  {{goto ot14}}
    {current ot14}     {{span key} {goto ot20}}
    {obsolete ot14}    {{span key} {goto ot20}}
    {deprecated ot14}  {{span key} {goto ot20}}
    {* ot14}           {{span err} {goto ot20}}
    {STATUS ot15}  {{goto ot16}}
    {/id ot16}  {{goto ot17}}
    {mandatory ot17}   {{span key} {goto ot20}}
    {optional ot17}    {{span key} {goto ot20}}
    {obsolete ot17}    {{span key} {goto ot20}}
    {deprecated ot17}  {{span key} {goto ot20}}
    {* ot17}           {{span err} {goto ot20}}
    {DESCRIPTION ot20}  {{push ot21} {goto qs1d}}
    {INSTALL-ERRORS ot20}  {{goto ot22}}
    {INSTALL-ERRORS ot21}  {{goto ot22}}
    {lcub ot22}  {{goto ot23}}
    {/id ot23}  {{goto ot24}}
    {id ot24}   {{span id} {goto ot25}}
    {* ot24}    {{span id} {goto ot25}}
    {( ot25}  {{goto ot26}}
    {positive31 ot26}    {{goto ot27}}
    {positive32 ot26}    {{goto ot27}}
    {positive63 ot26}    {{goto ot27}}
    {positive64 ot26}    {{goto ot27}}
    {positive-big ot26}  {{goto ot27}}
    {) ot27}  {{goto ot28}}
    {rcub ot28}  {{goto ot40}}
    {, ot28}     {{goto ot29}}
    {/id ot29}  {{goto ot30}}
    {id ot30}   {{span id} {goto ot25}}
    {* ot30}    {{span id} {goto ot25}}
    {rcub ot31}  {{goto ot40}}
    {REFERENCE ot20}  {{redo ot40}}
    {REFERENCE ot21}  {{redo ot40}}
    {REFERENCE ot40}  {{push ot41} {goto qs1}}
    {PIB-INDEX ot20}  {{redo ot41}}
    {PIB-INDEX ot21}  {{redo ot41}}
    {PIB-INDEX ot40}  {{redo ot41}}
    {PIB-INDEX ot41}  {{push ot44} {goto lor1}}
    {AUGMENTS ot20}   {{redo ot41}}
    {AUGMENTS ot21}   {{redo ot41}}
    {AUGMENTS ot40}   {{redo ot41}}
    {AUGMENTS ot41}   {{push ot44} {goto lor1}}
    {EXTENDS ot20}    {{redo ot41}}
    {EXTENDS ot21}    {{redo ot41}}
    {EXTENDS ot40}    {{redo ot41}}
    {EXTENDS ot41}    {{push ot44} {goto lor1}}
    {INDEX ot20}  {{goto ot45}}
    {INDEX ot21}  {{goto ot45}}
    {INDEX ot40}  {{goto ot45}}
    {INDEX ot41}  {{goto ot45}}
    {INDEX ot44}  {{goto ot45}}
    {lcub ot45}  {{goto ot46}}
    {IMPLIED ot46}  {{goto ot47}}
    {* ot46} {{push ot48} {redo oid1}}
    {* ot47} {{push ot48} {redo oid1}}
    {rcub ot48}  {{goto ot50}}
    {, ot48}     {{goto ot46}}
    {UNIQUENESS ot20}  {{goto ot51}}
    {UNIQUENESS ot21}  {{goto ot51}}
    {UNIQUENESS ot40}  {{goto ot51}}
    {UNIQUENESS ot41}  {{goto ot51}}
    {UNIQUENESS ot44}  {{goto ot51}}
    {UNIQUENESS ot50}  {{goto ot51}}
    {lcub ot51}  {{goto ot52}}
    {rcub ot52}  {{goto ot60}}
    {* ot52} {{push ot53} {redo oid1}}
    {, ot53} {{goto ot54}}
    {rcub ot53}  {{goto ot60}}
    {* ot54} {{push ot53} {redo oid1}}
    {DEFVAL ot20}  {{redo ot60}}
    {DEFVAL ot21}  {{redo ot60}}
    {DEFVAL ot40}  {{redo ot60}}
    {DEFVAL ot41}  {{redo ot60}}
    {DEFVAL ot44}  {{redo ot60}}
    {DEFVAL ot50}  {{redo ot60}}
    {DEFVAL ot60}  {{push ot70} {goto dv1}}
    {::= ot20}  {{goto lor1d}}
    {::= ot21}  {{goto lor1d}}
    {::= ot40}  {{goto lor1d}}
    {::= ot41}  {{goto lor1d}}
    {::= ot44}  {{goto lor1d}}
    {::= ot50}  {{goto lor1d}}
    {::= ot60}  {{goto lor1d}}
    {::= ot70}  {{goto lor1d}}

    {OBJECTS nt0}  {{goto nt1}}
    {lcub nt1}  {{push nt2} {goto oid1}}
    {rcub nt2}  {{goto nt10}}
    {, nt2}     {{push nt2} {goto oid1}}
    {STATUS nt0}   {{goto nt11}}
    {STATUS nt10}  {{goto nt11}}
    {/id nt11}  {{goto nt12}}
    {current nt12}     {{span key} {goto nt20}}
    {deprecated nt12}  {{span key} {goto nt20}}
    {obsolete nt12}    {{span key} {goto nt20}}
    {* nt12}           {{span err} {goto nt20}}
    {DESCRIPTION nt20}  {{push nt30} {goto qs1d}}
    {REFERENCE nt30}  {{push nt40} {goto qs1}}
    {::= nt30}  {{goto lor1d}}
    {::= nt40}  {{goto lor1d}}

    {ENTERPRISE tt0} {{push tt10} {goto oid1}}
    {VARIABLES tt10} {{goto tt11}}
    {lcub tt11}  {{push tt12} {goto oid1}}
    {rcub tt12}  {{goto tt20}}
    {, tt12}     {{push tt12} {goto oid1}}
    {DESCRIPTION tt10}  {{redo tt20}}
    {DESCRIPTION tt20}  {{push tt30} {goto qs1d}}
    {REFERENCE tt10}  {{redo tt30}}
    {REFERENCE tt20}  {{redo tt30}}
    {REFERENCE tt30}  {{push tt40} {goto qs1}}
    {::= tt10}  {{goto tt41}}
    {::= tt20}  {{goto tt41}}
    {::= tt30}  {{goto tt41}}
    {::= tt40}  {{goto tt41}}
    {zero tt41}         {{redo m99}}
    {positive31 tt41}   {{redo m99}}
    {positive32 tt41}   {{redo m99}}
    {positive63 tt41}   {{redo m99}}
    {positive64 tt41}   {{redo m99}}
    {positive-big tt41} {{redo m99}}
    {negative31 tt41}   {{redo m99}}
    {negative63 tt41}   {{redo m99}}
    {negative-big tt41} {{redo m99}}

    {::= oi0}  {{goto lor1d}}

    {::= td0}  {{goto td1}}
    {* td1}  {{push td3} {redo sx0}}
    {/Imn td1}  {{goto td2}}
    {TEXTUAL-CONVENTION td2}  {{span rep} {goto tc0}}
    {CHOICE td1}  {{goto ch0}}
    {* td3}  {{redo m99 1}}

    {DISPLAY-HINT tc0}  {{push tc10} {goto qs1}}
    {STATUS tc0} {{goto tc11}}
    {STATUS tc10} {{goto tc11}}
    {/id tc11}  {{goto tc12}}
    {current tc12}     {{span key} {goto tc20}}
    {deprecated tc12}  {{span key} {goto tc20}}
    {obsolete tc12}    {{span key} {goto tc20}}
    {* tc12}           {{span err} {goto tc20}}
    {DESCRIPTION tc20}  {{push tc30} {goto qs1d}}
    {REFERENCE tc30}    {{push tc40} {goto qs1}}
    {SYNTAX tc30}  {{redo tc40}}
    {SYNTAX tc40}  {{push td3} {goto sx0}}

    {lcub ch0}  {{goto ch1}}
    {/id ch1}  {{span def} skip-next {goto ch2}}
    {type-ref ch2}  {{span id} {goto ch20}}
    {NULL ch2}  {{goto ch20}}
    {OBJECT ch2}  {{goto ch3}}
    {IDENTIFIER ch3} {{goto ch20}}
    {OCTET ch2}  {{goto ch4}}
    {STRING ch4}  {{push ch20} {goto sxs0}}
    {INTEGER ch2}  {{goto ch5}}
    {* ch5}  {{redo ch20}}
    {lcub ch5}  {{push ch20} {goto sxe0}}
    {( ch5}  {{goto ch6}}
    {zero ch6}  {{goto ch7}}
    {* ch6}  {{push ch20} {redo sxr1}}
    {.. ch7}  {{goto ch8}}
    {* ch7}  {{push ch20} {redo sxr1 1}}
    {MAX ch8}  {{goto ch9}}
    {* ch8}  {{push ch20} {redo sxr1 2}}
    {) ch9}  {{goto ch20}}
    {/Itn ch2}  {{span id} {goto ch10}}
    {Integer32 ch10}  {{push ch20} {goto sxr0}}
    {* ch10}  {{goto ch20}}
    {, ch20}  {{goto ch1}}
    {rcub ch20}  {{redo m99}}

    {STATUS mc0} {{goto mc1}}
    {/id mc1}  {{goto mc2}}
    {current mc2}     {{span key} {goto mc10}}
    {deprecated mc2}  {{span key} {goto mc10}}
    {obsolete mc2}    {{span key} {goto mc10}}
    {* mc2}           {{span err} {goto mc10}}
    {DESCRIPTION mc10}  {{push mc20} {goto qs1d}}
    {REFERENCE mc20}  {{push mc30} {goto qs1}}
    {MODULE mc20}  {{goto mc31}}
    {MODULE mc30}  {{goto mc31}}
    {type-ref mc31}  {{span id} {goto mc32}}
    {* mc32}  {{push mc33} {redo oid1}}
    {MANDATORY-GROUPS mc31}  {{goto mc34}}
    {MANDATORY-GROUPS mc32}  {{goto mc34}}
    {MANDATORY-GROUPS mc33}  {{goto mc34}}
    {lcub mc34}  {{push mc35} {goto oid1}}
    {rcub mc35}  {{goto mc36}}
    {, mc35}     {{push mc35} {goto oid1}}
    {GROUP mc31}  {{redo mc36}}
    {GROUP mc32}  {{redo mc36}}
    {GROUP mc33}  {{redo mc36}}
    {GROUP mc36}  {{push mc37} {goto oid1}}
    {DESCRIPTION mc37}  {{push mc36} {goto qs1d}}
    {OBJECT mc31}  {{redo mc36}}
    {OBJECT mc32}  {{redo mc36}}
    {OBJECT mc33}  {{redo mc36}}
    {OBJECT mc36}  {{push mc38} {goto oid1}}
    {SYNTAX mc38}  {{push mc39} {goto sx0}}
    {WRITE-SYNTAX mc38}  {{redo mc39}}
    {WRITE-SYNTAX mc39}  {{push mc40} {goto sx0}}
    {MIN-ACCESS mc38}  {{goto mc41}}
    {MIN-ACCESS mc39}  {{goto mc41}}
    {MIN-ACCESS mc40}  {{goto mc41}}
    {/id mc41}  {{goto mc42}}
    {not-accessible mc42}         {{span key} {goto mc45}}
    {accessible-for-notify mc42}  {{span key} {goto mc45}}
    {read-only mc42}              {{span key} {goto mc45}}
    {read-write mc42}             {{span key} {goto mc45}}
    {read-create mc42}            {{span key} {goto mc45}}
    {* mc42}                      {{span err} {goto mc45}}
    {PIB-MIN-ACCESS mc38}  {{goto mc43}}
    {PIB-MIN-ACCESS mc39}  {{goto mc43}}
    {PIB-MIN-ACCESS mc40}  {{goto mc43}}
    {/id mc43}  {{goto mc44}}
    {not-accessible mc44}  {{span key} {goto mc45}}
    {install mc44}         {{span key} {goto mc45}}
    {notify mc44}          {{span key} {goto mc45}}
    {install-notify mc44}  {{span key} {goto mc45}}
    {report-only mc44}     {{span key} {goto mc45}}
    {* mc44}               {{span err} {goto mc45}}
    {DESCRIPTION mc38}  {{redo mc45}}
    {DESCRIPTION mc39}  {{redo mc45}}
    {DESCRIPTION mc40}  {{redo mc45}}
    {DESCRIPTION mc45}  {{push mc36} {goto qs1d}}
    {MODULE mc31}  {{goto mc31}}
    {MODULE mc32}  {{goto mc31}}
    {MODULE mc33}  {{goto mc31}}
    {MODULE mc36}  {{goto mc31}}
    {::= mc31}  {{goto lor1d}}
    {::= mc32}  {{goto lor1d}}
    {::= mc33}  {{goto lor1d}}
    {::= mc36}  {{goto lor1d}}

    {OBJECTS og0}  {{goto og1}}
    {lcub og1}  {{push og2} {goto oid1}}
    {rcub og2}  {{goto og10}}
    {, og2}     {{push og2} {goto oid1}}
    {STATUS og10}  {{goto og11}}
    {/id og11}  {{goto og12}}
    {current og12}     {{span key} {goto og20}}
    {deprecated og12}  {{span key} {goto og20}}
    {obsolete og12}    {{span key} {goto og20}}
    {* og12}           {{span err} {goto og20}}
    {DESCRIPTION og20}  {{push og30} {goto qs1d}}
    {REFERENCE og30}  {{push og40} {goto qs1}}
    {::= og30}  {{goto lor1d}}
    {::= og40}  {{goto lor1d}}

    {NOTIFICATIONS ng0}  {{goto ng1}}
    {lcub ng1}  {{push ng2} {goto oid1}}
    {rcub ng2}  {{goto ng10}}
    {, ng2}     {{push ng2} {goto oid1}}
    {STATUS ng10}  {{goto ng11}}
    {/id ng11}  {{goto ng12}}
    {current ng12}     {{span key} {goto ng20}}
    {deprecated ng12}  {{span key} {goto ng20}}
    {obsolete ng12}    {{span key} {goto ng20}}
    {* ng12}           {{span err} {goto ng20}}
    {DESCRIPTION ng20}  {{push ng30} {goto qs1d}}
    {REFERENCE ng30}  {{push ng40} {goto qs1}}
    {::= ng30}  {{goto lor1d}}
    {::= ng40}  {{goto lor1d}}

    {PRODUCT-RELEASE ac0}  {{push ac10} {goto qs1}}
    {STATUS ac10}  {{goto ac11}}
    {/id ac11}  {{goto ac12}}
    {current ac12}   {{span key} {goto ac20}}
    {obsolete ac12}  {{span key} {goto ac20}}
    {* ac12}         {{span err} {goto ac20}}
    {DESCRIPTION ac20}  {{push ac30} {goto qs1d}}
    {REFERENCE ac30}  {{push ac40} {goto qs1}}
    {SUPPORTS ac30} {{goto ac41}}
    {SUPPORTS ac40} {{goto ac41}}
    {type-ref ac41} {{span id} {goto ac42}}
    {* ac42}  {{push ac43} {redo oid1}}
    {INCLUDES ac42} {{goto ac44}}
    {INCLUDES ac43} {{goto ac44}}
    {lcub ac44}  {{push ac45} {goto oid1}}
    {rcub ac45}  {{goto ac50}}
    {, ac45}     {{push ac45} {goto oid1}}
    {SUPPORTS ac50} {{goto ac41}}
    {VARIATION ac50} {{push ac51} {goto oid1}}
    {SYNTAX ac51} {{push ac52} {goto sx0}}
    {WRITE-SYNTAX ac51} {{redo ac52}}
    {WRITE-SYNTAX ac52} {{push ac53} {goto sx0}}
    {ACCESS ac51}  {{goto ac54}}
    {ACCESS ac52}  {{goto ac54}}
    {ACCESS ac53}  {{goto ac54}}
    {/id ac54}  {{goto ac55}}
    {not-implemented ac55}  {{span key} {goto ac56}}
    {accessible-for-notify ac55}  {{span key} {goto ac56}}
    {read-only ac55}    {{span key} {goto ac56}}
    {read-write ac55}   {{span key} {goto ac56}}
    {read-create ac55}  {{span key} {goto ac56}}
    {write-only ac55}   {{span key} {goto ac56}}
    {* ac55}            {{span err} {goto ac56}}
    {CREATION-REQUIRES ac51}  {{goto ac57}}
    {CREATION-REQUIRES ac52}  {{goto ac57}}
    {CREATION-REQUIRES ac53}  {{goto ac57}}
    {CREATION-REQUIRES ac56}  {{goto ac57}}
    {lcub ac57}  {{push ac58} {goto oid1}}
    {rcub ac58}  {{goto ac59}}
    {, ac58}     {{push ac58} {goto oid1}}
    {DEFVAL ac51}  {{redo ac59}}
    {DEFVAL ac52}  {{redo ac59}}
    {DEFVAL ac53}  {{redo ac59}}
    {DEFVAL ac56}  {{redo ac59}}
    {DEFVAL ac59}  {{push ac60} {goto dv1}}
    {DESCRIPTION ac51}  {{redo ac60}}
    {DESCRIPTION ac52}  {{redo ac60}}
    {DESCRIPTION ac53}  {{redo ac60}}
    {DESCRIPTION ac56}  {{redo ac60}}
    {DESCRIPTION ac59}  {{redo ac60}}
    {DESCRIPTION ac60}  {{push ac50} {goto qs1d}}
    {::= ac50}  {{goto lor1d}}

    {lcub dv1}  {{goto dv2}}
    {lcub dv1}  {{goto dv2}}
    {radix-string dv2}  {{goto dv19}}
    {zero dv2}          {{goto dv19}}
    {positive31 dv2}    {{goto dv19}}
    {positive32 dv2}    {{goto dv19}}
    {positive63 dv2}    {{goto dv19}}
    {positive64 dv2}    {{goto dv19}}
    {positive-big dv2}  {{goto dv19}}
    {negative31 dv2}    {{goto dv19}}
    {negative63 dv2}    {{goto dv19}}
    {negative-big dv2}  {{goto dv19}}
    {quot dv2}  {{push dv19} {goto qs2}}
    {/id dv2}   {{span id} skip-next {goto dv19}}
    {lcub dv2}  {{goto dv3}}
    {rcub dv3}  {{goto dv19}}
    {/id dv3}  {{span id} skip-next {goto dv4}}
    {rcub dv4}  {{goto dv19}}
    {, dv4}  {{goto dv5}}
    {/id dv5}  {{span id} skip-next {goto dv6}}
    {rcub dv6}  {{goto dv19}}
    {, dv6}  {{goto dv5}}
    {( dv4}  {{goto dv7}}
    {zero dv7}        {{goto dv8}}
    {positive31 dv7}  {{goto dv8}}
    {positive32 dv7}  {{goto dv8}}
    {) dv8}  {{goto dv9}}
    {zero dv3}        {{goto dv9}}
    {positive31 dv3}  {{goto dv9}}
    {positive32 dv3}  {{goto dv9}}
    {rcub dv9}  {{goto dv19}}
    {/id dv9}  {{span id} skip-next {goto dv10}}
    {( dv10}  {{goto dv11}}
    {zero dv11}        {{goto dv12}}
    {positive31 dv11}  {{goto dv12}}
    {positive32 dv11}  {{goto dv12}}
    {) dv12}  {{goto dv9}}
    {zero dv9}        {{goto dv9}}
    {positive31 dv9}  {{goto dv9}}
    {positive32 dv9}  {{goto dv9}}
    {rcub dv19}  {goto-top pop}

    {BITS sx0}  {{goto sx1}}
    {lcub sx1}  {{goto sx2}}
    {/id sx2}  {{span def} skip-next {goto sx3}}
    {( sx3}  {{goto sx4}}
    {zero sx4}          {{goto sx5}}
    {positive31 sx4}    {{goto sx5}}
    {positive32 sx4}    {{goto sx5}}
    {positive63 sx4}    {{goto sx5}}
    {positive64 sx4}    {{goto sx5}}
    {positive-big sx4}  {{goto sx5}}
    {) sx5}  {{goto sx6}}
    {, sx6}  {{goto sx2}}
    {rcub sx6}  {goto-top pop}
    {type-ref sx0}  {{span id} {goto sx7}}
    {. sx7}  {{redo sx32}}
    {( sx7}  {{redo sx32}}
    {lcub sx7}  {{redo sx32}}
    {* sx7}  {redo goto-top pop}
    {SEQUENCE sx0}  {{goto sx10}}
    {OF sx10}  {{goto sx11}}
    {type-ref sx11}  {{span id} goto-top pop}
    {lcub sx10}  {{goto sx12}}
    {/id sx12}  {{span id} skip-next {goto sx13}}
    {INTEGER sx13}  {{goto sx16}}
    {BITS sx13}  {{goto sx16}}
    {OCTET sx13}  {{goto sx14}}
    {STRING sx14}  {{goto sx16}}
    {OBJECT sx13}  {{goto sx15}}
    {IDENTIFIER sx15}  {{goto sx16}}
    {type-ref sx13}  {{span id} {goto sx16}}
    {/Itn sx13}  {{span id} skip-next {goto sx16}}
    {, sx16}  {{goto sx12}}
    {rcub sx16}  {goto-top pop}
    {* sx16}  {{push sx18} {redo sxn0}}
    {* sx17}  {{span-top err} pop {goto sx18}}
    {, sx18}  {{goto sx12}}
    {rcub sx18}  {goto-top pop}
    {lsqb sx0}  {{goto sx20}}
    {APPLICATION sx20}  {{goto sx21}}
    {zero sx21}          {{goto sx22}}
    {positive31 sx21}    {{goto sx22}}
    {positive32 sx21}    {{goto sx22}}
    {positive63 sx21}    {{goto sx22}}
    {positive64 sx21}    {{goto sx22}}
    {positive-big sx21}  {{goto sx22}}
    {rsqb sx22}  {{goto sx23}}
    {IMPLICIT sx23}  {{goto sx30}}
    {/Itn sx0}  {{goto sx25}}
    {Integer32 sx25}  {{span id} {push sx38} {goto sxr0}}
    {TimeTicks sx25}   {{span id} goto-top pop}
    {IpAddress sx25}   {{span id} {push sx26} {goto sxa0}}
    {Counter32 sx25}   {{span id} {push sx26} {goto sxa0}}
    {Counter64 sx25}   {{span id} {push sx26} {goto sxa0}}
    {Gauge32 sx25}     {{span id} {push sx26} {goto sxr0}}
    {Integer64 sx25}   {{span id} {push sx26} {goto sxr0}}
    {Unsigned32 sx25}  {{span id} {push sx26} {goto sxr0}}
    {Unsigned64 sx25}  {{span id} {push sx26} {goto sxr0}}
    {Opaque sx25}      {{span id} {push sx26} {goto sxs0}}
    {* sx26}  {redo goto-top pop}
    {* sx0}  {{redo sx30}}
    {INTEGER sx30}  {{push sx38} {goto sxre0}}
    {/Itn sx30}  {{goto sx31}}
    {Integer32 sx31}  {{span id} {push sx38} {goto sxr0}}
    {OCTET sx30}  {{goto sx35}}
    {OBJECT sx30}  {{goto sx36}}
    {type-ref sx30}  {{span id} {goto sx32}}
    {. sx32}  {{goto sx33}}
    {( sx32}  {{push sx38} {goto sxa1}}
    {lcub sx32}  {{push sx38} {redo sxe0}}
    {type-ref sx33}  {{span id} {goto sx34}}
    {( sx34}  {{push sx38} {goto sxa1}}
    {lcub sx34}  {{push sx38} {redo sxe0}}
    {STRING sx35}  {{push sx38} {goto sxs0}}
    {IDENTIFIER sx36}  {{push sx38} {goto sxa0}}
    {* sx38}  {redo goto-top pop}
    {( sxr0}  {{goto sxr1}}
    {SIZE sxr1}  {{push sxx9} {redo sx81}}
    {* sxr1}  {{push sxr2} {redo sx71}}
    {) sxr2}  {pop goto-top pop}
    {lcub sxr0}  {{push sxx9} {goto sx91}}
    {* sxr0}  {redo goto-top pop}
    {( sxs0}  {{goto sxs1}}
    {SIZE sxs1}  {{push sxs2} {redo sx81}}
    {* sxs1}  {{push sxx9} {redo sx71}}
    {) sxs2}  {pop goto-top pop}
    {lcub sxs0}  {{push sxx9} {goto sx91}}
    {* sxs0}  {redo goto-top pop}
    {( sxe0}  {{goto sxe1}}
    {SIZE sxe1}  {{push sxx9} {redo sx81}}
    {* sxe1}  {{push sxx9} {redo sx71}}
    {lcub sxe0}  {{push sxe2} {goto sx91}}
    {rcub sxe2}  {pop goto-top pop}
    {* sxe0}  {redo goto-top pop}
    {( sxa0}  {{goto sxa1}}
    {SIZE sxa1}  {{push sxs2} {redo sx81}}
    {* sxa1}  {{push sxr2} {redo sx71}}
    {lcub sxa0}  {{push sxe2} {goto sx91}}
    {* sxa0}  {redo goto-top pop}
    {( sxn0}  {{goto sxn1}}
    {SIZE sxn1}  {{push sxx9} {redo sx81}}
    {* sxn1}  {{push sxx9} {redo sx71}}
    {lcub sxn0}  {{push sxx9} {goto sx91}}
    {* sxn0}  {redo goto-top pop}
    {( sxre0}  {{goto sxre1}}
    {SIZE sxre1}  {{push sxx9} {redo sx81}}
    {* sxre1}  {{push sxr2} {redo sx71}}
    {lcub sxre0}  {{push sxe2} {goto sx91}}
    {* sxre0}  {redo goto-top pop}
    {* sxx9}  {pop {span-top err} goto-top pop}
    {( sx70}  {{goto sx71}}
    {radix-string sx71}  {{goto sx72}}
    {zero sx71}          {{goto sx72}}
    {positive31 sx71}    {{goto sx72}}
    {positive32 sx71}    {{goto sx72}}
    {positive63 sx71}    {{goto sx72}}
    {positive64 sx71}    {{goto sx72}}
    {positive-big sx71}  {{goto sx72}}
    {negative31 sx71}    {{goto sx72}}
    {negative63 sx71}    {{goto sx72}}
    {negative-big sx71}  {{goto sx72}}
    {| sx72}  {{goto sx71}}
    {) sx72}  {redo goto-top}
    {.. sx72}  {{goto sx73}}
    {radix-string sx73}  {{goto sx74}}
    {zero sx73}          {{goto sx74}}
    {positive31 sx73}    {{goto sx74}}
    {positive32 sx73}    {{goto sx74}}
    {positive63 sx73}    {{goto sx74}}
    {positive64 sx73}    {{goto sx74}}
    {positive-big sx73}  {{goto sx74}}
    {negative31 sx73}    {{goto sx74}}
    {negative63 sx73}    {{goto sx74}}
    {negative-big sx73}  {{goto sx74}}
    {| sx74}  {{goto sx71}}
    {) sx74}  {redo goto-top}
    {( sx80}  {{goto sx81}}
    {SIZE sx81}  {{push sx82} {goto sx70}}
    {) sx82}  {pop {goto sx83}}
    {) sx83}  {redo goto-top}
    {lcub sx90}  {{goto sx91}}
    {/id sx91}  {{span def} skip-next {goto sx92}}
    {( sx92}  {{goto sx93}}
    {zero sx93}          {{goto sx94}}
    {positive31 sx93}    {{goto sx94}}
    {positive32 sx93}    {{goto sx94}}
    {positive63 sx93}    {{goto sx94}}
    {positive64 sx93}    {{goto sx94}}
    {positive-big sx93}  {{goto sx94}}
    {negative31 sx93}    {{goto sx94}}
    {negative63 sx93}    {{goto sx94}}
    {negative-big sx93}  {{goto sx94}}
    {) sx94}  {{goto sx95}}
    {, sx95}  {{goto sx91}}
    {rcub sx95}  {redo goto-top}

    {MACRO mac0}  {{goto mac1}}
    {::= mac1}  {{goto mac2}}
    {BEGIN mac2}  {{goto mac3}}
    {TYPE mac3}  {{goto mac4}}
    {NOTATION mac4}  {{goto mac5}}
    {::= mac5}  {{goto mac10}}
    {type-ref mac10}  {{span id} {goto mac30}}
    {quot mac10}  {{push mac30} {goto qs2}}
    {/id mac10}  {{goto mac11}}
    {type mac11}  {{span key} {goto mac12}}
    {( mac12}  {{goto mac13}}
    {TYPE mac13}  {{goto mac14}}
    {type-ref mac13}  {{span id} {goto mac15}}
    {type-ref mac14}  {{span id} {goto mac15}}
    {) mac15}  {{goto mac30}}
    {value mac11}  {{span key} {goto mac20}}
    {( mac20}  {{goto mac22}}
    {Update mac22}  {{goto mac23}}
    {type-ref mac23}  {{span id} {goto mac29}}
    {/id mac22}  {{span id} skip-next {goto mac24}}
    {OBJECT mac24}  {{goto mac25}}
    {IDENTIFIER mac25}  {{goto mac29}}
    {) mac29}  {{goto mac30}}
    {type-ref mac30}  {{span id} {goto mac30}}
    {quot mac30}  {{push mac30} {goto qs2}}
    {/id mac30}  {{goto mac11}}
    {VALUE mac30}  {{goto mac31}}
    {NOTATION mac31} {{goto mac32}}
    {::= mac32}  {{goto mac33}}
    {/id mac33}  {{goto mac34}}
    {value mac34}  {{span key} {goto mac35}}
    {( mac35}  {{goto mac36}}
    {VALUE mac36}  {{goto mac37}}
    {OBJECT mac37}  {{goto mac38}}
    {IDENTIFIER mac38} {{goto mac39}}
    {INTEGER mac37}  {{goto mac39}}
    {type-ref mac37}  {{span id} {goto mac39}}
    {) mac39}  {{goto mac40}}
    {END mac40}  {{redo mac60}}
    {type-ref-macsyn mac40}  {{span def} {goto mac41}}
    {::= mac41}  {{goto mac50}}
    {type-ref mac50}  {{span id} {goto mac60}}
    {quot mac50}  {{push mac60} {goto qs2}}
    {/id mac50}  {{goto mac51}}
    {* mac51}  {{span id} {goto mac60}}
    {type mac51}  {{span key} {goto mac52}}
    {* mac52}  {{redo mac60}}
    {( mac52}  {{goto mac53}}
    {/id mac53}  {{span id} skip-next {goto mac59}}
    {value mac51}  {{span key} {goto mac55}}
    {( mac55}  {{goto mac56}}
    {OBJECT mac56}  {{goto mac57}}
    {IDENTIFIER mac57}  {{goto mac59}}
    {IA5String mac56}  {{goto mac59}}
    {type-ref mac56}  {{span id} {goto mac59}}
    {Update mac56}  {{goto mac58}}
    {type-ref mac58}  {{span id} {goto mac59}}
    {/id mac56}  {{span id} skip-next {goto mac58}}
    {) mac59}  {{goto mac60}}
    {* mac60}  {{redo mac50}}
    {| mac60}  {{goto mac50}}
    {type-ref-macsyn mac60}  {{redo mac40}}
    {END mac60}  {{redo m99}}

    {lcub lor1}  {{push lor2} {goto oid1}}
    {rcub lor2}  {goto-top pop}
    {lcub lor1d}  {{push lor2d} {goto oid1}}
    {rcub lor2d}  {{redo m99}}

    {zero oid1}        {{goto oid2}}
    {positive31 oid1}  {{goto oid2}}
    {positive32 oid1}  {{goto oid2}}
    {/id oid1}  {{span id} skip-next {goto oid3}}
    {type-ref oid1}  {{goto oid6}}
    {, oid2}  {redo goto-top pop}
    {rcub oid2}  {redo goto-top pop}
    {* oid2}  {redo goto-top pop}
    {zero oid2}        {}
    {positive31 oid2}  {}
    {positive32 oid2}  {}
    {/id oid2}  {{span id} skip-next {goto oid3}}
    {type-ref oid2}  {{goto oid6}}
    {, oid3}  {redo goto-top pop}
    {rcub oid3}  {redo goto-top pop}
    {zero oid3}        {{goto oid2}}
    {positive31 oid3}  {{goto oid2}}
    {positive32 oid3}  {{goto oid2}}
    {* oid3}  {{redo oid2}}
    {( oid3}  {{goto oid4}}
    {zero oid4}        {{goto oid5}}
    {positive31 oid4}  {{goto oid5}}
    {positive32 oid4}  {{goto oid5}}
    {) oid5}  {{goto oid2}}
    {. oid6}  {{redo oid7 1}}
    {* oid6}  {{redo oid9 1}}
    {type-ref oid7}  {{span id} skip-next {goto oid8}}
    {/id oid8}  {{span id} skip-next {goto oid3}}
    {type-ref oid9}  {{span err} {goto oid2}}

    {quot qs1}  {{goto qs2}}
    {qstr qs2}  {{span str}}
    {quot qs2}  {goto-top pop}
    {quot qs1x}  {{goto qs2x}}
    {qstr qs2x}  {{span str}}
    {quot qs2x}  {goto-top}
    {quot qs1d}  {{goto qs2d}}
    {qstr qs2d}  {{span str}}
    {quot qs2d}  {div-top goto-top pop}
    {quot qs1dd}  {{goto qs2dd}}
    {qstr qs2dd}  {{span str}}
    {quot qs2dd}  {div-top goto-top pop div-top pop}
}

#               }}}4 artwork::grammar(mib)
#           }}}3 mib
#       }}}2 grammars
#   }}}1 artwork content processing

#   {{{1 xdv validator
# pity i didn't build this into xml2rfc initially,
# because integrating properly would be a lot of work...

#       {{{2 namespace
namespace eval xdv {
    variable dtd
    # This ::xdv::lineno is 0-based.
    variable lineno -1

    catch { array unset dtd }
}
#       }}}2 namespace
#       {{{2 rfc2629 DTD
# Strict content model does not allow section in back...
set xdv::dtd(rfc2629.cmodel) \
    [list rfc           [list front             ""   \
                              middle            ""   \
                              back              "?"] \
          front         [list title             ""   \
                              author            "+"  \
                              date              ""   \
                              area              "*"  \
                              workgroup         "*"  \
                              keyword           "*"  \
                              abstract          "?"  \
                              note              "*"] \
          middle        [list section           "+"  \
                              appendix          "*"  \
                              section           "*"] \
          back          [list references        "*"  \
                              section           "*"] \
          title         {}                           \
          author        [list organization      "?"   \
                              address           "*"] \
          organization  {}                           \
          address       [list postal            "?"  \
                              phone             "?"  \
                              facsimile         "?"  \
                              email             "?"  \
                              uri               "?"] \
          postal        [list street            "+"  \
                              [list city             \
                                    region           \
                                    code             \
                                    country]    *]   \
          street        {}                           \
          city          {}                           \
          region        {}                           \
          code          {}                           \
          country       {}                           \
          phone         {}                           \
          facsimile     {}                           \
          email         {}                           \
          uri           {}                           \
          date          {}                           \
          area          {}                           \
          workgroup     {}                           \
          keyword       {}                           \
          abstract      [list t                 "+"] \
          note          [list t                 "+"] \
          section       [list [list t                \
                                    figure           \
                                    texttable        \
                                    iref]       "*"  \
                                    section     "*"] \
          appendix      [list [list t                \
                                    figure           \
                                    texttable        \
                                    iref]       "*"  \
                                    appendix    "*"] \
          t             [list [list list             \
                                    figure           \
                                    xref             \
                                    eref             \
                                    iref             \
                                    cref             \
                                    vspace           \
                                    spanx]      "*"] \
          list          [list t                 "+"] \
          xref          {}                           \
          eref          {}                           \
          iref          {}                           \
          cref          {}                           \
          vspace        {}                           \
          spanx         {}                           \
          figure        [list iref              "*"  \
                              preamble          "?"  \
                              artwork           ""   \
                              postamble         "?"] \
          preamble      [list [list xref             \
                                    eref             \
                                    iref             \
                                    cref             \
                                    spanx]      "*"] \
          artwork       {}                           \
          postamble     [list [list xref             \
                                    eref             \
                                    iref             \
                                    cref             \
                                    spanx]      "*"] \
          texttable     [list preamble          "?"  \
                              ttcol             "+"  \
                              c                 "*"  \
                              postamble         "?"] \
          ttcol         {}                           \
          c             [list [list xref             \
                                    eref             \
                                    iref             \
                                    cref             \
                                    spanx]      "*"] \
          references    [list reference         "+"] \
          reference     [list front             ""   \
                              seriesInfo        "*"  \
                              format            "*"  \
                              annotation        "*"] \
          seriesInfo    {}                           \
          format        {}                           \
          annotation    [list [list xref             \
                                    eref             \
                                    iref             \
                                    cref             \
                                    spanx]      "*"]]

set xdv::dtd(rfc2629.pcdata) \
    [list annotation   \
          area         \
          artwork      \
          c            \
          city         \
          code         \
          country      \
          cref         \
          email        \
          eref         \
          facsimile    \
          keyword      \
          organization \
          phone        \
          postamble    \
          preamble     \
          region       \
          spanx        \
          street       \
          t            \
          ttcol        \
          title        \
          uri          \
          workgroup    \
          xref]

set xdv::dtd(rfc2629.rattrs) \
    [list note          [list title]  \
          section       [list title]  \
          appendix      [list title]  \
          xref          [list target] \
          eref          [list target] \
          iref          [list item]   \
          seriesInfo    [list name    \
                              value]  \
          format        [list type]]

set xdv::dtd(rfc2629.oattrs) \
    [list rfc           [list number      \
                              obsoletes   \
                              updates     \
                              category    \
                              seriesNo    \
                              ipr         \
                              iprExtract  \
                              submissionType \
                              consensus   \
                              docName     \
                              xml:lang]   \
          title         [list abbrev]     \
          author        [list initials    \
                              surname     \
                              fullname    \
                              role]       \
          organization  [list abbrev]     \
          date          [list day         \
                              month       \
                              year]       \
          section       [list anchor      \
                              toc]        \
          appendix      [list anchor      \
                              toc]        \
          t             [list anchor      \
                              hangText]   \
          list          [list style       \
                              hangIndent  \
                              counter]    \
          xref          [list pageno      \
                              format]     \
          iref          [list subitem     \
                              primary]    \
          cref          [list anchor      \
                              source]     \
          spanx         [list xml:space   \
                              style]      \
          vspace        [list blankLines] \
          figure        [list anchor      \
                              title       \
                              suppress-title \
                              src         \
                              align       \
                              alt         \
                              width       \
                              height]     \
          artwork       [list xml:space   \
                              name        \
                              type        \
                              src         \
                              align       \
                              alt         \
                              width       \
                              height]     \
          texttable     [list anchor      \
                              title       \
                              suppress-title \
                              align       \
                              style]      \
          ttcol         [list width       \
                              align]      \
          references    [list title]      \
          reference     [list anchor      \
                              target]     \
          seriesInfo    [list name        \
                              value]      \
          format        [list target      \
                              octets]]  \

set xdv::dtd(rfc2629.anchors) \
    [list anchor]
#       }}}2 rfc2629 DTD
#       {{{2 procs
proc xdv::validate_tree {root CM RA OA AN PC} {
    variable anchorX {}

    validate_tree_aux $root $CM $RA $OA $AN $PC {}
}

proc xdv::validate_tree_aux {parent CM RA OA AN PC stack} {
    variable anchorX
    variable dtd

    set name [lindex $parent 0]
    array set attrs [lindex $parent 1]
    set children [lrange $parent 2 end]

    lappend stack [list $name [array get attrs]]

    array set cmodel $dtd($CM)
    if {![info exists cmodel($name)]} {
        report "not expecting <$name> element" $stack
    }

    array set required $dtd($RA)
    if {[info exists required($name)]} {
        foreach k [set expected $required($name)] {
            if {![info exists attrs($k)]} {
                report "missing $k attribute in <$name> element" $stack
            }
        }
    } else {
        set expected {}
    }

    array set optional $dtd($OA)
    if {[catch { set optional($name) } possible]} {
        set possible {}
    }
    foreach k [array names attrs] {
        if {([string first . $k] < 0) \
                && ([lsearch -exact $expected $k] < 0) \
                && ([lsearch -exact $possible $k] < 0)} {
            report "unexpected $k attribute in <$name> element" $stack
        }
    }

    foreach {k v} [array get attrs] {
        if {[lsearch -exact $dtd($AN) $name/$k] >= 0} {
            if {[lsearch -exact $anchorX $v] >= 0} {
                report "duplicate anchor '$v'" $stack
            }
            lappend anchorX $v
        }
    }

    if {([info exists attrs(.pcdata)]) \
            && ([lsearch $dtd($PC) $name] < 0)} {
        report "not expecting pcdata in <$name> element" $stack
    }

    if {[catch { validate_cmodel $children $cmodel($name) } result]} {
        # The $stack list will have been upvar-appended on error.
        report $result $stack
    }

    foreach child $children {
        validate_tree_aux $child $CM $RA $OA $AN $PC $stack
    }
}

proc xdv::validate_cmodel {children cmodel} {
    # Uses uplevel proc xdv::shift_cmodel.
    # Uses uplevel proc xdv::xmerge.

    upvar name n

    set err "with content model {$cmodel} for <$n>"
    shift_cmodel

    set seen {}
    set expected {}
    foreach child $children {
        set e [lindex $child 0]
        while {1} {
            if {[lsearch -exact $elems $e] >= 0} {
                set expected {}
                switch -- $quant {
                    +      { set quant "*" }
                    ? - "" { shift_cmodel }
                }
            } else {
                switch -- $quant {
                    ? - * {
                        xmerge
                        shift_cmodel
                        continue
                    }

                    default {
                        upvar stack s
                        lappend s [list $e [lindex $child 1]]
                        append err ", seen {$seen} so far, now expecting "
                        switch -- [llength $elems] {
                            0       { lappend expected "</$n>" }
                            default { xmerge }
                        }
                        append err [or_list $expected]
                        error "$err, but not <$e>"
                    }
                }
            }
            break
        }
        lappend seen "$e"
    }
    switch -- $quant {
        ? - *   {}
        default {
            if {[llength $elems] > 0} {
                set err0 "seen {$seen} so far, first expecting "
                xmerge
                append err0 [or_list $expected]
                error "$err0 but got </$n>, $err"
            }
        }
    }
}

proc xdv::shift_cmodel {} {
    uplevel 1 {
        set elems  [lindex $cmodel 0]
        set quant  [lindex $cmodel 1]
        set cmodel [lrange $cmodel 2 end]
    }
}

proc xdv::xmerge {} {
    uplevel 1 {
        foreach x $elems {
            set y "<$x>"
            if {[lsearch -exact $expected $y] < 0} {
                lappend expected $y
            }
        }
    }
}

proc xdv::or_list {items} {
    set t ""
    set s ""
    set i 1
    set n [llength $items]
    foreach e $items {
        append t $s$e
        if {[incr i] == $n} {
            if {$n > 2} {
                set s ", or "
            } else {
                set s " or "
            }
        } else {
            set s ", "
        }
    }

    return $t
}

proc xdv::report {result stack} {
    global options

    if {[set i [llength $stack]] > 0} {
        array set attrs [lindex [lindex $stack end] 1]
        if {[info exists attrs(.lineno)]} {
            append result " around line $attrs(.lineno)"
        }

        # only report stack if fatal.
        if {$options(.STRICT)} {
            set text "Syntax:"
            while {$i > 0} {
                set frame [lindex $stack [incr i -1]]
                array set attrs [lindex $frame 1]
                append text "\n    "
                if {[info exists attrs(.lineno)]} {
                    append text [expr $attrs(.lineno) + 1]:
                }
                append text <[lindex $frame 0]
                foreach {k v} [lindex $frame 1] {
                    if {[string first . $k] < 0} {
                        regsub -all -- \" $v {\&quot;} v
                        append text " $k=\"$v\""
                    }
                }
                append text ">"
            }
            append result "\n\n$text"
        }
    }

    unexpected [unex_condtype] $result
}
#       }}}2 procs
#   }}}1 xdv validator

#   {{{1 tclsh/wish linkage

global guiP
if {[info exists guiP]} {
    return
}
set guiP 0
if {[llength $argv] > 1} {
    if {[catch {
        check_vrsn

        switch -- [llength $argv] {
            2 {
                set file [lindex $argv 1]
                if {![string compare $tcl_platform(platform) \
                             windows]} {
                    set f ""
                    foreach c [split $file ""] {
                        switch -- $c {
                            "\\"    { append f "\\\\" }
                            "\a"    { append f "\\a"  }
                            "\b"    { append f "\\b"  }
                            "\f"    { append f "\\f"  }
                            "\n"    { append f "\\n"  }
                            "\r"    { append f "\\r"  }
                            "\v"    { append f "\\v"  }
                            default { append f $c     }
                        }
                    }
                    set file $f
                }

                eval [file tail [file rootname [lindex $argv 0]]] \
                           $file
            }

            3 { xml2rfc [lindex $argv 1] [lindex $argv 2] }
        }

        check_vrsn_idle
    } result]} {
        if {![catch {package require Tk}]} {
            catch { wm geometry . 10x10+-100+-100 }
            catch { wm withdraw . }
            bgerror $result
        } else {
            puts stderr "$prog: error: $result"
        }
        exit 1
    }

    exit 0
} elseif {[catch {package require Tk}]} {
    set guiP -1
    #puts stdout ""
    puts stdout "invoke as \"xml2rfc   input-file output-file\""
    puts stdout "       or \"xml2txt   input-file\""
    puts stdout "       or \"xml2html  input-file\""
    puts stdout "       or \"xml2nroff input-file\""
    puts stdout "       or \"xml2unpg  input-file\""
} else {
    set guiP 1

    proc convert {w} {
        global prog
        global tcl_platform

        if {![string compare [set input [.input.ent get]] ""]} {
            tk_dialog .error "$prog: oops!" "no input file-name specified" \
                      error 0 OK
            return
        }
        set output [.output.ent get]

        if {[catch { xml2rfc $input $output } result]} {
            tk_dialog .error "$prog: oops!" $result error 0 OK
        } elseif {![string compare $tcl_platform(platform) windows]} {
            tk_dialog .ok xml2rfc "Finished." "" 0 OK
        }
    }

    proc fileDialog {w ent operation} {
        global tcl_platform

        # tcl_platform(platform) tcl_platform(os) windowingsystem tk_getSaveFile
        # ---------------------- ---------------- --------------- --------------
        # dos                    ""               ?               ?
        # macintosh              MacOS            classic         native
        # unix                   Darwin           aqua            native
        # unix                   Darwin           x11             proc
        # unix                   `uname -s`       x11             proc
        # windows                Win32s           win32           native
        # windows                Windows 95       win32           native
        # windows                Windows NT       win32           native
        # windows                Windows CE       win32           native

        # However [tk windowingsystem] did not exist before 8.4.
        if {![catch {set winsys [tk windowingsystem]}]} {
            set ext [expr    ![string compare $winsys classic] \
                          || ![string compare $winsys aqua]    ]
        } else {
            set ext [expr    [catch {info body tk_getSaveFile}              ] \
                          && [string compare $tcl_platform(platform) windows] ]
        }

        switch -- $tcl_platform(platform) {
            windows { set dx .txt }
            default { set dx ""   }
        }

        set in_types {
            {"XML files"               .xml  }
            {"All files"               *     }
        }
        set out_types {
            {"TeXT files"              .txt  }
            {"HTML files"              .html }
            {"NRoff files"             .nr   }
            {"UNPaGinated text files"  .unpg }
            {"XML files"               .xml  }
        }
        if {![string compare $operation "input"]} {
            set file [tk_getOpenFile -filetypes $in_types -parent $w]
        } else {
            if {   ![catch { set browse [.output.ent get] }]
                &&  [string compare $browse ""]} {
                if {!$ext} {
                    set browse [file rootname $browse]
                }
            } else {
                if {   ![catch { set browse [.input.ent get] }]
                    &&  [string compare $browse ""]} {
                    set browse [file rootname $browse]
                } else {
                    set browse Untitled
                }
                if {$ext} {
                    append browse ".txt"
                }
            }
            set file [tk_getSaveFile -filetypes $out_types -parent $w    \
                                     -initialdir  [file dirname $browse] \
                                     -initialfile [file tail    $browse] \
                                     -defaultextension $dx               ]
        }
        if [string compare $file ""] {
            $ent delete 0 end
            $ent insert 0 $file
            $ent xview end
            if {   ![string compare $operation "input"]
                && (    [catch { set browse [.output.ent get] }]
                    || ![string compare $browse ""])} {
                catch {
                    .output.ent insert 0 [file rootname $file].txt
                    .output.ent xview end
                }
            }
        }
    }

    eval destroy [winfo child .]

    wm title . $prog
    wm iconname . $prog
    wm geometry . +300+300

    label .msg -font "Helvetica 14" -wraplength 4i -justify left \
          -text "Convert XML to RFC"
    pack .msg -side top

    frame .buttons
    pack .buttons -side bottom -fill x -pady 2m
    pack \
        [button .buttons.code -text Convert -command "convert ."] \
        [button .buttons.dismiss -text Quit -command "destroy ."] \
        -side left -expand 1

    foreach i {input output} {
        set f [frame .$i]
        label $f.lab -text "Select $i file: " -anchor e -width 20
        entry $f.ent -width 20
        button $f.but -text "Browse ..." -command "fileDialog . $f.ent $i"
        pack $f.lab -side left
        pack $f.ent -side left -expand yes -fill x
        pack $f.but -side left
        pack $f -fill x -padx 1c -pady 3
    }

    check_vrsn
}

#   }}}1 tclsh/wish linkage

# vi: set sw=4 et si sta fdm=marker:
