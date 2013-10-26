## Client-Hints (Internet Draft)

Client Hints can be used as input to proactive content negotiation; just as the Accept header allowed clients to indicate what formats they prefer, Client Hints allow clients to indicate a list of device and agent specific preferences for the request resource.

Client Hints can be used to automate negotiation of optimal resolution and size of delivered image assets to different clients. For example, given the following HTML markup:

```html
<img src="img.jpg" width="160" alt="I'm responsive!">
```

The client and server can automatically negotiate the resolution and size of `img.jpg` via HTTP negotiation:

```http
GET /img.jpg HTTP/1.1
User-Agent: Awesome Browser
Accept: image/webp, image/jpg
CH-DPR: 2.0
CH-DW: 160
```
```http
HTTP/1.1 200 OK
Server: Awesome Server
Content-Type: image/jpg
Content-Length: 124523
Vary: CH-DPR, CH-DW
DPR: 2.0

(image data)
```

In above example, the client advertises its device pixel ratio (DPR) via `CH-DPR` header, and (optionally) the display width (in DIPs) of the requested asset. Given this information, the server is then able to dynamically select the optimal asset for the client, and confirms its selection via the `DPR` header.

For full details on negotiation workflow, refer to the [spec](https://github.com/igrigorik/http-client-hints/blob/master/draft-grigorik-http-client-hints-01.txt).


### Implementation status

Client Hints support [can be enabled](https://plus.google.com/100132233764003563318/posts/AS432bKs7pY) Chrome Canary via a `--enable-client-hints` flag. Current status:

* Chrome will only send the CH-DPR header.
* (WIP) Intrinsic size calculation: http://crbug.com/303863
* (WIP) Sent CH-DPR value is not updated on zoom: http://crbug.com/303856
* (WIP) Multi-display handling: http://crbug.com/303857

To experiment with Client Hints you can also use the [Client Hints extension for Chrome](https://chrome.google.com/webstore/detail/client-hints/gdghpgmkfaedgngmnahnaaegpacanlef), which allows you to set different values for CH headers. _(Note: extension works in any version of Chrome)._


### Interaction with src-N

Client Hints can be used alongside [src-N](http://tabatkins.github.io/specs/respimg/Overview.html) to automate resolution switching and simplify delivery of variable-sized images.

CH-DPR automates resolution use-case and eliminates the need to write `x` queries:

```html
<!-- src-N resolution switching -->
<img src-1="pic.png, picHigh.png 2x, picLow.png .5x">

<!-- equivalent functionality via CH-DPR -->
<img src="pic.png"> (or) <img src-1="pic.png">
```

CH-DW simplifies delivery of variable sized images: author specifies the breakpoints using src-N markup, the client computes the display width (in dips) of the image asset and sends it to the server. Given CH-DPR and CH-DW values, the server can then select the appropriate asset:

```html
<!-- src-N variable size + DPR selection -->
<img src-1="100% (30em) 50% (50em) calc(33% - 100px);
           pic100.png 100, pic200.png 200, pic400.png 400,
           pic800.png 800, pic1600.png 1600, pic3200.png 3200">
           
<!-- equivalent functionality via CH-DPR + CH-DW (see HTTP exchange above) -->
<img src-1="100% (30em) 50% (50em) calc(33% - 100px); pic.png">
```

The combination of `CH-DPR` and `CH-DW` allows the server to deliver 'pixel perfect' assets that match the device resolution and the exact display size. However, note that the server is not required to do so - e.g. it can round / bin the advertised values based on own logic and serve the closest matching asset (just as src-N picks the best / nearest asset based on provided urls in the markup). 

Finally, Client Hints also simplifies art-direction use case covered by src-N:

```html
<!-- src-N art-direction with resolution switching -->
<img src-1="(max-width: 30em) pic-small-1x.jpg 1x, pic-small-2x.jpg 2x"
     src-2="(max-width: 50em) pic-medium-1x.jpg 1x, pic-medium-2x.jpg 2x"
     src="pic-large.jpg">

<!-- equivalent functionality can be simplified with Client-Hints -->
<img src-1="(max-width: 30em) pic-small.jpg"
     src-2="(max-width: 50em) pic-medium.jpg"
     src="pic-large.jpg">
```


### Comparison to User-Agent & Cookie-based strategies

User-Agent sniffing cannot reliably detect the device pixel resolution of many devices (e.g. different generation iOS devices all have the same User-Agent header). Further, User-Agent detection cannot account for dynamic changes in DPR (e.g. zoomed in viewport on desktop devices). Similarly, User-Agent detection cannot tell us anything about the display width of the requested asset. In short, UA sniffing does not work.

HTTP Cookies can be used to [simulate similar behavior](https://github.com/jonathantneal/http-client-hints), but also have multiple limitations: client hints are not available on first request (missing cookie) or for any client who has cleared or disabled cookies; cookies impose additional client-side latency by requiring JavaScript execution to create and manage cookies; cookie solutions are limited to same-origin requests; cookie solutions are not HTTP cache friendly (cannot Vary on Cookie). 

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
    <td>Future proof</td>
    <td>Yes</td>
    <td>No</td>
    <td>Yes</td>
  </tr>
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
