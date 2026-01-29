import { trpcServer } from "@hono/trpc-server";
import { createContext } from "@typescript/api/context";
import { appRouter } from "@typescript/api/routers/index";
import { env } from "@typescript/env/server";
import { db } from "@typescript/db";
import { sql } from "drizzle-orm";
import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";

const app = new Hono();

app.use(logger());
app.use(
  "/*",
  cors({
    origin: env.CORS_ORIGIN,
    allowMethods: ["GET", "POST", "OPTIONS"],
  }),
);

app.use(
  "/api/trpc/*",
  trpcServer({
    router: appRouter,
    createContext: (_opts, context) => {
      return createContext({ context });
    },
  }),
);

app.get("/", (c) => {
  return c.text("OK");
});

// Health check endpoint that verifies database connectivity
app.get("/health", async (c) => {
  try {
    // Try to query the database to verify connectivity
    await db.execute(sql`SELECT 1`);
    return c.json({ status: "healthy", database: "connected" }, 200);
  } catch (error) {
    console.error("Health check failed:", error);
    return c.json(
      { status: "unhealthy", database: "disconnected", error: String(error) },
      503,
    );
  }
});

import { serve } from "@hono/node-server";

const port = Number(process.env.PORT) || 3000;

serve(
  {
    fetch: app.fetch,
    port,
  },
  (info) => {
    console.log(`Server is running on http://localhost:${info.port}`);
  },
);
