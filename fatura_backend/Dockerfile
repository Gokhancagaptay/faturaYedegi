# Backend Dockerfile
FROM node:18-bullseye
WORKDIR /app
COPY package*.json ./
# PDF -> PNG için poppler ve sharp bağımlılıkları
RUN apt-get update && apt-get install -y \
    build-essential \
    poppler-utils \
    && rm -rf /var/lib/apt/lists/*

RUN npm install --only=production
COPY . .
ENV PORT=3000
EXPOSE 3000
CMD ["npm", "start"]
