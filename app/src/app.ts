import { randomUUID } from "node:crypto";
import express, { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { logger } from "./logger";
import { metricsMiddleware } from "./metrics";
import { router } from "./routes";

export function buildApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  app.use(express.json({ limit: "100kb" }));
  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => (req.headers["x-request-id"] as string) ?? randomUUID(),
    }),
  );
  app.use(metricsMiddleware);
  app.use(router);
  app.use((_req, res) => res.status(404).json({ error: "not found" }));
  app.use((err: Error, req: Request, res: Response, _next: NextFunction) => {
    req.log.error(err, "unhandled error");
    res.status(500).json({ error: "internal error" });
  });
  return app;
}
