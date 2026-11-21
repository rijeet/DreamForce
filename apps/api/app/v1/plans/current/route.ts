import { NextResponse } from 'next/server';

import { getCurrentPlanDay } from '@/src/application/mvp/mvp-service';
import { HttpProblem, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    const localDate = new URL(request.url).searchParams.get('localDate');
    if (!localDate || !/^\d{4}-\d{2}-\d{2}$/.test(localDate)) {
      throw new HttpProblem(400, 'INVALID_LOCAL_DATE');
    }
    return NextResponse.json(await getCurrentPlanDay(user.userId, localDate));
  } catch (error) {
    return problemResponse(error);
  }
}
