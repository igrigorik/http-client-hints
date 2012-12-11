---
title: HTTP Client Hints
abbrev:
date: 2012
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

informative:


--- abstract

An increasing diversity of connected device form factors and software capabilities has created a need to deliver varying, or optimized content for each device.

The 'Client-Hints' header field for HTTP requests allows the client to describe its preferences and capabilities to an origin server to enable cache-friendly, server-side content adaptation, without imposing additional latency and deferred evaluation on the client.

Client-Hints also has the advantage of being able to transmit dynamic client preferences, such as available bandwidth, or current viewport size, which cannot be inferred through static client signature databases.

--- middle

Introduction
============

There are thousands of different devices accessing the web, each with different device capabilities and preference information. These device capabilities include hardware and software characteristics, as well as information about the state of the network to which the device is connected to.

One way to infer some of these capabilities is through User-Agent (UA) detection against an established database of client signatures. However, this technique requires acquiring such a database, keeping it up to date, and in many cases is simply not sufficient to do the device identification due to lack of enough unique information within the UA header.

  - UA detection is not reliable
  - UA detection is not cache friendly
  - UA detection depends on acquiring and maintenance of external databases
  - UA detection is unable to infer dynamic client preferences, such as current network conditions, or user-specified preferences (ex, decisions made while roaming)

This document defines a new request header field, "Client-Hints", that allows the client to make available hints, both static and dynamic, for servers about its preference and capabilities. "Client-Hints" allows server-side content adaption without imposing additional latency on the client, or requiring the use of additional device databases.

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

The "Client-Hints" Request Header Field
===============================

The "Client-Hints" request header field describes the current client preferences that the server can use to adapt and optimize the resource to satisfy a given request.

The Client-Hints field-value is a comma-delimited list of header fields. The  field-name values are case insensitive.


Client-Hints Header Fields
---------------

The client controls which header fields are communicated within the Client-Hints header, based on its default settings, or based on user configuration and preferences. The user may be given the choice to enable, disable, or override specific hints. For example, to allow the request for low-resolution images or other content type's while roaming on a foreign network, even while on a high-bandwidth link.

The client and server, or an intermediate proxy, may use an additional mechanism to negotiate which fields should be reported to allow for efficient content adaption.

This document defines the following well-known hint names:

### bw

- Description: Bandwidth (bw) of the current client connection, in kbps.
- Value Type: number

### vv

- Description: Visual Viewport (vv) size of the client, in CSS pixels (ex, 720x1024).
- Value Type: string

### dpr

- Description: Device Pixel Ratio (dpr), is the ratio between physical pixels and device-independent pixels on the device.
- Value Type: number


Interaction with Browser Hints
---------------

Browser Hints specifies a mechanism whereby origin servers can make available hints for browsers (clients) about their preferences and capabilities, without imposing overhead on their interactions or requiring support for them.

Through the use of Browser Hints, the server can advertise the support for specific Client Hint variables or capabilities, allowing the client to avoid sending variables which will have no effect on the server.

Interaction with HTTP proxies
---------------

Client Hints are designed to optimize interaction with existing cache and proxy servers.

When a resource is optimized based on the specified client hint information, a Vary response header can be specified for upstream cache and proxy servers. For fine-grained control, the Key response header could be used to define a custom cache key based on an individual or a combination of client hint values.

An optimizing proxy may also use an additional mechanism, such as Browser Hints, to negotiate which client hints can be communicated to enable better content adaptation.

Interaction with User Agent
---------------

Client Hints does not supersede or replace User-Agent. Existing device detection mechanisms can continue to use both mechanisms if necessary.

By advertising its capabilities within a request header, Client Hints allows for cache friendly, and explicit content adaptation.


IANA Considerations
===================

TBD


Security Considerations
=======================

The client controls which header fields are communicated and when. In cases such as incognito or anonymous profile browsing, the header can be omitted entirely if necessary.


--- back
