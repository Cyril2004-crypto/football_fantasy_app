declare module "@supabase/supabase-js" {
  export const createClient: any;
}

declare module "npm:@supabase/supabase-js@2" {
  export const createClient: any;
}

declare const Deno: {
  serve: (handler: (req: Request) => Response | Promise<Response>) => void;
  env: {
    get: (key: string) => string | undefined;
  };
};
