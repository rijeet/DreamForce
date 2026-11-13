import type { z } from 'zod';
import type {
  activityTemplateSchema, createSessionSchema, dailyReviewSchema,
  patchActivityTemplateSchema, sessionEventSchema, updateProfileSchema,
  updateSettingsSchema, weeklyPlanSchema,
} from '@dream-force/api-contract';

export type MvpRepository = {
  getProfile(userId: string): Promise<unknown>;
  updateProfile(userId: string, input: z.infer<typeof updateProfileSchema>): Promise<unknown>;
  updateSettings(userId: string, input: z.infer<typeof updateSettingsSchema>): Promise<unknown>;
  listActivities(userId: string): Promise<unknown>;
  createActivity(userId: string, input: z.infer<typeof activityTemplateSchema>): Promise<unknown>;
  patchActivity(userId: string, id: string, input: z.infer<typeof patchActivityTemplateSchema>): Promise<unknown>;
  archiveActivity(userId: string, id: string): Promise<void>;
  createFocusSession(userId: string, input: z.infer<typeof createSessionSchema>): Promise<unknown>;
  getFocusSession(userId: string, id: string): Promise<unknown>;
  submitSessionEvent(userId: string, id: string, input: z.infer<typeof sessionEventSchema>): Promise<unknown>;
  listPlans(userId: string): Promise<unknown>;
  createPlan(userId: string, input: z.infer<typeof weeklyPlanSchema>): Promise<unknown>;
  getPlan(userId: string, id: string): Promise<unknown>;
  getDailyReview(userId: string, date: string): Promise<unknown>;
  upsertDailyReview(userId: string, date: string, input: z.infer<typeof dailyReviewSchema>): Promise<unknown>;
};
