import { refreshSessionSchema, sessionTokenResponseSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { rotateRefreshToken } from '../../../../src/application/auth/auth-service';
import { parseJson, problemResponse } from '../../../../src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const { refreshToken } = await parseJson(request, refreshSessionSchema);
    return NextResponse.json(sessionTokenResponseSchema.parse(await rotateRefreshToken(refreshToken)));
  } catch (error) {
    return problemResponse(error);
  }
}
