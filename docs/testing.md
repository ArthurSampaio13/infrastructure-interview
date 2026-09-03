# Testing

## Smoke test

`tests/load/smoke.js` is a functional check, run by `make test` with 1 VU and 1 iteration. It
creates a post, lists posts with `?limit=5`, reads the created post back by id, and asserts the
documented error responses: 400 on a bad `limit`, 400 on a non-numeric id, 404 on an unknown id,
400 on an invalid body, 400 on malformed JSON, and 413 with a JSON body on a request over the
100 kB limit. That is 12 checks, and the threshold is `rate==1`, so one failed check fails the run.

`helm test posts-api -n posts-api` runs the chart's own test hook against the in-cluster Service.

## Load test

`tests/load/load.js` seeds one post, then runs 80% reads against it and 20% writes. It ramps to
`VUS` virtual users over 15 s, holds for `DURATION`, and ramps down over 15 s. The Makefile sets
`VUS=10` for a 7.6 GB host; the script on its own defaults to 20, and `DURATION` defaults to 2m.

The SLO is two k6 thresholds: `http_req_failed` under 1% and `http_req_duration` p95 under 300 ms.
A breached threshold makes k6 exit non-zero, which is how every chaos script decides pass or fail.

```bash
make load                          # VUS=10, 2m
VUS=20 DURATION=5m make load
```

## Chaos scenarios

`make chaos` runs four scripts in this order. Each starts the load test in the background, injects
a fault, and checks that the load test still met its SLO.

| Scenario | Script | What it does | Expected outcome |
| --- | --- | --- | --- |
| Zone outage | `tests/chaos/zone-outage.sh` | Cordons and drains every node in one zone while load runs | The PDB holds; the replica scheduled in that zone stays `Pending` until the zone comes back. MySQL reports 2/3 online instances during the outage, then 3/3 once the zone returns |
| MySQL primary kill | `tests/chaos/mysql-primary-kill.sh` | Finds the current InnoDB Cluster primary and deletes its pod | Group replication elects a new primary; the MySQL Router fails writes and reads over to it without the app restarting |
| Rolling upgrade | `tests/chaos/rolling-upgrade.sh` | Restarts the Deployment under load | The rollout completes with no SLO violation, the same effect as a `helm upgrade` to a new image tag |
| Random pod kill | `tests/chaos/pod-kill.sh` | Deletes a random `posts-api` pod, eight times, ten seconds apart | Kubernetes reschedules each pod and the SLO holds throughout |

`zone-outage.sh` takes the zone to drain as its first argument and defaults to `zone-b`
([why not `zone-a`](architecture.md#cluster-and-zones)).

## Results

All runs are on the same 7.6 GB WSL2 host. Cells are `p95 / error rate`.

| Version | Date | VUs | Zone outage | Primary kill | Rolling upgrade | Pod kill |
| --- | --- | --- | --- | --- | --- | --- |
| v0.2.1 | 2026-08-31 | 20 | 91 ms / 0% | 146 ms / 0.42% | 159 ms / 0% | 179 ms / 0% |
| 0.3.0 | 2026-09-02 | 10 | 133 ms / 0% | 152 ms / 0.24% | 269 ms / 0% | fail: host stall, then p95 382 ms |
| 0.3.0, after fixes | 2026-09-02 | 20 | fail: 210 ms / 21.95%, then 168 ms / 0.00% on retry | not run | not run | not run |

Random pod kill on 0.3.0 failed twice for host reasons. The first attempt failed on errors when the
host stalled for about 30 seconds, the control plane restarted, and the MySQL Operator rolled both
routers at once, which is not what the scenario injects. The second, after 25 minutes of
back-to-back scenarios with the host already in swap, held 0.15% errors but reached a p95 of
382 ms.

The 20 VU zone outage failed on its first attempt with 21.95% errors (9174 of 41785 requests) and
passed on retry with 0.00% errors over 45995 requests. The cause was scheduling. The drained
`zone-b` node happened to hold one of the two NGINX data plane replicas and the single NGF control
plane pod, so the entry point was gone for about 30 seconds while the replacement pod pulled its
image on another node. k6 reported connection resets and EOFs rather than 5xx responses, so those
requests never reached the app. By the retry both gateway pods sat in zones a and c, and the
`ScheduleAnyway` spread never moves one back, so the second drain hit a zone with no gateway pod
on it.

A zone outage is therefore transparent only when the drained zone holds no gateway pod. Fixing it
means a second NGF control plane replica and a preStop drain on the data plane, neither of which is
in this repo. A control run at 10 VUs on the same build passed with 0.00% errors and a p95 of
120 ms.

## How to read a failure

Every chaos script fails the same way: the k6 process it started in the background exits non-zero,
which means a threshold was breached, and the script prints the summary before exiting non-zero
itself. Read the `http_req_failed` line first: a high error rate with a normal p95 means requests
were refused rather than served slowly, and an EOF or a connection reset in place of a status code
means they never reached the app. Run `kubectl get pods -A -w` in a second terminal for the whole
scenario and watch the gateway pods in `gateway` and `nginx-gateway`, because a zone drain that
evicts them takes the entry point down for as long as the replacement needs to pull and start.
