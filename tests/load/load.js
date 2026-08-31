import http from "k6/http";
import { check } from "k6";

const VUS = Number(__ENV.VUS || 20);

export const options = {
  insecureSkipTLSVerify: true,
  stages: [
    { duration: "15s", target: VUS },
    { duration: __ENV.DURATION || "2m", target: VUS },
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

export function setup() {
  const r = http.post(
    `${BASE}/posts`,
    JSON.stringify({ title: "load", text: "load test post" }),
    { headers },
  );
  const id = r.status === 201 ? r.json("id") : undefined;
  if (!id) throw new Error(`seed post failed: status ${r.status}`);
  return { id };
}

export default function (data) {
  if (Math.random() < 0.8) {
    check(http.get(`${BASE}/posts/${data.id}`), { "read ok": (r) => r.status === 200 });
  } else {
    const res = http.post(
      `${BASE}/posts`,
      JSON.stringify({ title: "load", text: "load test post" }),
      { headers },
    );
    check(res, { "write ok": (r) => r.status === 201 });
  }
}
