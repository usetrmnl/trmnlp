var TRMNLPicker = (() => {
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to, key) && key !== except)
          __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to;
  };
  var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

  // src/index.js
  var src_exports = {};
  __export(src_exports, {
    default: () => src_default
  });
  var _DEFAULT_MODEL_NAME = "og_plus";
  var _API_CACHE_KEY = "trmnl-picker-api-cache";
  var _CACHE_TTL_MS = 24 * 60 * 60 * 1e3;
  var TRMNLPicker = class _TRMNLPicker {
    static API_BASE_URL = "https://usetrmnl.com";
    /**
     * Get cached API response from localStorage
     * @private
     * @static
     * @returns {{models: Array, palettes: Array} | null} Cached data or null if expired/missing
     */
    static _getCachedApiData() {
      try {
        const cached = localStorage.getItem(_API_CACHE_KEY);
        if (!cached)
          return null;
        const { timestamp, models, palettes } = JSON.parse(cached);
        const now = Date.now();
        if (now - timestamp > _CACHE_TTL_MS) {
          localStorage.removeItem(_API_CACHE_KEY);
          return null;
        }
        return { models, palettes };
      } catch (error) {
        console.warn("TRMNLPicker: Failed to read API cache:", error);
        return null;
      }
    }
    /**
     * Save API response to localStorage cache
     * @private
     * @static
     * @param {Array} models - Models array
     * @param {Array} palettes - Palettes array
     */
    static _setCachedApiData(models, palettes) {
      try {
        const cacheData = {
          timestamp: Date.now(),
          models,
          palettes
        };
        localStorage.setItem(_API_CACHE_KEY, JSON.stringify(cacheData));
      } catch (error) {
        console.warn("TRMNLPicker: Failed to save API cache:", error);
      }
    }
    /**
     * Create a TRMNLPicker instance, fetching data from TRMNL API if not provided
     *
     * Automatically caches API responses in localStorage for 24 hours to reduce network requests.
     *
     * @static
     * @param {string|Element} formIdOrElement - Form element ID or DOM element
     * @param {Object} options - Configuration options
     * @param {Array<Object>} [options.models] - Optional models array (fetched from API if not provided)
     * @param {Array<Object>} [options.palettes] - Optional palettes array (fetched from API if not provided)
     * @param {string} [options.localStorageKey] - Optional key for state persistence
     * @returns {Promise<TRMNLPicker>} Promise resolving to picker instance
     * @throws {Error} If API fetch fails when models or palettes are not provided
     *
     * @example
     * // Fetch models and palettes from API (or use cached data if available)
     * const picker = await TRMNLPicker.create('screen-picker')
     *
     * // Provide your own data
     * const picker = await TRMNLPicker.create('screen-picker', { models, palettes })
     */
    static async create(formId, options = {}) {
      let { models, palettes, localStorageKey } = options;
      if (!models && !palettes) {
        const cached = _TRMNLPicker._getCachedApiData();
        if (cached) {
          models = cached.models;
          palettes = cached.palettes;
        }
      }
      if (!models) {
        try {
          const response = await fetch(`${_TRMNLPicker.API_BASE_URL}/api/models`);
          if (!response.ok) {
            throw new Error(`Failed to fetch models: ${response.status} ${response.statusText}`);
          }
          const data = await response.json();
          models = data.data || data;
        } catch (error) {
          throw new Error(`TRMNLPicker: Failed to fetch models from API: ${error.message}`);
        }
      }
      if (!palettes) {
        try {
          const response = await fetch(`${_TRMNLPicker.API_BASE_URL}/api/palettes`);
          if (!response.ok) {
            throw new Error(`Failed to fetch palettes: ${response.status} ${response.statusText}`);
          }
          const data = await response.json();
          palettes = data.data || data;
        } catch (error) {
          throw new Error(`TRMNLPicker: Failed to fetch palettes from API: ${error.message}`);
        }
      }
      if (!options.models && !options.palettes) {
        _TRMNLPicker._setCachedApiData(models, palettes);
      }
      return new _TRMNLPicker(formId, { models, palettes, localStorageKey });
    }
    constructor(formIdOrElement, options = {}) {
      if (!formIdOrElement) {
        throw new Error("TRMNLPicker: formIdOrElement is required");
      }
      if (typeof formIdOrElement === "string") {
        this.formElement = document.getElementById(formIdOrElement);
        if (!this.formElement) {
          throw new Error(`TRMNLPicker: Form element with id "${formIdOrElement}" not found`);
        }
      } else if (formIdOrElement instanceof Element) {
        this.formElement = formIdOrElement;
      } else {
        throw new Error("TRMNLPicker: formIdOrElement must be a string ID or DOM element");
      }
      const { models, palettes, localStorageKey } = options;
      this.models = models;
      this.palettes = palettes;
      this.localStorageKey = localStorageKey;
      if (this.models && this.palettes) {
        if (!Array.isArray(this.models) || this.models.length === 0) {
          throw new Error("TRMNLPicker: models must be a non-empty array");
        }
        if (!Array.isArray(this.palettes) || this.palettes.length === 0) {
          throw new Error("TRMNLPicker: palettes must be a non-empty array");
        }
        this.models = this._filterValidModels();
        if (this.models.length === 0) {
          throw new Error("TRMNLPicker: no valid models found (all models have palettes with empty framework_class)");
        }
        this._initializeElements();
        this._bindEvents();
        this._setInitialState();
      }
    }
    /**
     * Filter out models where all their palettes have empty framework_class
     * @private
     * @returns {Array<Object>} Filtered models array
     */
    _filterValidModels() {
      return this.models.filter((model) => {
        return model.palette_ids.some((paletteId) => {
          const palette = this.palettes.find((p) => p.id === paletteId);
          return palette && palette.framework_class && palette.framework_class.trim() !== "";
        });
      });
    }
    /**
     * Get the first valid palette ID for a model (one with non-empty framework_class)
     * @private
     * @param {Object} model - Model object
     * @returns {string|null} First valid palette ID or null
     */
    _getFirstValidPaletteId(model) {
      if (!model)
        return null;
      for (const paletteId of model.palette_ids) {
        const palette = this.palettes.find((p) => p.id === paletteId);
        if (palette && palette.framework_class && palette.framework_class.trim() !== "") {
          return paletteId;
        }
      }
      return null;
    }
    /**
     * Find and store references to form elements using data-* attributes
     * @private
     */
    _initializeElements() {
      this.elements = {
        modelSelect: this.formElement.querySelector("[data-model-select]"),
        paletteSelect: this.formElement.querySelector("[data-palette-select]"),
        orientationToggle: this.formElement.querySelector("[data-orientation-toggle]"),
        darkModeToggle: this.formElement.querySelector("[data-dark-mode-toggle]"),
        resetButton: this.formElement.querySelector("[data-reset-button]"),
        // Optional: UI indicator elements
        orientationText: this.formElement.querySelector("[data-orientation-text]"),
        darkModeText: this.formElement.querySelector("[data-dark-mode-text]")
      };
      const required = ["modelSelect", "paletteSelect"];
      for (const key of required) {
        if (!this.elements[key]) {
          throw new Error(`TRMNLPicker: Required element "${key}" not found in form`);
        }
      }
    }
    /**
     * Bind event listeners to form elements
     * @private
     */
    _bindEvents() {
      this.handlers = {
        modelChange: this._handleModelChange.bind(this),
        paletteChange: this._handlePaletteChange.bind(this),
        orientationToggle: this._toggleOrientation.bind(this),
        darkModeToggle: this._toggleDarkMode.bind(this),
        reset: this._resetToModelDefaults.bind(this)
      };
      this.elements.modelSelect.addEventListener("change", this.handlers.modelChange);
      this.elements.paletteSelect.addEventListener("change", this.handlers.paletteChange);
      if (this.elements.orientationToggle) {
        this.elements.orientationToggle.addEventListener("click", this.handlers.orientationToggle);
      }
      if (this.elements.darkModeToggle) {
        this.elements.darkModeToggle.addEventListener("click", this.handlers.darkModeToggle);
      }
      if (this.elements.resetButton) {
        this.elements.resetButton.addEventListener("click", this.handlers.reset);
      }
    }
    /**
     * Set initial state and populate form
     * @private
     */
    _setInitialState() {
      const trmnlModels = this.models.filter((m) => m.kind === "trmnl");
      const byodModels = this.models.filter((m) => m.kind !== "trmnl");
      const sortTRMNL = [...trmnlModels].sort((a, b) => {
        const labelA = (a.label || a.name).toLowerCase();
        const labelB = (b.label || b.name).toLowerCase();
        return labelA.localeCompare(labelB);
      });
      const sortBYOD = [...byodModels].sort((a, b) => {
        const labelA = (a.label || a.name).toLowerCase();
        const labelB = (b.label || b.name).toLowerCase();
        return labelA.localeCompare(labelB);
      });
      this.elements.modelSelect.innerHTML = "";
      if (sortTRMNL.length > 0) {
        const trmnlGroup = document.createElement("optgroup");
        trmnlGroup.label = "TRMNL";
        sortTRMNL.forEach((model) => {
          const option = document.createElement("option");
          option.value = model.name;
          option.textContent = model.label || model.name;
          trmnlGroup.appendChild(option);
        });
        this.elements.modelSelect.appendChild(trmnlGroup);
      }
      if (sortBYOD.length > 0) {
        const byodGroup = document.createElement("optgroup");
        byodGroup.label = "BYOD";
        sortBYOD.forEach((model) => {
          const option = document.createElement("option");
          option.value = model.name;
          option.textContent = model.label || model.name;
          byodGroup.appendChild(option);
        });
        this.elements.modelSelect.appendChild(byodGroup);
      }
      const sortedModels = [...sortTRMNL, ...sortBYOD];
      this._state = {};
      const savedParams = this._loadFromLocalStorage();
      if (savedParams) {
        this._setParams("constructor", savedParams);
      } else {
        const defaultModel = sortedModels.find((m) => m.name === _DEFAULT_MODEL_NAME) || sortedModels[0];
        const defaultPaletteId = this._getFirstValidPaletteId(defaultModel);
        this._setParams("constructor", {
          modelName: defaultModel.name,
          paletteId: defaultPaletteId,
          isPortrait: false,
          isDarkMode: false
        });
      }
    }
    /**
     * Populate palette dropdown based on selected model
     * @private
     */
    _populateModelPalettes() {
      const modelName = this.elements.modelSelect.value;
      const model = this.models.find((m) => m.name === modelName);
      if (!model)
        return;
      this.elements.paletteSelect.innerHTML = "";
      model.palette_ids.forEach((paletteId) => {
        const palette = this.palettes.find((p) => p.id === paletteId);
        if (palette && palette.framework_class && palette.framework_class.trim() !== "") {
          const option = document.createElement("option");
          option.value = palette.id;
          option.textContent = palette.name;
          this.elements.paletteSelect.appendChild(option);
        }
      });
    }
    /**
     * Emit 'trmnl:change' event with current state and screen classes
     * @private
     * @param {string} origin - Source of the change ('constructor', 'form', 'setParams')
     * @fires TRMNLPicker#trmnl:change
     */
    _emitChangeEvent(origin) {
      this._saveToLocalStorage();
      const event = new CustomEvent("trmnl:change", {
        detail: {
          origin,
          ...this.state
        },
        bubbles: true
      });
      this.formElement.dispatchEvent(event);
    }
    /**
     * Load state from localStorage
     * @private
     * @returns {Object|null} Saved state or null if not available
     */
    _loadFromLocalStorage() {
      if (!this.localStorageKey)
        return null;
      try {
        const saved = localStorage.getItem(this.localStorageKey);
        if (saved) {
          return JSON.parse(saved);
        }
      } catch (error) {
        console.warn("TRMNLPicker: Failed to load from localStorage:", error);
      }
      return null;
    }
    /**
     * Save current state to localStorage
     * @private
     */
    _saveToLocalStorage() {
      if (!this.localStorageKey)
        return;
      try {
        localStorage.setItem(this.localStorageKey, JSON.stringify(this.params));
      } catch (error) {
        console.warn("TRMNLPicker: Failed to save to localStorage:", error);
      }
    }
    /**
     * Handle model selection change
     * @private
     */
    _handleModelChange(event) {
      this._setParams("form", { modelName: event.target.value });
    }
    /**
     * Handle palette selection change
     * @private
     */
    _handlePaletteChange(event) {
      this._setParams("form", { paletteId: event.target.value });
    }
    /**
     * Toggle orientation between portrait and landscape
     * @private
     */
    _toggleOrientation() {
      this._setParams("form", { isPortrait: !this._state.isPortrait });
    }
    /**
     * Toggle dark mode on/off
     * @private
     */
    _toggleDarkMode() {
      this._setParams("form", { isDarkMode: !this._state.isDarkMode });
    }
    /**
     * Reset to defaults: first valid palette, landscape orientation, light mode
     * @private
     */
    _resetToModelDefaults() {
      const model = this._state.model;
      if (!model)
        return;
      const firstPaletteId = this._getFirstValidPaletteId(model);
      this._setParams("form", {
        paletteId: firstPaletteId,
        isPortrait: false,
        isDarkMode: false
      });
    }
    /**
     * Update reset button enabled/disabled state
     * Button is disabled only when palette, orientation, and dark mode are all at defaults
     * @private
     */
    _updateResetButton() {
      if (!this.elements.resetButton)
        return;
      const model = this._state.model;
      if (!model)
        return;
      const firstValidPaletteId = this._getFirstValidPaletteId(model);
      const isPaletteDefault = this.elements.paletteSelect.value === String(firstValidPaletteId);
      const isOrientationDefault = this._state.isPortrait === false;
      const isDarkModeDefault = this._state.isDarkMode === false;
      const isAtDefaults = isPaletteDefault && isOrientationDefault && isDarkModeDefault;
      this.elements.resetButton.disabled = isAtDefaults;
      if (isAtDefaults) {
        this.elements.resetButton.classList.add("opacity-50", "cursor-default");
        this.elements.resetButton.setAttribute("aria-disabled", "true");
      } else {
        this.elements.resetButton.classList.remove("opacity-50", "cursor-default");
        this.elements.resetButton.removeAttribute("aria-disabled");
      }
    }
    /**
     * Get CSS classes for the current picker configuration
     * @private
     * @returns {Array<string>} Array of CSS class names for Framework CSS rendering
     *
     * Generated classes (in order):
     * 1. 'screen' - Base class (always present)
     * 2. palette.framework_class - From selected palette (e.g., 'screen--1bit')
     * 3. model.css.classes.device - From model API (e.g., 'screen--v2')
     * 4. model.css.classes.size - From model API (e.g., 'screen--md')
     * 5. 'screen--portrait' - Only when portrait orientation is enabled
     * 6. 'screen--1x' - Scale indicator (always 1x)
     * 7. 'screen--dark-mode' - Only when dark mode is enabled
     *
     * @example
     * const classes = picker.screenClasses
     * // ['screen', 'screen--1bit', 'screen--v2', 'screen--md', 'screen--1x']
     */
    get _screenClasses() {
      const model = this._state.model;
      const palette = this._state.palette;
      if (!model) {
        throw new Error("No model selected");
      }
      const classes = [];
      classes.push("screen");
      if (palette && palette.framework_class) {
        classes.push(palette.framework_class);
      }
      if (model.css && model.css.classes && model.css.classes.device) {
        classes.push(model.css.classes.device);
      }
      if (model.css && model.css.classes && model.css.classes.size) {
        classes.push(model.css.classes.size);
      }
      if (this._state.isPortrait) {
        classes.push("screen--portrait");
      }
      classes.push("screen--1x");
      if (this._state.isDarkMode) {
        classes.push("screen--dark-mode");
      }
      return classes;
    }
    /**
     * Get current picker parameters (serializable state)
     * @public
     * @returns {Object} Current parameters for persistence or API calls
     * @returns {string} return.modelName - Selected model name
     * @returns {string} return.paletteId - Selected palette ID
     * @returns {boolean} return.isPortrait - Portrait orientation flag
     * @returns {boolean} return.isDarkMode - Dark mode flag
     *
     * @example
     * const params = picker.params
     * // { modelName: 'og_plus', paletteId: '123', isPortrait: false, isDarkMode: false }
     *
     * // Can be used to restore state later
     * localStorage.setItem('picker-state', JSON.stringify(picker.params))
     */
    get params() {
      return {
        modelName: this._state.model?.name,
        paletteId: this._state.palette?.id,
        isPortrait: this._state.isPortrait,
        isDarkMode: this._state.isDarkMode
      };
    }
    /**
     * Update picker configuration programmatically
     * @public
     * @param {Object} params - Configuration object (all fields optional)
     * @param {string} [params.modelName] - Model name to select
     * @param {string} [params.paletteId] - Palette ID to select
     * @param {boolean} [params.isPortrait] - Portrait orientation
     * @param {boolean} [params.isDarkMode] - Dark mode enabled
     * @fires TRMNLPicker#trmnl:change
     * @throws {Error} If params is not an object
     *
     * @example
     * // Update single parameter
     * picker.setParams({ isDarkMode: true })
     *
     * // Update multiple parameters
     * picker.setParams({
     *   modelName: 'og_plus',
     *   paletteId: '123',
     *   isPortrait: true
     * })
     *
     * // Note: Changing model resets palette to first valid palette of that model
     */
    setParams(params) {
      this._setParams("setParams", params);
    }
    /**
     * Internal method to update picker state with origin tracking
     * @private
     * @param {string} origin - Source of change ('constructor', 'form', 'setParams')
     * @param {Object} params - Parameters to update
     * @returns {boolean} True if any changes were made
     */
    _setParams(origin, params) {
      if (!params || typeof params !== "object") {
        throw new Error("params must be an object");
      }
      let changed = false;
      if (params.modelName) {
        const model = this.models.find((m) => m.name === params.modelName);
        if (model) {
          this.elements.modelSelect.value = model.name;
          this._state.model = model;
          this._populateModelPalettes();
          const firstPaletteId = this._getFirstValidPaletteId(model);
          this.elements.paletteSelect.value = firstPaletteId;
          this._state.palette = this.palettes.find((p) => p.id === firstPaletteId);
          changed = true;
        }
      }
      if (params.paletteId) {
        const palette = this.palettes.find((p) => p.id === params.paletteId);
        if (palette) {
          this.elements.paletteSelect.value = palette.id;
          this._state.palette = palette;
          changed = true;
        }
      }
      if (typeof params.isPortrait === "boolean") {
        this._state.isPortrait = params.isPortrait;
        if (this.elements.orientationText) {
          this.elements.orientationText.textContent = this._state.isPortrait ? "Portrait" : "Landscape";
        }
        changed = true;
      }
      if (typeof params.isDarkMode === "boolean") {
        this._state.isDarkMode = params.isDarkMode;
        if (this.elements.darkModeText) {
          this.elements.darkModeText.textContent = this._state.isDarkMode ? "Dark Mode" : "Light Mode";
        }
        changed = true;
      }
      if (changed) {
        this._updateResetButton();
      }
      if (changed && origin) {
        this._emitChangeEvent(origin);
      }
      return changed;
    }
    /**
     * Get complete picker state including full model and palette objects
     * @public
     * @returns {{
     *   model: Object,
     *   palette: Object,
     *   isPortrait: boolean,
     *   isDarkMode: boolean,
     *   screenClasses: Array<string>,
     *   width: number,
     *   height: number
     * }} State object containing model (full model object from API), palette (full palette object from API), isPortrait flag, and isDarkMode flag
     *
     * @example
     * const state = picker.state
     * // {
     * //   model: { name: 'og_plus', label: 'OG+', width: 800, height: 480, ... },
     * //   palette: { id: '123', name: 'Black', framework_class: 'screen--1bit', ... },
     * //   isPortrait: false,
     * //   isDarkMode: false,
     * //   screenClasses: ['screen', 'screen--1bit', 'screen--v2', 'screen--md', 'screen--1x'],
     * //   width: 800,
     * //   height: 480
     * // }
     */
    get state() {
      return {
        screenClasses: this._screenClasses,
        ...this._dimensions,
        ...this._state
      };
    }
    /**
     * Get current dimensions (width and height) of the screen in pixels
     * @private
     * @returns {{ width: number, height: number }} Object with width and height properties
     */
    get _dimensions() {
      const model = this._state.model;
      let width = model.width / model.scale_factor;
      let height = model.height / model.scale_factor;
      if (this._state.isPortrait) {
        [width, height] = [height, width];
      }
      return { width, height };
    }
    /**
     * Clean up event listeners and references
     * @public
     */
    destroy() {
      this.elements.modelSelect.removeEventListener("change", this.handlers.modelChange);
      this.elements.paletteSelect.removeEventListener("change", this.handlers.paletteChange);
      if (this.elements.orientationToggle) {
        this.elements.orientationToggle.removeEventListener("click", this.handlers.orientationToggle);
      }
      if (this.elements.darkModeToggle) {
        this.elements.darkModeToggle.removeEventListener("click", this.handlers.darkModeToggle);
      }
      if (this.elements.resetButton) {
        this.elements.resetButton.removeEventListener("click", this.handlers.reset);
      }
      this.formElement = null;
      this.elements = null;
      this.handlers = null;
      this.models = null;
      this.palettes = null;
      this._state = null;
    }
  };
  var src_default = TRMNLPicker;
  return __toCommonJS(src_exports);
})();
TRMNLPicker=TRMNLPicker.default;
//# sourceMappingURL=trmnl-picker.js.map
