const hideBranding = () => {
  for (const element of document.querySelectorAll("a, span")) {
    if (element.textContent?.trim() === "Powered by Grafana") {
      element.style.display = "none";
    }
  }
};

hideBranding();
new MutationObserver(hideBranding).observe(document.documentElement, {
  childList: true,
  subtree: true,
});
