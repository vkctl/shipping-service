import os

from flask import Flask, jsonify, request

from shipping.rates import RATES, calculate_shipping
from shipping.flags import all_flags, is_enabled

app = Flask(__name__)

VERSION = os.environ.get("APP_VERSION", "dev")
ENVIRONMENT = os.environ.get("APP_ENVIRONMENT", "local")


@app.get("/health")
def health():
    return jsonify(status="ok", version=VERSION, environment=ENVIRONMENT, flags=all_flags())


@app.get("/rates")
def rates():
    return jsonify(rates=RATES)


@app.post("/quote")
def quote():
    body = request.get_json(silent=True) or {}
    try:
        weight = float(body["weight_kg"])
    except (KeyError, TypeError, ValueError):
        return jsonify(error="weight_kg must be a number"), 400

    tier = body.get("tier", "standard")
    try:
        cost = calculate_shipping(weight, tier, bulk_discount_enabled=is_enabled("bulk_discount"))
    except ValueError as exc:
        return jsonify(error=str(exc)), 400

    return jsonify(weight_kg=weight, tier=tier, cost=round(cost, 2))