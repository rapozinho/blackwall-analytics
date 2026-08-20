# BlackWall Analytics — frontend (build Vite servido por nginx)
#
# Duas etapas: o Node so' existe para compilar. A imagem final leva apenas os
# arquivos estaticos, sem node_modules e sem codigo-fonte.
FROM node:20-alpine AS build

WORKDIR /app

# package*.json antes do resto: muda pouco, entao a camada de dependencias fica
# em cache enquanto so' o codigo muda.
COPY package.json package-lock.json ./
# `npm ci` respeita o lockfile — build reprodutivel, diferente de `npm install`.
RUN npm ci

COPY . .
RUN npm run build


FROM nginx:1.27-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

# nginx:alpine ja roda os workers como `nginx`; o master precisa de root para
# abrir a porta 80. Para rodar 100% sem root, use a imagem nginxinc/nginx-unprivileged
# e troque a porta para 8080.
EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://127.0.0.1/ || exit 1
