// Sends the host inquiry form to Firestore (hostInquiries), whose rules
// allow creating one with these fields only. A hidden field catches bots.
(function () {
  var form = document.getElementById("host-form");
  var status = document.getElementById("host-status");
  if (!form || !window.fetch) return;
  var url = "https://firestore.googleapis.com/v1/projects/battlebaseball-prod/databases/(default)/documents/hostInquiries?key=AIzaSyCzgOv4-sEQOaEW4Ig14o9PWAen8xQa5Mo";
  form.addEventListener("submit", function (ev) {
    ev.preventDefault();
    var d = new FormData(form);
    if (d.get("website")) return;
    var team = String(d.get("team") || "").trim();
    var contact = String(d.get("contact") || "").trim();
    var email = String(d.get("email") || "").trim();
    if (!team || !contact || email.indexOf("@") < 1) {
      status.className = "form-status err";
      status.textContent = "Please fill in your team, your name, and your email.";
      return;
    }
    var s = function (k) { return { stringValue: String(d.get(k) || "").trim() }; };
    var body = {
      fields: {
        team: s("team"), city: s("city"), contact: s("contact"), email: s("email"),
        phone: s("phone"), message: s("message"), status: { stringValue: "new" },
        createdAt: { timestampValue: new Date().toISOString() }
      }
    };
    status.className = "form-status";
    status.textContent = "Sending…";
    fetch(url, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) })
      .then(function (r) {
        if (!r.ok) throw new Error(r.status);
        form.reset();
        status.className = "form-status ok";
        status.textContent = "Thanks! We'll be in touch soon.";
      })
      .catch(function () {
        status.className = "form-status err";
        status.textContent = "That didn't go through. Email support@getbattleplan.app and we'll get back to you.";
      });
  });
})();
