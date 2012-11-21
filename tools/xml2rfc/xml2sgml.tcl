#!/bin/sh
# the next line restarts using wish \
exec wish "$0" "$0" "$@"


# TODO:
#       seriesInfo: RFC, I-D
#       iref


#
# here begins TclXML 1.1.1
#


# earlier versions used to "package require xml 1.8", but because newer tcl
# installations have an incompatibly-verionsed sgml package, this caused
# nothing but problems. hence, we just include TclXML-1.1.1 wholesale toward
# the end of the file...


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
    if {[regexp {<!DOCTYPE[^[<]+\[([^]]+)\]} $sgml discard dtd]} {
        regsub {(<!DOCTYPE[^[<]+)(\[[^]]+\])} $sgml {\1\&xml:intdtd;} sgml
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
        }
    }

    foreach {tag close empty param text} $sgml {

        # Keep track of lines in the input
        incr state(line) [regsub -all \n $param {} discard]
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
                            uplevel #0 $options(-errorcommand) "unexpected characters \"<$tag\" around line $state(line)"
                        } elseif {![regexp {\?$} $param]} {
                            uplevel #0 $options(-errorcommand) "XML Declaration missing characters \"?>\" around line $state(line)"
                        } else {

                            # Get the version number
                            if {[regexp {[      ]*version="(-+|[a-zA-Z0-9_.:]+)"[       ]*} $param discard version] || [regexp {[       ]*version='(-+|[a-zA-Z0-9_.:]+)'[       ]*} $param discard version]} {
                                if {[string compare $version "1.0"]} {
                                    # Should we support future versions?
                                    # At least 1.X?
                                    uplevel #0 $options(-errorcommand) "document XML version \"$version\" is incompatible with XML version 1.0"
                                }
                            } else {
                                uplevel #0 $options(-errorcommand) "XML Declaration missing version information around line $state(line)"
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
                        if {![regsub {\?$} $param {} param]} {
                            uplevel #0 $options(-errorcommand) "PI: expected '?' character around line $state(line)"
                        } else {
                            uplevel #0 $options(-processinginstructioncommand) [list [string range $tag 1 end] [string trimleft $param]]
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
                                            uplevel #0 $options(-errorcommand) "syntax error: PUBLIC identifier not followed by system literal around line $state(line)"
                                        }
                                    } else {
                                        uplevel #0 $options(-errorcommand) "syntax error: PUBLIC identifier not followed by literal around line $state(line)"
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
                        uplevel #0 $options(-errorcommand) [list "unknown processing instruction \"<$tag>\" around line $state(line)"]
                    }
                }
            }
            *,1,* -
            *,0,/,/ {
                # Syntax error
                uplevel #0 $options(-errorcommand) [list [list syntax error: closed/empty tag: tag $tag param $param empty $empty close $close around line $state(line)]]
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
                uplevel #0 $options(-characterdatacommand) [list $text]
            }
        } elseif {[string length [string trim $text]]} {
            uplevel #0 $options(-errorcommand) "unexpected text \"$text\" in document prolog around line $state(line)"
        }

    }

    # If this is the end of the document, close all open containers
    if {$options(-final) && [llength $state(stack)]} {
        eval $options(-errorcommand) [list [list element [lindex $state(stack) end] remains unclosed around line $state(line)]]
    }

    return {}
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
            uplevel #0 $options(-errorcommand) [list $attr around line $state(line)]
            set attr {}
        }
    }

    set empty {}
    if {$cfg(-empty) && $options(-reportempty)} {
        set empty {-empty 1}
    }

    # Invoke callback
    uplevel #0 $options(-elementstartcommand) [list $tag $attr] $empty

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
        uplevel #0 $options(-errorcommand) [list "end tag \"$tag\" does not match open element \"[lindex $state(stack) end]\" around line $state(line)"]
        return
    }

    # Update state
    set state(stack) [lreplace $state(stack) end end]

    set empty {}
    if {$cfg(-empty) && $options(-reportempty)} {
        set empty {-empty 1}
    }

    # Invoke callback
    uplevel #0 $options(-elementendcommand) [list $tag] $empty

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
#               {} {:seq {{} head} {* {:choice {{} p} {{} list} {{} note}}} {* div2}}
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

