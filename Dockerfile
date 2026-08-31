# syntax=docker/dockerfile:1

# ---------- base: shared settings ----------
FROM python:3.12-slim AS base

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get upgrade -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt ./
RUN pip install --require-hashes -r requirements.txt

# ---------- builder: produce the wheel ----------
FROM base AS builder

ARG APP_VERSION=0.0.0
ENV SETUPTOOLS_SCM_PRETEND_VERSION=${APP_VERSION}

RUN pip install build==1.2.2 setuptools-scm==8.1.0

COPY pyproject.toml ./
COPY src/ ./src/

RUN python -m build --wheel --no-isolation --outdir /dist

# ---------- dev: editable, hot reload ----------
FROM base AS dev

ENV APP_ENVIRONMENT=dev \
    FLASK_APP=shipping.api \
    PYTHONPATH=/app/src

COPY pyproject.toml ./
COPY src/ ./src/

EXPOSE 8000

CMD ["flask", "run", "--host=0.0.0.0", "--port=8000", "--debug"]

# ---------- runtime: what ships to production ----------
FROM base AS runtime

ARG APP_VERSION=0.0.0
ENV APP_VERSION=${APP_VERSION}

RUN groupadd --system --gid 1001 app \
    && useradd --system --uid 1001 --gid app --no-create-home app

COPY --from=builder /dist/*.whl /tmp/
RUN pip install --no-deps /tmp/*.whl && rm -rf /tmp/*.whl

USER 1001:1001

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8000/health').status==200 else 1)"]

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--access-logfile", "-", "shipping.api:app"]