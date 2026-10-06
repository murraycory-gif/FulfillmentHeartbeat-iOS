const toggle = document.querySelector("#nav-toggle");
const drawer = document.querySelector("#drawer");
const scrim = document.querySelector("#scrim");

function setDrawer(open) {
  if (!drawer || !toggle) return;
  drawer.classList.toggle("open", open);
  toggle.setAttribute("aria-expanded", open ? "true" : "false");
  if (scrim) scrim.hidden = !open;
}

if (toggle && drawer) {
  toggle.addEventListener("click", (event) => {
    event.stopPropagation();
    setDrawer(!drawer.classList.contains("open"));
  });
  if (scrim) scrim.addEventListener("click", () => setDrawer(false));
  const close = drawer.querySelector("[data-close-drawer]");
  if (close) close.addEventListener("click", () => setDrawer(false));
}
