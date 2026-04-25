FROM node:18-alpine

# Patch Alpine OS packages to clear fixable CVEs (OpenSSL libcrypto3/libssl3)
RUN apk update && apk upgrade && rm -rf /var/cache/apk/*

WORKDIR /app

COPY package*.json ./

# npm install instead of npm ci because package-lock.json needs regenerating
# after the next.js version bump. Switch back to npm ci once lock file is updated.
RUN npm install

ARG NEXT_PUBLIC_API_BASE
ENV NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE}

COPY . .

RUN npm run build

EXPOSE 3000

CMD ["npm", "run", "start"]