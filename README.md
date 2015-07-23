## HTTP Client-Hints (Internet Draft)

This specification defines a set of HTTP request header fields, colloquially known as Client Hints, that are intended to be used as input to proactive content negotiation; just as the `Accept` header allows clients to indicate what formats they prefer, Client Hints allow clients to indicate a list of device and agent specific preferences.

**Latest draft:** http://igrigorik.github.io/http-client-hints/

* [Available hints](#available-hints)
* [Opt-in hint delvery](#opt-in-hint-delivery)
* [Use cases](#use-cases)
  - [Responsive Design + Server Side Components (RESS)](#responsive-design--server-side-components-ress)
  - [`<img>` element](#img-element)
    + [Delivering DPR-aware images](#delivering-dpr-aware-images)
    + [Delivering DPR and resource width aware images](#delivering-dpr-and-resource-width-aware-images)
  - [`<picture>` element](#picture-element)
    + [Device-pixel-ratio-based selection](#device-pixel-ratio-based-selection)
    + [Device-pixel-ratio and viewport-based selection](#device-pixel-ratio-and-viewport-based-selection)
    + [Resource selection](#resource-selection)
  - [Maximum downlink speed](#maximum-downlink-speed)
* [Hands-on example](#hands-on-example)
* [Implementation status](#implementation-status)

---

### Available hints
Current list includes `DPR` (device pixel ratio), `Width` (display width), `Viewport-Width`, and `Downlink` (maximum downlink speed) request headers, and `Content-DPR` response header that is used to confirm the DPR of selected image resources - see full definitions in <a href="http://igrigorik.github.io/http-client-hints/">latest spec</a>.

_Note: have a proposal for another hint? Open an issue, document your use case._

### Opt-in hint delivery
For the main document request, some user agent supported hints, and specifically the 'RW' hint, should be sent to the server. 
That is in order to support use-cases where server-side processing requires HTML manipulations, such as the [RESS](http://www.lukew.com/ff/entry.asp?1392) technique.

For other resources, in order to reduce request overhead the hints can be sent based on opt-in basis. Therefore, the user agent may refrain from sending hints over sub-resource requests, unless the server advertises support for these hints. See <a href="http://igrigorik.github.io/http-client-hints/#rfc.section.2.3.1">Advertising Support for Client Hints</a> for more details. 

### Use cases 
#### Responsive Design + Server Side Components (RESS)

The application may want to deliver alternate set of optimized resources based on advertised hints. For example, it may use the device pixel ratio (`DPR`), or the layout viewport width (`Viewport-Width`) to respond with optimized HTML markup, CSS, or script resources - see [Responsive Design + Server Side Components (RESS)](http://www.lukew.com/ff/entry.asp?1392).

_Note: Applications that use this approach must also serve appropriate `Vary` and `Cache-Control` response headers to ensure correct delivery of optimized assets._

#### `<img>` element
##### Delivering DPR-aware images
`DPR` hint automates device-pixel-ratio-based selection and enables delivery of optimal image variant without any changes in markup. For example, given the following HTML markup:

```html
<img src="img.jpg" alt="I'm a DPR-aware image!">
```

The client and server can negotiate the appropriate resolution of `img.jpg` via HTTP negotiation:

```http
GET /img.jpg HTTP/1.1
User-Agent: Awesome Browser
Accept: image/webp, image/jpg
DPR: 2.0
```
```http
HTTP/1.1 200 OK
Server: Awesome Server
Content-Type: image/jpg
Content-Length: 124523
Vary: DPR
Content-DPR: 2.0

(image data)
```

In the above example, the user agent advertises its device pixel ratio via `DPR` request header on the image request. Given this information, the server is able to select and respond with the optimal resource variant for the client. For full details refer to the latest [spec](http://igrigorik.github.io/http-client-hints/).

_Note: when server side DPR-selection is used the server must confirm the DPR of the selected resource via `Content-DPR` response header to allow the user agent to compute the correct intrinsic size of the image._

##### Delivering DPR and resource width aware images
If the image resource width is known at request time, the user agent can communicate it to the server to enable selection of an optimized resource. For example, given the following HTML markup:

```html
<img src="img.jpg" width="160" alt="I'm a DPR and width aware image!">
```

The client and server can negotiate an optimized asset based on `DPR` and `Width` request hints: 

```http
GET /img.jpg HTTP/1.1
User-Agent: Awesome Browser
Accept: image/webp, image/jpg
DPR: 2.0
Width: 160
```
```http
HTTP/1.1 200 OK
Server: Awesome Server
Content-Type: image/jpg
Content-Length: 124523
Vary: DPR, Width
Content-DPR: 2.0

(image data)
```

In the above example, the user agent advertises its device pixel ratio and image resource width via respective `DPR` and `Width` headers on the image request. Given this information, the server is able to select and respond with the optimal resource variant for the client:

* The server can scale the asset to requested width, or return the closest available match to help reduce number of transfered bytes.
* The server can factor in the device pixel ratio of the device in its selection algorithm.

Note that the display width of the image may not be available at request time, in which case the user agent would omit the `Width` hint. Also, the exact logic as to which asset is selected is deferred to the server, which can optimize its selection based on available resources, cache hit rates, and other criteria.


#### `<picture>` element

Client Hints can be used alongside [picture element](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#the-picture-element) to automate resolution switching, simplify art-direction, and automate delivery of variable-sized images. 

##### Device-pixel-ratio-based selection
DPR header automates [device-pixel-ratio-based selection](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#introduction-3:device-pixel-ratio-2) by eliminating the need to write `x` descriptors for `img` and `picture` elements:

```html
<!-- picture resolution switching -->
<picture>
  <source srcset="pic1x.jpg 1x, pic2x.jpg 2x, pic4x.jpg 4x">
  <img alt="A rad wolf." src="pic1x.jpg">
</picture>

<!-- alternative and equivalent syntax -->
<img src="pic1x.jpg" srcset="pic2x.jpg 2x, pic4x.jpg 4x" alt="A rad wolf.">

<!-- equivalent functionality with DPR hint -->
<img alt="A rad wolf." src="pic.jpg">

<!-- ... similarly ... -->

<!-- picture art-direction with resolution switching -->
<picture>
  <source media="(min-width: 45em)" srcset="large-1.jpg, large-2.jpg 2x">
  <source media="(min-width: 18em)" srcset="med-1.jpg, med-2.jpg 2x">
  <img src="small-1.jpg" srcset="small-2.jpg 2x" alt="The president giving an award." width="500" height="500">
</picture>

<!-- equivalent functionality with resolution switching with Client Hints -->
<picture>
  <source media="(min-width: 45em)" srcset="large.jpg">
  <source media="(min-width: 18em)" srcset="med.jpg">
  <img src="small.jpg" alt="The president giving an award." width="500" height="500">
</picture>
```

Note that the second example with [art direction-based selection](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#introduction-3:art-direction-3) illustrates that hints do not eliminate the need for the `picture` element. Rather, Client Hints is able to simplify and automate certain parts of the negotiation, allowing the developer to focus on art direction, which by definition requires developer/designer input.

##### Device-pixel-ratio and viewport-based selection
The combination of `DPR` and `Width` hints also simplifies delivery of variable sized images when [viewport-based selection](http://www.whatwg.org/specs/web-apps/current-work/multipage/embedded-content.html#introduction-3:viewport-based-selection-2) is used. The developer specifies the resource width of the image in `vw` units (which are relative to viewport width) via `sizes` attribute and the user agent handles the rest: 

```html
<!-- viewport-based selection -->
<img src="wolf-400.jpg" sizes="100vw" alt="The rad wolf"
     srcset="wolf-400.jpg 400w, wolf-800.jpg 800w, wolf-1600.jpg 1600w">

<!-- equivalent functionality with DPR and Width hints -->
<img src="wolf.jpg" sizes="100vw" alt="The rad wolf">
```

* Device pixel ratio is communicated via the `DPR` request header
* The `vw` size is converted to CSS `px` size based on client's layout viewport size and the resulting value is communicated via the `Width` request header
* The server computes the optimal image variant based on communicated `DPR` and `Width` values and responds with the optimal image variant.

HTTP negotiation flow for the example above:

```
> GET /wolf.jpg HTTP/1.1
> DPR: 2.0
> Width: 400

(Server: 2x DPR * 400 CSS px = 800px -> selects wolf-800.jpg or performs a resize)

< 200 OK
< Content-DPR: 2.0
< Vary: DPR, Width
< ...
```

In situations where multiple layout breakpoints impact the image's dimensions the workflow is similar to that of the previous example:

```html
<!-- multiple layout breakpoints -->
<img src="swing-400.jpg" alt="Kettlebell Swing"
  sizes="(max-width: 30em) 100vw, (max-width: 50em) 50vw, calc(33vw - 100px)"
  srcset="swing-200.jpg 200w, swing-400.jpg 400w, swing-800.jpg 800w, swing-1600.jpg 1600w">

<!-- equivalent functionality with DPR and Width hints -->
<img src="swing.jpg" alt="Kettlebell Swing"
  sizes="(max-width: 30em) 100vw, (max-width: 50em) 50vw,calc (33vw - 100px)">
```

The combination of the `DPR` and `Width` hints allows the server to deliver 'pixel perfect' images that match the device resolution and exact display size. However, the server is not required to do so: it can round or bin the advertised values based on own logic and serve the closest matching resource - just as `srcset` picks the nearest resource based on the provided parameters in the markup.

##### Resource selection
When request hints are used the resource selection algorithm logic is shared between the user agent and the server: the user agent may apply own selection rules based on specified markup and defer other decisions to the server by communicating the appropriate `DPR` and `Width` values within the image request. With that, a few considerations to keep in mind:

* The device pixel ratio and the resource width may change after the initial image request was sent to the server - e.g. layout change, desktop zoom, etc. When this occurs, and if resource selection is done via `sizes` or `srcset` attributes, the decision to initiate a new request is deferred to the user agent: it may send a new request advertising new hint values, or it may choose to reuse and rescale the existing asset. Note that this is the [default behavior of the user agent](https://github.com/ResponsiveImagesCG/picture-element/issues/230) - i.e. the user agent is **not** required to initiate a new request and use of hints does not modify this behavior.
* For cases where an environment change (layout, zoom, etc.) must trigger a new asset download, you should use art-direction with `source` and appropriate media queries. 

Use of Client Hints does not incur additional or unnecessary requests. However, as an extra optimization, the server should [advertise the Key caching header](http://igrigorik.github.io/http-client-hints/#rfc.section.2.3.2) to improve cache efficiency.


#### Maximum downlink speed
The application may want to deliver an alternate set of resources (e.g. - alternate image asset, stylesheet, HTML document, media stream, and so on) based on the maximum downlink (`Downlink`) speed of the client, as defined by the [`downlinkMax` attribute](https://w3c.github.io/netinfo/#downlinkmax-attribute) in the W3C Network Information API.


### Hands-on example

A hands-on example courtesy of [resrc.it](http://www.resrc.it/):

```bash
# Request 100 CSS px wide asset with DPR of 1.0
$> curl -s http://app.resrc.it/http://www.resrc.it/img/demo/preferred.jpg \
  -o /dev/null -w "Image bytes: %{size_download}\n" \
  -H "DPR: 1.0" -H "Width: 100"
Image bytes: 9998

# Request 100 CSS px wide asset with DPR of 1.5
$> curl -s http://app.resrc.it/http://www.resrc.it/img/demo/preferred.jpg \
  -o /dev/null -w "Image bytes: %{size_download}\n" \
  -H "DPR: 1.5" -H "Width: 100"
Image bytes: 17667

# Request 200 CSS px wide asset with DPR of 1.0
$> curl -s http://app.resrc.it/http://www.resrc.it/img/demo/preferred.jpg \
  -o /dev/null -w "Image bytes: %{size_download}\n" \
  -H "DPR: 1.0" -H "Width: 200"
Image bytes: 28535
```

ReSRC.it servers automate the delivery of optimal image assets based on advertised `DPR` and `Width` hint values and append the correct caching header (`Vary: DPR, Width`), which allows the asset to be cached on the client and by any Vary-capable intermediaries.


### Implementation status
* IE: [Under Consideration](http://status.modern.ie/httpclienthints?term=client%20hints)
* Mozilla: [935216 - Implement Client-Hints HTTP header](https://bugzilla.mozilla.org/show_bug.cgi?id=935216)
* Blink: [Intent to Implement: Client-Hints header (DPR switching)](https://groups.google.com/a/chromium.org/d/msg/blink-dev/c38s7y6dH-Q/bNFczRZj5MsJ)
  - Chrome Canary has limited Client Hints support behind a runtime flag:
    * Enable _chrome://flags/#enable-experimental-web-platform-features_
    * Launch Chrome with `--enable-client-hints` flag
  - Alternatively, you can install [Client-Hints extension for Chrome](https://chrome.google.com/webstore/detail/client-hints/gdghpgmkfaedgngmnahnaaegpacanlef), which allows you to set different values for DPR headers.


### Feedback
Please feel free to open a new issue, or send a pull request!
