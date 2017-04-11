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