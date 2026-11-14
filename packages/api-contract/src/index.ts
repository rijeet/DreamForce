import { z } from "zod";

export const healthResponseSchema = z.object({
  status: z.literal("ok"),
  service: z.literal("dream-force-api"),
});

export type HealthResponse = z.infer<typeof healthResponseSchema>;
export const CURRENT_TERMS_VERSION = 'terms-v1-2026-11-14';
export const SCREEN_TIME_CONSENT_VERSION = 'screen-time-sync-v1';

export const timezoneSchema = z.string().min(1).max(64).refine((timezone) => {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: timezone });
    return true;
  } catch {
    return false;
  }
}, 'Must be a valid IANA time zone');

export const googleAuthorizationCodeSchema = z.object({
  authorizationCode: z.string().min(1).max(4096),
  codeVerifier: z.string().min(43).max(128),
  termsAcceptedVersion: z.literal(CURRENT_TERMS_VERSION),
  screenTimeConsentVersion: z.literal(SCREEN_TIME_CONSENT_VERSION).optional(),
  timezone: timezoneSchema.optional(),
});

export const googleIdTokenSchema = z.object({
  idToken: z.string().min(20).max(8192),
  timezone: timezoneSchema.optional(),
  termsAcceptedVersion: z.literal(CURRENT_TERMS_VERSION),
  screenTimeConsentVersion: z.literal(SCREEN_TIME_CONSENT_VERSION).optional(),
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
  screenTimeSyncEnabled: z.boolean().optional(),
  screenTimeConsentVersion: z.literal(SCREEN_TIME_CONSENT_VERSION).optional(),
}).refine(
  (settings) => settings.screenTimeSyncEnabled !== true || Boolean(settings.screenTimeConsentVersion),
  { path: ['screenTimeConsentVersion'], message: 'A consent version is required to enable screen-time sync.' },
);

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
export const updateWeeklyPlanSchema = weeklyPlanSchema.extend({
  version: z.number().int().positive(),
});

export const skipPlanOccurrenceSchema = z.object({
  state: z.literal('skipped'),
});

export const dailyReviewSchema = z.object({
  timezone: timezoneSchema,
  mood: z.enum(['positive', 'mixed', 'difficult']).nullable().optional(),
  summary: z.string().max(1000).nullable().optional(),
  reflection: z.string().max(5000).nullable().optional(),
  reasonTags: z.array(z.string().trim().min(1).max(80)).max(20).optional(),
  version: z.number().int().positive().optional(),
});

export const screenTimeUsageRowSchema = z.object({
  localDate: z.string().date(),
  timezoneId: timezoneSchema,
  packageName: z.string().trim().min(1).max(255),
  appLabel: z.string().trim().min(1).max(160),
  usageSeconds: z.number().int().min(0).max(86400),
});
export const screenTimeUploadSchema = z.object({
  queriedAt: z.string().datetime(),
  rows: z.array(screenTimeUsageRowSchema).min(1).max(20000),
}).refine(({ rows }) => {
  const keys = rows.map((row) => `${row.localDate}|${row.timezoneId}|${row.packageName}`);
  return new Set(keys).size === keys.length;
}, { path: ['rows'], message: 'Each app may appear once per local date and timezone.' });
export const screenTimePeriodSchema = z.enum(['day', 'week', 'month', 'year']);

export const activityInsightDaySchema = z.object({
  date: z.string().date(),
  focusSeconds: z.number().int().nonnegative(),
  completedSessions: z.number().int().nonnegative(),
});

export const activityInsightCategorySchema = z.object({
  name: z.string().min(1),
  focusSeconds: z.number().int().nonnegative(),
  completedSessions: z.number().int().nonnegative(),
});

export const activityInsightsResponseSchema = z.object({
  period: screenTimePeriodSchema,
  timezone: timezoneSchema,
  year: z.number().int().nullable(),
  earliestYear: z.number().int(),
  totalFocusSeconds: z.number().int().nonnegative(),
  completedSessions: z.number().int().nonnegative(),
  days: z.array(activityInsightDaySchema),
  categories: z.array(activityInsightCategorySchema),
});

export const screenTimeInsightDaySchema = z.object({
  date: z.string().date(),
  usageSeconds: z.number().int().nonnegative(),
});

export const screenTimeInsightsResponseSchema = z.object({
  period: screenTimePeriodSchema,
  timezone: timezoneSchema,
  year: z.number().int().nullable(),
  startDate: z.string().date(),
  endDate: z.string().date(),
  totalUsageSeconds: z.number().int().nonnegative(),
  days: z.array(screenTimeInsightDaySchema),
  updatedAt: z.string().datetime().nullable(),
  apps: z.array(z.object({
    packageName: z.string(),
    appLabel: z.string(),
    usageSeconds: z.number().int().nonnegative(),
    queriedAt: z.string().datetime(),
  })),
});
