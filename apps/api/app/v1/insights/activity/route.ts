import { NextResponse } from 'next/server';

import { getActivityInsights } from '@/src/application/mvp/mvp-service';
import { readServerEnvironment } from '@/src/infrastructure/env';
import { HttpProblem, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    const params = new URL(request.url).searchParams;
    const period = params.get('period') ?? 'week';
    const yearValue = params.get('year');
    const year = yearValue === null ? undefined : Number(yearValue);
    if (period !== 'day' && period !== 'week' && period !== 'month' && period !== 'year') {
      throw new HttpProblem(400, 'INVALID_INSIGHTS_PERIOD');
    }
    if (yearValue !== null && (!Number.isInteger(year) || year! < 2000 || year! > 2100)) {
      throw new HttpProblem(400, 'INVALID_INSIGHTS_YEAR');
    }
    return NextResponse.json({
      ...await getActivityInsights(user.userId, period, year),
      earliestYear: readServerEnvironment().INSIGHTS_HEATMAP_EARLIEST_YEAR,
    });
  } catch (error) {
    return problemResponse(error);
  }
}
