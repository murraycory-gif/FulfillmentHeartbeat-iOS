try {
  if (sessionStorage.getItem("hb.web.navCollapsed") === "1") {
    document.documentElement.classList.add("nav-collapsed");
  }
} catch (e) {
  /* private mode */
}
