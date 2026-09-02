from flask import Flask, jsonify
import os
import socket

app = Flask(__name__)


@app.route("/")
def index():
    return jsonify(
        message="Containerized microservice running on EKS",
        hostname=socket.gethostname(),
        version=os.getenv("APP_VERSION", "dev"),
    )


@app.route("/healthz")
def healthz():
    # Liveness: process is up and can respond at all
    return jsonify(status="ok"), 200


@app.route("/ready")
def ready():
    # Readiness: in a real service this would check DB/cache connectivity
    # before accepting traffic. Kept simple here since this service is stateless.
    return jsonify(status="ready"), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
