import { createMvpUseCases } from '../APP.BLL/mvp/mvp-use-cases';
import { neonMvpRepository } from '../APP.Infrastructure/persistence/neon-mvp-repository';

// The outer API layer is the composition root: implementations point inward
// through the repository contract and are supplied to the BLL here.
export const mvp = createMvpUseCases(neonMvpRepository);
export const { archiveActivity, createActivity, createFocusSession, createPlan,
  getDailyReview, getFocusSession, getPlan, getProfile, listActivities, listPlans,
  patchActivity, submitSessionEvent, updateProfile, updateSettings,
  upsertDailyReview } = mvp;
