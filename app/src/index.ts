import { config } from "./config";
import { logger } from "./logger";
import { dataSource } from "./data-source";
import { buildApp } from "./app";
import { buildOpsApp, AppState } from "./ops";

async function main() {
  await dataSource.initialize();

  const state: AppState = { shuttingDown: false };
  const server = buildApp().listen(config.PORT, () => {
    logger.info({ port: config.PORT }, "api listening");
  });
  const opsServer = buildOpsApp(state).listen(config.METRICS_PORT, () => {
    logger.info({ port: config.METRICS_PORT }, "ops listening");
  });

  const shutdown = (signal: string) => {
    if (state.shuttingDown) return;
    state.shuttingDown = true;
    logger.info({ signal }, "shutting down");
    setTimeout(() => process.exit(1), 10_000).unref();
    server.close(() => {
      opsServer.close(async () => {
        await dataSource.destroy();
        process.exit(0);
      });
    });
  };
  process.on("SIGTERM", () => shutdown("SIGTERM"));
  process.on("SIGINT", () => shutdown("SIGINT"));
}

main().catch((err) => {
  logger.error(err, "startup failed");
  process.exit(1);
});
