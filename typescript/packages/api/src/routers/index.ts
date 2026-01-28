import { publicProcedure, router } from "../index";

import { resumeRouter } from "./resume";

export const appRouter = router({
  healthCheck: publicProcedure.query(() => {
    return "OK";
  }),
  resume: resumeRouter,
});
export type AppRouter = typeof appRouter;