proc sgml::nullable {nodeType rep name {subtree {}}} {
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

proc sgml::DTDAttribute {name type default {value {}}} {
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


#
# here ends TclXML 1.1.1
#


global dparser
if {![info exists dparser]} {
    set dparser ""
}


proc xml2sgml {input {output ""}} {
    global errorCode errorInfo
    global dparser errorP passno stdout

    if {![string compare [file extension $input] ""]} {
        append input .xml
    }

    set stdin [open $input { RDONLY }]
    set inputD [file dirname [set ifile $input]]

    if {![string compare $output ""]} {
        set output [file rootname $input].sgml
    }
    if {![string compare $input $output]} {
        error "input and output files must be different"
    }

    if {[file exists [set file [file join $inputD .xml2rfc.rc]]]} {
        source $file
    }

    set data [prexml [read $stdin] $inputD $input]

    catch { close $stdin }

    set code [catch {
        if {![string compare $dparser ""]} {
            global emptyA

            set dparser [xml::parser]
            array set emptyA {}

            $dparser configure \
                        -elementstartcommand          { xml_begin           } \
                        -elementendcommand            { xml_end             } \
                        -characterdatacommand         { xml_pcdata          } \
                        -entityreferencecommand       ""                      \
                        -errorcommand                 { unexpected error    } \
                        -warningcommand               { unexpected warning  } \
                        -entityvariable               emptyA                  \
                        -final                        yes                     \
                        -reportempty                  no
        }

        set passmax 2
        set stdout ""
        for {set passno 1} {$passno <= $passmax} {incr passno} {
            xml_pass start $output
            $dparser parse $data
            xml_pass end
            if {$errorP} {
                break
            }
        }
    } result]
    set ecode $errorCode
    set einfo $errorInfo

    catch { close $stdout }

    if {$code == 1} {
        set result [around2fl $result]

        catch {
            global stack

            if {[llength $stack] > 0} {
                set text "Context: "
                foreach frame $stack {
                    append text "\n    <[lindex $frame 0]"
                    foreach {k v} [lindex $frame 2] {
                        regsub -all {"} $v {&quot;} v
                        append text " $k=\"$v\""
                    }
                    append text ">"
                }
                append result "\n\n$text"
            }
        }
    }

    return -code $code -errorinfo $einfo -errorcode $ecode $result
}

proc prexml {stream inputD {inputF ""}} {
    global env tcl_platform

    if {[catch { set path $env(XML_LIBRARY) }]} {
        set path [list $inputD]
    }
    switch -- $tcl_platform(platform) {
        windows {
            set c ";"
        }

        default {
            set c ":"
        }
    }
    set path [split $path $c]

    if {[string first "%include." $stream] < 0} {
        set newP 1
    } else {
        set newP 0
    }
    set stream [prexmlaux $newP $stream $inputD $inputF $path]

# because <![CDATA[ ... ]]> isn't supported in TclXML...
    set data ""
    set litN [string length [set litS "<!\[CDATA\["]]
    set litO [string length [set litT "\]\]>"]]
    while {[set x [string first $litS $stream]] >= 0} {
        append data [string range $stream 0 [expr $x-1]]
        set stream [string range $stream [expr $x+$litN] end]
        if {[set x [string first $litT $stream]] < 0} {
            error "missing close to CDATA"
        }
        set y [string range $stream 0 [expr $x-1]]
        regsub -all {&} $y {\&amp;} y
        regsub -all {<} $y {\&lt;}  y
        append data $y
        set stream [string range $stream [expr $x+$litO] end]
    }
    append data $stream

    return $data
}

proc prexmlaux {newP stream inputD inputF path} {
    global fldata

# an MTR hack...

# the old way:
#
# whenever "%include.whatever;" is encountered, act as if the DTD contains
#
#       <!ENTITY % include.whatever SYSTEM "whatever.xml">
#
# this yields a nested (and cheap-and-easy) include facility.
#

# the new way:
#
# <?rfc include='whatever' ?>
#
# note that this occurs *before* the xml parsing occurs, so they aren't hidden
# inside a <![CDATA[ ... ]]> block.
#

    if {$newP} {
        set litS "<?rfc include="
        set litT "?>"
    } else {
        set litS "%include."
        set litT ";"
    }
    set litN [string length $litS]
    set litO [string length $litT]

    set data ""
    set fldata [list [list $inputF [set lineno 1] [numlines $stream]]]
    while {[set x [string first $litS $stream]] >= 0} {
        incr lineno [numlines [set initial \
                                   [string range $stream 0 [expr $x-1]]]]
        append data $initial
        set stream [string range $stream [expr $x+$litN] end]
        if {[set x [string first $litT $stream]] < 0} {
            error "missing close to %include.*"
        }
        set y [string range $stream 0 [expr $x-1]]
        if {$newP} {
            set y [string trim $y]
            if {[set quoteP [string first "'" $y]]} {
                regsub -- {^"([^"]*)"$} $y {\1} y
            } else {
                regsub -- {^'([^']*)'$} $y {\1} y
            }
        }
        if {![regexp -nocase -- {^[a-z0-9.-]+$} $y]} {
            error "invalid include $y"
        }
        set include ""
        foreach dir $path {
            if {(![file exists [set file [file join $dir $y]]]) \
                    && (![file exists [set file [file join $dir $y.xml]]])} {
                continue
            }
            set fd [open $file { RDONLY }]
            set include [read $fd]
            catch { close $fd }
            break
        }
        if {![string compare $include ""]} {
            error "unable to find external file $y.xml"
        }

        set len [numlines $include]
        set flnew {}
        foreach fldatum $fldata {
            set end [lindex $fldatum 2]
            if {$end >= $lineno} {
                set fldatum [lreplace $fldatum 2 2 [expr $end+$len]]
            }
            lappend flnew $fldatum
        }
        set fldata $flnew
        lappend fldata [list $file $lineno $len]

        set stream $include[string range $stream [expr $x+$litO] end]
    }
    append data $stream

    return $data
}

proc numlines {text} {
    set n [llength [split $text "\n"]]
    if {![string compare [string range $text end end] "\n"]} {
        incr n -1
    }

    return $n
}

proc around2fl {result} {
    global fldata

    if {[regexp -nocase -- { around line ([1-9][0-9]*)} $result x lineno] \
            != 1} {
        return $result
    }

    set file ""
    set offset 0
    set max 0
    foreach fldatum $fldata {
        if {[set start [lindex $fldatum 1]] > $lineno} {
            break
        }
        if {[set new [expr $start+[set len [lindex $fldatum 2]]]] < $max} {
            continue
        }

        if {$lineno <= $new} {
            set file [lindex $fldatum 0]
            set offset [expr $lineno-$start]
        } else {
            incr offset -$len
            set max $new
        }
    }

    set tail " around line $offset"
    if {[string compare $file [lindex [lindex $fldata 0] 0]]} {
        append tail " in $file"
    }
    regsub " around line $lineno" $result $tail result

    return $result
}

proc xml_pass {tag {output ""}} {
    global counter depth elem elemN errorP passno stack stdout

    switch -- $tag {
        start {
            catch { unset depth }
            array set depth [list bookinfo 0 list 0 note 0 section 0]
            set elemN 0
            set stack {}
            switch --  $passno {
                1 {
                    catch {unset counter }
                    catch {unset elem }
                    set errorP 0
                }

                2 {
                    set stdout [open $output { WRONLY CREAT TRUNC }]
                }
            }
        }

        end {
        }
    }

}

proc xml_begin {name {av {}}} {
    global counter depth elem elemN errorP passno stack stdout

    incr elemN

# because TclXML... quotes attribute values containing "]"
    set kv ""
    foreach {k v} $av {
        lappend kv $k
        regsub -all {\\\[} $v {[} v
        lappend kv $v
    }
    set av $kv

    if {($passno == 1) && ($elemN > 1)} {
        set parent [lindex [lindex $stack end] 1]
        array set pv $elem($parent)
        lappend pv(.CHILDREN) $elemN
        set elem($parent) [array get pv]
    }

    lappend stack [list $name [set elemX $elemN] $av]

    if {$passno == 1} {
        array set attrs $av
        array set attrs [list .NAME $name .CHILDREN {}]
        if {[lsearch -exact [list title organization \
                                  street city region code country \
                                  phone facsimile email uri \
                                  area workgroup keyword \
                                  ttcol spanx \
                                  xref eref seriesInfo] $name] >= 0} {
            set attrs(.PCDATA) ""
        }
        switch -- $name {
            list {
                if {![info exists attrs(style)]} {
                    set style empty
    
                    foreach frame [lrange $stack 0 end-1] {
                        if {[string compare [lindex $frame 0] list]} {
                            continue
                        }
                        set elemY [lindex $frame 1]
                        array set pv $elem($elemY)
        
                        set style $pv(style)
                    }

                    set attrs(style) $style
                }

                if {![string first "format " $attrs(style)]} {
                    set format [string trimleft \
                                       [string range $attrs(style) 7 end]]
                    set attrs(style) hanging
                    if {([string compare [set attrs(format) $format] ""]) \
                            && (![info exists counter($format)])} {
                        set counter($format) 0
                    }
                } else {
                    set attrs(format) ""
                }
            }

            t {
                if {![info exists attrs(hangText)]} {
                    set style ""
                    set format ""
    
                    foreach frame [lrange $stack 0 end-1] {
                        if {[string compare [lindex $frame 0] list]} {
                            continue
                        }
                        set elemY [lindex $frame 1]
                        array set pv $elem($elemY)

                        set style $pv(style)
                        set format $pv(format)
                    }
                
                    if {[string compare $format ""]} {
                        set attrs(hangText) \
                            [format $format [incr counter($format)]]
                    }
                }
            }
        }

        set elem($elemN) [array get attrs]

        return
    }

    if {([lsearch -exact [list front area workgroup keyword \
                               abstract note section appendix \
                               t list figure preamble postamble \
                               texttable ttcol c \
                               xref eref iref vspace spanx back] $name] >= 0) \
            && ([lsearch0 $stack references] >= 0)} {
        return  
    }

    array set attrs $elem($elemX)

    switch -- $name {
        rfc {
            puts $stdout \
                 "<!DOCTYPE book PUBLIC \"-//OASIS//DTD DocBook V3.1//EN\">"
            puts $stdout "<book>"
        }

        front {
            incr depth(bookinfo)
            puts $stdout "<bookinfo>"

            if {[lsearch0 $stack reference] >= 0} {
                set hitP 0
                foreach child [find_element seriesInfo $attrs(.CHILDREN)] {
                    array set sv $elem($child)
                    switch -- $sv(name) {
                        isbn - issn {
                            set hitP 1
                        }
                    }
                    unset sv
                }
                if {!$hitP} {
                    set attrs(.ORGNAME) ""
                    set elem($elemX) [array get attrs]
                }
            }
        }

        title {
            if {[lsearch0 $stack reference] >= 0} {
                set reference [lindex [lindex $stack end-2] 1]
                array set rv $elem($reference)
                foreach child [find_element seriesInfo $rv(.CHILDREN)] {
                    array set sv $elem($child)
                    switch -- $sv(name) {
                        RFC {
                            set attrs(.PCDATA) \
                                "RFC $sv(value): $attrs(.PCDATA)"
                            break
                        }
                    }
                    unset sv
                }
            }

            puts -nonewline $stdout "<title>"
            pcdata_sgml $attrs(.PCDATA)
            puts $stdout "</title>"
        }

        author {
            if {[lsearch0 $stack reference] >= 0} {
                set reference [lindex [lindex $stack end-2] 1]
                array set rv $elem($reference)
            }
            set authorP 0
            set firstP 0

            if {[info exists attrs(fullname)]} {
                if {([info exists attrs(surname)]) \
                        && ([string compare $attrs(fullname) \
                                    "$attrs(initials) $attrs(surname)"]) \
                        && ([set x [string last $attrs(surname) \
                                           $attrs(fullname)]] > 0)} {
                    set name [string range $attrs(fullname) 0 [expr $x-1]]

                    if {[info exists attrs(initials)]} {
                        set i {}
                        foreach n [lrange [split $attrs(initials) .] 1 end-1] {
                            set i [linsert $i 0 $n]
                        }
                        foreach n $i {
                            if {[set x [string last "$n. " $name]] > 0} {
                                set name [string range $name 0 [expr $x-1]]
                            } else {
                                break
                            }
                        }
                    }

                    if {([info exists attrs(initials)]) \
                            && ([string compare $attrs(initials) \
                                        [set name \
                                             [string trimright $name]]])} {
                        if {!$authorP} {
                            incr authorP
                            puts $stdout "<author>"
                        }

                        incr firstP
                        puts -nonewline $stdout "<firstname>"
                        pcdata_sgml $name
                        puts $stdout "</firstname>"
                    }
                }
            }

            if {(!$firstP) && ([info exists attrs(initials)])} {
                if {!$authorP} {
                    incr authorP
                    puts $stdout "<author>"
                }
                puts -nonewline $stdout "<othername role=\"initials\">"
                pcdata_sgml $attrs(initials)
                puts $stdout "</othername>"
            }

            if {[info exists attrs(surname)]} {
                if {!$authorP} {
                    incr authorP
                    puts $stdout "<author>"
                }
                puts -nonewline $stdout "<surname>"
                pcdata_sgml $attrs(surname)
                puts $stdout "</surname>"
            }

            foreach child [find_element organization $attrs(.CHILDREN)] {
                array set ov $elem($child)
                if {[set x [string last . $ov(.PCDATA)]] \
                        == [expr [string length $ov(.PCDATA)]-1]} {
                    set ov(.PCDATA) [string range $ov(.PCDATA) 0 [expr $x-1]]
                }
                if {[lsearch0 $stack reference] >= 0} {
                    if {![info exists rv(.ORGNAME)]} {
                        set rv(.ORGNAME) $ov(.PCDATA)
                        set elem($reference) [array get rv]
                    }
                    break
                }

                if {!$authorP} {
                    incr authorP
                    puts $stdout "<author>"
                }
                puts $stdout "<affiliation>"

                puts -nonewline $stdout "<orgname>"
                pcdata_sgml $ov(.PCDATA)
                puts $stdout "</orgname>"

                if {[info exists ov(abbrev)]} {
                    puts -nonewline $stdout "<shortaffil>"
                    pcdata_sgml $ov(abbrev)
                    puts $stdout "</shortaffil>"
                }

                puts $stdout "</affiliation>"
                break
            }

# street, city, region, code country
# phone, facsimile, email, uri

            if {$authorP} {
                puts $stdout "</author>"
            }
        }

        date {
            if {[lsearch0 $stack reference] >= 0} {
                set tag releaseinfo
            } else {
                set tag pubdate
            }
            if {[info exists attrs(year)]} {
                puts -nonewline $stdout "<$tag>"
                if {[info exists attrs(month)]} {
                    puts -nonewline $stdout "$attrs(month) "
                }
                puts $stdout "$attrs(year)</$tag>"
            }

            if {$depth(bookinfo) > 0} {
                incr depth(bookinfo) -1
                puts $stdout "</bookinfo>"
            }
        }

        area - workgroup - keyword {
        }

        abstract {
            puts $stdout "<preface>"
            puts $stdout "<title>Abstract</title>"
        }

        note {
            if {![string compare [string tolower $attrs(title)] dedication]} {
                puts $stdout "<dedication>"
                return
            }

            if {$depth(note) > 0} {
                puts $stdout "<sect$depth(note)>"
            } else {
                puts $stdout "<preface>"
            }
            puts -nonewline $stdout "<title>"
            pcdata_sgml $attrs(title)
            puts $stdout "</title>"

            incr depth(note)
        }

        middle {
        }

        section {
            if {$depth(section) > 0} {
                puts -nonewline $stdout "<sect$depth(section)"
            } elseif {[lsearch0 $stack back] >= 0} {
                puts $stdout "<appendix"
            } else {
                puts -nonewline $stdout "<chapter"
            }
            if {[info exists attrs(anchor)]} {
                av_sgml id $attrs(anchor)
                av_sgml xreflabel $attrs(title)
            }
            puts $stdout ">"
            puts -nonewline $stdout "<title>"
            pcdata_sgml $attrs(title)
            puts $stdout "</title>"

            incr depth(section)
        }

        t {
            if {[info exists attrs(hangText)]} {
                puts -nonewline $stdout "<varlistentry><term>"
                pcdata_sgml $attrs(hangText)
                puts $stdout "</term>"
            }
            if {[lsearch0 $stack list] >= 0} {
                puts $stdout "<listitem>"
            }
            puts $stdout "<para>"
        }

        list {
            switch -- $attrs(style) {
                numbers {
                    puts $stdout "<orderedlist numeration=\"arabic\">"
                }

                symbols {
                    puts $stdout "<itemizedlist>"
                }

                hanging {
                    puts $stdout "<variablelist>"
                }

                default {
                    error "list style empty"
                }
            }

            incr depth(list)
        }

        figure {
# handled in artwork...
        }

        preamble {
            puts $stdout "<para>"
        }

        artwork {
            set figure [lindex [lindex $stack end-1] 1]
            array set fv $elem($figure)

            if {[info exists fv(title)]} {
                if {[info exists attrs(type)]} {
                    puts -nonewline $stdout "<example"
                } else {
                    puts -nonewline $stdout "<figure"
                }
                if {[info exists fv(anchor)]} {
                    av_sgml id $fv(anchor)
                    av_sgml xreflabel $fv(title)
                }
                puts $stdout ">"                
                puts -nonewline $stdout "<title>"
                pcdata_sgml $fv(title)
                puts $stdout "</title>"
            }

            if {[info exists attrs(type)]} {
                puts $stdout "<$attrs(type)>"
            } else {
                puts $stdout "<screen>"
            }
        }

        postamble {
            puts $stdout "<para>"
        }

        texttable {
# handled in first ttcol...
        }

        ttcol {
            if {![info exists attrs(.COLNO)]} {
                set texttable [lindex [lindex $stack end-1] 1]
                array set tv $elem($texttable)

                set children [find_element ttcol $tv(.CHILDREN)]
                set colmax [llength $children]

                set colno 0
                foreach child $children {
                    catch { unset cv }
                    array set cv [list width "" align left]
                    array set cv $elem($child)

                    set cv(.COLNO) [list [incr colno] $colmax]

                    set elem($child) [array get cv]
                }

                set children [find_element c $tv(.CHILDREN)]
                set rowmax [expr [llength $children]/$colmax]

                set colno 0
                foreach child $children {
                    catch { unset cv }
                    array set cv $elem($child)

                    set offset [expr $colno%$colmax]
                    set cv(.ROWNO) [list [expr 1+($colno/$colmax)] $rowmax]
                    set cv(.COLNO) [list [incr offset] $colmax]
                    incr colno

                    set elem($child) [array get cv]
                }

                puts -nonewline $stdout "<table"
                if {[info exists attr(anchor)]} {
                    av_sgml id $attr(anchor)
                    av_sgml xreflabel $attr(title)
                }
                puts $stdout ">"
                if {[info exists attr(title)]} {
                    puts -nonewline $stdout "<title>"
                    pcdata_sgml $attr(title)
                    puts $stdout "</title>"
                }
                puts -nonewline $stdout "<tgroup"
                av_sgml cols $colmax
                puts $stdout ">"
            
                foreach child [find_element ttcol $tv(.CHILDREN)] {
                    array set cv $elem($child)

                    puts -nonewline $stdout "<colspec"
                    av_sgml align $cv(align)
                    if {[string compare $cv(width) ""]} {
                        regsub -- "%" $cv(width) "*" width
                        av_sgml colwidth $width
                    }
                    puts $stdout ">"
                }

                puts $stdout "<thead>"
            }
            puts -nonewline $stdout "<entry>"
            pcdata_sgml $attrs(.PCDATA)
        }

        c {
            set texttable [lindex [lindex $stack end-1] 1]
            array set tv $elem($texttable)

            if {[lindex $attrs(.COLNO) 0] == 1} {
                if {[lindex $attrs(.ROWNO) 0] == 1} {
                    puts $stdout "<tbody>"
                }
                puts $stdout "<row>"
            }

            puts -nonewline $stdout "<entry>"
        }

        xref {
            if {[string compare $attrs(.PCDATA) ""]} {
                pcdata_sgml "$attrs(.PCDATA) "
            }
            puts -nonewline $stdout " <xref "
            av_sgml linkend $attrs(target)
            puts -nonewline $stdout ">"                
        }

        eref {
            if {[string compare $attrs(.PCDATA) ""]} {
                pcdata_sgml $attrs(.PCDATA)
                puts -nonewline $stdout " (<systemitem"
                av_sgml role $attrs(target)
                puts -nonewline $stdout "></systemitem>"
            } else {
                error "eref contains no pcdata"
            }
        }

        iref {
        }

        vspace {
        }

        spanx {
            array set attrs [list style emph]
            switch -- $attrs(style) {
                emph {
                    set c emphasis
                }

                strong {
                    set c literal
                }

                verb {
                    set c computeroutput
                }

                default {
                    set c ""
                }
            }

            if {[string compare $c ""]} {
                puts -nonewline $stdout <$c>
            }
            pcdata_sgml $attrs(.PCDATA)
            if {[string compare $c ""]} {
                puts -nonewline $stdout </$c>
            }
        }


        back {
        }

        references {
            puts $stdout "<bibliography>"
            if {[info exists attrs(title)]} {
                puts -nonewline $stdout "<title>"
                pcdata_sgml $attrs(title)
                puts $stdout "</title>"
            } else {
                puts $stdout "<title>References</title>"
            }
        }

        reference {
            puts -nonewline $stdout "<biblioentry"
            if {[info exists attrs(anchor)]} {
                av_sgml id $attrs(anchor)
                av_sgml xreflabel $attrs(anchor)
            }
            puts $stdout ">"
        }

        seriesInfo {
            set reference [lindex [lindex $stack end-1] 1]
            array set rv $elem($reference)

            switch -- [set tag [string tolower $attrs(name)]] {
                isbn - issn {
                    puts $stdout "<$tag>$attrs(value)</$tag>"
                    if {[info exists rv(.ORGNAME)]} {
                        puts -nonewline $stdout "<publisher><publishername>"
                        pcdata_sgml $rv(.ORGNAME)
                        puts $stdout "</publishername></publisher>"
                    }
                }

                rfc {
                }

                internet-draft {
                }
            }
        }
    }
}

proc xml_end {name} {
    global counter depth elem elemN errorP passno stack stdout

    set frame [lindex $stack end]
    set stack [lreplace $stack end end]

    if {$passno == 1} {
        return
    }

    if {([lsearch -exact [list front \
                               abstract note section appendix \
                               t list figure preamble postamble \
                               texttable ttcol c \
                               xref eref iref vspace spanx back] $name] >= 0) \
            && ([lsearch0 $stack references] >= 0)} {
        return  
    }

    set elemX [lindex $frame 1]
    array set attrs $elem($elemX)

    switch -- $name {
        rfc {
            puts $stdout "</book>"
        }

        front {
            if {$depth(bookinfo) > 0} {
                incr depth(bookinfo) -1
                puts $stdout "</bookinfo>"
            }
        }

        title {
        }

        author {
        }

        date {
        }

        area - workgroup - keyword {
        }

        abstract {
            puts $stdout "</preface>"
        }

        note {
            if {![string compare [string tolower $attrs(title)] dedication]} {
                puts $stdout "</dedication>"
                return
            }

            incr depth(note) -1

            if {$depth(note) > 0} {
                puts $stdout "</sect$depth(note)>"
            } else {
                puts $stdout "</preface>"
            }
        }

        middle {
        }

        section {
            incr depth(section) -1

            if {$depth(section) > 0} {
                puts $stdout "</sect$depth(section)>"
            } elseif {[lsearch0 $stack back] >= 0} {
                puts $stdout "</appendix>"
            } else {
                puts $stdout "</chapter>"
            }
        }

        t {
            puts $stdout ""
            puts $stdout "</para>"
            if {[lsearch0 $stack list] >= 0} {
                puts $stdout "</listitem>"
            }
            if {[info exists attrs(hangText)]} {
                puts $stdout "</varlistentry>"
            }
        }

        list {
            incr depth(list) -1

            switch -- $attrs(style) {
                numbers {
                    puts $stdout "</orderedlist>"
                }

                symbols {
                    puts $stdout "</itemizedlist>"
                }

                hanging {
                    puts $stdout "</variablelist>"
                }

                default {
                }
            }
        }

        figure {
# handled in artwork...
        }

        preamble {
            puts $stdout ""
            puts $stdout "</para>"
        }

        artwork {
            set figure [lindex [lindex $stack end] 1]
            array set fv $elem($figure)

            if {[info exists attrs(type)]} {
                puts $stdout "</$attrs(type)>"
            } else {
                puts $stdout "</screen>"
            }
            if {[info exists fv(title)]} {
                if {[info exists attrs(type)]} {
                    puts -nonewline $stdout "</example>"
                } else {
                    puts -nonewline $stdout "</figure>"
                }
            }
        }

        postamble {
            puts $stdout ""
            puts $stdout "</para>"
        }

        texttable {
        }

        ttcol {
            set texttable [lindex [lindex $stack end] 1]
            array set tv $elem($texttable)

            puts $stdout "</entry>"

            if {[lindex $attrs(.COLNO) 0] == [lindex $attrs(.COLNO) 1]} {
                puts $stdout "</thead>"
            }
        }

        c {
            set texttable [lindex [lindex $stack end] 1]
            array set tv $elem($texttable)

            puts $stdout "</entry>"

            if {[lindex $attrs(.COLNO) 0] == [lindex $attrs(.COLNO) 1]} {
                puts $stdout "</row>"
                if {[lindex $attrs(.ROWNO) 0] == [lindex $attrs(.ROWNO) 1]} {
                    puts $stdout "</tbody>"
                    puts $stdout "</tgroup>"
                    puts $stdout "</table>"
                }
            }
        }

        xref {
        }

        eref {
        }

        iref {
        }

        vspace {
        }

        spanx {
        }

        back {
        }

        references {
            puts $stdout "</bibliography>"
        }

        reference {
            puts $stdout "</biblioentry>"
        }

        seriesInfo {
        }
    }
}

proc xml_pcdata {text} {
    global counter depth elem elemN errorP passno stack stdout

    if {[string length [set chars [string trim $text]]] <= 0} {
        return
    }

    regsub -all "\r" $text "\n" text

    set frame [lindex $stack end]

    if {$passno == 1} {
        set elemX [lindex $frame 1]
        array set attrs $elem($elemX)
        if {[info exists attrs(.PCDATA)]} {
            if {[string compare [lindex $frame 0] spanx]} {
                append attrs(.PCDATA) $chars
            } else {
                append attrs(.PCDATA) $text
            }
            set elem($elemX) [array get attrs]
        }

        return
    }

    if {[lsearch0 $stack references] >= 0} {
        return
    }

    switch -- [lindex $frame 0] {
        artwork {
            set pre 1
        }

        t
            -
        preamble
            -
        postamble
            -
        c {
            set pre 0
        }

        default {
            return
        }
    }

    pcdata_sgml $text $pre
}

proc av_sgml {k v} {
    global counter depth elem elemN errorP passno stack stdout

    regsub -all {"} $v {\&quot;} v

    puts -nonewline $stdout " $k=\"$v\""
}

proc pcdata_sgml {text {pre 0}} {
    global counter depth elem elemN errorP passno stack stdout

    if {$pre} {
        puts $stdout $text
        return
    }

    foreach {ei begin end} [list *   <emphasis>        </emphasis> \
                                 '   <literal>         </literal>  \
                                 {"} <computeroutput>  </computeroutput>] {
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

    regsub -all -nocase {&apos;} $text {'} text
    regsub -all -nocase {&quot;} $text {"} text
    regsub -all -nocase {&#151;} $text {\&mdash;} text

    puts -nonewline $stdout $text
}

proc lsearch0 {list exact} {
    set x 0
    foreach elem $list {
        if {![string compare [lindex $elem 0] $exact]} {
            return $x
        }
        incr x
    }

    return -1
}

proc find_element {name children} {
    global counter depth elemN elem passno stack xref

    set result ""
    foreach child $children {
        array set attrs $elem($child)

        if {![string compare $attrs(.NAME) $name]} {
            lappend result $child
        }
    }

    return $result
}

proc unexpected {args} {
    global errorP

    set text [join [lrange $args 1 end] " "]

    set errorP 1
    return -code error $text
}


#
# tclsh/wish linkage
#


global guiP
if {[info exists guiP]} {
    return
}
set guiP 0
if {![info exists tk_version]} {
    if {$tcl_interactive} {
        set guiP -1
        puts stdout ""
        puts stdout "invoke as \"xml2sgml input-file output-file\""
    }
} elseif {[llength $argv] > 0} {
    switch -- [llength $argv] {
        2 {
            set file [lindex $argv 1]
            if {![string compare $tcl_platform(platform) windows]} {
                set f ""
                foreach c [split $file ""] {
                    switch -- $c {
                        "\\" { append f "\\\\" }

                        "\a" { append f "\\a" }

                        "\b" { append f "\\b" }

                        "\f" { append f "\\f" }

                        "\n" { append f "\\n" }

                        "\r" { append f "\\r" }

                        "\v" { append f "\\v" }

                        default {
                            append f $c
                        }
                    }
                }
                set file $f
            }

            eval [file tail [file rootname [lindex $argv 0]]] $file
        }

        3 {
            xml2sgml [lindex $argv 1] [lindex $argv 2]
        }
    }

    exit 0
} else {
    set guiP 1

    proc convert {w} {
        if {![string compare [set input [.input.ent get]] ""]} {
            tk_dialog .error "xml2sgml: oops!" "no input filename specified" \
                      error 0 OK
            return
        }
        set output [.output.ent get]

        if {[catch { xml2sgml $input $output } result]} {
            tk_dialog .error "xml2sgml: oops!" $result error 0 OK
        }
    }

    proc fileDialog {w ent operation} {
        set input {
            {"XML files"                .xml                    }
            {"All files"                *                       }
        }
        set output {
            {"SGML files"               .sgml                   }
        }
        if {![string compare $operation "input"]} {
            set file [tk_getOpenFile -filetypes $input -parent $w]
        } else {
            if {[catch { set input [.input.ent get] }]} {
                set input Untitled
            } else {
                set input [file rootname $input]
            }
            set file [tk_getSaveFile -filetypes $output -parent $w \
                            -initialfile $input -defaultextension .txt]
        }
        if [string compare $file ""] {
            $ent delete 0 end
            $ent insert 0 $file
            $ent xview end
        }
    }

    eval destroy [winfo child .]

    wm title . xml2sgml
    wm iconname . xml2sgml
    wm geometry . +300+300

    label .msg -font "Helvetica 14" -wraplength 4i -justify left \
          -text "Convert XML (rfc2629) to SGML (docbook)"
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
}
