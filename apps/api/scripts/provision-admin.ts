import { provisionAdmin } from '../src/application/auth/auth-service';

const [email] = process.argv.slice(2);
const password = process.env.DREAM_FORCE_ADMIN_PASSWORD;

if (!email || !password) {
  throw new Error('Usage: DREAM_FORCE_ADMIN_PASSWORD=<password> npm run provision:admin -- <email>');
}

if (password.length < 12) throw new Error('Admin password must contain at least 12 characters.');

const admin = await provisionAdmin(email, password);
console.log(`Provisioned admin ${admin.email} (${admin.id}).`);
