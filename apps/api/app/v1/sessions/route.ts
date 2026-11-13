import { createSessionSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { createFocusSession } from '@/src/application/mvp/mvp-service';
import { HttpProblem, parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
export async function POST(request: Request) { try { const user = await requireAuthenticatedUser(request); if (!request.headers.get('idempotency-key')) throw new HttpProblem(400, 'IDEMPOTENCY_KEY_REQUIRED'); return NextResponse.json(await createFocusSession(user.userId, await parseJson(request, createSessionSchema)), { status: 201 }); } catch (error) { return problemResponse(error); } }
