import { Client, Receiver } from '@upstash/qstash';

import { readServerEnvironment } from '../env';

export function createQStashClient() {
  return new Client({ token: readServerEnvironment().QSTASH_TOKEN });
}

export function createQStashReceiver() {
  const environment = readServerEnvironment();
  return new Receiver({
    currentSigningKey: environment.QSTASH_CURRENT_SIGNING_KEY,
    nextSigningKey: environment.QSTASH_NEXT_SIGNING_KEY,
  });
}
