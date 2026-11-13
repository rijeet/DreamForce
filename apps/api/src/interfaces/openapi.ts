import { OpenAPIRegistry, OpenApiGeneratorV31, extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';
import { activityTemplateSchema, adminSignInSchema, createSessionSchema, dailyReviewSchema, googleSignInSchema, healthResponseSchema, refreshSessionSchema, sessionEventSchema, sessionTokenResponseSchema, updateProfileSchema, weeklyPlanSchema } from '@dream-force/api-contract';
import { z } from 'zod';

extendZodWithOpenApi(z);

const registry = new OpenAPIRegistry();
registry.registerComponent('securitySchemes', 'bearerAuth', {
  type: 'http',
  scheme: 'bearer',
  bearerFormat: 'JWT',
});
const problemSchema = z.object({
  type: z.string().url(),
  title: z.string(),
  status: z.number().int(),
  code: z.string(),
});

registry.registerPath({
  method: 'get',
  path: '/v1/health',
  tags: ['System'],
  responses: { 200: { description: 'API is available', content: { 'application/json': { schema: healthResponseSchema } } } },
});

registry.registerPath({ method: 'get', path: '/v1/ready', tags: ['System'], description: 'Checks required runtime dependencies: Neon PostgreSQL and Upstash Redis.', responses: { 200: { description: 'Neon and Upstash Redis are available' }, 503: { description: 'A required dependency is unavailable' } } });

const bearerSecurity = [{ bearerAuth: [] }];
const mvpPaths = [
  ['get', '/v1/me', undefined, 'Read current profile and settings.', 'Profile & Settings'],
  ['patch', '/v1/me', z.object({ profile: updateProfileSchema.optional(), settings: z.object({}).passthrough().optional() }), 'Update current profile or settings.', 'Profile & Settings'],
  ['get', '/v1/activity-templates', undefined, 'List own and built-in activities.', 'Activities'],
  ['post', '/v1/activity-templates', activityTemplateSchema, 'Create an activity template.', 'Activities'],
  ['post', '/v1/sessions', createSessionSchema, 'Create an automatic focus/rest session. Requires Idempotency-Key.', 'Focus Sessions'],
  ['get', '/v1/plans', undefined, 'List weekly plans.', 'Weekly Plans'],
  ['post', '/v1/plans', weeklyPlanSchema, 'Create a weekly plan.', 'Weekly Plans'],
] as const;
for (const [method, path, requestSchema, description, tag] of mvpPaths) {
  registry.registerPath({
    method,
    path,
    description,
    tags: [tag],
    security: bearerSecurity,
    request: requestSchema ? { body: { content: { 'application/json': { schema: requestSchema } } } } : undefined,
    responses: { 200: { description: 'Success' }, 201: { description: 'Created' }, 400: { description: 'Invalid request' }, 401: { description: 'Access token required' } },
  });
}
registry.registerPath({ method: 'get', path: '/v1/sessions/{id}', tags: ['Focus Sessions'], security: bearerSecurity, request: { params: z.object({ id: z.string().uuid() }) }, responses: { 200: { description: 'Session snapshot' }, 404: { description: 'Session not found' } } });
registry.registerPath({ method: 'post', path: '/v1/sessions/{id}/events', tags: ['Focus Sessions'], security: bearerSecurity, request: { params: z.object({ id: z.string().uuid() }), body: { content: { 'application/json': { schema: sessionEventSchema } } } }, responses: { 200: { description: 'Updated session snapshot' }, 409: { description: 'Invalid state transition' }, 412: { description: 'Stale session version' } } });
registry.registerPath({ method: 'get', path: '/v1/plans/{id}', tags: ['Weekly Plans'], security: bearerSecurity, request: { params: z.object({ id: z.string().uuid() }) }, responses: { 200: { description: 'Plan and entries' }, 404: { description: 'Plan not found' } } });
registry.registerPath({ method: 'get', path: '/v1/daily-reviews/{localDate}', tags: ['Daily Reviews'], security: bearerSecurity, request: { params: z.object({ localDate: z.string().date() }) }, responses: { 200: { description: 'Review or null' } } });
registry.registerPath({ method: 'put', path: '/v1/daily-reviews/{localDate}', tags: ['Daily Reviews'], security: bearerSecurity, request: { params: z.object({ localDate: z.string().date() }), body: { content: { 'application/json': { schema: dailyReviewSchema } } } }, responses: { 200: { description: 'Saved review' }, 412: { description: 'Stale review version' } } });

for (const [path, requestSchema, description] of [
  ['/v1/auth/google', googleSignInSchema, 'Verify an Android Google ID token or exchange a PKCE authorization code.'],
  ['/v1/auth/admin/login', adminSignInSchema, 'Authenticate a script-provisioned admin.'],
  ['/v1/auth/refresh', refreshSessionSchema, 'Rotate an opaque refresh token.'],
] as const) {
  registry.registerPath({
    method: 'post',
    path,
    description,
    tags: ['Authentication'],
    request: { body: { content: { 'application/json': { schema: requestSchema } } } },
    responses: {
      200: { description: 'Session tokens', content: { 'application/json': { schema: sessionTokenResponseSchema } } },
      201: { description: 'New session tokens', content: { 'application/json': { schema: sessionTokenResponseSchema } } },
      400: { description: 'Invalid request', content: { 'application/problem+json': { schema: problemSchema } } },
      401: { description: 'Authentication failed', content: { 'application/problem+json': { schema: problemSchema } } },
    },
  });
}

registry.registerPath({
  method: 'post',
  path: '/v1/auth/logout',
  tags: ['Authentication'],
  request: { body: { content: { 'application/json': { schema: refreshSessionSchema } } } },
  responses: { 204: { description: 'Refresh session revoked' } },
});

registry.registerPath({
  method: 'get',
  path: '/v1/admin/health',
  tags: ['Administration'],
  security: [{ bearerAuth: [] }],
  responses: {
    200: { description: 'Admin route is available' },
    401: { description: 'Missing or invalid access token' },
    403: { description: 'Admin role required' },
  },
});

export function createOpenApiDocument() {
  return new OpenApiGeneratorV31(registry.definitions).generateDocument({
    openapi: '3.1.0',
    info: { title: 'Dream Force API', version: '0.1.0', description: 'Android MVP serverless API.' },
    servers: [{ url: '/', description: 'Current deployment' }],
  });
}
