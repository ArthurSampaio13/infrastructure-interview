import { z } from "zod";

const schema = z.object({
  DB_HOST: z.string().min(1),
  DB_PORT: z.coerce.number().int().default(3306),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string().min(1),
  DB_NAME: z.string().min(1),
  PORT: z.coerce.number().int().default(3000),
  METRICS_PORT: z.coerce.number().int().default(9464),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace"]).default("info"),
});

const parsed = schema.safeParse(process.env);
if (!parsed.success) {
  console.error("invalid configuration:", JSON.stringify(parsed.error.flatten().fieldErrors));
  process.exit(1);
}

export const config = parsed.data;
