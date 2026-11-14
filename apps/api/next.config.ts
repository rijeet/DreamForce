import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  // Keep the hot-reload output independent from `next build`/`next start`.
  // Sharing .next lets a build replace chunks while a dev server still serves
  // webpack-runtime.js files that refer to the previous chunk set.
  distDir: process.env.NODE_ENV === 'development' ? '.next-dev' : '.next',
};

export default nextConfig;
