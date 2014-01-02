## HTTP Client-Hints (Internet Draft) 

HTTP Client Hints can be used as input to proactive content negotiation; just as the Accept header allowed clients to indicate what formats they prefer, Client Hints allow clients to indicate a list of device and agent specific preferences.

HTTP Client Hints can be used to automate negotiation of optimal resolution and size of delivered image resources to different clients. For example, given the following HTML markup:

```html
<img src="img.jpg" width="160" alt="I'm responsive!">
```

The client and server can automatically negotiate the resolution and size of `img.jpg` via HTTP negotiation:

```http
GET /img.jpg HTTP/1.1
User-Agent: Awesome Browser
Accept: image/webp, image/jpg
CH-DPR: 2.0
CH-RW: 160
```
```http
HTTP/1.1 200 OK
Server: Awesome Server
Content-Type: image/jpg
Content-Length: 124523
Vary: CH-DPR, CH-RW
DPR: 2.0

(image data)
```

In above example, the client advertises its device pixel ratio (DPR) via `CH-DPR` header, and the resource display width via `CH-RW` (in DIPs) of the requested resource. Given this information, the server is then able to dynamically select the optimal resource for the client, and confirms its selection via the `DPR` header.

For full details on negotiation workflow, refer to the [spec](https://github.com/igrigorik/http-client-hints/blob/master/draft-grigorik-http-client-hints-01.txt).


### Implementation status

* Blink: [Intent to Implement: Client-Hints header (DPR switching)](https://groups.google.com/a/chromium.org/d/msg/blink-dev/c38s7y6dH-Q/bNFczRZj5MsJ)
* Mozilla: [935216 - Implement Client-Hints HTTP header](https://bugzilla.mozilla.org/show_bug.cgi?id=935216)

Client Hints support can be enabled in Chrome Canary:

* Launch Chrome with `--enable-client-hints` flag (this tells Chrome to emit CH-DPR request header)
* Enable _chrome://flags/#enable-experimental-web-platform-features_ (DPR selection confirmation support)

If you want to override sent Client-Hints headers, you can also install [Client-Hints extension for Chrome](https://chrome.google.com/webstore/detail/client-hints/gdghpgmkfaedgngmnahnaaegpacanlef), which allows you to set different values for CH-DPR headers. Note that (currently) Chrome does not update sent DPR value on (desktop) zoom (http://crbug.com/303856), and does not handle multi-display setups (http://crbug.com/303857).


### Interaction with picture element

Client Hints can be used alongside [picture element](http://picture.responsiveimages.org/) to automate resolution switching, simplify art-direction, and automate delivery of variable-sized and "pixel perfect" images. Let's consider the different scenarios covered by `<picture>`...

[Example 1](http://picture.responsiveimages.org/#examples): CH-DPR automates resolution switching use-case and eliminates the need to write `x` queries. As a result, the regular `<img>` tag becomes "resolution aware" without any extra work on behalf of the site owner:

```html
<!-- picture resolution switching -->
<picture>
  <source srcset="pic1x.jpg 1x, pic2x.jpg 2x, pic4x.jpg 4x">
  <img alt="A rad wolf." src="pic1x.jpg">
</picture>

<!-- equivalent functionality via CH-DPR -->
<img alt="A rad wolf." src="pic.jpg">
```

[Example 2/3](http://picture.responsiveimages.org/#examples): similar to example above, CH-DPR automates resolution switching in example #3. As a result, the markup in example #2 is functionally equivalent to #3 - the UA advertises the DPR and server performs the resolution selection. As a result the site owner can focus on art-direction (which, by definition, is a manual task and must be specified in the markup).

```html
<!-- (Example 2) art-direction with media queries -->
<picture>
  <source media="(min-width: 45em)" srcset="large.jpg">
  <source media="(min-width: 18em)" srcset="med.jpg">
  <img src="small.jpg" alt="The president giving an award." width="500" height="500">
</picture>

<!-- (Example 3) art-direction with media queries + resolution switching -->
<picture>
  <source media="(min-width: 45em)" srcset="large-1.jpg, large-2.jpg 2x">
  <source media="(min-width: 18em)" srcset="med-1.jpg, med-2.jpg 2x">
  <source srcset="small-1.jpg, small-2.jpg 2x">
  <img src="small-1.jpg" alt="The president giving an award." width="500" height="500">
</picture>
```

[Example 4](http://picture.responsiveimages.org/#examples): combination of CH-RW and CH-DPR simplifies delivery of variable sized images. The site author specifies the viewport width of the image via `sizes` attribute and the source, the device DPR and resource width are both sent to the server, and given this information the server computes the optimal variant and returns it to the client.

```html
<!-- (Example 4) variable density / size selection -->
<picture>
  <source sizes="100%" srcset="pic400.jpg 400w, pic800.jpg 800w, pic1600.jpg 1600w">
  <img src="pic400.jpg" alt="The president giving an award.">
</picture>

<!-- equivalent functionality with CH-DPR and CH-RW -->
<picture>
  <source sizes="100%" srcset="pic.jpg">
  <img alt="">
</picture>
```

Example flow for above example:

```
> GET /pic.jpg HTTP/1.1
> CH-DPR: 2.0
> CH-RW: 200

(Server: 2x DPR * 200 width = 400px -> selects pic400.jpg or performs a resize)

< 200 OK
< DPR: 2.0
< ...
```

[Example 5](http://picture.responsiveimages.org/#examples): in situations where multiple layout breakpoints are present the workflow is similar to that of example #4. To select the optimal resolution and size:

```html
<!-- (Example 5) multiple layout breakpoints -->
<picture>
  <source sizes="(max-width: 30em) 100%, (max-width: 50em) 50%, calc(33%-100px)"
          srcset="pic100.png 100w, pic200.png 200w, pic400.png 400w,
                  pic800.png 800w, pic1600.png 1600w, pic3200.png 3200w">
  <img src="pic400.png" alt="The president giving an award.">
</picture>

<!-- equivalent functionality with CH -->
<picture>
  <source sizes="(max-width: 30em) 100%, (max-width: 50em) 50%, calc(33%-100px)"
          srcset="pic.png">
  <img alt="">
</picture>
```

The combination of `CH-DPR` and `CH-RW` allows the server to deliver 'pixel perfect' images that match the device resolution and the exact display size. However, note that the server is not required to do so - e.g. it can round / bin the advertised values based on own logic and serve the closest matching resource (just as src-N picks the best / nearest resource based on provided urls in the markup).

Finally, since a hands-on example is worth a thousand words (courtesy of [resrc.it](http://www.resrc.it/) who recently added Client Hints support):

```bash
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

Resrc.it servers automate the delivery of optimal image assets based on advertised CH-DPR and CH-RW values and append the correct caching header (Vary: CH-DPR, CH-RW), which allows the asset to be cached on the client and by any Vary-capable intermediaries.


### Comparison to User-Agent & Cookie-based strategies

User-Agent sniffing cannot reliably detect the device pixel resolution of many devices (e.g. different generation iOS devices all have the same User-Agent header). Further, User-Agent detection cannot account for dynamic changes in DPR (e.g. zoomed in viewport on desktop devices). Similarly, User-Agent detection cannot tell us anything about the resource display width of the requested resource. In short, UA sniffing does not work.

HTTP Cookies can be used to [approximate CH behavior](https://github.com/jonathantneal/http-client-hints), but are subject to many limitations: client hints are not available on first request (missing cookie) or for any client who has cleared or disabled cookies; cookies impose additional client-side latency by requiring JavaScript execution to create and manage cookies; cookie solutions are limited to same-origin requests; cookie solutions are not HTTP cache friendly (cannot Vary on Cookie).

<table>
<thead>
  <tr>
    <th></th>
    <th>Client-Hints</th>
    <th>UA Sniffing</th>
    <th>Cookies</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td>Third-party database</td>
    <td>No</td>
    <td>Yes</td>
    <td>No</td>
  </tr>
  <tr>
    <td>Latency penalty</td>
    <td>No</td>
    <td>No</td>
    <td>Yes</td>
  </tr>
  <tr>
    <td>Hides resources from browser</td>
    <td>No</td>
    <td>No</td>
    <td>Yes</td>
  </tr>
  <tr>
    <td>Future proof</td>
    <td>Yes</td>
    <td>No</td>
    <td>Yes</td>
  </tr>
  <tr>
    <td>Dynamic variables</td>
    <td>Yes</td>
    <td>No</td>
    <td>Yes</td>
  </tr>
  <tr>
    <td>User overrides</td>
    <td>Yes</td>
    <td>No</td>
    <td>No</td>
  </tr>
  <tr>
    <td>Standardized / interoperable</td>
    <td>Yes</td>
    <td>No</td>
    <td>No</td>
  </tr>
</tbody>
</table>

### Feedback

Please feel free to open a new issue, or send a pull request!

[![Analytics](https://ga-beacon.appspot.com/UA-71196-10/ga-beacon/readme)](https://github.com/igrigorik/ga-beacon)
