import { NextResponse } from 'next/server';

import { updateWeeklyPlanSchema } from '@dream-force/api-contract';
import { getPlan, updatePlan } from '@/src/application/mvp/mvp-service';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };
export async function GET(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { id } = await params; return NextResponse.json(await getPlan(user.userId, id)); } catch (error) { return problemResponse(error); } }
export async function PUT(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { id } = await params; return NextResponse.json(await updatePlan(user.userId, id, await parseJson(request, updateWeeklyPlanSchema))); } catch (error) { return problemResponse(error); } }
