import { weeklyPlanSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { createPlan, listPlans } from '@/src/APP.API/composition-root';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
export async function GET(request: Request) { try { const user = await requireAuthenticatedUser(request); return NextResponse.json(await listPlans(user.userId)); } catch (error) { return problemResponse(error); } }
export async function POST(request: Request) { try { const user = await requireAuthenticatedUser(request); return NextResponse.json(await createPlan(user.userId, await parseJson(request, weeklyPlanSchema)), { status: 201 }); } catch (error) { return problemResponse(error); } }
