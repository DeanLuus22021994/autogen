# Base image with Node.js
FROM node:18-alpine as build

# Set working directory
WORKDIR /app

# Copy package.json and package-lock.json
COPY ui/package*.json ./

# Install dependencies
RUN npm install

# Copy UI source code
COPY ui/src ./src
COPY ui/public ./public

# Build the React app
RUN npm run build

# Production environment
FROM nginx:stable-alpine

# Copy built assets from the build stage
COPY --from=build /app/build /usr/share/nginx/html

# Copy custom nginx config
COPY ui/nginx.conf /etc/nginx/conf.d/default.conf

# Expose port
EXPOSE 3000

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
