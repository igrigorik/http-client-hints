---
title: HTTP Client Hints
abbrev:
date: 2013
category: info

ipr: trust200902
area: General
workgroup:
keyword: Internet-Draft

stand_alone: yes
pi: [toc, tocindent, sortrefs, symrefs, strict, compact, comments, inline]

author:
 -
    ins: I. Grigorik
    name: Ilya Grigorik
    organization:
    email: ilya@igvita.com
    uri: http://www.igvita.com/

normative:
  RFC2119:
  RFC5234:
  RFC5226:
  I-D.ietf-httpbis-p1-messaging:
  I-D.ietf-httpbis-p2-semantics:
  I-D.nottingham-http-browser-hints:
  I-D.fielding-http-key:

informative:

--- abstract

An increasing diversity of connected device form factors and software capabilities has created a need to deliver varying, or optimized content for each device.

Client Hints can be used as input to proactive content negotiation; just as the Accept header allowed clients to indicate what formats they prefer, Client Hints allow clients to indicate a list of device and agent specific preferences.

--- middle

Introduction
============

There are thousands of different devices accessing the web, each with different device capabilities and preference information. These device capabilities include hardware and software characteristics, as well as dynamic user and client preferences.

One way to infer some of these capabilities is through User-Agent (UA) detection against an established database of client signatures. However, this technique requires acquiring such a database, integrating it into the serving path, and keeping it up to date. However, even once this infrastructure is deployed, UA sniffing has the following limitations:

  - UA detection requires an external device database
  - UA detection cannot reliably identify all static variables
  - UA detection cannot infer any dynamic client preferences
  - UA detection is not cache friendly

A popular alternative strategy is to use HTTP cookies to communicate some information about the client. However, this approach is also not cache friendly, bound by same origin policy, and imposes additional client-side latency by requiring JavaScript execution to create and manage HTTP cookies.

This document defines a set of new request Client Hint header fields that allow the client to perform proactive content negotiation {{I-D.ietf-httpbis-p2-semantics}} by indicating a list of device and agent specific preferences, through a mechanism similar to the Accept header which is used to indicate preferred response formats.


Notational Conventions
----------------------

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT",
"SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in {{RFC2119}}.

This document uses the Augmented Backus-Naur Form (ABNF) notation of
{{RFC5234}} with the list rule extension defined in
{{I-D.ietf-httpbis-p1-messaging}}, Appendix B. It includes by reference the
OWS, field-name and quoted-string rules from that document, and the
parameter rule from {{I-D.ietf-httpbis-p2-semantics}}.

The "CH" Request Header Fields
===============================

Each "CH" request header field describes an example list of client preferences that the server can use to adapt and optimize the resource to satisfy a given request. The full name of the hint consists of a "CH-" prefix and hint type, and the field-value is a comma-delimited list of header fields. The field-name values are case insensitive.

~~~
  CH-{type} = #client-hint
  client-hint = parameter
~~~


Hint Syntax
---------------

Hints header fields are allowed to be defined as a single boolean or numeric value, or as a list of header fields with the same types. Where possible, single boolean (i.e. as a flag) or numeric value should be used, so that the hint's don't consume too much space in client requests.

When a single numeric or boolean value is used, the hint value is the full field value. When a list of hints is used, the hint values are the comma-separated values within the field value.

Hint header fields are allowed to have a numeric value. However, where possible, they can can be defined as flags (i.e., as a hint name only), or as a single numeric value, so that the hints don't consume too much space in client requests.

Hint values can be defined as one of two types:

- Boolean - indicated by the presence of the hint name. If the hint name is absent in the last message containing the client hint header field, it is considered false.
- Numeric - value indicated by the full field-value contents (single value), or by the digits after "=" of the hint name, up to the first non-digit character. If the hint does not have an argument, its value is assumed to be 0.

Note that HTTP/1.1 allows headers with comma-separated values to be conveyed using multiple instances of the same header; as a result, the hints are collected from all instances of the same header on the message in question before being considered complete. If the same hint is used more than once, then the last hint overrides all previous occurrences, and the final ordering of unique hints is not significant.


Predefined Hints
---------------

The client controls which Client Hint headers and their respective header fields are communicated, based on its default settings, or based on user configuration and preferences. The user may be given the choice to enable, disable, or override specific hints.

The client and server, or an intermediate proxy, may use an opt-in mechanism to negotiate which fields should be reported to allow for efficient content adaption.

This document defines the following hints:

### CH-DPR

- Description: Device Pixel Ratio (dpr), is the ratio between physical pixels and density independent pixels on the device.
- Value Type: number

### CH-DW

- Description: device-width in primary orientation, in density independent pixels.
- Value Type: number


