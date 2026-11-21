import { NextResponse } from 'next/server';

import { finalizeDueAccountDeletion } from '@/src/application/account/account-deletion';
import { createQStashReceiver } from '@/src/infrastructure/jobs/qstash';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  const body = await request.text();
  const signature = request.headers.get('upstash-signature');
  if (!signature) return new NextResponse(null, { status: 401 });
  try {
    await createQStashReceiver().verify({ signature, body });
  } catch {
    return new NextResponse(null, { status: 401 });
  }
  let userId = '';
  try {
    const payload = JSON.parse(body) as { userId?: unknown };
    if (typeof payload.userId === 'string') userId = payload.userId;
  } catch {
    return new NextResponse(null, { status: 400 });
  }
  if (!userId) return new NextResponse(null, { status: 400 });
  await finalizeDueAccountDeletion(userId);
  return NextResponse.json({ ok: true });
}
