import { screenTimePeriodSchema, screenTimeUploadSchema, timezoneSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { getScreenTimeInsights, uploadScreenTimeUsage } from '@/src/application/mvp/mvp-service';
import { HttpProblem, parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';

export async function GET(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    const params = new URL(request.url).searchParams;
    const parsedPeriod = screenTimePeriodSchema.safeParse(params.get('period') ?? 'week');
    const parsedTimezone = timezoneSchema.safeParse(params.get('timezone') ?? 'UTC');
    if (!parsedPeriod.success || !parsedTimezone.success) throw new HttpProblem(400, 'INVALID_SCREEN_TIME_RANGE');
    return NextResponse.json(await getScreenTimeInsights(user.userId, parsedPeriod.data, parsedTimezone.data));
  } catch (error) {
    return problemResponse(error);
  }
}

export async function PUT(request: Request) {
  try {
    const user = await requireAuthenticatedUser(request);
    const input = await parseJson(request, screenTimeUploadSchema);
    return NextResponse.json(await uploadScreenTimeUsage(user.userId, input));
  } catch (error) {
    return problemResponse(error);
  }
}
