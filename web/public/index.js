const trmnlp = {};

trmnlp.connectLiveRender = function () {
  const ws = new WebSocket("/live_reload");

  ws.onopen = function () {
    console.log("Connected to live reload socket");
  };

  ws.onmessage = function (msg) {
    const payload = JSON.parse(msg.data);

    if (payload.type === "reload") {
      trmnlp.fetchPreview();
      trmnlp.userData.textContent = JSON.stringify(payload.user_data, null, 2);
      hljs.highlightAll();
    }
  };

  ws.onclose = function () {
    console.log("Reconnecting to live reload socket...");
    setTimeout(trmnlp.connectLiveRender, 1000);
  };
};


trmnlp.fetchPreview = function (pickerState) {
  const screenClasses = (pickerState?.screenClasses || trmnlp.picker.state.screenClasses).join(" ");
  const encodedScreenClasses = encodeURIComponent(screenClasses);
  let src = `/render/${trmnlp.view}.${trmnlp.formatSelect.value}?screen_classes=${encodedScreenClasses}`;

  // If requesting a PNG, also include dimensions, dark mode, and color depth
  if (trmnlp.formatSelect.value === 'png') {
    const state = pickerState || trmnlp.picker.state;
    const width = encodeURIComponent(state.width);
    const height = encodeURIComponent(state.height);
    const isDarkMode = state.isDarkMode ? 1 : 0;

    // derive numeric color depth from classes like 'screen--1bit'
    const grays = state.palette.grays || 2;
    const colorDepth = Math.ceil(Math.log2(grays));

    src += `&width=${width}&height=${height}&color_depth=${colorDepth}`;
  }

  trmnlp.spinner.style.display = "inline-block";
  trmnlp.iframe.src = src;
};

// Load custom fields from API and populate editor
trmnlp.loadCustomFields = async function() {
  const container = document.getElementById('custom-fields-container');
  container.innerHTML = ''; // Clear existing fields

  const config = await fetch('/api/config').then(r => r.json());
  const customFields = config.custom_fields || {};
  const pluginFields = config.plugin_fields || [];

  // Create a set of existing field keys
  const existingKeys = new Set(Object.keys(customFields));

  // First, add rows for plugin-defined fields (with or without values)
  pluginFields.forEach(field => {
    const keyname = field.keyname;
    const value = customFields[keyname] || field.default || '';

    if (field.field_type === 'select' && field.options) {
      // Render as dropdown
      trmnlp.addSelectFieldRow(container, keyname, value, field.options);
    } else {
      // Render as text input
      const placeholder = field.description || 'Value';
      trmnlp.addFieldRowWithHint(container, keyname, value, placeholder, true);
    }
    existingKeys.delete(keyname);
  });

  // Then add any custom fields that aren't in plugin definition
  existingKeys.forEach(key => {
    trmnlp.addFieldRow(container, key, customFields[key]);
  });
};

// Custom fields editor functionality
trmnlp.initCustomFieldsEditor = async function() {
  const container = document.getElementById('custom-fields-container');
  const addBtn = document.getElementById('add-field-btn');
  const saveBtn = document.getElementById('save-fields-btn');

  await trmnlp.loadCustomFields();

  // Add field button
  addBtn.addEventListener('click', () => {
    trmnlp.addFieldRow(container, '', '');
  });

  // Save button
  saveBtn.addEventListener('click', async () => {
    const rows = container.querySelectorAll('.custom-field-row');
    const newCustomFields = {};

    rows.forEach(row => {
      const key = row.querySelector('input[name="key"]').value.trim();
      // Value can be either input or select
      const valueInput = row.querySelector('input[name="value"]');
      const valueSelect = row.querySelector('select[name="value"]');
      const value = valueInput ? valueInput.value : (valueSelect ? valueSelect.value : '');
      if (key) {
        newCustomFields[key] = value;
      }
    });

    saveBtn.disabled = true;
    saveBtn.textContent = 'Saving...';

    try {
      const response = await fetch('/api/config', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ custom_fields: newCustomFields })
      });

      const result = await response.json();

      if (result.error) {
        alert('Error saving: ' + result.error);
      } else {
        // Refresh the preview
        trmnlp.fetchPreview();

        // Update user data display
        const dataResponse = await fetch('/data');
        const userData = await dataResponse.json();
        trmnlp.userData.textContent = JSON.stringify(userData, null, 2);
        hljs.highlightAll();
      }
    } catch (err) {
      alert('Error saving: ' + err.message);
    }

    saveBtn.disabled = false;
    saveBtn.textContent = 'Save & Reload';
  });
};

trmnlp.addFieldRow = function(container, key, value) {
  trmnlp.addFieldRowWithHint(container, key, value, 'Value', false);
};

trmnlp.addSelectFieldRow = function(container, key, selectedValue, options) {
  const row = document.createElement('div');
  row.className = 'custom-field-row';

  const optionsHtml = options.map(opt => {
    const selected = String(opt) === String(selectedValue) ? 'selected' : '';
    return `<option value="${trmnlp.escapeHtml(String(opt))}" ${selected}>${trmnlp.escapeHtml(String(opt))}</option>`;
  }).join('');

  row.innerHTML = `
    <input type="text" name="key" placeholder="Field name" value="${trmnlp.escapeHtml(key)}" readonly class="required-field">
    <select name="value" class="custom-field-select">
      ${optionsHtml}
    </select>
    <button type="button" class="btn btn-remove" disabled>×</button>
  `;

  container.appendChild(row);
};

trmnlp.addFieldRowWithHint = function(container, key, value, placeholder, isRequired) {
  const row = document.createElement('div');
  row.className = 'custom-field-row';
  const keyReadonly = isRequired ? 'readonly' : '';
  const keyClass = isRequired ? 'required-field' : '';
  row.innerHTML = `
    <input type="text" name="key" placeholder="Field name" value="${trmnlp.escapeHtml(key)}" ${keyReadonly} class="${keyClass}">
    <input type="text" name="value" placeholder="${trmnlp.escapeHtml(placeholder)}" value="${trmnlp.escapeHtml(value)}">
    <button type="button" class="btn btn-remove" ${isRequired ? 'disabled' : ''}>×</button>
  `;

  const removeBtn = row.querySelector('.btn-remove');
  if (!isRequired) {
    removeBtn.addEventListener('click', () => {
      row.remove();
    });
  }

  container.appendChild(row);
};

trmnlp.escapeHtml = function(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
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
  });

  trmnlp.picker = await TRMNLPicker.create('picker-form', { localStorageKey: 'trmnlp-picker' });

  // Initialize custom fields editor
  trmnlp.initCustomFieldsEditor();
});
