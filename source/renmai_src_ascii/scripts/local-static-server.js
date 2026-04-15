const http = require('http');
const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '..');
const port = Number(process.env.RENMAI_LOCAL_PORT || 8788);

const mimeTypes = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
};

function send(response, statusCode, body, contentType) {
  response.writeHead(statusCode, {
    'Content-Type': contentType,
    'Cache-Control': 'no-store',
  });
  response.end(body);
}

function safeResolve(urlPath) {
  const pathname = decodeURIComponent(String(urlPath || '/').split('?')[0]);
  const normalized = pathname === '/' ? '/index.html' : pathname;
  const filePath = path.resolve(rootDir, `.${normalized}`);
  return filePath.startsWith(rootDir) ? filePath : null;
}

const server = http.createServer((request, response) => {
  const filePath = safeResolve(request.url);
  if (!filePath) {
    send(response, 403, 'Forbidden', 'text/plain; charset=utf-8');
    return;
  }

  fs.readFile(filePath, (error, buffer) => {
    if (error) {
      if (error.code === 'ENOENT') {
        send(response, 404, 'Not Found', 'text/plain; charset=utf-8');
        return;
      }
      send(response, 500, 'Server Error', 'text/plain; charset=utf-8');
      return;
    }

    const extension = path.extname(filePath).toLowerCase();
    send(response, 200, buffer, mimeTypes[extension] || 'application/octet-stream');
  });
});

server.listen(port, '127.0.0.1', () => {
  console.log(`Renmai local static server running at http://127.0.0.1:${port}/index.html`);
});
