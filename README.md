## Client-Hints (Internet Draft)

There are thousands of different devices accessing the web, each with different device capabilities and preference information. These device capabilities include hardware and software characteristics, as well as dynamic user and client preferences.

One way to infer some of these capabilities is through User-Agent (UA) detection against an established database of client signatures. However, this technique requires acquiring such a database, integrating it into the serving path, and keeping it up to date. However, even once this infrastructure is deployed, UA sniffing has the following limitations:

  - UA detection depends on acquiring and maintenance of external databases
  - UA detection cannot reliably identify all static variables
  - UA detection cannot infer any dynamic client preferences
  - UA detection is not cache friendly

A popular alternative strategy is to use HTTP cookies to communicate some information about the client. However, this approach is also not cache friendly, bound by same origin policy, and imposes additional client-side latency by requiring JavaScript execution to create and manage HTTP cookies.

This document defines a new request Client Hint header field, "CH", that allows the client to make available hints, both static and dynamic, to origin and intermediate servers about its preference and capabilities. "CH" allows server-side content adaption without imposing additional latency on the client, requiring the use of additional device databases, while allowing cache-friendly deployments.

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
    <td>Latency Penalty</td>
    <td>No</td>
    <td>No</td>
    <td>Yes</td>
  </tr>
  <tr>
    <td>Hides Resources from browser</td>
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
    <td>Standardized / Interoperable</td>
    <td>Yes *</td>
    <td>No</td>
    <td>No</td>
  </tr>
</tbody>
</table>

## FAQ

#### What do you mean by cache friendly?

Once the resource is optimized based on client CH hint, it can be cached through Vary: CH, or in combination with Key for fine-grained cache control.

Vary: User-Agent does not work, because the amount of variation in the User-Agent header renders any asset effectively uncacheable. Same problem, but worse, for Cookies.

#### Which variables will be sent in CH header?

CH is a generic transport and is not tied to any specific variable. Having said that, the provided examples are device width (dw), device height (dh), and device pixel ration (dpr).

#### Why device width and height, not viewport?

The browser may not yet know the viewport size when the request is being dispatched, which creates a race condition.

#### When should the CH header be sent?

CH is an optional header. The client can decide when to append it to the request. Having said that, HTTP is stateless, so it is recommended that the client sends the CH header for all requests.

#### CH adds extra bytes!

True. The CH header will add 10-20 bytes to the outbound request. However, the 10-20 upstream bytes can easily translate to hundreds of saved Kilobytes in downstream direction when applied to images (60% of the bytes for an average page).

#### I want to add a new CH variable, how?

Open a bug, motivate the use case.



### Feedback

Please feel free to open a new issue, or send a pull request!
