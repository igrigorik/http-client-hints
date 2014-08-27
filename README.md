## HTTP Client-Hints (Internet Draft)

This specification defines a set of HTTP request header fields, colloquially known as Client Hints, that are intended to be used as input to proactive content negotiation; just as the Accept header allows clients to indicate what formats they prefer, Client Hints allow clients to indicate a list of device and agent specific preferences.

Client Hints can be used to automate negotiation and delivery of optimized assets for a particular device - e.g. resolution and size of delivered image resources, alternate stylesheets, scripts, and so on. For example, given the following HTML markup for an image resource:

```html
<img src="img.jpg" width="160" alt="I'm responsive!">
```

The client and server can negotiate the resolution and size of `img.jpg` via HTTP negotiation:

```http
GET /img.jpg HTTP/1.1
User-Agent: Awesome Browser
Accept: image/webp, image/jpg
DPR: 2.0
RW: 160
```
```http
HTTP/1.1 200 OK
Server: Awesome Server
Content-Type: image/jpg
Content-Length: 124523
Vary: DPR, RW
Content-DPR: 2.0

(image data)
```

In the above example, the user agent advertises its device pixel ratio (DPR) and resource display width (RW) via respective `DPR` and `RW` reqest headers on the image request. Given this information, the server is then able to select and respond with the optimal resource variant for the client. For full details on negotiation workflow, refer to the latest [spec](http://igrigorik.github.io/http-client-hints/).


### Interaction with picture element

Client Hints can be used alongside [picture element](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#the-picture-element) to automate resolution switching, simplify art-direction, and automate delivery of variable-sized and "pixel perfect" images. Let's consider different `<picture>` scenarios...

DPR header automates [device-pixel-ratio-based selection](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#introduction-3:device-pixel-ratio-2) by eliminating the need to write `x` queries. As a result, the `<img>` tag becomes "resolution aware" without any extra work on behalf of the site owner:

```html
<!-- picture resolution switching -->
<picture>
  <source srcset="pic1x.jpg 1x, pic2x.jpg 2x, pic4x.jpg 4x">
  <img alt="A rad wolf." src="pic1x.jpg">
</picture>

<!-- equivalent functionality via DPR client hint -->
<img alt="A rad wolf." src="pic.jpg">

<!-- ... similarly ... -->

<!-- picture art-direction with resolution switching -->
<picture>
  <source media="(min-width: 45em)" srcset="large-1.jpg, large-2.jpg 2x">
  <source media="(min-width: 18em)" srcset="med-1.jpg, med-2.jpg 2x">
  <source srcset="small-1.jpg, small-2.jpg 2x">
  <img src="small-1.jpg" alt="The president giving an award." width="500" height="500">
</picture>

<!-- equivalent functionality with resolution switching via Client Hints -->
<picture>
  <source media="(min-width: 45em)" srcset="large.jpg">
  <source media="(min-width: 18em)" srcset="med.jpg">
  <img src="small.jpg" alt="The president giving an award." width="500" height="500">
</picture>
```

Note that the second example with [art direction-based selection](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#introduction-3:art-direction-3) illustrates that Client Hints does not eliminate the need for the picture element. Rather, Client Hints is able to simplify and automate certain parts of the negotiation, allowing the developer to focus on art direction, which by definition requires developer/designer input.

Finally, the combination of RW and DPR hints also simplifies delivery of variable sized images when [viewport-based selection](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#introduction-3:viewport-based-selection-2) is used. The developer specifies the resource width of the image in `vw` units (which is relative to viewport width) via `sizes` attribute and the user agent handles the rest: 

```html
<!-- viewport-based selection -->
<img src="wolf-400.jpg" sizes="100vw" alt="The rad wolf"
     srcset="wolf-400.jpg 400w, wolf-800.jpg 800w, wolf-1600.jpg 1600w">

<!-- equivalent functionality via DPR and RW hints -->
<img src="wolf.jpg" sizes="100vw" alt="The rad wolf">
```

* Current device pixel ratio is communicated via the `DPR` request header
* The `vw` size is converted to CSS pixel size based on client's layout viewport size and the resulting value is communicated via the `RW` request header
* The server computes the optimal image variant based on communicated DPR and RW values and returns the response with a `Content-DPR` response header that confirms its selection.

Example HTTP request flow for the above example:

```
> GET /wolf.jpg HTTP/1.1
> DPR: 2.0
> RW: 400

(Server: 2x DPR * 400 width = 800px -> selects wolf-800.jpg or performs a resize)

< 200 OK
< Content-DPR: 2.0
< Vary: DPR, RW
< ...
```

In situations where multiple layout breakpoints are present the workflow is similar to that of the previous example. To select the optimal resolution and size:

```html
<!-- multiple layout breakpoints -->
<img src="swing-400.jpg" alt="Kettlebell Swing"
  sizes="(max-width: 30em) 100vw, (max-width: 50em) 50vw, calc(33vw - 100px)"
  srcset="swing-200.jpg 200w, swing-400.jpg 400w, swing-800.jpg 800w, swing-1600.jpg 1600w">

<!-- equivalent functionality with Client Hints -->
<img src="swing.jpg" alt="Kettlebell Swing"
  sizes="(max-width: 30em) 100vw, (max-width: 50em) 50vw,calc (33vw - 100px)">
```

The combination of the `DPR` and `RW` hints allows the server to deliver 'pixel perfect' images that match the device resolution and the exact display size. However, note that the server is not required to do so - e.g. it can round/bin the advertised values based on own logic and serve the closest matching resource (just as `srcset` picks the best/nearest resource based on the provided parameters in the markup).

Finally, since a hands-on example is worth a thousand words (courtesy of [resrc.it](http://www.resrc.it/)):

```bash
# Note: resrc.it is folloing older spec, hence CH- prefix, which is now unnecesarry.
#
# Request 100 px wide asset with DPR 1.0
$> curl -s http://app.resrc.it/http://www.resrc.it/img/demo/preferred.jpg \
  -o /dev/null -w "Image bytes: %{size_download}\n" \
  -H "CH-DPR: 1.0" -H "CH-RW: 100"
Image bytes: 9998

# Request 100 px wide asset with DPR 1.5
$> curl -s http://app.resrc.it/http://www.resrc.it/img/demo/preferred.jpg \
  -o /dev/null -w "Image bytes: %{size_download}\n" \
  -H "CH-DPR: 1.5" -H "CH-RW: 100"
Image bytes: 17667

# Request 200 px wide asset with DPR 1.0
$> curl -s http://app.resrc.it/http://www.resrc.it/img/demo/preferred.jpg \
  -o /dev/null -w "Image bytes: %{size_download}\n" \
  -H "CH-DPR: 1.0" -H "CH-RW: 200"
Image bytes: 28535
```

ReSRC.it servers automate the delivery of optimal image assets based on advertised DPR and RW values and append the correct caching header (Vary: DPR, RW), which allows the asset to be cached on the client and by any Vary-capable intermediaries.


### Implementation status

* Blink: [Intent to Implement: Client-Hints header (DPR switching)](https://groups.google.com/a/chromium.org/d/msg/blink-dev/c38s7y6dH-Q/bNFczRZj5MsJ)
* Mozilla: [935216 - Implement Client-Hints HTTP header](https://bugzilla.mozilla.org/show_bug.cgi?id=935216)

Chrome Canary has limited Client Hints support behind a runtime flag:

* Enable _chrome://flags/#enable-experimental-web-platform-features_
* Launch Chrome with `--enable-client-hints` flag

If you want to override sent Client Hints headers, you can also install [Client-Hints extension for Chrome](https://chrome.google.com/webstore/detail/client-hints/gdghpgmkfaedgngmnahnaaegpacanlef), which allows you to set different values for DPR headers. Also, note that Chrome (currently) does not update sent DPR value on (desktop) zoom (http://crbug.com/303856), and does not handle multi-display setups (http://crbug.com/303857).


### Feedback

Please feel free to open a new issue, or send a pull request!
