# bunny
httpie compatible curl alternative

Curl is very weak specially in REST APi testing. Httpie is great but has many bugs (e.g. When calling https, response headers disappear!).
I tried to create a httpie (and soon curl!) compatible alternative for developers to test their API.

./bunny https://dlang.org

Post JSON data:

./bunny POST http://myapi.com/login username=myusername password=mypassword
