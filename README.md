## Client-Hints (Internet Draft)

An increasing diversity of connected device form factors and software capabilities has created a need to deliver varying, or optimized content for each device.

The 'Client-Hints' header field for HTTP requests allows the client to describe its preferences and capabilities to an origin server to enable cache-friendly, server-side content adaptation, without imposing additional latency and deferred evaluation on the client.

Client-Hints also has the advantage of being able to transmit dynamic client preferences, such as available bandwidth, or current viewport size, which cannot be inferred through static client signature databases (aka, User-Agent device detection).

### Feedback

Please feel free to open a new issue, or send a pull request!
