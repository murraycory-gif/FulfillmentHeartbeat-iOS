try {
  if (location.username || location.password) {
    location.replace(location.origin + location.pathname + location.search + location.hash);
  }
} catch (e) {
  /* location is unavailable */
}

try {
  if (sessionStorage.getItem("hb.web.navCollapsed") === "1") {
    document.documentElement.classList.add("nav-collapsed");
  }
} catch (e) {
  /* private mode */
}
