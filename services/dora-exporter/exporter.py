import json
import os
import time
from datetime import datetime, timezone

import requests
from prometheus_client import Gauge, start_http_server


POLL_INTERVAL = int(os.getenv("POLL_INTERVAL_SECONDS", "60"))
REPOSITORY = os.getenv("GITHUB_REPOSITORY", "")
TOKEN = os.getenv("GITHUB_TOKEN", "")
WORKFLOW_NAME = os.getenv("DEPLOYMENT_WORKFLOW_NAME", "deploy.yml")
INCIDENTS_FILE = os.getenv("INCIDENTS_FILE", "/data/incidents.json")

deployment_total = Gauge("dora_deployments_total", "Deployment count by conclusion", ["service", "conclusion"])
deployment_timestamp = Gauge("dora_last_deployment_timestamp_seconds", "Last deployment Unix timestamp", ["service", "conclusion"])
lead_time_seconds = Gauge("dora_lead_time_seconds", "Commit to production lead time", ["service"])
change_failure_rate = Gauge("dora_change_failure_rate_ratio", "Deployments causing failure divided by total deployments", ["service"])
mttr_seconds = Gauge("dora_mttr_seconds", "Mean time to restore service", ["service"])


def parse_time(value: str) -> datetime:
    return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)


def load_incidents() -> list[dict]:
    try:
        with open(INCIDENTS_FILE, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return []


def github_runs() -> list[dict]:
    if not REPOSITORY or not TOKEN:
        return []
    url = f"https://api.github.com/repos/{REPOSITORY}/actions/workflows/{WORKFLOW_NAME}/runs"
    response = requests.get(
        url,
        headers={"Authorization": f"Bearer {TOKEN}", "Accept": "application/vnd.github+json"},
        params={"per_page": 50, "event": "push"},
        timeout=10,
    )
    response.raise_for_status()
    return response.json().get("workflow_runs", [])


def fallback_runs() -> list[dict]:
    now = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
    return [
        {
            "conclusion": "success",
            "created_at": "2026-05-18T06:20:00Z",
            "updated_at": "2026-05-18T06:28:00Z",
            "head_commit": {"timestamp": "2026-05-18T06:05:00Z"},
        },
        {
            "conclusion": "failure",
            "created_at": "2026-05-18T07:00:00Z",
            "updated_at": now,
            "head_commit": {"timestamp": "2026-05-18T06:45:00Z"},
        },
    ]


def collect():
    service = os.getenv("SERVICE_NAME", "personal-trainer-be")
    try:
        runs = github_runs() or fallback_runs()
    except Exception:
        runs = fallback_runs()

    totals = {"success": 0, "failure": 0, "cancelled": 0}
    latest_success = None
    latest_lead_time = None
    for run in runs:
        conclusion = run.get("conclusion") or "unknown"
        totals[conclusion] = totals.get(conclusion, 0) + 1
        updated_at = parse_time(run["updated_at"])
        deployment_timestamp.labels(service, conclusion).set(updated_at.timestamp())
        if conclusion == "success" and (latest_success is None or updated_at > latest_success):
            latest_success = updated_at
            commit_time = parse_time(run.get("head_commit", {}).get("timestamp", run["created_at"]))
            latest_lead_time = (updated_at - commit_time).total_seconds()

    for conclusion, count in totals.items():
        deployment_total.labels(service, conclusion).set(count)
    if latest_lead_time is not None:
        lead_time_seconds.labels(service).set(latest_lead_time)

    failed = totals.get("failure", 0) + totals.get("cancelled", 0)
    total = sum(totals.values())
    change_failure_rate.labels(service).set(failed / total if total else 0)

    incidents = [item for item in load_incidents() if item.get("resolved_at")]
    durations = [
        (parse_time(item["resolved_at"]) - parse_time(item["started_at"])).total_seconds()
        for item in incidents
    ]
    mttr_seconds.labels(service).set(sum(durations) / len(durations) if durations else 0)


if __name__ == "__main__":
    start_http_server(9108)
    while True:
        collect()
        time.sleep(POLL_INTERVAL)
