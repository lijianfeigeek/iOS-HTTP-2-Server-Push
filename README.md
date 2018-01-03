![HTTP/2](http://7xraw1.com1.z0.glb.clouddn.com/20170411149190414882815.jpg)
# HTTP/2 Server Push 是什么
当用户的浏览器和服务器在建立链接后，服务器主动将一些资源推送给浏览器并缓存起来，这样当浏览器接下来请求这些资源时就直接从缓存中读取，不会在从服务器上拉了，提升了速率。举一个例子就是：

假如一个页面有3个资源文件index.html,index.css,index.js,当浏览器请求index.html的时候，服务器不仅返回index.html的内容，同时将index.css和index.js的内容push给浏览器，当浏览器下次请求这2两个文件时就可以直接从缓存中读取了。

如下图所示:
![Apple-http2ServerPush](http://7xraw1.com1.z0.glb.clouddn.com/20170411149190039117815.png)

# HTTP/2 Server Push 原理是什么
要想了解server push原理，首先要理解一些概念。我们知道HTTP/2传输的格式并不像HTTP1使用文本来传输，而是启用了二进制帧(Frames)格式来传输，和server push相关的帧主要分成这几种类型：

1. HEADERS frame(请求返回头帧):这种帧主要携带的http请求头信息，和HTTP1的header类似。
2. DATA frames(数据帧) :这种帧存放真正的数据content，用来传输。
3. PUSH_PROMISE frame(推送帧):这种帧是由server端发送给client的帧，用来表示server push的帧，这种帧是实现server push的主要帧类型。
4. RST_STREAM(取消推送帧):这种帧表示请求关闭帧，简单讲就是当client不想接受某些资源或者接受timeout时会向发送方发送此帧，和PUSH_PROMISE frame一起使用时表示拒绝或者关闭server push。

(PS:HTTP/2相关的帧其实包括[10种帧](https://tools.ietf.org/html/rfc7540#section-11.2)，正是因为底层数据格式的改变，才为HTTP/2带来许多的特性，帧的引入不仅有利于压缩数据，也有利于数据的安全性和可靠传输性。)

了解了相关的帧类型，下面就是具体server push的实现过程了：

1. 由多路复用我们可以知道HTTP/2中对于同一个域名的请求会使用一条tcp链接而用不同的stream ID来区分各自的请求。
2. 当client使用stream 1请求index.html时，server正常处理index.html的请求，并可以得知index.html页面还将要会请求index.css和index.js。
3. server使用stream 1发送PUSH_PROMISE frame给client告诉client我这边可以使用stream 2来推送index.js和stream 3来推送index.css资源。
4. server使用stream 1正常的发送HEADERS frame和DATA frames将index.html的内容返回给client。
5. client接收到PUSH_PROMISE frame得知stream 2和stream 3来接收推送资源。
6. server拿到index.css和index.js便会发送HEADERS frame和DATA frames将资源发送给client。
7. client拿到push的资源后会缓存起来当请求这个资源时会从直接从从缓存中读取。

# Server Push 怎么用
## 使用 nghttp2 调试 HTTP/2 流量
查看 HTTP/2 流量的几种方式
- 在 Chrome 地址栏输入 `chrome://net-internals/#http2`，使用 Chrome 自带的 HTTP/2 调试工具；
     使用方便，但受限于 Chrome 浏览器，对于 Chrome 不支持的 h2c（HTTP/2 Cleartext，没有部署 TLS 的 HTTP/2）协议无能为力。同时，这个工具显示的信息经过了解析和筛选，不够全面。
- 使用 Wireshark 调试 HTTP/2 流量；
    Wireshark 位于服务端和浏览器之间，充当的是中间人角色，用它查看 HTTP/2 over HTTPS 流量时，必须拥有网站私钥或者借助浏览器共享对称密钥，才能解密 TLS 流量，配置起来比较麻烦。

 nghttp2，是一个用 C 实现的 HTTP/2 库，支持 h2c。它可以做为其它软件的一部分，为其提供 HTTP/2 相关功能（例如 curl 的 HTTP/2 功能就是用的 nghttp2）。除此之外，它还提供了四个有用的 HTTP/2 工具：
 
 - nghttp：HTTP/2 客户端；
 - nghttpd：HTTP/2 服务端；
 - nghttpx：HTTP/2 代理，提供 HTTP/1、HTTP/2 等协议之间的转换；
 - h2load：HTTP/2 性能测试工具；　
 

### nghttp2 安装
先来用 brew 看一下有没有 nghttp 相关的库：
```
~ brew search nghttp
nghttp2
```
看来是有 nghttp2 的，再用 brew 看下需要安装哪些环境：
```
~ brew info nghttp2
nghttp2: stable 1.21.0 (bottled), HEAD
HTTP/2 C Library
https://nghttp2.org/
Not installed
From: https://github.com/Homebrew/homebrew-core/blob/master/Formula/nghttp2.rb
==> Dependencies
Build: sphinx-doc ✘, pkg-config ✔, cunit ✘
Required: c-ares ✘, libev ✘, openssl ✔, libevent ✘, jansson ✘, boost ✘, spdylay ✘
Recommended: jemalloc ✘
==> Requirements
Optional: python3 ✔
==> Options
--with-examples
	Compile and install example programs
--with-python3
	Build python3 bindings
--without-docs
	Don't build man pages
--without-jemalloc
	Build without jemalloc support
--HEAD
	Install HEAD version
```

看来需要的依赖还挺多。

使用 brew 安装 nghttp2 ：
```
brew install nghttp2
```

一切妥当后，nghttp2 提供的几个工具就可以直接用了。

### nghttp
nghttp 做为一个功能完整的 HTTP/2 客户端，非常适合用来查看和调试 HTTP/2 流量。它支持的参数很多，通过官方文档或者 nghttp -h 都能查看。最常用几个参数如下：

- -v, --verbose，输出完整的 debug 信息；
- -n, --null-out，丢弃下载的数据；
- -a, --get-assets，下载 html 中的 css、js、image 等外链资源；
- -H, --header = < HEADER >，添加请求头部字段，如 -H':method: PUT'；
- -u, --upgrade，使用 HTTP 的 Upgrade 机制来协商 HTTP/2 协议，用于 h2c，详见下面的例子；

以下是使用 nghttp 访问 https://h2o.examp1e.net 的结果。从调试信息中可以清晰看到 h2c 协商以及 Server Push 的整个过程：

```
nghttp -nv 'https://h2o.examp1e.net'
[  0.201] Connected
The negotiated protocol: h2
[  1.180] send SETTINGS frame <length=12, flags=0x00, stream_id=0>
          (niv=2)
          [SETTINGS_MAX_CONCURRENT_STREAMS(0x03):100]
          [SETTINGS_INITIAL_WINDOW_SIZE(0x04):65535]
[  1.180] send PRIORITY frame <length=5, flags=0x00, stream_id=3>
          (dep_stream_id=0, weight=201, exclusive=0)
[  1.180] send PRIORITY frame <length=5, flags=0x00, stream_id=5>
          (dep_stream_id=0, weight=101, exclusive=0)
[  1.180] send PRIORITY frame <length=5, flags=0x00, stream_id=7>
          (dep_stream_id=0, weight=1, exclusive=0)
[  1.180] send PRIORITY frame <length=5, flags=0x00, stream_id=9>
          (dep_stream_id=7, weight=1, exclusive=0)
[  1.180] send PRIORITY frame <length=5, flags=0x00, stream_id=11>
          (dep_stream_id=3, weight=1, exclusive=0)
[  1.180] send HEADERS frame <length=39, flags=0x25, stream_id=13>
          ; END_STREAM | END_HEADERS | PRIORITY
          (padlen=0, dep_stream_id=11, weight=16, exclusive=0)
          ; Open new stream
          :method: GET
          :path: /
          :scheme: https
          :authority: h2o.examp1e.net
          accept: */*
          accept-encoding: gzip, deflate
          user-agent: nghttp2/1.21.1
[  1.373] recv SETTINGS frame <length=12, flags=0x00, stream_id=0>
          (niv=2)
          [SETTINGS_MAX_CONCURRENT_STREAMS(0x03):100]
          [SETTINGS_INITIAL_WINDOW_SIZE(0x04):16777216]
[  1.373] recv SETTINGS frame <length=0, flags=0x01, stream_id=0>
          ; ACK
          (niv=0)
[  1.373] recv (stream_id=13) :method: GET
[  1.373] recv (stream_id=13) :scheme: https
[  1.373] recv (stream_id=13) :authority: h2o.examp1e.net
[  1.373] recv (stream_id=13) :path: /search/jquery-1.9.1.min.js
[  1.373] recv (stream_id=13) accept: */*
[  1.373] recv (stream_id=13) accept-encoding: gzip, deflate
[  1.373] recv (stream_id=13) user-agent: nghttp2/1.21.1
[  1.373] recv PUSH_PROMISE frame <length=59, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0, promised_stream_id=2)
[  1.373] recv (stream_id=2) :status: 200
[  1.373] recv (stream_id=2) server: h2o/2.2.0-beta2
[  1.373] recv (stream_id=2) date: Mon, 10 Apr 2017 06:30:29 GMT
[  1.373] recv (stream_id=2) content-type: application/javascript
[  1.373] recv (stream_id=2) last-modified: Thu, 14 May 2015 04:10:14 GMT
[  1.373] recv (stream_id=2) etag: "55542026-169d5"
[  1.373] recv (stream_id=2) accept-ranges: bytes
[  1.373] recv (stream_id=2) x-http2-push: pushed
[  1.373] recv (stream_id=2) content-length: 92629
[  1.373] recv HEADERS frame <length=126, flags=0x04, stream_id=2>
          ; END_HEADERS
          (padlen=0)
          ; First push response header
[  1.373] recv (stream_id=13) :method: GET
[  1.373] recv (stream_id=13) :scheme: https
[  1.373] recv (stream_id=13) :authority: h2o.examp1e.net
[  1.373] recv (stream_id=13) :path: /search/oktavia-jquery-ui.js
[  1.373] recv (stream_id=13) accept: */*
[  1.373] recv (stream_id=13) accept-encoding: gzip, deflate
[  1.373] recv (stream_id=13) user-agent: nghttp2/1.21.1
[  1.373] recv PUSH_PROMISE frame <length=33, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0, promised_stream_id=4)
[  1.373] recv (stream_id=4) :status: 200
[  1.373] recv (stream_id=4) server: h2o/2.2.0-beta2
[  1.373] recv (stream_id=4) date: Mon, 10 Apr 2017 06:30:29 GMT
[  1.373] recv (stream_id=4) content-type: application/javascript
[  1.373] recv (stream_id=4) last-modified: Thu, 14 May 2015 04:10:14 GMT
[  1.373] recv (stream_id=4) etag: "55542026-1388"
[  1.373] recv (stream_id=4) accept-ranges: bytes
[  1.374] recv (stream_id=4) x-http2-push: pushed
[  1.374] recv (stream_id=4) content-length: 5000
[  1.374] recv HEADERS frame <length=28, flags=0x04, stream_id=4>
          ; END_HEADERS
          (padlen=0)
          ; First push response header
[  1.374] recv (stream_id=13) :method: GET
[  1.374] recv (stream_id=13) :scheme: https
[  1.374] recv (stream_id=13) :authority: h2o.examp1e.net
[  1.374] recv (stream_id=13) :path: /search/oktavia-english-search.js
[  1.374] recv (stream_id=13) accept: */*
[  1.374] recv (stream_id=13) accept-encoding: gzip, deflate
[  1.374] recv (stream_id=13) user-agent: nghttp2/1.21.1
[  1.374] recv PUSH_PROMISE frame <length=35, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0, promised_stream_id=6)
[  1.374] recv (stream_id=6) :status: 200
[  1.374] recv (stream_id=6) server: h2o/2.2.0-beta2
[  1.374] recv (stream_id=6) date: Mon, 10 Apr 2017 06:30:29 GMT
[  1.374] recv (stream_id=6) content-type: application/javascript
[  1.374] recv (stream_id=6) last-modified: Thu, 14 May 2015 04:10:14 GMT
[  1.374] recv (stream_id=6) etag: "55542026-34dd6"
[  1.374] recv (stream_id=6) accept-ranges: bytes
[  1.374] recv (stream_id=6) x-http2-push: pushed
[  1.374] recv (stream_id=6) content-length: 216534
[  1.374] recv HEADERS frame <length=31, flags=0x04, stream_id=6>
          ; END_HEADERS
          (padlen=0)
          ; First push response header
[  1.374] recv (stream_id=13) :method: GET
[  1.374] recv (stream_id=13) :scheme: https
[  1.374] recv (stream_id=13) :authority: h2o.examp1e.net
[  1.374] recv (stream_id=13) :path: /assets/style.css
[  1.374] recv (stream_id=13) accept: */*
[  1.374] recv (stream_id=13) accept-encoding: gzip, deflate
[  1.374] recv (stream_id=13) user-agent: nghttp2/1.21.1
[  1.374] recv PUSH_PROMISE frame <length=24, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0, promised_stream_id=8)
[  1.374] recv (stream_id=8) :status: 200
[  1.374] recv (stream_id=8) server: h2o/2.2.0-beta2
[  1.374] recv (stream_id=8) date: Mon, 10 Apr 2017 06:30:29 GMT
[  1.374] recv (stream_id=8) content-type: text/css
[  1.374] recv (stream_id=8) last-modified: Tue, 20 Sep 2016 05:27:06 GMT
[  1.374] recv (stream_id=8) etag: "57e0c8aa-1586"
[  1.374] recv (stream_id=8) accept-ranges: bytes
[  1.374] recv (stream_id=8) x-http2-push: pushed
[  1.374] recv (stream_id=8) content-length: 5510
[  1.374] recv HEADERS frame <length=58, flags=0x04, stream_id=8>
          ; END_HEADERS
          (padlen=0)
          ; First push response header
[  1.374] recv (stream_id=13) :method: GET
[  1.374] recv (stream_id=13) :scheme: https
[  1.374] recv (stream_id=13) :authority: h2o.examp1e.net
[  1.374] recv (stream_id=13) :path: /assets/searchstyle.css
[  1.374] recv (stream_id=13) accept: */*
[  1.374] recv (stream_id=13) accept-encoding: gzip, deflate
[  1.374] recv (stream_id=13) user-agent: nghttp2/1.21.1
[  1.374] recv PUSH_PROMISE frame <length=28, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0, promised_stream_id=10)
[  1.374] recv (stream_id=10) :status: 200
[  1.374] recv (stream_id=10) server: h2o/2.2.0-beta2
[  1.374] recv (stream_id=10) date: Mon, 10 Apr 2017 06:30:29 GMT
[  1.374] recv (stream_id=10) content-type: text/css
[  1.374] recv (stream_id=10) last-modified: Tue, 20 Sep 2016 05:27:06 GMT
[  1.374] recv (stream_id=10) etag: "57e0c8aa-8dd"
[  1.374] recv (stream_id=10) accept-ranges: bytes
[  1.374] recv (stream_id=10) x-http2-push: pushed
[  1.374] recv (stream_id=10) content-length: 2269
[  1.374] recv HEADERS frame <length=27, flags=0x04, stream_id=10>
          ; END_HEADERS
          (padlen=0)
          ; First push response header
[  1.374] recv (stream_id=13) :status: 200
[  1.374] recv (stream_id=13) server: h2o/2.2.0-beta2
[  1.374] recv (stream_id=13) date: Mon, 10 Apr 2017 06:30:29 GMT
[  1.374] recv (stream_id=13) link: </search/jquery-1.9.1.min.js>; rel=preload
[  1.374] recv (stream_id=13) link: </search/oktavia-jquery-ui.js>; rel=preload
[  1.374] recv (stream_id=13) link: </search/oktavia-english-search.js>; rel=preload
[  1.374] recv (stream_id=13) link: </assets/style.css>; rel=preload
[  1.374] recv (stream_id=13) link: </assets/searchstyle.css>; rel=preload
[  1.374] recv (stream_id=13) cache-control: no-cache
[  1.374] recv (stream_id=13) content-type: text/html
[  1.374] recv (stream_id=13) last-modified: Wed, 05 Apr 2017 06:55:14 GMT
[  1.374] recv (stream_id=13) etag: "58e494d2-1665"
[  1.374] recv (stream_id=13) accept-ranges: bytes
[  1.374] recv (stream_id=13) set-cookie: h2o_casper=AmgAAAAAAAAAAAAYxfEYAAABSA; Path=/; Expires=Tue, 01 Jan 2030 00:00:00 GMT; Secure
[  1.374] recv (stream_id=13) content-length: 5733
[  1.374] recv HEADERS frame <length=304, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0)
          ; First response header
[  1.375] send SETTINGS frame <length=0, flags=0x01, stream_id=0>
          ; ACK
          (niv=0)
[  1.566] recv DATA frame <length=16137, flags=0x00, stream_id=2>
[  1.567] recv DATA frame <length=5000, flags=0x01, stream_id=4>
          ; END_STREAM
[  1.567] recv DATA frame <length=4915, flags=0x00, stream_id=6>
[  1.766] recv DATA frame <length=2829, flags=0x00, stream_id=8>
[  1.766] recv DATA frame <length=2269, flags=0x01, stream_id=10>
          ; END_STREAM
[  1.766] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=33120)
[  1.767] recv DATA frame <length=9065, flags=0x00, stream_id=2>
[  1.970] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  1.970] recv DATA frame <length=2681, flags=0x01, stream_id=8>
          ; END_STREAM
[  1.971] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=2>
          (window_size_increment=33855)
[  1.971] recv DATA frame <length=10072, flags=0x00, stream_id=2>
[  2.172] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  2.172] recv DATA frame <length=4248, flags=0x00, stream_id=2>
[  2.173] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  2.173] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=34002)
[  2.173] recv DATA frame <length=4248, flags=0x00, stream_id=2>
[  2.577] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  2.578] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  2.579] recv DATA frame <length=12762, flags=0x00, stream_id=6>
[  2.777] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  2.777] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=6>
          (window_size_increment=33241)
[  2.778] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  3.177] recv DATA frame <length=8505, flags=0x00, stream_id=2>
[  3.177] recv DATA frame <length=5667, flags=0x00, stream_id=6>
[  3.177] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=33993)
[  3.177] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  3.177] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  3.378] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  3.579] recv DATA frame <length=11343, flags=0x00, stream_id=6>
[  3.580] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=34002)
[  3.580] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=2>
          (window_size_increment=33984)
[  3.583] recv DATA frame <length=7086, flags=0x00, stream_id=2>
[  3.779] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  4.186] recv DATA frame <length=7086, flags=0x00, stream_id=2>
[  4.186] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  4.186] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  4.395] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  4.396] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  4.602] recv DATA frame <length=5667, flags=0x00, stream_id=6>
[  4.602] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=6>
          (window_size_increment=33993)
[  4.602] recv DATA frame <length=2829, flags=0x00, stream_id=2>
[  4.602] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=33975)
[  4.808] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  4.809] recv DATA frame <length=6379, flags=0x01, stream_id=2>
          ; END_STREAM
[  5.010] recv DATA frame <length=3536, flags=0x00, stream_id=6>
[  5.420] recv DATA frame <length=8505, flags=0x00, stream_id=6>
[  5.420] recv DATA frame <length=5667, flags=0x00, stream_id=6>
[  5.628] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  5.842] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  5.842] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  5.842] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=34002)
[  5.842] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=6>
          (window_size_increment=33281)
[  6.057] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  6.273] recv DATA frame <length=8505, flags=0x00, stream_id=6>
[  6.490] recv DATA frame <length=9924, flags=0x00, stream_id=6>
[  6.490] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  6.706] recv DATA frame <length=4248, flags=0x00, stream_id=6>
[  6.706] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=34002)
[  6.706] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=6>
          (window_size_increment=34002)
[  6.924] recv DATA frame <length=8505, flags=0x00, stream_id=6>
[  7.141] recv DATA frame <length=8505, flags=0x00, stream_id=6>
[  7.361] recv DATA frame <length=8505, flags=0x00, stream_id=6>
[  7.361] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=34020)
[  7.574] recv DATA frame <length=9924, flags=0x00, stream_id=6>
[  7.574] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=6>
          (window_size_increment=34029)
[  7.787] recv DATA frame <length=9924, flags=0x00, stream_id=6>
[  7.787] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  7.998] recv DATA frame <length=7086, flags=0x00, stream_id=6>
[  8.210] recv DATA frame <length=9924, flags=0x00, stream_id=6>
[  8.210] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=0>
          (window_size_increment=34011)
[  8.210] send WINDOW_UPDATE frame <length=4, flags=0x00, stream_id=6>
          (window_size_increment=34011)
[  8.425] recv DATA frame <length=11343, flags=0x00, stream_id=6>
[  8.426] recv DATA frame <length=2829, flags=0x00, stream_id=6>
[  8.426] recv DATA frame <length=4053, flags=0x01, stream_id=6>
          ; END_STREAM
[  8.631] recv DATA frame <length=4443, flags=0x00, stream_id=13>
[  8.633] recv DATA frame <length=1290, flags=0x01, stream_id=13>
          ; END_STREAM
[  8.633] send GOAWAY frame <length=8, flags=0x00, stream_id=0>
          (last_stream_id=10, error_code=NO_ERROR(0x00), opaque_data(0)=[])
```

当然，我们也可以使用 `grep` 搜索出来 server push 的相关 stream：

```
nghttp -nv 'https://h2o.examp1e.net' | grep 'PUSH_PROMISE'
[  1.582] recv PUSH_PROMISE frame <length=59, flags=0x04, stream_id=13>
[  1.582] recv PUSH_PROMISE frame <length=33, flags=0x04, stream_id=13>
[  1.582] recv PUSH_PROMISE frame <length=35, flags=0x04, stream_id=13>
[  1.582] recv PUSH_PROMISE frame <length=24, flags=0x04, stream_id=13>
[  1.582] recv PUSH_PROMISE frame <length=28, flags=0x04, stream_id=13>
```

## 使用 NodeJS 搭建 HTTP/2 服务器
在大前端的时代背景下，客户端开发不会点 JavaScript 都快混不下去了，笔者前段时间在我司前端轮岗了两周，再加上之前也写过 ReactNative，但还是感觉前端变化之快领人咋舌，革命尚未结束，同志仍需努力啊。

咱们直接上代码：
```
var http2 = require('http2');// http2
var url=require('url'); // https://www.npmjs.com/package/url
var fs=require('fs'); // https://www.npmjs.com/package/fs
var mine=require('mine');
var path=require('path'); // 路径
 
var server = http2.createServer({
  key: fs.readFileSync('./localhost.key'),
  cert: fs.readFileSync('./localhost.crt')
}, function(request, response) {

    // var pathname = url.parse(request.url).pathname;
    var realPath = './push.json' ;//path.join(pathname,"push.json");    //这里设置自己的文件路径，这是该次response返回的内容;
 
    var pushArray = [];
    var ext = path.extname(realPath);
    ext = ext ? ext.slice(1) : 'unknown';
    var contentType = mine[ext] || "text/plain";
 
    if (fs.existsSync(realPath)) {
        
        console.log('success')
        response.writeHead(200, {
            'Content-Type': contentType
        });
        
        response.write(fs.readFileSync(realPath,'binary'));

        // 注意 push 路径必须是绝对路径，这是该次 server push 返回的内容
        var pushItem = response.push('/Users/f.li/Desktop/http2-nodeServer/newpush.json', {
                response: {
                  'content-type': contentType
                }    
        });
        pushItem.end(fs.readFileSync('/Users/f.li/Desktop/http2-nodeServer/newpush.json','binary'),()=>{
          console.log('newpush end')
        });

        response.end();
 
    } else {
      response.writeHead(404, {
          'Content-Type': 'text/plain'
      });

      response.write("This request URL " + realPath + " was not found on this server.");
      response.end();
    }
 
});
 
server.listen(3000, function() {
  console.log('listen on 3000');
});
```
这里需要注意几点：
- 创建http2的nodejs服务必须时基于https的，因为现在主流的浏览器都要支持SSL/TLS的http2，证书和私钥可以自己通过[OPENSSL](https://www.openssl.org/)生成。
- node http2的相关api和正常的node httpserver相同，可以直接使用。

使用 nghttp 测试一下我们的代码有没有进行 server push：
```
~ nghttp -nv 'https://localhost:3000/'
[  0.007] Connected
The negotiated protocol: h2
[  0.029] recv SETTINGS frame <length=0, flags=0x00, stream_id=0>
          (niv=0)
[  0.029] send SETTINGS frame <length=12, flags=0x00, stream_id=0>
          (niv=2)
          [SETTINGS_MAX_CONCURRENT_STREAMS(0x03):100]
          [SETTINGS_INITIAL_WINDOW_SIZE(0x04):65535]
[  0.029] send SETTINGS frame <length=0, flags=0x01, stream_id=0>
          ; ACK
          (niv=0)
[  0.029] send PRIORITY frame <length=5, flags=0x00, stream_id=3>
          (dep_stream_id=0, weight=201, exclusive=0)
[  0.029] send PRIORITY frame <length=5, flags=0x00, stream_id=5>
          (dep_stream_id=0, weight=101, exclusive=0)
[  0.029] send PRIORITY frame <length=5, flags=0x00, stream_id=7>
          (dep_stream_id=0, weight=1, exclusive=0)
[  0.029] send PRIORITY frame <length=5, flags=0x00, stream_id=9>
          (dep_stream_id=7, weight=1, exclusive=0)
[  0.029] send PRIORITY frame <length=5, flags=0x00, stream_id=11>
          (dep_stream_id=3, weight=1, exclusive=0)
[  0.029] send HEADERS frame <length=38, flags=0x25, stream_id=13>
          ; END_STREAM | END_HEADERS | PRIORITY
          (padlen=0, dep_stream_id=11, weight=16, exclusive=0)
          ; Open new stream
          :method: GET
          :path: /
          :scheme: https
          :authority: localhost:3000
          accept: */*
          accept-encoding: gzip, deflate
          user-agent: nghttp2/1.21.1
[  0.043] recv SETTINGS frame <length=0, flags=0x01, stream_id=0>
          ; ACK
          (niv=0)
[  0.049] recv (stream_id=13) :status: 200
[  0.049] recv (stream_id=13) content-type: text/plain
[  0.049] recv (stream_id=13) date: Tue, 11 Apr 2017 08:34:46 GMT
[  0.049] recv HEADERS frame <length=34, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0)
          ; First response header
[  0.049] recv DATA frame <length=35, flags=0x00, stream_id=13>
[  0.049] recv (stream_id=13) :method: GET
[  0.049] recv (stream_id=13) :scheme: https
[  0.050] recv (stream_id=13) :authority: localhost:3000
[  0.050] recv (stream_id=13) :path: /Users/f.li/Desktop/http2-nodeServer/newpush.json
[  0.050] recv PUSH_PROMISE frame <length=56, flags=0x04, stream_id=13>
          ; END_HEADERS
          (padlen=0, promised_stream_id=2)
[  0.050] recv DATA frame <length=0, flags=0x01, stream_id=13>
          ; END_STREAM
[  0.050] recv (stream_id=2) :status: 200
[  0.050] recv (stream_id=2) date: Tue, 11 Apr 2017 08:34:46 GMT
[  0.050] recv HEADERS frame <length=2, flags=0x04, stream_id=2>
          ; END_HEADERS
          (padlen=0)
          ; First push response header
[  0.050] recv DATA frame <length=21, flags=0x00, stream_id=2>
[  0.050] recv DATA frame <length=0, flags=0x01, stream_id=2>
          ; END_STREAM
[  0.050] send GOAWAY frame <length=8, flags=0x00, stream_id=0>
          (last_stream_id=2, error_code=NO_ERROR(0x00), opaque_data(0)=[])
```

看到了 PUSH_PROMISE 的帧，说明进行了 server push。

同样也可以使用chrome查看 server push，如下图所示：
![chrome 查看 http2 server push](http://7xraw1.com1.z0.glb.clouddn.com/20170411149190121682527.png)

服务端介绍基本完毕。下面我们来介绍一些 iOS 客户端对 Server Push 的使用。

## iOS 使用 HTTP/2 Server Push
Apple 在这方面做的很好，基本实现了客户端无感调用http/2 server push。但是笔者查看了些许资料，现在只有iOS 10 支持 http/2。

直接上代码吧：
```
#import "ViewController.h"

@interface ViewController ()<NSURLSessionDelegate>

@property(nonatomic,strong)NSURLSession *session;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}
#pragma mark - Touch
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self urlSession];
}
#pragma mark - 发送请求
- (void)urlSession
{
    NSURL *url = [NSURL URLWithString:@"https://localhost:3000"];
    
    //发送HTTPS请求是需要对网络会话设置代理的
    _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        // 收到该次请求后，立即请求下次的内容
        [self urlSessionPush];
        
    }];
    
    [dataTask resume];
}

- (void)urlSessionPush
{
    NSURL *url = [NSURL URLWithString:@"https://localhost:3000/Users/f.li/Desktop/http2-nodeServer/newpush.json"];
    NSURLSessionDataTask *dataTask = [_session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        NSLog(@"%@",[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
    }];
    [dataTask resume];
}

#pragma mark - URLSession Delegate
- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    // 这里还要设置下 plist 中设置 ATS
    if (![challenge.protectionSpace.authenticationMethod isEqualToString:@"NSURLAuthenticationMethodServerTrust"])
    {
        return;
    }
    NSURLCredential *credential = [[NSURLCredential alloc] initWithTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
}


- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics
{
    NSArray *fetchTypes = @[ @"Unknown", @"Network Load", @"Server Push", @"Local Cache"];
    
    for(NSURLSessionTaskTransactionMetrics *transactionMetrics in [metrics transactionMetrics])
    {
        
        NSLog(@"protocol[%@] reuse[%d] fetch:%@ - %@", [transactionMetrics networkProtocolName], [transactionMetrics isReusedConnection], fetchTypes[[transactionMetrics resourceFetchType]], [[transactionMetrics request] URL]);
        
        if([transactionMetrics resourceFetchType] == NSURLSessionTaskMetricsResourceFetchTypeServerPush)
        {
            NSLog(@"Asset was server pushed");
        }
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

```

分别看下服务端和客户端的Log:
客户端：
```
Http2ServerPush[2525:274943] protocol[h2] reuse[0] fetch:Network Load - https://localhost:3000/
Http2ServerPush[2525:274943] {"message":" http2.0 server is ok"}
Http2ServerPush[2525:274943] protocol[h2] reuse[1] fetch:Server Push - https://localhost:3000/Users/f.li/Desktop/http2-nodeServer/newpush.json
Http2ServerPush[2525:274943] Asset was server pushed
Http2ServerPush[2525:274943] {"message":"newPush"}
```

服务端：
```
http2-nodeServer npm start

> http2-nodeServer@1.0.0 start /Users/f.li/Desktop/http2-nodeServer
> node index.js

listen on 3000
success
newpush end
```
看来确实是客户端发出了两次请求，但是服务端只响应了一次（该次响应+ server push）

# 本文相关Demo
- [Github:lijianfeigeek](https://github.com/lijianfeigeek/iOS-HTTP-2-Server-Push)

# 参考文献
- [HTTP2 Server Push的研究 | AlloyTeam](http://www.alloyteam.com/2017/01/http2-server-push-research/)
- [使用 nghttp2 调试 HTTP/2 流量 | JerryQu 的小站](https://imququ.com/post/intro-to-nghttp2.html)
- [objective c - HTTP/2 Server Push in iOS 10 - Stack Overflow](http://stackoverflow.com/questions/40755758/http-2-server-push-in-ios-10)
- [使用NSURLSession或者AFN发送HTTPS请求 - 简书](http://www.jianshu.com/p/d833ac6fa5ab)
