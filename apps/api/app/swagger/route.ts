import { NextResponse } from 'next/server';

export const runtime = 'nodejs';

export function GET() {
  return new NextResponse(`<!doctype html><html><head><meta charset="utf-8"><title>Dream Force API</title><link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css"></head><body><div id="swagger-ui"></div><script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script><script>SwaggerUIBundle({url:'/openapi.json',dom_id:'#swagger-ui',persistAuthorization:true});</script></body></html>`, {
    headers: { 'content-type': 'text/html; charset=utf-8' },
  });
}
