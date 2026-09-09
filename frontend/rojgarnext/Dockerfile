FROM cirrusci/flutter:stable AS builder

WORKDIR /app
COPY . .
RUN flutter clean && flutter pub get && flutter build web --release --base-href=/

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]