/** @type {import('next').NextConfig} */
const nextConfig = {
    env: {
      NEXT_PUBLIC_BACKEND_URL: "http://backend-service", // Replace with your Kubernetes backend service name
    },
  };

  module.exports = nextConfig;
