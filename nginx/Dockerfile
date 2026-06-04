FROM nginx:1.27-alpine
RUN apk add --no-cache certbot certbot-nginx gettext
COPY nginx.conf /etc/nginx/nginx.conf.template
EXPOSE 80 443
CMD ["/bin/sh", "-c", "envsubst '${DOMAIN}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf && nginx -g 'daemon off;'"]
