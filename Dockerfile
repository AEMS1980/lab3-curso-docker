FROM node:24-alpine AS base
RUN npm install --global pnpm@10.11.0
WORKDIR /app
FROM base AS build
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY tsconfig*.json nest-cli.json ./
COPY src ./src
RUN pnpm build
FROM base AS prod-deps
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --prod --frozen-lockfile
FROM node:24-alpine AS runtime
ENV NODE_ENV=production PORT=3000
WORKDIR /app
COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
COPY --from=build --chown=node:node /app/dist ./dist
COPY --chown=node:node package.json ./
USER node
EXPOSE 3000
CMD ["node", "dist/main.js"]