## Demo / reference CH-aware server

Running local instance for local testing:

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

A quick example using curl:

```bash
$> curl -H'CH-DPR:1.8' -v http://localhost:4567/photo.jpg | wc -l

> GET /photo.jpg HTTP/1.1
> User-Agent: curl/7.30.0
> Host: localhost:4567
> Accept: */*
> CH-DPR:1.8
>
< HTTP/1.1 200 OK
< Content-Type: image/jpeg
< Vary: CH-DPR
< Dpr: 1.5
< Content-Length: 381135
< X-Content-Type-Options: nosniff
* Server WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27) is not blacklisted
< Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
< Date: Wed, 30 Oct 2013 18:47:32 GMT
< Connection: Keep-Alive
<
{ [data not shown]
100  372k  100  372k    0     0  56.6M      0 --:--:-- --:--:-- --:--:-- 60.5M
* Connection #0 to host localhost left intact
    1361
```

Note that we sent a "1.8" DPR hint, and the server has responded with closest
match, which in this case is "1.5" (as confirmed by DPR header).
