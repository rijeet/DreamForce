import { updateProfileSchema, updateSettingsSchema } from '@dream-force/api-contract';
import { NextResponse } from 'next/server';

import { requestAccountDeletion } from '@/src/application/account/account-deletion';
import { getProfile, updateProfile, updateSettings } from '@/src/application/mvp/mvp-service';
import { problemResponse, requireAuthenticatedUser } from '@/src/interfaces/http/auth';

export const runtime = 'nodejs';
export async function GET(request: Request) { try { const user = await requireAuthenticatedUser(request); return NextResponse.json(await getProfile(user.userId)); } catch (error) { return problemResponse(error); } }
export async function PATCH(request: Request) { try { const user = await requireAuthenticatedUser(request); const body = await request.json(); const profile = updateProfileSchema.parse(body.profile ?? {}); const settings = updateSettingsSchema.parse(body.settings ?? {}); if (Object.keys(profile).length) await updateProfile(user.userId, profile); if (Object.keys(settings).length) await updateSettings(user.userId, settings); return NextResponse.json(await getProfile(user.userId)); } catch (error) { return problemResponse(error); } }
export async function DELETE(request: Request) { try { const user = await requireAuthenticatedUser(request); return NextResponse.json(await requestAccountDeletion(user.userId), { status: 202 }); } catch (error) { return problemResponse(error); } }
