/**
 * Build PostgreSQL connection URL from env vars.
 * Use either DATABASE_URL or DATABASE_USER + DATABASE_PASSWORD + DATABASE_HOST + DATABASE_NAME.
 */

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export function getDatabaseUrl(): string {
  if (process.env.DATABASE_URL) {
    return process.env.DATABASE_URL;
  }

  const user = required("DATABASE_USER");
  const password = required("DATABASE_PASSWORD");
  const host = required("DATABASE_HOST");
  const database = required("DATABASE_NAME");
  const port = process.env.DATABASE_PORT ?? "5432";
  const schema = process.env.DATABASE_SCHEMA ?? "public";

  const encodedUser = encodeURIComponent(user);
  const encodedPassword = encodeURIComponent(password);
  const encodedSchema = encodeURIComponent(schema);

  return `postgresql://${encodedUser}:${encodedPassword}@${host}:${port}/${database}?schema=${encodedSchema}`;
}
