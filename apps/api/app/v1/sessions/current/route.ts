import { NextResponse } from 'next/server';

import { getCurrentFocusSession } from '@/src/application/mvp/mvp-service';
import { problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    return NextResponse.json(await getCurrentFocusSession(user.userId));
  } catch (error) {
    return problemResponse(error);
  }
}