Examples
---------------

For example, given the following request header:

~~~
  CH-DPR: 2.0
  CH-DW: 384
~~~

The server knows that the client's screen width is 384px, as measured by density independent pixels on the device and the device pixel ratio is 2.0.


Server selection confirmation
---------------

The server may decide to use provided client hint information to select an alternate resource. When the server performs such selection, because the alternate resource does not necessarily have to match the value of provided hint, it should indicate the value of selected resource via a corresponding response header. For example, given the following request header:

~~~
  CH-DPR: 2.0
~~~

If the server uses the hint to perform resource selection, it should confirm its selection via a response header matching the hint name:

~~~
  DPR: 1.5
~~~

The DPR response header indicates to the client that the server has selected an asset with DPR resolution of 1.5. The client may use this information to perform additional processing on the resource - for example, calculate the appropriate intrinsic size of an image asset.


Opt-in mechanism
---------------

CH is an optional header which may be sent by the client when making a request to the server. The client may decide to always send the header, or use an opt-in mechanism, such as a predefined or user specified list of origins, remembered site preference based on past navigation history, or any other forms of opt-in.

For example, the server may advertise its support via Accept-CH header:

~~~
  Accept-CH: DPR, DW
~~~

When a client receives the Accept-CH header indicating support for Client Hint adaptation, it should append the CH headers that match the advertised field-values. For example, based on Accept-CH example above, the client may append CH-DPR and CH-DW headers to subsequent requests.


Interaction with Caches
---------------

Client Hints may be combined with Key ({{I-D.fielding-http-key}}) to enable fine-grained control of the cache key for improved cache efficiency. For example, the server may return the following set of instructions:

~~~
  Key: CH-DW;r=[320:640]
~~~

Above example indicates that the cache key should be based on the CH-DW header, and the asset should be cached and made available for any client whose device width (dw) falls between 320 and 640 px.

~~~
  Key: CH-DPR;r=[1.5:]
~~~

Above examples indicates that the cache key should be based on the CH-DPR header, and the asset should be cached and made available for any client whose device pixel ratio (DPR) is 1.5, or higher.

In absence of support for fine-grained control of the cache key via the Key header field, Vary response header can be used to indicate that served resource has been adapted based on specified Client Hint preferences.

~~~
  Vary: CH-DPR
~~~


Relationship to the User-Agent Request Header
---------------

Client Hints does not supersede or replace User-Agent. Existing device detection mechanisms can continue to use both mechanisms if necessary. By advertising its capabilities within a request header, Client Hints allows for cache friendly and proactive content negotiation.


IANA Considerations
===================

The CH Request Header Field
---------------

This document defines the "CH-DPR", "CH-DW" HTTP request fields, and registers it in the Permanent Message Headers registry.

- Header field name: CH-DPR
- Applicable protocol: HTTP
- Status: Informational
- Author/Change controller: Ilya Grigorik, ilya@igvita.com
- Specification document(s): [this document]
- Related information: for Client Hints

- Header field name: CH-DW
- Applicable protocol: HTTP
- Status: Informational
- Author/Change controller: Ilya Grigorik, ilya@igvita.com
- Specification document(s): [this document]
- Related information: for Client Hints

The HTTP Hints
---------------

This document registers the "ch" HTTP Hint ({{I-D.nottingham-http-browser-hints}}), as defined in section 2.1:

- Hint Name: ch
- Hint Type: origin, hop
- Description: When present, this hint indicates support for Client-Hints adaptation.
- Value Type: numeric
- Contact: ilya@igvita.com
- Specification: this document


The HTTP Client Hints Registry
---------------

This document establishes the HTTP Client Hints Registry.

New hints are registered using Expert Review (see {{RFC5226}}), by sending e-mail to iana@iana.org (or using other mechanisms, as established by IANA).

New hints are expected to be implemented in at least one client in common use. The Expert MAY use their judgment in determining what "common" is, and when something is considered to be implemented.

New hints MUST be optional; they cannot place requirements upon
implementations. Specifically, new hints MUST NOT make communication non-conformant with HTTP itself; i.e., this is not a mechanism for changing the HTTP protocol in incompatible ways.

See section 2.1 for constraints on the syntax of hint names and hint values.

Registration requests MUST use the following template:

* Hint Name: [name of hint]
* Hint Value: ["boolean" or "numeric"]
* Description: [description of hint]
* Contact: [e-mail address(es)]
* Specification: [optional; reference or URI to more info]
* Notes: [optional]

The initial contents of the registry are defined in section 2.2.


Security Considerations
=======================

The client controls which header fields are communicated and when. In cases such as incognito or anonymous profile browsing, the header can be omitted if necessary.


--- back
