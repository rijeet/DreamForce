import { NextResponse } from 'next/server';

import { cancelAccountDeletion } from '@/src/application/account/account-deletion';
import { problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    await cancelAccountDeletion(user.userId);
    return new NextResponse(null, { status: 204 });
  } catch (error) {
    return problemResponse(error);
  }
}
