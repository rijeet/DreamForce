import { dailyReviewSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { getDailyReview, upsertDailyReview } from '@/src/application/mvp/mvp-service';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
type Context = { params: Promise<{ localDate: string }> };
export async function GET(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { localDate } = await params; return NextResponse.json(await getDailyReview(user.userId, localDate)); } catch (error) { return problemResponse(error); } }
export async function PUT(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { localDate } = await params; return NextResponse.json(await upsertDailyReview(user.userId, localDate, await parseJson(request, dailyReviewSchema))); } catch (error) { return problemResponse(error); } }
