# ---------- Build stage ----------
FROM node:22-alpine AS build

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# ---------- Production stage ----------
FROM nginx:alpine

COPY --from=build /app/dist /usr/share/nginx/html

# SPA-like fallback: route unknown paths to 404 page (Astro static output)
RUN printf 'server {\n\
  listen 80;\n\
  server_name _;\n\
  root /usr/share/nginx/html;\n\
  index index.html;\n\
\n\
  location / {\n\
    try_files $uri $uri/ $uri/index.html =404;\n\
  }\n\
\n\
  # cache static assets aggressively\n\
  location /_astro/ {\n\
    expires 1y;\n\
    add_header Cache-Control "public, immutable";\n\
  }\n\
\n\
  # never cache html\n\
  location ~* \.html$ {\n\
    expires -1;\n\
    add_header Cache-Control "no-store";\n\
  }\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
