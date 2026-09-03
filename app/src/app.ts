import { randomUUID } from "node:crypto";
import express, { NextFunction, Request, Response } from "express";
import helmet from "helmet";
import { pinoHttp } from "pino-http";
import { logger } from "./logger";
import { metricsMiddleware } from "./metrics";
import { router } from "./routes";

const requestIdPattern = /^[\w.-]{1,128}$/;

type HttpError = Error & { status?: number; expose?: boolean; type?: string };

export function buildApp() {
  const app = express();
  app.disable("x-powered-by");
  app.use(helmet());
  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => {
        const id = req.headers["x-request-id"];
        return typeof id === "string" && requestIdPattern.test(id) ? id : randomUUID();
      },
    }),
  );
  app.use(metricsMiddleware);
  app.use(express.json({ limit: "100kb" }));
  app.use(router);
  app.use((_req, res) => res.status(404).json({ error: "not found" }));
  app.use((err: HttpError, req: Request, res: Response, _next: NextFunction) => {
    if (err.type === "entity.parse.failed") {
      res.status(400).json({ error: "invalid json body" });
      return;
    }
    const status = err.status ?? 500;
    if (status < 500) {
      req.log.warn({ err }, "request rejected");
      res.status(status).json({ error: err.expose ? err.message : "bad request" });
      return;
    }
    req.log.error(err, "unhandled error");
    res.status(500).json({ error: "internal error" });
  });
  return app;
}
