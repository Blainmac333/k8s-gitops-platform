FROM node:20-bookworm-slim

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Upgrade npm to pull in a patched version of the bundled tar dependency (CVE fix).
# npm@latest (v12) requires Node >=22; pin to npm@11 which supports Node 20.
RUN npm install -g npm@11

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