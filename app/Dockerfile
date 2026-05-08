# syntax=docker/dockerfile:1.7

# Stage 1: install production dependencies
FROM node:26-slim AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev

# Stage 2: runtime image
FROM node:26-slim
WORKDIR /home/node/app
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .

USER node

EXPOSE 3000
ENV NODE_ENV=production \
    PORT=3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:'+process.env.PORT+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

CMD ["node", "index.js"]
