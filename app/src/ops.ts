import express from "express";
import { dataSource } from "./data-source";
import { registry } from "./metrics";

export interface AppState {
  shuttingDown: boolean;
}

export function buildOpsApp(state: AppState) {
  const app = express();
  app.disable("x-powered-by");

  app.get("/healthz", (_req, res) => res.json({ status: "ok" }));

  app.get("/readyz", async (_req, res) => {
    if (state.shuttingDown) return res.status(503).json({ status: "shutting down" });
    try {
      await Promise.race([
        dataSource.query("SELECT 1"),
        new Promise((_r, reject) => setTimeout(() => reject(new Error("timeout")), 2000)),
      ]);
      res.json({ status: "ready" });
    } catch {
      res.status(503).json({ status: "database unavailable" });
    }
  });

  app.get("/metrics", async (_req, res) => {
    res.set("Content-Type", registry.contentType);
    res.send(await registry.metrics());
  });

  return app;
}
