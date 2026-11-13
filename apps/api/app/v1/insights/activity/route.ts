import { NextResponse } from 'next/server';

import { getActivityInsights } from '@/src/application/mvp/mvp-service';
import { HttpProblem, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    const period = new URL(request.url).searchParams.get('period') ?? 'week';
    if (period !== 'day' && period !== 'week' && period !== 'month' && period !== 'year') {
      throw new HttpProblem(400, 'INVALID_INSIGHTS_PERIOD');
    }
    return NextResponse.json(await getActivityInsights(user.userId, period));
  } catch (error) {
    return problemResponse(error);
  }
}
