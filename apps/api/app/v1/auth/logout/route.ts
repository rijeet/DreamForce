import { refreshSessionSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { revokeRefreshToken } from '../../../../src/application/auth/auth-service';
import { parseJson, problemResponse } from '../../../../src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const { refreshToken } = await parseJson(request, refreshSessionSchema);
    await revokeRefreshToken(refreshToken);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    return problemResponse(error);
  }
}
