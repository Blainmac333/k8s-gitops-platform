FROM node:18-alpine

WORKDIR /app

COPY package*.json ./

RUN npm ci

ARG NEXT_PUBLIC_API_BASE
ENV NEXT_PUBLIC_API_BASE=${NEXT_PUBLIC_API_BASE}

COPY . .

RUN npm run build

EXPOSE 3000

CMD ["npm", "run", "start"]