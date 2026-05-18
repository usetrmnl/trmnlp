const trmnlp = {};

trmnlp.connectLiveRender = function () {
  // EventSource reconnects automatically, so no manual retry loop is needed.
  const source = new EventSource("/live_reload");

  source.onopen = function () {
    console.log("Connected to live reload stream");
  };

  source.onmessage = function (event) {
    const payload = JSON.parse(event.data);

    if (payload.type === "reload") {
      trmnlp.fetchPreview();
      trmnlp.userData.textContent = JSON.stringify(payload.user_data, null, 2);
      hljs.highlightAll();
    }
  };
};


trmnlp.fetchPreview = function (pickerState) {
  const state = pickerState || trmnlp.picker?.state;
  const screenClasses = (state?.screenClasses || []).join(" ");
  const encodedScreenClasses = encodeURIComponent(screenClasses);
  let src = `/render/${trmnlp.view}.${trmnlp.formatSelect.value}?screen_classes=${encodedScreenClasses}`;

  // Pass dimensions for both HTML and PNG renders so trmnl.device.{width,height}
  // in the Liquid context tracks the picker model selection.
  if (state) {
    const width = encodeURIComponent(state.width);
    const height = encodeURIComponent(state.height);
    src += `&width=${width}&height=${height}`;
  }

  // PNG-only: dark mode + color depth from palette
  if (trmnlp.formatSelect.value === 'png' && state) {
    const isDarkMode = state.isDarkMode ? 1 : 0;
    const grays = state.palette.grays || 2;
    const colorDepth = Math.ceil(Math.log2(grays));
    src += `&color_depth=${colorDepth}`;
  }

  trmnlp.spinner.style.display = "inline-block";
  trmnlp.iframe.src = src;
};

trmnlp.refreshUserData = async function (state) {
  if (!state) return;
  const params = new URLSearchParams({ width: state.width, height: state.height });
  try {
    const response = await fetch(`/data?${params}`);
    if (!response.ok) return;
    trmnlp.userData.textContent = await response.text();
    hljs.highlightAll();
  } catch (e) {
    console.warn("Failed to refresh user-data:", e);
  }
};

document.addEventListener("DOMContentLoaded", async function () {
  trmnlp.view = document.querySelector("meta[name='trmnl-view']").content;
  trmnlp.iframe = document.querySelector("iframe");
  trmnlp.formatSelect = document.querySelector(".select-format");
  trmnlp.userData = document.getElementById("user-data");
  trmnlp.spinner = document.querySelector(".spinner");
  trmnlp.isLiveReloadEnabled =
    document.querySelector("meta[name='live-reload']").content === "true";

  if (trmnlp.isLiveReloadEnabled) {
    trmnlp.connectLiveRender();
  }

  const formatValue = localStorage.getItem("trmnlp-format") || "html";

  trmnlp.formatSelect.value = formatValue;
  trmnlp.formatSelect.addEventListener("change", () => {
    localStorage.setItem("trmnlp-format", trmnlp.formatSelect.value);
    trmnlp.fetchPreview();
  });

  trmnlp.iframe.addEventListener("load", () => {
    trmnlp.spinner.style.display = "none";
  });

  document.getElementById('picker-form').addEventListener('trmnl:change', (event) => {
    trmnlp.iframe.style.width = `${event.detail.width}px`;
    trmnlp.iframe.style.height = `${event.detail.height}px`;

    trmnlp.fetchPreview(event.detail);
    trmnlp.refreshUserData(event.detail);
  });

  trmnlp.picker = await TRMNLPicker.create('picker-form', { localStorageKey: 'trmnlp-picker' });
});
