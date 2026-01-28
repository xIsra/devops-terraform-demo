import { db } from "@typescript/db";
import type { Context as HonoContext } from "hono";

export type CreateContextOptions = {
  context: HonoContext;
};

export async function createContext({ context }: CreateContextOptions) {
  // No auth configured
  return {
    session: null,
    db,
  };
}

export type Context = Awaited<ReturnType<typeof createContext>>;
