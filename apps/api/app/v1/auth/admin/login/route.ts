import { adminSignInSchema, sessionTokenResponseSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { signInAdmin } from '../../../../../src/application/auth/auth-service';
import { parseJson, problemResponse } from '../../../../../src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const input = await parseJson(request, adminSignInSchema);
    return NextResponse.json(sessionTokenResponseSchema.parse(await signInAdmin(input.email, input.password)));
  } catch (error) {
    return problemResponse(error);
  }
}
