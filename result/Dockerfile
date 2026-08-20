FROM node:24.18.0-slim

# add curl for healthcheck
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl tini && \
    addgroup --system --gid 10002 app && \
    adduser --system --uid 10002 --ingroup app app && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/app

COPY package*.json ./

RUN npm ci --omit=dev && \
 npm cache clean --force

COPY --chown=app:app . .

ENV NODE_ENV=production
ENV PORT=8080
EXPOSE 8080

USER app

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["node", "server.js"]
