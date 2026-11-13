import { NextResponse } from 'next/server';

import { problemResponse, requireAdmin } from '../../../../src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const admin = await requireAdmin(request);
    return NextResponse.json({ status: 'ok', role: admin.role });
  } catch (error) {
    return problemResponse(error);
  }
}
