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

informative:


--- abstract

An increasing diversity of connected device form factors and software capabilities has created a need to deliver varying, or optimized content for each device.

The 'CH' header field for HTTP requests allows the client to describe its preferences and capabilities to an origin or an intermediary server to enable cache-friendly, server-side content adaptation, without imposing additional latency and deferred evaluation on the client.

--- middle

Introduction
============

There are thousands of different devices accessing the web, each with different device capabilities and preference information. These device capabilities include hardware and software characteristics, as well as dynamic user and client preferences.

One way to infer some of these capabilities is through User-Agent (UA) detection against an established database of client signatures. However, this technique requires acquiring such a database, integrating it into the serving path, and keeping it up to date. However, even once this infrastructure is deployed, UA sniffing has the following limitations:

  - UA detection depends on acquiring and maintenance of external databases
  - UA detection cannot reliably identify all static variables
  - UA detection cannot infer any dynamic client preferences
  - UA detection is not cache friendly

A popular alternative strategy is to use HTTP cookies to communicate some information about the client. However, this approach is also not cache friendly, bound by same origin policy, and imposes additional client-side latency by requiring JavaScript execution to create and manage HTTP cookies.

This document defines a new request Client Hint header field, "CH", that allows the client to make available hints, both static and dynamic, to origin and intermediate servers about its preference and capabilities. "CH" allows server-side content adaption without imposing additional latency on the client, requiring the use of additional device databases, while allowing cache-friendly deployments.


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

The "CH" request header field describes an example list of client preferences that the server can use to adapt and optimize the resource to satisfy a given request. The CH field-value is a comma-delimited list of header fields, and the field-name values are case insensitive.

CH Header Fields
---------------

The client controls which header fields are communicated within the CH header, based on its default settings, or based on user configuration and preferences. The user may be given the choice to enable, disable, or override specific hints. For example, to allow the request for low-resolution images or other content type's while roaming on a foreign network, even while on a high-bandwidth link.

The client and server, or an intermediate proxy, may use an additional mechanism to negotiate which fields should be reported to allow for efficient content adaption.

This document defines the following well-known hint names:

### dh

- Description: Device height (dh) of the client, in physical pixels.
- Value Type: number

### dw

- Description: Device width (dw) of the client, in physical pixels.
- Value Type: number

### dpr

- Description: Device Pixel Ratio (dpr), is the ratio between physical pixels and device-independent pixels on the device.
- Value Type: number

Other client hints may be communicated by the client. The decision as to which specific hints will be communicated is always made by the client.


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

For example, the server may advertise its support for Client Hints via Hop or Origin Hint:

~~~
  HH: ch
  OH: ch
~~~

When a client receives the Hop or Origin Hint header indicating support for Client Hint adaptation, it should append the CH header to subsequent requests to the same origin server. Further, the client may remember this hint and automatically append the CH header for all future requests to the same origin.

Interaction with Key
---------------

Client Hints may be combined with Key to enable fine-grained control of the cache key for improved cache efficiency. For example, the server may return the following set of instructions:

~~~
  Key: CH;pr=dw[320:640]
~~~

Above example indicates that the cache key should be based on the CH header, and the asset should be cached and made available for any client whose device width falls between 320 and 640 px.

~~~
  Key: CH;pr=dpr[1.5:]
~~~

Above examples indicates that the cache key should be based on the CH header, and the asset should be cached and made available for any client whose device pixel ratio is 1.5, or higher.


Interaction with HTTP proxies
---------------

In absence of support for fine-grained control of the cache key via the Key header field, Vary response header can be used to indicate that served resource has been adapted based on specified Client Hint preferences.

Interaction with User Agent
---------------

Client Hints does not supersede or replace User-Agent. Existing device detection mechanisms can continue to use both mechanisms if necessary. By advertising its capabilities within a request header, Client Hints allows for cache friendly and explicit content adaptation.


IANA Considerations
===================

TBD


Security Considerations
=======================

The client controls which header fields are communicated and when. In cases such as incognito or anonymous profile browsing, the header can be omitted if necessary.


--- back
