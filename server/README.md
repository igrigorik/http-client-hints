To see Client-Hints in action you will need both a CH-aware server and a CH-aware client...

### Client-Hints servers

* See checked in **ch-dpr-server** for a sample ruby server
* See checked in **nginx-ch-dpr.conf** for sample nginx implementation

You can run both of the above locally to test the server. Alternatively, you can seem them in action here:

* Ruby server: http://ch-dpr-demo.herokuapp.com/photo.jpg
* Nginx server: http://www.igvita.com/downloads/ch/photos/awesome.jpg 

For an end-to-end test, setup your client (see below) and head to: http://www.igvita.com/downloads/ch/


### Client-Hints clients

* Chrome Canary supports Client-Hints:
 * Enable _chrome://flags/#enable-experimental-web-platform-features_
 * Launch Canary with `--enable-clients` from comand line 
 * You can also install [Client-Hints extension for Chrome](https://chrome.google.com/webstore/detail/client-hints/gdghpgmkfaedgngmnahnaaegpacanlef) to easily overwrite the advertised client DPR. 

Chrome will automatically send the device DPR (via CH-DPR header), and will also use the returned DPR confirmation (via DPR header) to adjust the intrinsic size calculation of the displayed asset. Finally, head to http://www.igvita.com/downloads/ch/ to see Client-Hints in action - if you've enabled the right flags then all images should be displayed at correct intrinsic size and resolution. Now try changing your DPR value via the extension - voila!

Alternatively, you can test Client-Hints with your favorite command line client. Simply pass the right CH headers when making the request. For example, using curl:

```bash
$> curl -H'CH-DPR: 1.8' -v http://ch-dpr-demo.herokuapp.com/photo.jpg | wc -l

> GET /photo.jpg HTTP/1.1
> User-Agent: curl/7.30.0
> Host: ch-dpr-demo.herokuapp.com
> Accept: */*
> CH-DPR: 1.8
>
< HTTP/1.1 200 OK
< Content-Type: image/jpeg
< Date: Wed, 30 Oct 2013 19:02:18 GMT
< Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
< DPR: 1.5
< Vary: CH-DPR
< X-Content-Type-Options: nosniff
< Content-Length: 381135
< Connection: keep-alive
<
[data not shown]
    1361
```

In example above we're sending a "1.8" DPR hint to the server, and the server has decided to respond with a "1.5" (as confirmed via "DPR: 1.5" header) asset. Try changing it to a different value, or omit the header entirely. 


