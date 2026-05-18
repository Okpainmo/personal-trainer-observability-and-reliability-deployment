import logging
import random
import time
from http import HTTPStatus

from fastapi import FastAPI, HTTPException, Request, Response
from opentelemetry import trace
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from pythonjsonlogger import jsonlogger


handler = logging.StreamHandler()
handler.setFormatter(jsonlogger.JsonFormatter("%(asctime)s %(levelname)s %(name)s %(message)s %(trace_id)s %(span_id)s"))
logger = logging.getLogger("test-api")
logger.setLevel(logging.INFO)
logger.addHandler(handler)
logger.propagate = False

app = FastAPI(title="Test API", version="1.0.0")
tracer = trace.get_tracer(__name__)

REQUESTS = Counter("http_requests_total", "Total HTTP requests", ["method", "route", "status"])
REQUEST_LATENCY = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency",
    ["method", "route", "status"],
    buckets=(0.05, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 10),
)


def current_trace_fields() -> dict[str, str]:
    span = trace.get_current_span()
    context = span.get_span_context()
    if not context.is_valid:
        return {"trace_id": "", "span_id": ""}
    return {
        "trace_id": format(context.trace_id, "032x"),
        "span_id": format(context.span_id, "016x"),
    }


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    route = request.url.path
    start = time.perf_counter()
    status = "500"
    try:
        response = await call_next(request)
        status = str(response.status_code)
        return response
    finally:
        duration = time.perf_counter() - start
        REQUESTS.labels(request.method, route, status).inc()
        REQUEST_LATENCY.labels(request.method, route, status).observe(duration)
        logger.info(
            "request_completed",
            extra={
                **current_trace_fields(),
                "method": request.method,
                "route": route,
                "status": status,
                "duration_ms": round(duration * 1000, 2),
            },
        )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/workout")
def workout(delay_ms: int = 0, fail: bool = False):
    with tracer.start_as_current_span("build_workout_plan") as span:
        delay_ms = min(max(delay_ms, 0), 10000)
        if delay_ms:
            span.set_attribute("simulated.delay_ms", delay_ms)
            time.sleep(delay_ms / 1000)
        if fail:
            span.set_attribute("simulated.failure", True)
            logger.error("workout_generation_failed", extra=current_trace_fields())
            raise HTTPException(status_code=HTTPStatus.INTERNAL_SERVER_ERROR, detail="simulated workout failure")
        exercises = random.sample(["squats", "pushups", "plank", "lunges", "rows"], 3)
        span.set_attribute("workout.exercise_count", len(exercises))
        return {"member": "demo-athlete", "plan": exercises}


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
