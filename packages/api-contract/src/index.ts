import { z } from "zod";

export const healthResponseSchema = z.object({
  status: z.literal("ok"),
  service: z.literal("dream-force-api"),
});

export type HealthResponse = z.infer<typeof healthResponseSchema>;

export const googleAuthorizationCodeSchema = z.object({
  authorizationCode: z.string().min(1).max(4096),
  codeVerifier: z.string().min(43).max(128),
});

export const googleIdTokenSchema = z.object({
  idToken: z.string().min(20).max(8192),
});

// Android sends a Google-issued ID token. Keep the PKCE variant for clients
// that use an authorization-code flow.
export const googleSignInSchema = z.union([
  googleAuthorizationCodeSchema,
  googleIdTokenSchema,
]);

export const adminSignInSchema = z.object({
  email: z.string().email().max(320),
  password: z.string().min(12).max(256),
});

export const refreshSessionSchema = z.object({
  refreshToken: z.string().min(32).max(512),
});

export const sessionTokenResponseSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  expiresIn: z.number().int().positive(),
});

export type GoogleSignIn = z.infer<typeof googleSignInSchema>;
export type AdminSignIn = z.infer<typeof adminSignInSchema>;

export const uuidSchema = z.string().uuid();
export const timezoneSchema = z.string().min(1).max(64);

export const updateProfileSchema = z.object({
  displayName: z.string().trim().min(1).max(80).nullable().optional(),
  avatarUrl: z.string().url().max(2048).nullable().optional(),
  gender: z.string().trim().max(80).nullable().optional(),
  dateOfBirth: z.string().date().nullable().optional(),
  country: z.string().trim().max(100).nullable().optional(),
  city: z.string().trim().max(100).nullable().optional(),
  profession: z.string().trim().max(120).nullable().optional(),
  timezone: timezoneSchema.optional(),
  locale: z.string().trim().min(2).max(35).optional(),
});

export const updateSettingsSchema = z.object({
  themePreference: z.enum(['system', 'light', 'dark']).optional(),
  phaseNotificationsEnabled: z.boolean().optional(),
  soundEnabled: z.boolean().optional(),
  hapticsEnabled: z.boolean().optional(),
  analyticsAppUsageOptIn: z.boolean().optional(),
  weekStartsOn: z.number().int().min(1).max(7).optional(),
});

export const activityTemplateSchema = z.object({
  name: z.string().trim().min(1).max(80),
  iconKey: z.string().trim().min(1).max(40),
  category: z.string().trim().max(40).nullable().optional(),
  plannedMinutes: z.number().int().min(1).max(480),
});
export const patchActivityTemplateSchema = activityTemplateSchema.partial().extend({ version: z.number().int().positive() });

export const createSessionSchema = z.object({
  templateId: uuidSchema.nullable().optional(),
  planOccurrenceId: uuidSchema.nullable().optional(),
  name: z.string().trim().min(1).max(80),
  iconKey: z.string().trim().min(1).max(40),
  category: z.string().trim().max(40).nullable().optional(),
  plannedMinutes: z.number().int().min(1).max(480),
  timezone: timezoneSchema,
});
export const sessionEventSchema = z.object({
  clientEventId: uuidSchema,
  eventType: z.enum(['pause', 'resume', 'cancel']),
  expectedVersion: z.number().int().positive(),
  clientOccurredAt: z.string().datetime().optional(),
});

export const weeklyPlanEntrySchema = z.object({
  templateId: uuidSchema,
  weekday: z.number().int().min(1).max(7),
  position: z.number().int().min(0),
  localStartTime: z.string().regex(/^\d{2}:\d{2}(:\d{2})?$/).nullable().optional(),
  plannedMinutesOverride: z.number().int().min(1).max(480).nullable().optional(),
});
export const weeklyPlanSchema = z.object({
  name: z.string().trim().min(1).max(80),
  timezone: timezoneSchema,
  entries: z.array(weeklyPlanEntrySchema).max(70),
});

export const dailyReviewSchema = z.object({
  timezone: timezoneSchema,
  mood: z.enum(['positive', 'mixed', 'difficult']).nullable().optional(),
  summary: z.string().max(1000).nullable().optional(),
  reflection: z.string().max(5000).nullable().optional(),
  reasonTags: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  version: z.number().int().positive().optional(),
});
