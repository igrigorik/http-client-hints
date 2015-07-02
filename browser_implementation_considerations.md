# Client Hints - Browser implementation considerations

This document serves as an extension to the [Client Hints
specification][client-hints].

The Client Hints specification is intended for a wide audience, and does not specify a number of details relevant to user agent implementors. This document aims to fill that gap.

[client-hints]: http://igrigorik.github.io/http-client-hints/

## `Width`

The [`Width` request header][width] is sent by the client and indicates the layout width of an HTMLImageElement in CSS px.

User agents request images long before page layout occurs.
For this reason, the `Width` hint can only be sent by user agents when the layout width of the image is indicated in markup, via either the `width` or `sizes` attributes.

When an image resource is listed within an HTMLImageElement, user agents may look for these attributes directly on that HTMLImageElement.
The value of `sizes`, if present, takes precedence over the value of `width`.
When the image resource is listed within an HTMLSourceElement (with an HTMLPictureElement parent and an HTMLImageElement sibling),
user agents must only use widths provided within a `sizes` attribute on that HTMLSourceElement.

[width]: http://igrigorik.github.io/http-client-hints/#the-width-client-hint

TODO: Insert normative text here.

## Background images and `Width`

Sending `Width` request headers for background images is problematic for two reasons:

* Background images are requested at style calculation time, but
  their layout dimensions are only known later, at layout time.
* Background images' dimensions are not constrained by the dimensions of
  their container, and can be influenced by a multitude of CSS
  properties. We need to account for that before we can use the container
  dimensions as the `Width` value.

At this time, it seems like there's no way to send `Width`
info for background images.

TODO: Insert normative text here?

## Request contexts

TODO: Does it make sense to limit CH to image contexts?

TODO: Insert normative text here?

## Content-DPR

Once the server has modified the dimensions of an image resource following the user agent's inclusion of one or more Client Hints in the request,
the server’s response must include a [`Content-DPR` header][content-dpr].
This header confirms that the hints sent by the user agent were acted upon,
and tells the user agent that the intrinsic dimensions of the received resource should be adjusted using the `Content-DPR` value
in order to match the original resource's intrinsic dimensions.

This prevents page layouts (which may rely on the original image's intrinsic dimensions) from breaking,
and insures that the image is viewed at the correct dimensions if and when it is viewed standalone, outside of the context of an HTML document.

When information correcting an image’s intrinsic dimensions is provided by both the
`Content-DPR` header and `srcset` attribute's descriptors, the `Content-DPR` header takes precedence.

TODO: Turn this into normative text.

[content-dpr]: http://igrigorik.github.io/http-client-hints/#confirming-selected-dpr 

## Server preference persistence

User agents MAY maintain a server's `Accept-CH` preference beyond the current browsing session.
When they do, they MUST clear that preference in the usual cases where such state is cleared. (Browsing history cleared, etc).

TODO: Turn this into normative text.

## Viewport changes
User agents MAY re-request image resources in case that the viewport
have changed since the time in which these resources were requested.

TODO: Turn this into normative text.

## Implementation notes

### Handling `Accept-CH` before the document is created

The [`Accept-CH`][accept-ch] header is used by the server to notify the
user agent that the server supports certain hints, and will act upon them.

When provided by the server as an HTTP header, the browser often
encounters the header before the Document object exists. That means that
the server preference state has to be maintained and passed over to the
Document object once it is created.

[accept-ch]: http://igrigorik.github.io/http-client-hints/#advertising-support-for-client-hints

### Handling `Accept-CH` in the preloader

When the `Accept-CH` header is provided as an HTMLMetaElement (`<meta
http-equiv="Accept-CH">`), user agents need to be able to process and apply this
preference even when the images are requested by the preloader.

Currently, preloader-based image requests are sent out before the HTMLMetaElement is parsed and the
preference is applied on the Document. In order to meet the above requirement, preloaders must scan for `<meta>` tags and maintain the parsed out preference themselves.
