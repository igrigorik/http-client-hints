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

This document defines a new request Client Hint header field, "CH", that allows the client to perform proactive content negotiation {{I-D.ietf-httpbis-p2-semantics}} by indicating a list of device and agent specific preferences, through a mechanism similar to the Accept header which is used to indicate prefered response formats.


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

The "CH" Request Header Field
===============================

The "CH" request header field describes an example list of client preferences that the server can use to adapt and optimize the resource to satisfy a given request. The CH field-value is a comma-delimited list of header fields, and the field-name values are case insensitive.

~~~
  CH = 1#client_hint
~~~


Hint Syntax
---------------

Hints are allowed to have a numeric value. However, where possible, they can can be defined as flags (i.e., as a hint name only), so that the hints don't consume too much space in client requests.

~~~
  client_hint = hint_name [ "=" hint_value ]
  hint_name = ALPHA *( DIGIT / "_" / "-" )
  hint_value = 1*DIGIT
~~~

Hints can be defined as one of two types:

- Boolean - indicated by the presence of the hint name. If the hint name is absent in the last message containing the client hint header field, it is considered false.
- Numeric - value indicated by the digits after "=", up to the first non-digit character. If the hint does not have an argument, its value is assumed to be 0.

Note that HTTP/1.1 allows headers with comma-separated values to be conveyed using multiple instances of the same header; as a result, the hints are collected from all instances of the CH header on the message in question before being considered complete.


Pre-defined Hints
---------------

The client controls which header fields are communicated within the CH header, based on its default settings, or based on user configuration and preferences. The user may be given the choice to enable, disable, or override specific hints. For example, to allow the request for low-resolution images or other content type's while roaming on a foreign network, even while on a high-bandwidth link.

The client and server, or an intermediate proxy, may use an additional mechanism to negotiate which fields should be reported to allow for efficient content adaption.

This document defines the following hint names:

### dh

- Description: Device height (dh) of the client, in physical pixels.
- Value Type: number

### dw

- Description: Device width (dw) of the client, in physical pixels.
- Value Type: number

### dpr

- Description: Device Pixel Ratio (dpr), is the ratio between physical pixels and device-independent pixels on the device.
- Value Type: number

Other client hints may be communicated by the client. The decision as to which specific hints will be sent is made by the client.


Examples
---------------

For example, given the following request header:

~~~
  CH: dh=1280, dw=768, dpr=2.0
~~~

The server knows that the clients physical screen size is 1280x768px, and that the device pixel ratio is 2.0.


Server opt-in with Hop and Origin Hints
---------------

CH is an optional header which may be sent by the client when making a request to the server. The client may decide to always send the header, or use an optional opt-in mechanism, such as a predefined list of origins, user specified list of origins, or any other forms of opt-in.

For example, the server may advertise its support for Client Hints via Hop and/or Origin Hint ({{I-D.nottingham-http-browser-hints}}):

~~~
  HH: ch
  OH: ch
~~~

When a client receives the Hop or Origin Hint header indicating support for Client Hint adaptation, it should append the CH header to subsequent requests to the same origin server. Further, the client may remember this hint and automatically append the CH header for all future requests to the same origin.


Interaction with Caches
---------------

Client Hints may be combined with Key ({{I-D.fielding-http-key}}) to enable fine-grained control of the cache key for improved cache efficiency. For example, the server may return the following set of instructions:

~~~
  Key: CH;pr=dw[320:640]
~~~

Above example indicates that the cache key should be based on the CH header, and the asset should be cached and made available for any client whose device width (dw) falls between 320 and 640 px.

~~~
  Key: CH;pr=dpr[1.5:]
~~~

Above examples indicates that the cache key should be based on the CH header, and the asset should be cached and made available for any client whose device pixel ratio (dpr) is 1.5, or higher.

In absence of support for fine-grained control of the cache key via the Key header field, Vary response header can be used to indicate that served resource has been adapted based on specified Client Hint preferences.

~~~
  Vary: CH
~~~


Relationship to the User-Agent Request Header
---------------

Client Hints does not supersede or replace User-Agent. Existing device detection mechanisms can continue to use both mechanisms if necessary. By advertising its capabilities within a request header, Client Hints allows for cache friendly and proactive content negotiation.


IANA Considerations
===================

The CH Request Header Field
---------------

This document defines the "CH" HTTP request field, and registers it in the Permanent Message Headers registry.

- Header field name: CH
- Applicable protocol: HTTP
- Status: Informational
- Author/Change controller: Ilya Grigorik, ilya@igvita.com
- Specification document(s): [this document]
- Related information: for Client Hints


The HTTP Hints
---------------

This document registers HTTP Hints ({{I-D.nottingham-http-browser-hints}}) in section 2.1, and the following:

- Hint Name: ch
- Hint Type: origin, hop
- Description: When present, this hint indicates support for Client-Hints adaptation.
- Value Type: numeric
- Contact: ilya@igvita.com
- Specification: this document

TBD: need to explicitly define the registry, and the policy for defining new hints.


Security Considerations
=======================

The client controls which header fields are communicated and when. In cases such as incognito or anonymous profile browsing, the header can be omitted if necessary.


--- back
