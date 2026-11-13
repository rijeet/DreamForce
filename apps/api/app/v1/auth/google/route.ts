import { googleSignInSchema, sessionTokenResponseSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { exchangeGoogleAuthorizationCode, signInWithGoogleIdToken } from '../../../../src/application/auth/auth-service';
import { parseJson, problemResponse } from '../../../../src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const input = await parseJson(request, googleSignInSchema);
    const tokens = 'idToken' in input
      ? await signInWithGoogleIdToken(input.idToken, input.timezone)
      : await exchangeGoogleAuthorizationCode(input);
    return NextResponse.json(sessionTokenResponseSchema.parse(tokens), { status: 201 });
  } catch (error) {
    return problemResponse(error);
  }
}
