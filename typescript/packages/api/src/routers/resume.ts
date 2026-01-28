import { resumes } from "@typescript/db/schema/index";
import { eq } from "drizzle-orm";
import { z } from "zod";

import { publicProcedure, router } from "../index";

export const resumeRouter = router({
  list: publicProcedure.query(async ({ ctx }) => {
    const allResumes = await ctx.db.select().from(resumes);
    return allResumes;
  }),

  get: publicProcedure
    .input(z.object({ id: z.string().uuid() }))
    .query(async ({ ctx, input }) => {
      const [resume] = await ctx.db
        .select()
        .from(resumes)
        .where(eq(resumes.id, input.id))
        .limit(1);
      return resume;
    }),

  create: publicProcedure
    .input(
      z.object({
        userId: z.string(),
        resumeData: z.any(), // JSON data
      }),
    )
    .mutation(async ({ ctx, input }) => {
      const [resume] = await ctx.db
        .insert(resumes)
        .values({
          userId: input.userId,
          resumeData: input.resumeData,
        })
        .returning();
      return resume;
    }),
});
