FROM nginx:alpine

# Copy static files to nginx html directory
COPY . /usr/share/nginx/html

# Remove Dockerfile and config files from served content
RUN rm -f /usr/share/nginx/html/Dockerfile \
    /usr/share/nginx/html/nginx.conf

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
