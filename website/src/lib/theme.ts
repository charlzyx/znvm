export const themeStorageKey = "znvm-theme";

// Runs from the document head before first paint. Stored light/dark wins.
// Anything else follows prefers-color-scheme.
export const themeBootScript = `(function(){try{var t=localStorage.getItem("${themeStorageKey}");var d=t==="dark"||(t!=="light"&&window.matchMedia("(prefers-color-scheme: dark)").matches);var r=document.documentElement;r.classList.remove("light","dark");r.classList.add(d?"dark":"light");r.style.colorScheme=d?"dark":"light";}catch(e){}})();`;
