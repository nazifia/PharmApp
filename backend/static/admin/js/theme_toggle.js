/**
 * PharmApp Admin — Dark / Light theme toggle
 * Persists preference to localStorage under key 'pharmapp-theme'.
 * Applies theme by setting data-bs-theme on <html> (Jazzmin/Bootstrap 5).
 */
(function () {
  'use strict';

  var STORAGE_KEY = 'pharmapp-theme';
  var DEFAULT     = 'dark';

  // ── Apply saved theme immediately (before DOM ready) to prevent FOUC ──────
  var saved = localStorage.getItem(STORAGE_KEY) || DEFAULT;
  document.documentElement.setAttribute('data-bs-theme', saved);

  // ── After DOM is ready, inject the toggle button ──────────────────────────
  document.addEventListener('DOMContentLoaded', function () {

    function currentTheme() {
      return document.documentElement.getAttribute('data-bs-theme') || DEFAULT;
    }

    function applyTheme(theme) {
      document.documentElement.setAttribute('data-bs-theme', theme);
      localStorage.setItem(STORAGE_KEY, theme);
      updateIcon(theme);
    }

    function updateIcon(theme) {
      var btn = document.getElementById('pharm-theme-btn');
      if (!btn) return;
      var icon  = btn.querySelector('.theme-icon');
      var label = btn.querySelector('.theme-label');
      if (theme === 'dark') {
        if (icon)  icon.textContent  = '☀️';
        if (label) label.textContent = 'Light mode';
        btn.title = 'Switch to light mode';
      } else {
        if (icon)  icon.textContent  = '🌙';
        if (label) label.textContent = 'Dark mode';
        btn.title = 'Switch to dark mode';
      }
    }

    // Build the button element
    var li  = document.createElement('li');
    li.className = 'nav-item';
    li.innerHTML = (
      '<a id="pharm-theme-btn" href="#" role="button"'
      + ' style="display:inline-flex;align-items:center;gap:5px;'
      + 'padding:0.4rem 0.75rem;color:#94a3b8;text-decoration:none;'
      + 'font-size:13px;transition:color 0.15s;white-space:nowrap">'
      + '<span class="theme-icon" style="font-size:15px"></span>'
      + '<span class="theme-label" style="font-size:12px;font-weight:500"></span>'
      + '</a>'
    );

    // Insert into the right-side navbar (try multiple selectors for compatibility)
    var navbar = (
      document.querySelector('.navbar-nav.ml-auto')
      || document.querySelector('.navbar-nav.ms-auto')
      || document.querySelector('ul.navbar-right')
      || document.querySelector('.navbar-nav')
    );
    if (navbar) {
      navbar.insertBefore(li, navbar.firstChild);
    }

    // Set initial icon state
    updateIcon(currentTheme());

    // Click handler
    document.getElementById('pharm-theme-btn') &&
      document.getElementById('pharm-theme-btn').addEventListener('click', function (e) {
        e.preventDefault();
        applyTheme(currentTheme() === 'dark' ? 'light' : 'dark');
      });

    // Hover style
    document.getElementById('pharm-theme-btn') &&
      document.getElementById('pharm-theme-btn').addEventListener('mouseenter', function () {
        this.style.color = '#e2e8f0';
      });
    document.getElementById('pharm-theme-btn') &&
      document.getElementById('pharm-theme-btn').addEventListener('mouseleave', function () {
        this.style.color = '#94a3b8';
      });
  });
})();
