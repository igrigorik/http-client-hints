A simple reference server to demo Client-Hints in action. For an end-to-end demo, first you'll need Chrome Canary, and then:

* Enable chrome://flags/#enable-experimental-web-platform-features
* Launch Canary with `--enable-clients` from comand line
* Visit: http://jsbin.com/akOtEJA/1/quiet

If you've enabled the right flags, then the above page should render all images with the same intrinsic size and the DPR negotiation is handled transparently by the browser (Chrome sends CH-DPR header).

_Note: above demo provides an override DPR parameter to illustrate rendering at differing resolutions. In practice, no such thing is actually required - i.e. look at the source for first example image._


## Demo instance on Heroku

* http://ch-dpr-demo.herokuapp.com/photo.jpg
* http://ch-dpr-demo.herokuapp.com/photo.jpg?force_dpr=2.2

A quick example using curl:

```bash
$> curl -H'CH-DPR:1.8' -v http://ch-dpr-demo.herokuapp.com/photo.jpg | wc -l

> GET /photo.jpg HTTP/1.1
> User-Agent: curl/7.30.0
> Host: ch-dpr-demo.herokuapp.com
> Accept: */*
> CH-DPR:1.8
>
< HTTP/1.1 200 OK
< Content-Type: image/jpeg
< Date: Wed, 30 Oct 2013 19:02:18 GMT
< Dpr: 1.5
* Server WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27) is not blacklisted
< Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
< Vary: CH-DPR
< X-Content-Type-Options: nosniff
< Content-Length: 381135
< Connection: keep-alive
<
[data not shown]
    1361
```

Note that we sent a "1.8" DPR hint and the server has responded with closest
match it has on disk, which in this case is "1.5" (as confirmed by DPR header). To test this behavior in the browser


### Running local instance

```bash
$> bundle install
$> ruby dpr_server.rb

# to run specs
$> rake spec
```

With the server up and running, try loading a few images:

* http://localhost:4567/missing.jpg (return 404)
* http://localhost:4567/photo.jpg (if sending CH-DPR header)
* http://localhost:4567/photo.jpg?force_dpr=1.8 (force DPR)

