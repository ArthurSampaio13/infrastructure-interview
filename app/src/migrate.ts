import { dataSource } from "./data-source";
import { logger } from "./logger";

async function main() {
  await dataSource.initialize();
  const applied = await dataSource.runMigrations();
  logger.info({ applied: applied.map((m) => m.name) }, "migrations complete");
  await dataSource.destroy();
}

main().catch((err) => {
  logger.error(err, "migration failed");
  process.exit(1);
});
