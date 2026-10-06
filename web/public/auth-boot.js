// First paint after sign-in. A cached 401 for /data must not become "NO DATA".

export const AUTH_RETRIES = 4;

export function packRequestInit() {
  return { cache: "reload", credentials: "same-origin" };
}

export function packUrl(url, attempt, nonce) {
  const join = String(url).includes("?") ? "&" : "?";
  return `${url}${join}hb=${nonce}-${attempt}`;
}

export function paintWhileLoading(home, settled) {
  if (home) return "dashboard";
  if (!settled) return "loading";
  return "nodata";
}

export function afterPackStatus(status, attempt) {
  const tries = Number(attempt) || 0;
  if (status === 401 || status === 403) {
    if (tries + 1 < AUTH_RETRIES) return "retry";
    return "login";
  }
  if (tries + 1 < AUTH_RETRIES) return "retry";
  return "fail";
}
