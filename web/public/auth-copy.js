document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-copy]");
  if (!button) return;
  const input = document.getElementById(button.getAttribute("data-copy"));
  const text = input && input.value;
  if (!text) return;
  const copied = () => {
    button.textContent = "Copied";
  };
  if (navigator.clipboard && navigator.clipboard.writeText) {
    navigator.clipboard.writeText(text).then(copied, () => {
      input.focus();
      input.select();
    });
    return;
  }
  input.focus();
  input.select();
});
