# Client Hints - Browser implementation considerations

This document's goal is to serve as an extension to the [Client Hints
specification][client-hints], and to specify the various aspects of implementing
Client-Hints in browsers.
Since the Client Hints specification is destined at a wider audience
than browser implementers, it does not include any browser-specific
details. This document aims to fill that gap.

[client-hints]: http://igrigorik.github.io/http-client-hints/

## `Width`
The [`Width` request header][width]
is a hint destined to provide the server with the accurate dimensions of an image resource,
as opposed to the dimensions of the viewport (provided by the [`Viewport-Width` request header][viewport-width]).

Since image start downloading long before the page layout happens, at the time image download start,
the accurate dimensions required to display certain image dimensions are not known.

For that reason, the `Width` hint can only be provided when there's a
clear markup hint indicating the browser what the dimensions of the
resources are going to be.

The markup hints used for that purpose are the `width` and `sizes`
attributes when the image resource is defined on an HTMLImageElement,
and the `sizes` attribute when the image resource is defined on an
HTMLSourceElement with an HTMLPictureElement parent and an
HTMLImageElement sibling.

[width]: http://igrigorik.github.io/http-client-hints/#the-width-client-hint
[viewport-width]: http://igrigorik.github.io/http-client-hints/#the-viewport-width-client-hint

TODO: Insert normative text here.

## Background images and `Width`

Even though background images seem like a better candidate for layout
based `Width` values, currently that's not the case:

* Background images are being requested at style calculation time, while
  the full dimensions are (mostly) known at layout time.
* Background images dimensions are not constrained by the dimensions of
  their container, and can be influenced by a multitude of CSS
properties. We need to account to that before we can use the container
dimensions as the `Width` value.

Therefore, at this time, it seems like there's no way to send `Width`
info for background images.

TODO: Insert normative text here?

## Which request contexts should hints be sent on
TODO: Does it make sense to limit CH to image contexts?

TODO: Insert normative text here?

## Content-DPR

The [`Content-DPR` header][content-dpr] is used by the server to confirm
that the hints were acted upon, and that the intrinsic dimensions of the
received resource should be adjusted to match the original resource's
intrinsic dimensions. That's in order to avoid cases where the page's
layout (which may rely on the original image's intrinsic dimensions)
would break, or that the image would be displayed in the wrong
dimensions when viewed in the browser as a standalone.

Browsers should respect the `Content-DPR` header and adjust the image
resource's intrinsic dimensions according to it.
In case where the intrinsic dimensions are corrected by both the
`Content-DPR` header and the `srcset` attribute's descriptors, the
`Content-DPR` header takes precedence.

TODO: Turn this into normative text.

[content-dpr]: http://igrigorik.github.io/http-client-hints/#confirming-selected-dpr 

## Server preference persistence
Browsers MAY maintain a server's `Accept-CH` preference for the duration
of the browsing session or beyond it.
In case that the browser have maintained such state, it MUST clear that
preference state in the usual cases where such state is cleared.
(Browsing history cleared, etc).

TODO: Turn this into normative text.

## Implementation notes

### Handling `Accept-CH` before the document is created
The [`Accept-CH`][accept-ch] header is used by the server to notify the
client that the server supports certain hints, and will act upon them.

When provided by the server as an HTTP header, the browser often
encounters the header before the Document object exists. That means that
the server preference state has to be maintained and passed over to the
Document object once one is created.

[accept-ch]: http://igrigorik.github.io/http-client-hints/#advertising-support-for-client-hints

### Handling `Accept-CH` in the preloader

When the `Accept-CH` header is provided as an HTMLMetaElement (`<meta
http-equiv="Accept-CH">`), we need to be able to process and apply this
preference even when the images are requested by the preloader, and the
image requests are sent out before the HTMLMetaElement is parsed and the
preference is applied on the Document.

That can be achieved by scanning for `<meta>` tags and maintaining the
parsed out preference in the preloader.

