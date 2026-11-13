import { ZodError, z } from 'zod';
import { NextResponse } from 'next/server';

import { AuthenticationError, authenticateAccessToken } from '../../application/auth/auth-service';

function describeValidationIssues(error: ZodError) {
  const output: Array<{ field: string; message: string }> = [];
  const visit = (issues: ZodError['issues']) => {
    for (const issue of issues) {
      if (issue.code === 'invalid_union') {
        for (const alternative of issue.unionErrors) visit(alternative.issues);
      } else {
        output.push({ field: issue.path.join('.') || '(body)', message: issue.message });
      }
    }
  };
  visit(error.issues);
  return output;
}

export async function parseJson(request: Request, schema: z.ZodType) {
  try {
    return schema.parse(await request.json());
  } catch (error) {
    if (error instanceof ZodError || error instanceof SyntaxError) {
      const issues = error instanceof ZodError
        ? describeValidationIssues(error)
        : [{ field: '(body)', message: 'Request body must be valid JSON.' }];
      throw new HttpProblem(400, 'INVALID_REQUEST', issues);
    }
    throw error;
  }
}

export async function requireAuthenticatedUser(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization?.startsWith('Bearer ')) throw new HttpProblem(401, 'ACCESS_TOKEN_MISSING');
  try {
    return await authenticateAccessToken(authorization.slice('Bearer '.length));
  } catch (error) {
    if (error instanceof AuthenticationError) throw new HttpProblem(401, error.code);
    throw error;
  }
}

export async function requireAdmin(request: Request) {
  const identity = await requireAuthenticatedUser(request);
  if (identity.role !== 'admin') throw new HttpProblem(403, 'ADMIN_ROLE_REQUIRED');
  return identity;
}

export function problemResponse(error: unknown) {
  if (error instanceof HttpProblem) return error.response();
  if (error instanceof AuthenticationError) return new HttpProblem(401, error.code).response();
  if (error instanceof ZodError) {
    const issues = describeValidationIssues(error);
    return new HttpProblem(500, 'INVALID_API_RESPONSE', issues).response();
  }
  console.error('Unhandled API error', error);
  return new HttpProblem(500, 'INTERNAL_ERROR').response();
}

export class HttpProblem extends Error {
  constructor(readonly status: number, readonly code: string, readonly issues?: Array<{field: string; message: string}>) {
    super(code);
  }

  response() {
    return NextResponse.json(
      { type: `https://dreamforce.app/problems/${this.code.toLowerCase()}`, title: this.code, status: this.status, code: this.code, ...(this.issues ? { issues: this.issues } : {}) },
      { status: this.status, headers: { 'content-type': 'application/problem+json' } },
    );
  }
}
