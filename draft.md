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

One way to infer some of these capabilities is through User-Agent detection against an established database of client signatures. However, this technique requires acquiring such a database, keeping it up to date, and in many cases is simply not sufficient to distinguish the various devices with the same  fingerprint. User-Agent detection is:

  - Offers unreliable device detection
  - Depends on acquiruing and maitenance of external databases
  - Not cache friendly, as it is not practical to Vary on User-Agent, and provides no fine-grained control to Vary content based on device capabilities or prefernces
  - Unable to infer dynamic client preferences, such as current network conditions, or user-specified preferences (ex, decisions made while roaming)

This document defines a new request header field, "Client-Hints", that allows the client to make available hints for servers about its preference or capabilities, to allow server-side content adaption without impossing additional latency on the client, or requiring the use of additional device databases.

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

The Client-Hints field-value is a comma-delimited list of well-defined header fields, delimited by semicolons. Both the field-name and modifier names themselves are case insensitive.


Pre-defined Client Hints
---------------

All communicated client hints are available within the browser, such that content adaption could be done both on the client, and on the server. As such, Client-Hints do not define any new client information that is not already available within the browser.

This document defines the following hints:

### bw

- Description: Bandwidth (bw) of the current client connection, in kbps.
- Value Type: number

### vv

- Description: Visual Viewport (vv) size of the client, in CSS pixels (ex, 720x1024).
- Value Type: string

### dpr

- Description: Device Pixel Ratio (dpr), is the ratio between physical pixels and device-independent pixels on the device.
- Value Type: number

### dc

- Description: Device Capabilities (dc), is a bit-packed signature of enabled client features to assist with content adaptation based on common device class attributes. There are hundreds of

The dc value is the integer value of the bitfield, with the following indexes:

0. CSS Level 1 or does not support cascading (minimal CSS support)
1. CSS Level 2.1 with 50%+ on ACID2 test     (limited CSS support)
2. CSS Level 2.1 with 75%+ on ACID2 test     (good CSS support)
3. CSS Level 3 with 75%+ on ACID3 test       (excellent CSS support)
4. JavaScript support
5. XMLHttpRequest support
6. Touch screen device and support for touch
7. WebP support (maybe?)

... (TBD: more?)

Each bit should be marked as 1 if the client meets the criteria. For example, for a device which supports all of the above criteria, the bitmap is "11111111", which is equivalent to dc=255. For a device, which supports JavaScript and has good CSS support, but does not support XMLHttpRequest, touch, or WebP the bitmap is "00010111", which is equivalen tto dc=23.


// (Ilya) the downside to this approach is that we're hardcoding these values into the spec, and they *will* get out of sync. It would better if we could define a layer of indirection here, which would allow us to be more feature proof. For example: simply define class A,B,C,D,E (5 out to be enough ;-)), and pull out the definition of each into a separate (external) mechanism, such that as devices evolve, we can reclaim or upgrade what each class defines.


(WIP) References for common attributes and device clases:
- http://jquerymobile.com/gbs/
- http://oreilly.com/iphone/excerpts/iphone-mobile-design-development/mobile-web-development.html
- https://docs.google.com/presentation/d/1y_A6VOZy9bD2i0VLHv9ZWr0W3hZJvlTNCDA0itjI0yM/edit#slide=id.g331d4cda_0_92


Interaction with HTTP proxies
---------------

Client Hints are designed to optimize interaction with existing cache and proxy servers.

When a resource is optimized based on the specified Client Hint information, a Vary response header can be specified for upstream cache and proxy servers. For fine-grained control, the Key response header could be used to define a custom cache key based on an individual or a combination of client hint values.

Unlike the User-Agent string, which is a sinle opaque string, Client Hints provides a stable, customizable, cache friendly mechanism for content adaptation.

Interaction with Browser Hints
---------------

Browser Hints specifies a mechanism whereby origin servers can make available hints for browsers (clients) about their preferences and capabilities, without imposing overhead on their interactions or requiring support for them.

Through the use of Browser Hints, the server can advertise the support for specific Client Hint variables or capabilities, allowing the client to avoid sending variables which will have no effect on the server.


Interaction with User Agent
---------------

Client Hints does not superseed or replace User Agent in any way. Existing device detection mechanisms can continue to use both mechanisms if necessary.

By advertising its capabilities within a request header, Client Hints allows for cache friendly, and explicit content adaptation.



IANA Considerations
===================

TBD


Security Considerations
=======================

Client Hints does not provide any additional data about the browser, or the user, that is currently not available within the browser itself. In cases such as incognito or anonymous profile browsing, the header can be omitted entirely if necessary.

Similarly, the user may be given the choice to enable, disable, or override specific hints. For example, to allow the request for low-resolution images and other content while roaming on a foreign network.


--- back
