(function() {
  var storageKey = "mark-sui-theme";

  function storedTheme() {
    try {
      return localStorage.getItem(storageKey);
    } catch (error) {
      return null;
    }
  }

  function saveTheme(theme) {
    try {
      localStorage.setItem(storageKey, theme);
    } catch (error) {
      return;
    }
  }

  function setTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
  }

  function updateButton(button, theme) {
    var icon = button.querySelector(".theme-toggle-icon");
    var label = button.querySelector(".theme-toggle-label");
    icon.textContent = theme === "dark" ? "L" : "D";
    label.textContent = theme === "dark" ? "Light" : "Dark";
    button.setAttribute(
      "aria-label",
      theme === "dark" ? "Switch to light theme" : "Switch to dark theme"
    );
  }

  var initialTheme = storedTheme() || "light";
  setTheme(initialTheme);

  document.addEventListener("DOMContentLoaded", function() {
    if (!document.body) {
      return;
    }

    var button = document.createElement("button");
    button.type = "button";
    button.className = "theme-toggle";

    var icon = document.createElement("span");
    icon.className = "theme-toggle-icon";
    icon.setAttribute("aria-hidden", "true");

    var label = document.createElement("span");
    label.className = "theme-toggle-label";

    button.appendChild(icon);
    button.appendChild(label);
    updateButton(button, document.documentElement.getAttribute("data-theme"));

    button.addEventListener("click", function() {
      var currentTheme = document.documentElement.getAttribute("data-theme");
      var nextTheme = currentTheme === "dark" ? "light" : "dark";
      setTheme(nextTheme);
      saveTheme(nextTheme);
      updateButton(button, nextTheme);
    });

    var nav = document.querySelector("header nav");
    var header = document.querySelector("header");
    if (header && nav) {
      header.insertBefore(button, nav);
      return;
    }

    (header || document.body).appendChild(button);
  });
})();
