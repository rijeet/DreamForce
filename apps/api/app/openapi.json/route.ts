import { NextResponse } from 'next/server';

import { createOpenApiDocument } from '../../src/interfaces/openapi';

export const runtime = 'nodejs';

export function GET() {
  return NextResponse.json(createOpenApiDocument());
}
