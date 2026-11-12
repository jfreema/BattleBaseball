// Fills the landing page's event list from the app's live data, through
// Firestore's REST API (public events only; the rules allow reading them).
// The page reads fine without it: the fallback card stays.
(function () {
  var list = document.getElementById("event-list");
  if (!list || !window.fetch) return;
  var url = "https://firestore.googleapis.com/v1/projects/battlebaseball-prod/databases/(default)/documents:runQuery?key=AIzaSyCzgOv4-sEQOaEW4Ig14o9PWAen8xQa5Mo";
  var body = {
    structuredQuery: {
      from: [{ collectionId: "events" }],
      where: {
        fieldFilter: {
          field: { fieldPath: "status" },
          op: "IN",
          value: { arrayValue: { values: [{ stringValue: "open" }, { stringValue: "closed" }, { stringValue: "live" }] } }
        }
      },
      limit: 12
    }
  };
  function val(f, k) {
    var v = f && f[k];
    if (!v) return null;
    return v.stringValue != null ? v.stringValue
      : v.integerValue != null ? Number(v.integerValue)
      : v.doubleValue != null ? v.doubleValue
      : v.booleanValue != null ? v.booleanValue
      : v.timestampValue != null ? new Date(v.timestampValue) : null;
  }
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  var labels = { open: "Registration open", closed: "Registration closed", live: "Happening now" };
  fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
    .then(function (r) { return r.ok ? r.json() : []; })
    .then(function (rows) {
      var events = rows.filter(function (r) { return r.document; }).map(function (r) {
        var f = r.document.fields || {};
        return {
          id: r.document.name.split("/").pop(),
          name: val(f, "name") || "Battle Baseball Showcase",
          status: val(f, "status"),
          start: val(f, "start"),
          city: val(f, "city") || "Baton Rouge, LA",
          venue: val(f, "venue") || "",
          ages: val(f, "ageGroups") || "",
          price: val(f, "price"),
          host: val(f, "hostTeam") || ""
        };
      });
      if (!events.length) return;
      events.sort(function (a, b) { return (a.start || 9e15) - (b.start || 9e15); });
      list.textContent = "";
      events.forEach(function (e) {
        var li = el("li");
        var a = el("a", "event");
        a.href = "/app/events/" + encodeURIComponent(e.id);
        a.appendChild(el("span", "eyebrow", (e.ages ? e.ages + " · " : "") + "Player showcase"));
        a.appendChild(el("h3", null, e.name));
        var when = e.start ? e.start.toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" }) : "Date coming soon";
        a.appendChild(el("p", null, when + " · " + (e.venue ? e.venue + ", " : "") + e.city));
        var chips = el("div");
        chips.appendChild(el("span", "chip" + (e.status === "open" ? " go" : ""), labels[e.status] || e.status));
        chips.appendChild(el("span", "chip", e.price != null ? "$" + e.price : "Price coming soon"));
        if (e.host) chips.appendChild(el("span", "chip", "Hosted by " + e.host));
        a.appendChild(chips);
        li.appendChild(a);
        list.appendChild(li);
      });
    })
    .catch(function () {});
})();
