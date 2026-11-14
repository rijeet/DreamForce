import { skipPlanOccurrenceSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { skipPlanOccurrence } from '@/src/application/mvp/mvp-service';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };

export async function PATCH(request: Request, { params }: Context) {
  try {
    const user = await requireAuthenticatedUser(request);
    const { id } = await params;
    const input = await parseJson(request, skipPlanOccurrenceSchema);
    if (input.state === 'skipped') await skipPlanOccurrence(user.userId, id);
    return NextResponse.json({ id, state: input.state });
  } catch (error) {
    return problemResponse(error);
  }
}
