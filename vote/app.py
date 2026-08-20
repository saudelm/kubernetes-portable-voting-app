from flask import Flask, render_template, request, make_response, g
from redis import Redis
import os
import socket
import secrets
import json
import logging

option_a = os.getenv('OPTION_A', "Cats")
option_b = os.getenv('OPTION_B', "Dogs")
redis_host = os.getenv('REDIS_HOST', "redis")
redis_port = int(os.getenv('REDIS_PORT', "6379"))
hostname = socket.gethostname()

app = Flask(__name__)

gunicorn_error_logger = logging.getLogger('gunicorn.error')
app.logger.handlers.extend(gunicorn_error_logger.handlers)
app.logger.setLevel(logging.INFO)

def get_redis():
    if not hasattr(g, 'redis'):
        g.redis = Redis(host=redis_host, port=redis_port, db=0, socket_timeout=5)
    return g.redis

@app.route("/healthz")
def healthz():
    return "ok", 200

@app.route("/readyz")
def readyz():
    try:
        get_redis().ping()
    except Exception:
        return "redis unavailable", 503
    return "ready", 200

@app.route("/", methods=['POST','GET'])
def hello():
    voter_id = request.cookies.get('voter_id')
    if not voter_id:
        voter_id = secrets.token_hex(16)

    vote = None

    if request.method == 'POST':
        redis = get_redis()
        vote = request.form.get('vote')
        if vote not in {'a', 'b'}:
            return "invalid vote", 400
        app.logger.info('Received vote for %s', vote)
        data = json.dumps({'voter_id': voter_id, 'vote': vote})
        redis.rpush('votes', data)

    resp = make_response(render_template(
        'index.html',
        option_a=option_a,
        option_b=option_b,
        hostname=hostname,
        vote=vote,
    ))
    resp.set_cookie('voter_id', voter_id, httponly=True, samesite='Lax')
    return resp


if __name__ == "__main__":
    app.run(host='0.0.0.0', port=int(os.getenv('PORT', "8080")), debug=True, threaded=True)
