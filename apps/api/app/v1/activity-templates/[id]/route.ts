import { patchActivityTemplateSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { archiveActivity, patchActivity } from '@/src/application/mvp/mvp-service';
import { parseJson, problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
type Context = { params: Promise<{ id: string }> };
export async function PATCH(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { id } = await params; return NextResponse.json(await patchActivity(user.userId, id, await parseJson(request, patchActivityTemplateSchema))); } catch (error) { return problemResponse(error); } }
export async function DELETE(request: Request, { params }: Context) { try { const user = await requireAuthenticatedUser(request); const { id } = await params; await archiveActivity(user.userId, id); return new NextResponse(null, { status: 204 }); } catch (error) { return problemResponse(error); } }
