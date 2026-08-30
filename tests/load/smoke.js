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

  check(http.get(`${BASE}/posts`), {
    "list returns 200": (r) => r.status === 200,
    "list contains created post": (r) => r.json().some((p) => p.id === id),
  });
  check(http.get(`${BASE}/posts/${id}`), { "get by id returns 200": (r) => r.status === 200 });
  check(http.get(`${BASE}/posts/999999`), { "unknown id returns 404": (r) => r.status === 404 });
  check(http.post(`${BASE}/posts`, "{}", { headers }), {
    "invalid body returns 400": (r) => r.status === 400,
  });
}
