import type { MvpRepository } from '../../APP.Entity/ports/mvp-repository';

/** Application use cases depend on the Entity-layer repository contract only. */
export function createMvpUseCases(repository: MvpRepository) {
  return {
    getProfile: repository.getProfile.bind(repository),
    updateProfile: repository.updateProfile.bind(repository),
    updateSettings: repository.updateSettings.bind(repository),
    listActivities: repository.listActivities.bind(repository),
    createActivity: repository.createActivity.bind(repository),
    patchActivity: repository.patchActivity.bind(repository),
    archiveActivity: repository.archiveActivity.bind(repository),
    createFocusSession: repository.createFocusSession.bind(repository),
    getFocusSession: repository.getFocusSession.bind(repository),
    submitSessionEvent: repository.submitSessionEvent.bind(repository),
    listPlans: repository.listPlans.bind(repository),
    createPlan: repository.createPlan.bind(repository),
    getPlan: repository.getPlan.bind(repository),
    getDailyReview: repository.getDailyReview.bind(repository),
    upsertDailyReview: repository.upsertDailyReview.bind(repository),
  };
}
