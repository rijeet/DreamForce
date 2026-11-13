import { activityTemplateSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { createActivity, listActivities } from '@/src/application/mvp/mvp-service';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
export async function GET(request: Request) { try { const user = await requireAuthenticatedUser(request); return NextResponse.json(await listActivities(user.userId)); } catch (error) { return problemResponse(error); } }
export async function POST(request: Request) { try { const user = await requireAuthenticatedUser(request); return NextResponse.json(await createActivity(user.userId, await parseJson(request, activityTemplateSchema)), { status: 201 }); } catch (error) { return problemResponse(error); } }
