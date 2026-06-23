FROM oven/bun:1-alpine

RUN apk add --no-cache openssl

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

COPY prisma ./prisma
COPY prisma.config.ts ./
COPY lib ./lib
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/resolve-database-url.ts ./scripts/
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 5555

ENTRYPOINT ["/entrypoint.sh"]
