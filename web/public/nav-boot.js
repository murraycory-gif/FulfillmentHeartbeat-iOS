try {
  const url = new URL(location.href);
  if (url.username || url.password) {
    url.username = "";
    url.password = "";
    location.replace(url.href);
  }
} catch (e) {
  /* location is unavailable */
}

try {
  if (sessionStorage.getItem("hb.web.navCollapsed") !== "0") {
    document.documentElement.classList.add("nav-collapsed");
  }
} catch (e) {
  /* private mode */
}
