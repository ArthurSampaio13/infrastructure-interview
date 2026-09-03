import http from "k6/http";
import { check } from "k6";

export const options = {
  insecureSkipTLSVerify: true,
  vus: 1,
  iterations: 1,
  thresholds: { checks: ["rate==1"] },
  hosts: { "posts.local.test": "127.0.0.1" },
};

const BASE = __ENV.BASE_URL || "https://posts.local.test";
const headers = { "Content-Type": "application/json" };

export default function () {
  const created = http.post(
    `${BASE}/posts`,
    JSON.stringify({ title: "smoke", text: "smoke test", categories: [{ name: "general" }] }),
    { headers },
  );
  check(created, { "create returns 201": (r) => r.status === 201 });
  const id = created.json("id");

  check(http.get(`${BASE}/posts?limit=5`), {
    "list returns 200": (r) => r.status === 200,
    "list is capped at 5": (r) => r.json().length <= 5,
    "list contains created post": (r) => r.json().some((p) => p.id === id),
  });
  check(http.get(`${BASE}/posts?limit=0`), { "bad limit returns 400": (r) => r.status === 400 });
  check(http.get(`${BASE}/posts/${id}`), { "get by id returns 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/posts/abc`), { "non-numeric id returns 400": (r) => r.status === 400 });
  check(http.get(`${BASE}/posts/999999`), { "unknown id returns 404": (r) => r.status === 404 });
  check(http.post(`${BASE}/posts`, "{}", { headers }), {
    "invalid body returns 400": (r) => r.status === 400,
  });
  check(http.post(`${BASE}/posts`, "{not json", { headers }), {
    "malformed json returns 400": (r) => r.status === 400,
  });
  const big = JSON.stringify({ title: "big", text: "x".repeat(150 * 1024) });
  check(http.post(`${BASE}/posts`, big, { headers }), {
    "oversized body returns 413": (r) => r.status === 413,
    "oversized body is json": (r) => r.headers["Content-Type"].startsWith("application/json"),
  });
}
