import { useQuery } from "@tanstack/react-query";

import { trpc } from "@/utils/trpc";

import type { Route } from "./+types/_index";

export function meta({}: Route.MetaArgs) {
  return [
    { title: "Resume Viewer" },
    { name: "description", content: "View and manage resumes" },
  ];
}

export default function Home() {
  const resumesQuery = useQuery(trpc.resume.list.queryOptions());

  return (
    <div className="container mx-auto max-w-4xl px-4 py-8">
      <h1 className="mb-6 text-3xl font-bold">Resume Viewer</h1>

      {resumesQuery.isLoading && (
        <div className="text-muted-foreground">Loading resumes...</div>
      )}

      {resumesQuery.error && (
        <div className="rounded-lg border border-red-500 bg-red-50 p-4 text-red-700 dark:bg-red-950 dark:text-red-300">
          Error loading resumes: {resumesQuery.error.message}
        </div>
      )}

      {resumesQuery.data && (
        <div className="grid gap-4">
          {resumesQuery.data.length === 0 ? (
            <div className="rounded-lg border p-6 text-center text-muted-foreground">
              No resumes found. Create one to get started.
            </div>
          ) : (
            resumesQuery.data.map((resume) => (
              <div key={resume.id} className="rounded-lg border p-6 shadow-sm">
                <div className="mb-4 flex items-center justify-between">
                  <div>
                    <h2 className="text-xl font-semibold">
                      Resume {resume.id.slice(0, 8)}
                    </h2>
                    <p className="text-sm text-muted-foreground">
                      User: {resume.userId}
                    </p>
                    <p className="text-xs text-muted-foreground">
                      Created: {new Date(resume.createdAt).toLocaleDateString()}
                    </p>
                  </div>
                </div>
                <div className="rounded-md bg-muted p-4">
                  <pre className="overflow-x-auto text-sm">
                    {JSON.stringify(resume.resumeData, null, 2)}
                  </pre>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}
