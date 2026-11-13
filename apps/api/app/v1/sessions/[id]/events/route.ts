import { sessionEventSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { submitSessionEvent } from '@/src/APP.API/composition-root';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };
export async function POST(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { id } = await params; return NextResponse.json(await submitSessionEvent(user.userId, id, await parseJson(request, sessionEventSchema))); } catch (error) { return problemResponse(error); } }
