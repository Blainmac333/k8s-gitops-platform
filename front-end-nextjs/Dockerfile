FROM node:20-bookworm-slim

RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*

# Upgrade npm to pull in a patched version of the bundled tar dependency (CVE fix).
RUN npm install -g npm@latest

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