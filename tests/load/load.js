import http from "k6/http";
import { check } from "k6";

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: "15s", target: 50 },
    { duration: __ENV.DURATION || "2m", target: 50 },
    { duration: "15s", target: 0 },
  ],
  thresholds: {
    http_req_failed: ["rate<0.01"],
    http_req_duration: ["p(95)<300"],
  },
  hosts: { "posts.local.test": "127.0.0.1" },
};

const BASE = __ENV.BASE_URL || "https://posts.local.test";
const headers = { "Content-Type": "application/json" };

export default function () {
  if (Math.random() < 0.8) {
    check(http.get(`${BASE}/posts`), { "read ok": (r) => r.status === 200 });
  } else {
    const res = http.post(
      `${BASE}/posts`,
      JSON.stringify({ title: "load", text: "load test post" }),
      { headers },
    );
    check(res, { "write ok": (r) => r.status === 201 });
  }
}
