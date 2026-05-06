FROM node:18-slim

# add curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tini && \
    addgroup --system --gid 10002 app && \
    adduser --system --uid 10002 --ingroup app app && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

# have nodemon available for local dev use (file watching)
RUN npm install -g nodemon

COPY package*.json ./

RUN npm ci && \
 npm cache clean --force

COPY --chown=app:app . .

ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

USER app

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
