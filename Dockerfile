# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# ──────────────────────────────────────────────
# Stage 1: Build the frontend (Node.js)
# ──────────────────────────────────────────────
FROM node:20-slim AS frontend-builder

WORKDIR /app

# Install dependencies first (layer cache)
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# Copy source and build
COPY index.html tsconfig.json vite.config.ts eslint.config.js ./
COPY src ./src
COPY public ./public
RUN yarn build

# ──────────────────────────────────────────────
# Stage 2: Python runtime image
# ──────────────────────────────────────────────
FROM python:3.11-slim AS runtime

WORKDIR /app

# Install system dependencies required by some Python packages
# (e.g. pyodbc needs unixodbc, vl-convert-python needs libssl)
RUN apt-get update && apt-get install -y --no-install-recommends \
        unixodbc \
        libgomp1 \
        && rm -rf /var/lib/apt/lists/*

# Copy Python project metadata and install dependencies
COPY pyproject.toml requirements.txt ./
COPY py-src ./py-src
COPY MANIFEST.in ./

# Copy the pre-built frontend assets into the expected location
COPY --from=frontend-builder /app/py-src/data_formulator/dist ./py-src/data_formulator/dist

# Install the package (editable install not needed in production)
RUN pip install --no-cache-dir .

# Expose the default port
EXPOSE 5567

# Data directory for workspaces (can be overridden with a volume mount)
VOLUME ["/root/.data_formulator"]

# Copy optional .env template so users know where to place their .env
COPY .env.template .env.template

# Launch the application
# Pass --dev so the server does not try to open a browser window
CMD ["data_formulator", "--dev", "--port", "5567"]
