import dotenv from "dotenv";
import { defineConfig } from "drizzle-kit";

// Load from environment or try to load from .env file if it exists
dotenv.config({
  path: "../../apps/server/.env",
});
// Also load from current directory .env if it exists
dotenv.config();

export default defineConfig({
  schema: "./src/schema",
  out: "./src/migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DATABASE_URL || "",
  },
});
