# Client Hints - Browser implementation considerations

This document serves as an extension to the [Client Hints
specification][client-hints].

The Client Hints specification is intended for a wide audience, and does not specify a number of details relevant to user agent implementors. This document aims to fill that gap.

[client-hints]: http://igrigorik.github.io/http-client-hints/

## `Width`

The [`Width` request header][width] is sent by the client and indicates the  width of an HTMLImageElement in physical pixels - i.e. same value as provided by the [w descriptor](https://html.spec.whatwg.org/multipage/embedded-content.html#introduction-3:viewport-based-selection-2) for viewport-based selection.

User agents request images long before page layout occurs.
For this reason, the `Width` hint can only be sent by user agents when the layout width of the image is indicated in markup, via the `sizes` attributes.

A `Width` hint should be sent only with request in the context of an
image, when these requests are initiated by an HTMLImageElement with a
`sizes` attribute. The value of the `Width` attribute should be the
return value of the [parse a sizes attribute][parse-sizes] algorithm.

[width]: http://igrigorik.github.io/http-client-hints/#the-width-client-hint
[parse-sizes]: https://html.spec.whatwg.org/multipage/embedded-content.html#parse-a-sizes-attribute 

ISSUE: Add the 'width' attribute into the mix, once [it's added to the srcset logic](https://github.com/ResponsiveImagesCG/picture-element/issues/268).
TODO: Shape the above to be normative text.

## Request contexts

ISSUE: Does it make sense to limit CH to image contexts?

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

## Viewport-Width

The `Viewport-Width` value should be the size of the [initial containing block](http://www.w3.org/TR/CSS21/visudet.html#containing-block-details) in CSS pixels.
When the height or width of the initial containing block is changed, the value sent for consecutive requests should be scaled accordingly.

_Note:_ The initial containing block's size is affected
by the presence of scrollbars on the viewport.

## Server preference persistence

User agents MAY maintain a server's `Accept-CH` preference beyond the current browsing session.
When they do, they MUST clear that preference in the usual cases where such state is cleared. (Browsing history cleared, etc).

TODO: Turn this into normative text.

## Viewport changes
User agents MAY re-request image resources in case that the viewport
have changed since the time in which these resources were requested.

TODO: Turn this into normative text.

## `Accept-CH`
As defined, the [`Accept-CH`][accept-ch] header is not mandatory, and
user agents may send the various CH hints without relying on the
`Accept-CH` header.
User agents may also use the presence of the `Accept-CH` opt-in header
in the response to the navigational request as a signal to send the
various `CH` hints on sub-resource requests for that Document, including
ones that are retrieved from third-party hosts.
That is to address the full range of use-cases, e.g. authors hosting
their HTML on a single server, but serving them from a different one.

ISSUE: Do we want to keep `Accept-CH` or should we just send hints on all
requests with an image context?

## Background images and `Width`

Sending `Width` request headers for background images is hard for two reasons:

* Background images are requested at style calculation time, but
  their layout dimensions are only known later, at layout time.
* Background images' dimensions are not constrained by the dimensions of
  their container, and can be influenced by a multitude of CSS
  properties. We need to account for that before we can use the container
  dimensions as the `Width` value.

At this time, it seems like there's no way to send `Width`
info for background images.

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
