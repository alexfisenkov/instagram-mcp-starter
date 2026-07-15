import { requestJsonHttp } from "./http-json.js";

export type GraphQueryValue = string | number | boolean | string[] | number[] | boolean[] | undefined;

export type GraphQuery = Record<string, GraphQueryValue>;

export class MetaClient {
  private readonly accessToken: string;
  private readonly apiVersion: string;
  private readonly baseUrl: string;

  constructor(options: { accessToken: string; apiVersion: string; baseUrl: string }) {
    this.accessToken = options.accessToken;
    this.apiVersion = options.apiVersion;
    this.baseUrl = options.baseUrl.replace(/\/+$/, "");
  }

  async get(path: string, query: GraphQuery & { query?: GraphQuery } = {}): Promise<unknown> {
    const url = this.buildUrl(path);
    const nestedQuery = query.query;
    for (const [key, value] of Object.entries(query)) {
      if (key === "query") continue;
      appendParam(url, key, value as GraphQueryValue);
    }
    if (nestedQuery) {
      for (const [key, value] of Object.entries(nestedQuery)) {
        appendParam(url, key, value);
      }
    }
    url.searchParams.set("access_token", this.accessToken);

    const response = await requestJsonHttp(url, {
      method: "GET",
      headers: { accept: "application/json" }
    });
    const body = response.body;
    if (!response.ok || isMetaError(body)) {
      throw new Error(formatMetaError(response.status, body));
    }
    return body;
  }

  private buildUrl(path: string): URL {
    if (/^https?:\/\//i.test(path)) return new URL(path);
    const cleanPath = path.startsWith("/") ? path : `/${path}`;
    if (cleanPath.startsWith(`/${this.apiVersion}/`)) {
      return new URL(cleanPath, this.baseUrl);
    }
    return new URL(`/${this.apiVersion}${cleanPath}`, this.baseUrl);
  }
}

function appendParam(url: URL, key: string, value: GraphQueryValue): void {
  if (value === undefined) return;
  if (Array.isArray(value)) {
    url.searchParams.set(key, value.join(","));
    return;
  }
  url.searchParams.set(key, String(value));
}

function isMetaError(value: unknown): boolean {
  return isRecord(value) && isRecord(value.error);
}

function formatMetaError(status: number, body: unknown): string {
  if (isRecord(body) && isRecord(body.error)) {
    const error = body.error;
    const message = typeof error.message === "string" ? error.message : "Meta Graph API error";
    const type = typeof error.type === "string" ? error.type : "unknown";
    const code = typeof error.code === "number" || typeof error.code === "string" ? error.code : "unknown";
    return `Meta Graph API error ${status}: ${message} (${type}, code ${code})`;
  }
  return `Meta Graph API error ${status}`;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}
