const accessKeyId = import.meta.env.VITE_AWS_ACCESS_KEY_ID;
const secretAccessKey = import.meta.env.VITE_AWS_SECRET_ACCESS_KEY;
const region = 'us-east-1';
const bucketName = 'forza-bucket-1'; // Move this here for cleaner separation

if (!accessKeyId || !secretAccessKey) {
  console.warn("AWS credentials are missing from environment variables!");
}

export default {
  region,
  bucketName,
  credentials: {
    accessKeyId,
    secretAccessKey,
  },
};

