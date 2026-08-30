import { Registry, collectDefaultMetrics, Histogram, Counter } from "prom-client";
import { NextFunction, Request, Response } from "express";

export const registry = new Registry();
collectDefaultMetrics({ register: registry });

const duration = new Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration",
  labelNames: ["method", "route", "status"],
  buckets: [0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5],
  registers: [registry],
});

const total = new Counter({
  name: "http_requests_total",
  help: "HTTP requests",
  labelNames: ["method", "route", "status"],
  registers: [registry],
});

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const end = duration.startTimer();
  res.on("finish", () => {
    const route = req.route?.path ?? "unmatched";
    const labels = { method: req.method, route, status: String(res.statusCode) };
    end(labels);
    total.inc(labels);
  });
  next();
}
