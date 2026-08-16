const root = document.getElementById("app");
const toast = document.getElementById("toast");
const confirmDialog = document.getElementById("confirm-dialog");
const state = { page: "dashboard", license: null, device: null, business: null, query: "", invoiceDraft: { customerMode: "saved", items: [{}] }, posDraft: { items: [], customerId: "", walkInName: "", walkInPhone: "", paymentMethod: "CASH", amountReceived: "", search: "", heldBillId: null }, autoPrintInvoice: false };
const icon = (name, className = "") => window.AVSBIcon(name, className);

const navItems = [
  ["dashboard", "dashboard", "Dashboard"], ["pos", "cart", "Quick POS"], ["customers", "users", "Customers"], ["products", "package", "Products"],
  ["inventory", "inventory", "Inventory"], ["invoices", "file", "Invoices"], ["payments", "payment", "Payments"], ["reports", "reports", "Reports"], ["settings", "settings", "Settings"],
];

function esc(value) {
  return String(value ?? "").replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character]);
}
function money(paise) { return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(Number(paise || 0) / 100); }
function date(value, time = false) { if (!value) return "—"; return new Date(value).toLocaleString("en-IN", time ? { dateStyle: "medium", timeStyle: "short" } : { dateStyle: "medium" }); }
function today() { return new Date().toISOString().slice(0, 10); }
function inputDate(days = 0) { const value = new Date(); value.setDate(value.getDate() + days); return value.toISOString().slice(0, 10); }
function status(value) { return `<span class="status ${esc(value)}">${esc(String(value).replaceAll("_", " "))}</span>`; }
function initials(value) { return String(value || "AV").trim().split(/\s+/).slice(0, 2).map((part) => part[0]).join("").toUpperCase(); }
function phoneDigits(value) { return String(value || "").replace(/\D/g, "").slice(0, 10); }
function formatLicenseKey(value) {
  const characters = String(value || "").toUpperCase().replace(/[^A-Z0-9]/g, "").slice(0, 16);
  return characters.match(/.{1,4}/g)?.join("-") || "";
}
function configureRestrictedInput(input) {
  if (!(input instanceof HTMLInputElement)) return;
  if (input.type === "tel" || ["phone", "walkInPhone", "posWalkInPhone"].includes(input.name)) {
    input.type = "tel";
    input.inputMode = "numeric";
    input.maxLength = 10;
    input.pattern = "[0-9]{10}";
    input.title = "Enter exactly 10 digits.";
  }
  if (input.name === "licenseKey") {
    input.maxLength = 19;
    input.pattern = "[A-Z0-9]{4}(?:-[A-Z0-9]{4}){3}";
    input.title = "Enter a license key in ABCD-EFGH-JKLM-NPQR format.";
  }
}

root.addEventListener("focusin", (event) => configureRestrictedInput(event.target));
root.addEventListener("input", (event) => {
  const input = event.target;
  configureRestrictedInput(input);
  if (!(input instanceof HTMLInputElement)) return;
  if (input.type === "tel" || ["phone", "walkInPhone", "posWalkInPhone"].includes(input.name)) input.value = phoneDigits(input.value);
  if (input.name === "licenseKey") input.value = formatLicenseKey(input.value);
}, true);

async function invoke(channel, input) {
  const result = await window.avSmartbilling.invoke(channel, input);
  if (!result.ok) throw new Error(result.message || "Operation failed.");
  return result.data;
}

function notify(message, error = false) {
  toast.textContent = message;
  toast.className = `toast show${error ? " error" : ""}`;
  clearTimeout(notify.timer);
  notify.timer = setTimeout(() => { toast.className = "toast"; }, 4500);
}

function confirmAction(title, message) {
  document.getElementById("confirm-title").textContent = title;
  document.getElementById("confirm-message").textContent = message;
  confirmDialog.showModal();
  return new Promise((resolve) => {
    confirmDialog.addEventListener("close", () => resolve(confirmDialog.returnValue === "confirm"), { once: true });
  });
}

function field(label, name, value = "", options = {}) {
  const full = options.full ? " full" : "";
  if (options.textarea) return `<label class="field${full}"><span>${esc(label)}</span><textarea class="textarea" name="${esc(name)}" ${options.required ? "required" : ""}>${esc(value)}</textarea></label>`;
  return `<label class="field${full}"><span>${esc(label)}</span><input class="input" type="${options.type || "text"}" name="${esc(name)}" value="${esc(value)}" ${options.required ? "required" : ""} ${options.step ? `step="${options.step}"` : ""} ${options.min !== undefined ? `min="${options.min}"` : ""}></label>`;
}

async function boot() {
  try {
    const bootstrap = await invoke("app:bootstrap");
    state.license = bootstrap.license;
    state.device = bootstrap.device;
    state.business = bootstrap.business;
    if (!state.license.active) return renderActivation();
    renderShell();
    await navigate("dashboard");
  } catch (error) {
    root.innerHTML = `<main class="activation"><section class="activation-card"><p class="eyebrow">AV Smartbilling</p><h1>Unable to start local billing</h1><p class="notice error">${esc(error.message)}</p></section></main>`;
  }
}

function renderActivation() {
  const expired = state.license?.activated && !state.license.active;
  root.innerHTML = `<main class="activation"><section class="activation-card"><div class="brand-mark">${icon("receipt")}</div><p class="eyebrow" style="margin-top:18px">AV Smartbilling Desktop</p><h1>${expired ? "Validate this installation" : "Activate this device"}</h1><p class="muted">Billing data is stored locally in SQLite and works offline. Internet is needed only for activation, periodic validation, cloud backup and restore.</p>${state.license?.error ? `<p class="notice error">${esc(state.license.error)}</p>` : ""}
    <form id="activation-form" class="form-grid" style="margin-top:24px">
      ${field("License key", "licenseKey", "", { required: true, full: true })}
      ${field("Device name", "deviceName", state.device?.deviceName || "This computer", { required: true, full: true })}
      <div class="field full"><button class="button" type="submit">Activate software</button></div>
    </form>
    ${expired ? `<button id="validate-license" class="button secondary" style="width:100%;margin-top:12px">Validate stored activation online</button>` : ""}
    <p class="muted" style="font-size:11px;margin-top:20px">The admin Control Center is not included in this software.</p>
  </section></main>`;
  document.getElementById("activation-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const button = event.currentTarget.querySelector("button");
    button.disabled = true; button.textContent = "Activating…";
    try {
      const data = Object.fromEntries(new FormData(event.currentTarget));
      state.license = await invoke("license:activate", data);
      notify("Activation successful.");
      renderShell(); await navigate("dashboard");
    } catch (error) { notify(error.message, true); button.disabled = false; button.textContent = "Activate software"; }
  });
  document.getElementById("validate-license")?.addEventListener("click", async (event) => {
    event.currentTarget.disabled = true; event.currentTarget.textContent = "Validating…";
    try { state.license = await invoke("license:validate"); renderShell(); await navigate("dashboard"); notify("License validated."); }
    catch (error) { notify(error.message, true); event.currentTarget.disabled = false; event.currentTarget.textContent = "Validate stored activation online"; }
  });
}

function renderShell() {
  root.innerHTML = `<div class="shell"><button class="sidebar-backdrop" id="sidebar-backdrop" aria-label="Close navigation"></button><aside class="sidebar" id="sidebar"><div class="logo"><div class="brand-mark">${icon("receipt")}</div><div class="logo-copy"><strong>AV Smartbilling</strong><small>Offline Billing Desk</small></div></div><nav class="nav"><p class="nav-section">Workspace</p>${navItems.map(([id, iconName, label]) => `<button data-nav="${id}">${icon(iconName, "nav-icon")}<span>${label}</span></button>`).join("")}</nav><footer class="side-foot"><div class="identity-mark">${esc(initials(state.license.customerName))}</div><div class="identity-copy"><p>${esc(state.license.customerName)}</p><small>${esc(state.license.planName)} · Local SQLite</small></div></footer></aside><div class="body"><header class="topbar"><div class="topbar-start"><button class="icon-button mobile-menu" id="mobile-menu" aria-label="Open navigation">${icon("menu")}</button><label class="search-wrap">${icon("search")}<input id="global-filter" class="search" placeholder="Search this page…" autocomplete="off"><kbd>⌘ K</kbd></label></div><span class="offline-pill">${icon("shield")}<span class="dot"></span>Offline ready</span></header><main id="content" class="content"></main></div></div>`;
  root.querySelectorAll("[data-nav]").forEach((button) => button.addEventListener("click", () => navigate(button.dataset.nav)));
  document.getElementById("mobile-menu").addEventListener("click", () => document.getElementById("sidebar").classList.toggle("open"));
  document.getElementById("sidebar-backdrop").addEventListener("click", () => document.getElementById("sidebar").classList.remove("open"));
  document.getElementById("global-filter").addEventListener("input", (event) => {
    state.query = event.target.value.toLowerCase();
    document.querySelectorAll("[data-filter-row]").forEach((row) => { row.hidden = !row.textContent.toLowerCase().includes(state.query); });
  });
  document.addEventListener("keydown", focusGlobalFilter);
}

function focusGlobalFilter(event) {
  if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
    event.preventDefault();
    document.getElementById("global-filter")?.focus();
  }
}

function pageHeader(eyebrow, title, description, action = "") {
  return `<header class="page-head"><div><p class="eyebrow">${esc(eyebrow)}</p><h1>${esc(title)}</h1><p class="muted">${esc(description)}</p></div>${action}</header>`;
}

async function navigate(page, detail) {
  if (state.pageKeyHandler) document.removeEventListener("keydown", state.pageKeyHandler);
  state.pageKeyHandler = null;
  state.page = page; state.query = "";
  document.getElementById("global-filter").value = "";
  root.querySelectorAll("[data-nav]").forEach((button) => button.classList.toggle("active", button.dataset.nav === page));
  document.getElementById("sidebar").classList.remove("open");
  const content = document.getElementById("content");
  content.innerHTML = `<div class="loading"><span class="spinner"></span>Loading local data…</div>`;
  try {
    if (page === "dashboard") await renderDashboard(content);
    if (page === "pos") await renderPos(content);
    if (page === "customers") await renderCustomers(content);
    if (page === "customer-form") await renderCustomerForm(content, detail);
    if (page === "products") await renderProducts(content);
    if (page === "product-form") await renderProductForm(content, detail);
    if (page === "inventory") await renderInventory(content);
    if (page === "invoices") await renderInvoices(content);
    if (page === "invoice-form") await renderInvoiceForm(content);
    if (page === "invoice-view") await renderInvoice(content, detail);
    if (page === "payments") await renderPayments(content);
    if (page === "payment-form") await renderPaymentForm(content, detail);
    if (page === "reports") await renderReports(content);
    if (page === "settings") await renderSettings(content);
  } catch (error) { content.innerHTML = `${pageHeader("Local database", "Unable to load page", error.message)}<p class="notice error">${esc(error.message)}</p>`; }
}

async function renderDashboard(content) {
  const data = await invoke("billing:dashboard"); state.business = data.business;
  content.innerHTML = `${pageHeader(data.business.company_name, "Billing dashboard", "Live totals from this computer's SQLite database.")}<section class="cards"><article class="card"><small>Customers</small><strong>${data.counts.customers}</strong></article><article class="card"><small>Products</small><strong>${data.counts.products}</strong></article><article class="card"><small>Total sales</small><strong>${money(data.counts.sales)}</strong></article><article class="card"><small>Outstanding</small><strong>${money(data.counts.sales-data.counts.received)}</strong></article></section><section class="surface"><div class="surface-head"><h2>Recent invoices</h2><button class="button" data-go="invoice-form">Create invoice</button></div>${invoiceTable(data.recent)}</section>`;
  content.querySelector("[data-go]").addEventListener("click", () => navigate("invoice-form")); bindInvoiceLinks(content);
}

async function renderPos(content) {
  const [allProducts, allCustomers, heldBills] = await Promise.all([invoke("billing:products"), invoke("billing:customers"), invoke("billing:held-bills")]);
  const products = allProducts.filter((row) => row.status === "ACTIVE" && row.stock_quantity > 0);
  const customers = allCustomers.filter((row) => row.status === "ACTIVE");
  const draft = state.posDraft;
  draft.items = draft.items.filter((item) => products.some((product) => product.id === item.productId));

  function totals() {
    return draft.items.reduce((result, item) => {
      const product = products.find((row) => row.id === item.productId);
      if (!product) return result;
      const subtotal = Math.round(product.price_in_paise * Number(item.quantity));
      const discount = Math.round(subtotal * Number(item.discountPercent || 0) / 100);
      const taxable = subtotal - discount;
      const tax = Math.round(taxable * product.tax_rate_basis_points / 10000);
      return { subtotal: result.subtotal + subtotal, discount: result.discount + discount, tax: result.tax + tax, total: result.total + taxable + tax };
    }, { subtotal: 0, discount: 0, tax: 0, total: 0 });
  }

  function addProduct(product) {
    const current = draft.items.find((item) => item.productId === product.id);
    if (current) {
      if (Number(current.quantity) + 1 > product.stock_quantity) return notify(`Only ${product.stock_quantity} ${product.unit} available.`, true);
      current.quantity = Number(current.quantity) + 1;
    } else draft.items.push({ productId: product.id, quantity: 1, discountPercent: 0 });
    draft.search = "";
    paint("barcode");
  }

  function paint(focus) {
    const sum = totals();
    if (!draft.amountReceived && draft.paymentMethod !== "CREDIT" && sum.total) draft.amountReceived = (sum.total / 100).toFixed(2);
    const matches = products.filter((product) => `${product.name} ${product.sku} ${product.barcode || ""} ${product.category || ""}`.toLowerCase().includes(draft.search.toLowerCase())).slice(0, 12);
    const itemRows = draft.items.map((item, index) => {
      const product = products.find((row) => row.id === item.productId);
      const line = Math.round(product.price_in_paise * Number(item.quantity));
      return `<tr><td><b>${esc(product.name)}</b><small class="table-sub">${esc(product.sku)} · Stock ${product.stock_quantity}</small></td><td><div class="quantity-control"><button type="button" data-qty="-1" data-index="${index}">−</button><input data-quantity="${index}" type="number" min="0.001" max="${product.stock_quantity}" step="0.001" value="${esc(item.quantity)}"><button type="button" data-qty="1" data-index="${index}">+</button></div></td><td><input class="discount-input" data-discount="${index}" type="number" min="0" max="100" step="0.01" value="${esc(item.discountPercent || 0)}">%</td><td class="money-cell">${money(line)}</td><td><button type="button" class="link-button danger-text" data-remove="${index}">Remove</button></td></tr>`;
    }).join("");
    content.innerHTML = `${pageHeader("Offline retail billing", "Quick POS", "Scan, bill, accept payment and print without internet.", `<div class="shortcut-strip"><span>F2 Search</span><span>F4 Customer</span><span>F8 Payment</span><span>F9 Pay & Print</span></div>`)}<div class="pos-layout"><section class="pos-catalog"><form id="barcode-form" class="barcode-box"><label for="barcode-input">${icon("barcode")}<span><b>Scan barcode</b><small>USB scanners work as keyboard input</small></span></label><input id="barcode-input" class="input" autocomplete="off" placeholder="Scan barcode or enter SKU" autofocus></form><label class="pos-search">${icon("search")}<input id="pos-search" value="${esc(draft.search)}" placeholder="Search product, SKU, barcode or category"></label><div class="product-results">${matches.length ? matches.map((product) => `<button type="button" data-add-product="${esc(product.id)}"><span><b>${esc(product.name)}</b><small>${esc(product.sku)}${product.barcode ? ` · ${esc(product.barcode)}` : ""}</small></span><span class="product-price">${money(product.price_in_paise)}<small>${product.stock_quantity} ${esc(product.unit)}</small></span></button>`).join("") : `<p class="empty">No available products match this search.</p>`}</div>${heldBills.length ? `<div class="held-panel"><div class="surface-head"><h3>Held bills</h3><span>${heldBills.length}</span></div>${heldBills.map((bill) => `<button type="button" data-resume="${esc(bill.id)}"><span><b>${esc(bill.label)}</b><small>${date(bill.updated_at, true)}</small></span><span>Resume</span></button>`).join("")}</div>` : ""}</section><form id="pos-checkout" class="pos-cart"><div class="pos-customer"><label class="field"><span>Customer</span><select class="select" id="pos-customer"><option value="" ${!draft.customerId ? "selected" : ""}>Walk-in customer</option>${customers.map((customer) => `<option value="${esc(customer.id)}" ${draft.customerId === customer.id ? "selected" : ""}>${esc(customer.name)} · ${esc(customer.phone)}</option>`).join("")}</select></label>${!draft.customerId ? `<div class="walkin-inline">${field("Customer name", "posWalkInName", draft.walkInName, { required: true })}${field("Mobile number", "posWalkInPhone", draft.walkInPhone, { required: true })}</div>` : ""}</div><div class="pos-cart-table"><table><thead><tr><th>Item</th><th>Qty</th><th>Discount</th><th>Amount</th><th></th></tr></thead><tbody>${itemRows || `<tr><td colspan="5" class="empty">Scan or select a product to begin.</td></tr>`}</tbody></table></div><div class="pos-totals"><div><span>Subtotal</span><b>${money(sum.subtotal)}</b></div><div><span>Discount</span><b>− ${money(sum.discount)}</b></div><div><span>GST</span><b>${money(sum.tax)}</b></div><div class="grand"><span>Grand total</span><b>${money(sum.total)}</b></div></div><div class="payment-box"><label class="field"><span>Payment method</span><select id="pos-payment" class="select"><option value="CASH">Cash</option><option value="UPI">UPI</option><option value="CARD">Card</option><option value="BANK_TRANSFER">Bank transfer</option><option value="CREDIT">Credit / Pay later</option><option value="OTHER">Other</option></select></label>${draft.paymentMethod !== "CREDIT" ? field("Amount received (₹)", "posAmountReceived", draft.amountReceived, { type: "number", step: "0.01", min: 0, required: true }) : `<p class="notice">This invoice will remain due and can be paid later.</p>`}<label class="field"><span>Tax type</span><select id="pos-tax-type" class="select"><option value="INTRA_STATE">CGST + SGST</option><option value="INTER_STATE">IGST</option></select></label></div><div class="hold-row"><input id="hold-label" class="input" placeholder="Hold label, e.g. Counter 2"><button type="button" id="hold-bill" class="button secondary">Hold bill</button></div><div class="pos-actions"><button type="submit" class="button secondary" data-print="false">Complete sale</button><button type="submit" class="button" data-print="true">Pay & Print <kbd>F9</kbd></button></div></form></div>`;
    document.getElementById("pos-payment").value = draft.paymentMethod;
    bind();
    if (focus === "search") document.getElementById("pos-search")?.focus();
    if (focus === "barcode") document.getElementById("barcode-input")?.focus();
  }

  function bind() {
    document.getElementById("barcode-form").addEventListener("submit", (event) => {
      event.preventDefault();
      const value = document.getElementById("barcode-input").value.trim().toLowerCase();
      const product = products.find((row) => String(row.barcode || "").toLowerCase() === value || row.sku.toLowerCase() === value);
      if (!product) return notify("No active in-stock product matches that barcode or SKU.", true);
      addProduct(product);
    });
    document.getElementById("pos-search").addEventListener("input", (event) => { draft.search = event.target.value; paint("search"); });
    content.querySelectorAll("[data-add-product]").forEach((button) => button.addEventListener("click", () => addProduct(products.find((row) => row.id === button.dataset.addProduct))));
    content.querySelectorAll("[data-qty]").forEach((button) => button.addEventListener("click", () => { const item = draft.items[Number(button.dataset.index)]; const product = products.find((row) => row.id === item.productId); item.quantity = Math.max(.001, Math.min(product.stock_quantity, Number(item.quantity) + Number(button.dataset.qty))); draft.amountReceived = ""; paint(); }));
    content.querySelectorAll("[data-quantity]").forEach((input) => input.addEventListener("change", () => { const item = draft.items[Number(input.dataset.quantity)]; const product = products.find((row) => row.id === item.productId); item.quantity = Math.max(.001, Math.min(product.stock_quantity, Number(input.value) || 1)); draft.amountReceived = ""; paint(); }));
    content.querySelectorAll("[data-discount]").forEach((input) => input.addEventListener("change", () => { draft.items[Number(input.dataset.discount)].discountPercent = Math.max(0, Math.min(100, Number(input.value) || 0)); draft.amountReceived = ""; paint(); }));
    content.querySelectorAll("[data-remove]").forEach((button) => button.addEventListener("click", () => { draft.items.splice(Number(button.dataset.remove), 1); draft.amountReceived = ""; paint(); }));
    document.getElementById("pos-customer").addEventListener("change", (event) => { draft.customerId = event.target.value; paint(); });
    document.querySelector('[name="posWalkInName"]')?.addEventListener("input", (event) => { draft.walkInName = event.target.value; });
    document.querySelector('[name="posWalkInPhone"]')?.addEventListener("input", (event) => { draft.walkInPhone = event.target.value; });
    document.getElementById("pos-payment").addEventListener("change", (event) => { draft.paymentMethod = event.target.value; draft.amountReceived = ""; paint(); });
    document.querySelector('[name="posAmountReceived"]')?.addEventListener("input", (event) => { draft.amountReceived = event.target.value; });
    document.getElementById("hold-bill").addEventListener("click", async () => { try { const result = await invoke("billing:hold-bill", { ...draft, label: document.getElementById("hold-label").value }); notify(result.message); state.posDraft = { items: [], customerId: "", walkInName: "", walkInPhone: "", paymentMethod: "CASH", amountReceived: "", search: "", heldBillId: null }; await navigate("pos"); } catch (error) { notify(error.message, true); } });
    content.querySelectorAll("[data-resume]").forEach((button) => button.addEventListener("click", () => { const held = heldBills.find((bill) => bill.id === button.dataset.resume); Object.assign(draft, held.payload, { heldBillId: held.id, search: "" }); paint("barcode"); }));
    document.getElementById("pos-checkout").addEventListener("submit", async (event) => {
      event.preventDefault();
      if (!draft.items.length) return notify("Add at least one product.", true);
      const button = event.submitter;
      button.disabled = true;
      const payload = { ...draft, walkInName: draft.walkInName, walkInPhone: draft.walkInPhone, items: draft.items, taxType: document.getElementById("pos-tax-type").value };
      try {
        const result = await invoke("billing:create-pos-sale", payload);
        if (draft.heldBillId) await invoke("billing:delete-held-bill", { id: draft.heldBillId });
        state.posDraft = { items: [], customerId: "", walkInName: "", walkInPhone: "", paymentMethod: "CASH", amountReceived: "", search: "", heldBillId: null };
        state.autoPrintInvoice = button.dataset.print === "true";
        notify(`Sale ${result.invoiceNumber} completed${result.changeInPaise ? `. Change: ${money(result.changeInPaise)}` : "."}`);
        await navigate("invoice-view", result.id);
      } catch (error) { notify(error.message, true); button.disabled = false; }
    });
  }

  state.pageKeyHandler = (event) => {
    if (event.key === "F2") { event.preventDefault(); document.getElementById("pos-search")?.focus(); }
    if (event.key === "F4") { event.preventDefault(); document.getElementById("pos-customer")?.focus(); }
    if (event.key === "F8") { event.preventDefault(); document.getElementById("pos-payment")?.focus(); }
    if (event.key === "F9") { event.preventDefault(); document.querySelector('#pos-checkout [data-print="true"]')?.click(); }
  };
  document.addEventListener("keydown", state.pageKeyHandler);
  paint("barcode");
}

function invoiceTable(invoices) {
  if (!invoices.length) return `<p class="empty">No invoices saved on this computer yet.</p>`;
  return `<div class="table-wrap"><table><thead><tr><th>Invoice</th><th>Customer</th><th>Date</th><th>Total</th><th>Paid</th><th>Status</th><th></th></tr></thead><tbody>${invoices.map((row) => `<tr data-filter-row><td><button class="link-button" data-invoice="${esc(row.id)}">${esc(row.invoice_number)}</button></td><td>${esc(row.customer_name)}</td><td>${date(row.issued_at)}</td><td>${money(row.total_in_paise)}</td><td>${money(row.paid_in_paise)}</td><td>${status(row.status)}</td><td class="actions"><button class="link-button" data-invoice="${esc(row.id)}">View / Print</button></td></tr>`).join("")}</tbody></table></div>`;
}
function bindInvoiceLinks(container) { container.querySelectorAll("[data-invoice]").forEach((button) => button.addEventListener("click", () => navigate("invoice-view", button.dataset.invoice))); }

async function renderCustomers(content) {
  const rows = await invoke("billing:customers");
  content.innerHTML = `${pageHeader("Local records", "Customers", "Customer information stored only on this computer.", `<button class="button" id="new-customer">Add customer</button>`)}<section class="surface">${rows.length ? `<div class="table-wrap"><table><thead><tr><th>Name</th><th>Phone</th><th>Email</th><th>GSTIN</th><th>Invoices</th><th>Status</th><th></th></tr></thead><tbody>${rows.map((row) => `<tr data-filter-row><td><b>${esc(row.name)}</b></td><td>${esc(row.phone || "—")}</td><td>${esc(row.email || "—")}</td><td>${esc(row.gstin || "—")}</td><td>${row.invoice_count}</td><td>${status(row.status)}</td><td class="actions"><button class="link-button" data-edit-customer="${esc(row.id)}">Edit</button> <button class="link-button danger-text" data-delete-customer="${esc(row.id)}" data-name="${esc(row.name)}">Delete</button></td></tr>`).join("")}</tbody></table></div>` : `<p class="empty">No local customers yet.</p>`}</section>`;
  document.getElementById("new-customer").addEventListener("click", () => navigate("customer-form"));
  content.querySelectorAll("[data-edit-customer]").forEach((button) => button.addEventListener("click", () => navigate("customer-form", rows.find((row) => row.id === button.dataset.editCustomer))));
  content.querySelectorAll("[data-delete-customer]").forEach((button) => button.addEventListener("click", async () => { if (!await confirmAction(`Delete ${button.dataset.name}?`, "Customers used by invoices will be archived so accounting history remains intact.")) return; try { const result=await invoke("billing:delete-customer",{id:button.dataset.deleteCustomer}); notify(result.message); await navigate("customers"); } catch(error){notify(error.message,true);} }));
}

async function renderCustomerForm(content, customer = {}) {
  content.innerHTML = `${pageHeader("Local customer", customer.id ? "Edit customer" : "Add customer", "Changes are saved immediately to SQLite.")}<form id="customer-form" class="panel form-grid"><input type="hidden" name="id" value="${esc(customer.id || "")}">${field("Name","name",customer.name,{required:true})}${field("Phone","phone",customer.phone)}${field("Email","email",customer.email,{type:"email"})}${field("GSTIN","gstin",customer.gstin)}${field("Address","address",customer.address,{textarea:true,full:true})}<label class="field"><span>Status</span><select class="select" name="status"><option value="ACTIVE" ${customer.status !== "INACTIVE" ? "selected" : ""}>Active</option><option value="INACTIVE" ${customer.status === "INACTIVE" ? "selected" : ""}>Inactive</option></select></label><div class="form-actions field full"><button type="button" class="button secondary" id="cancel">Cancel</button><button class="button">${customer.id ? "Update customer" : "Create customer"}</button></div></form>`;
  document.getElementById("cancel").addEventListener("click",()=>navigate("customers"));
  document.getElementById("customer-form").addEventListener("submit",async(event)=>{event.preventDefault();const form=event.currentTarget;if(customer.id&&!await confirmAction("Update customer?","Save these changes to the local customer record?"))return;try{const result=await invoke("billing:save-customer",Object.fromEntries(new FormData(form)));notify(result.message);await navigate("customers");}catch(error){notify(error.message,true);}});
}

async function renderProducts(content) {
  const rows=await invoke("billing:products");
  const visibleRows=rows.filter(row=>row.status==="ACTIVE"||row.invoice_count===0);
  content.innerHTML=`${pageHeader("Local inventory","Products","Barcode-ready products, pricing, GST and stock stored in SQLite.",`<button class="button" id="new-product">Add product</button>`)}<section class="surface">${visibleRows.length?`<div class="table-wrap"><table><thead><tr><th>Product</th><th>SKU / Barcode</th><th>Category</th><th>Purchase</th><th>Selling</th><th>GST</th><th>Stock</th><th>Status</th><th></th></tr></thead><tbody>${visibleRows.map(row=>`<tr data-filter-row><td><b>${esc(row.name)}</b><small class="table-sub">${esc(row.hsn_sac?`HSN/SAC ${row.hsn_sac}`:row.description||"")}</small></td><td><span class="mono">${esc(row.sku)}</span><small class="table-sub mono">${esc(row.barcode||"No barcode")}</small></td><td>${esc(row.category||"—")}</td><td>${money(row.purchase_price_in_paise)}</td><td><b>${money(row.price_in_paise)}</b></td><td>${row.tax_rate_basis_points/100}%</td><td>${row.stock_quantity} ${esc(row.unit)}</td><td>${status(row.status)}</td><td class="actions"><button class="link-button" data-edit-product="${esc(row.id)}">Edit</button> <button class="link-button danger-text" data-delete-product="${esc(row.id)}" data-name="${esc(row.name)}">Delete</button></td></tr>`).join("")}</tbody></table></div>`:`<p class="empty">No active products in the catalogue.</p>`}</section>`;
  document.getElementById("new-product").addEventListener("click",()=>navigate("product-form"));
  content.querySelectorAll("[data-edit-product]").forEach(button=>button.addEventListener("click",()=>navigate("product-form",visibleRows.find(row=>row.id===button.dataset.editProduct))));
  content.querySelectorAll("[data-delete-product]").forEach(button=>button.addEventListener("click",async()=>{if(!await confirmAction(`Delete ${button.dataset.name}?`,"If this product has no invoice history it will be permanently deleted. Otherwise it will be removed from the catalogue while historical invoices remain intact."))return;try{const result=await invoke("billing:delete-product",{id:button.dataset.deleteProduct});notify(result.message);await navigate("products");}catch(error){notify(error.message,true);}}));
}

async function renderProductForm(content, product={}) {
  const generatedSku=product.id?product.sku:await invoke("billing:generate-sku");
  content.innerHTML=`${pageHeader("Local inventory",product.id?"Edit product":"Add product","Configure barcode, purchase and selling prices, GST, HSN/SAC and traceable opening stock.")}<form id="product-form" class="panel form-grid"><input type="hidden" name="id" value="${esc(product.id||"")}">${field("Product name","name",product.name,{required:true})}${field("SKU","sku",generatedSku,{required:true})}${field("Barcode","barcode",product.barcode)}${field("Category","category",product.category)}${field("HSN / SAC","hsnSac",product.hsn_sac)}${field("Unit","unit",product.unit||"unit",{required:true})}${field("Purchase price (₹)","purchasePrice",product.purchase_price_in_paise!==undefined?product.purchase_price_in_paise/100:"",{type:"number",step:"0.01",min:0})}${field("Selling price (₹)","price",product.price_in_paise!==undefined?product.price_in_paise/100:"",{type:"number",step:"0.01",min:0,required:true})}${field("GST rate (%)","taxRate",product.tax_rate_basis_points!==undefined?product.tax_rate_basis_points/100:0,{type:"number",step:"0.01",min:0,required:true})}${field(product.id?"Current stock":"Opening stock","stockQuantity",product.stock_quantity??0,{type:"number",step:"0.001",min:0,required:true})}${field("Low-stock threshold","lowStockThreshold",product.low_stock_threshold??"",{type:"number",step:"0.001",min:0})}<label class="field"><span>Status</span><select class="select" name="status"><option value="ACTIVE" ${product.status!=="INACTIVE"?"selected":""}>Active</option><option value="INACTIVE" ${product.status==="INACTIVE"?"selected":""}>Inactive</option></select></label>${field("Description","description",product.description,{textarea:true,full:true})}<div class="form-actions field full"><button type="button" class="button secondary" id="cancel">Cancel</button><button class="button">${product.id?"Update product":"Create product"}</button></div></form>`;
  document.getElementById("cancel").addEventListener("click",()=>navigate("products"));
  document.getElementById("product-form").addEventListener("submit",async(event)=>{event.preventDefault();const form=event.currentTarget;if(product.id&&!await confirmAction("Update product?","Save these product and stock changes locally?"))return;try{const result=await invoke("billing:save-product",Object.fromEntries(new FormData(form)));notify(result.message);await navigate("products");}catch(error){notify(error.message,true);}});
}

async function renderInventory(content) {
  const data = await invoke("billing:inventory");
  const activeProducts = data.products.filter((row) => row.status === "ACTIVE");
  content.innerHTML = `${pageHeader("Traceable local stock", "Inventory", "Purchases, returns and corrections create an auditable movement instead of silently overwriting stock.")}<section class="panel"><form id="stock-form" class="form-grid"><label class="field full"><span>Product</span><select class="select" name="productId" required><option value="">Select product</option>${activeProducts.map((row) => `<option value="${esc(row.id)}">${esc(row.name)} · ${esc(row.sku)} · ${row.stock_quantity} ${esc(row.unit)}</option>`).join("")}</select></label><label class="field"><span>Movement</span><select class="select" name="movementType"><option value="PURCHASE">Purchase / Stock in</option><option value="RETURN">Sales return / Stock in</option><option value="ADJUSTMENT">Set counted stock</option></select></label>${field("Quantity", "quantity", "", { type: "number", step: "0.001", min: 0, required: true })}${field("Reference", "reference")}${field("Notes", "notes") }<div class="form-actions field full"><button class="button">Update stock</button></div></form></section><section class="surface"><div class="surface-head"><h2>Current stock</h2><span class="muted">${data.products.length} products</span></div><div class="table-wrap"><table><thead><tr><th>Product</th><th>Category</th><th>Current stock</th><th>Low-stock level</th><th>Value at cost</th><th>Status</th></tr></thead><tbody>${data.products.map((row) => `<tr data-filter-row><td><b>${esc(row.name)}</b><small class="table-sub mono">${esc(row.sku)}</small></td><td>${esc(row.category || "—")}</td><td class="${row.stock_quantity <= row.effective_low_stock_threshold ? "low-stock" : ""}">${row.stock_quantity} ${esc(row.unit)}</td><td>${row.effective_low_stock_threshold} ${esc(row.unit)}</td><td>${money(row.purchase_price_in_paise * row.stock_quantity)}</td><td>${status(row.status)}</td></tr>`).join("")}</tbody></table></div></section><section class="surface"><div class="surface-head"><h2>Stock movement history</h2><span class="muted">Latest 250 entries</span></div>${data.movements.length ? `<div class="table-wrap"><table><thead><tr><th>Date</th><th>Product</th><th>Type</th><th>Change</th><th>Balance</th><th>Reference / Notes</th></tr></thead><tbody>${data.movements.map((row) => `<tr data-filter-row><td>${date(row.created_at, true)}</td><td><b>${esc(row.product_name)}</b><small class="table-sub mono">${esc(row.sku)}</small></td><td>${status(row.movement_type)}</td><td class="${row.quantity_change > 0 ? "stock-in" : "stock-out"}">${row.quantity_change > 0 ? "+" : ""}${row.quantity_change} ${esc(row.unit)}</td><td>${row.quantity_after} ${esc(row.unit)}</td><td>${esc([row.reference_id, row.notes].filter(Boolean).join(" · ") || "—")}</td></tr>`).join("")}</tbody></table></div>` : `<p class="empty">No stock movements yet.</p>`}</section>`;
  document.getElementById("stock-form").addEventListener("submit", async (event) => {
    event.preventDefault();
    const data = Object.fromEntries(new FormData(event.currentTarget));
    const label = data.movementType === "ADJUSTMENT" ? "Set counted stock?" : "Record stock movement?";
    if (!await confirmAction(label, "This change will update current stock and add a permanent inventory history entry.")) return;
    try { const result = await invoke("billing:adjust-stock", data); notify(result.message); await navigate("inventory"); } catch (error) { notify(error.message, true); }
  });
}

async function renderInvoices(content) {
  const rows=await invoke("billing:invoices");content.innerHTML=`${pageHeader("Local sales","Invoices","Create, view and print invoices without internet.",`<button class="button" id="new-invoice">Create invoice</button>`)}<section class="surface">${invoiceTable(rows)}</section>`;document.getElementById("new-invoice").addEventListener("click",()=>navigate("invoice-form"));bindInvoiceLinks(content);
}

async function renderInvoiceForm(content) {
  const [customers,products,business]=await Promise.all([invoke("billing:customers"),invoke("billing:products"),invoke("billing:settings")]);
  const activeCustomers=customers.filter(row=>row.status==="ACTIVE"),activeProducts=products.filter(row=>row.status==="ACTIVE"&&row.stock_quantity>0);
  if(!activeProducts.length){content.innerHTML=`${pageHeader("Local invoice","Products required","Add an active product with available stock before creating an invoice.",`<button class="button" id="go-products">Open products</button>`)}`;document.getElementById("go-products").addEventListener("click",()=>navigate("products"));return;}
  const productOptions=(selected="")=>`<option value="">Select product</option>${activeProducts.map(row=>`<option value="${esc(row.id)}" ${selected===row.id?"selected":""}>${esc(row.name)} · ${esc(row.sku)} · ${money(row.price_in_paise)} · Stock ${row.stock_quantity}</option>`).join("")}`;
  content.innerHTML=`${pageHeader("Local invoice","Create professional invoice","Stock, GST split and invoice numbering are committed in one SQLite transaction.")}<form id="invoice-form" class="panel"><div class="form-grid"><label class="field"><span>Customer type</span><select class="select" id="customer-mode"><option value="saved">Saved customer</option><option value="walkin">Walk-in customer</option></select></label><label class="field" id="saved-customer"><span>Customer</span><select class="select" name="customerId"><option value="">Select customer</option>${activeCustomers.map(row=>`<option value="${esc(row.id)}">${esc(row.name)} · ${esc(row.phone)}</option>`).join("")}</select></label><div id="walkin-fields" class="field full" hidden><div class="form-grid">${field("Customer name","walkInName")}${field("Mobile number","walkInPhone")}</div></div>${field("Invoice date","issuedAt",today(),{type:"date",required:true})}${field("Due date","dueAt",inputDate(7),{type:"date"})}<label class="field"><span>GST treatment</span><select class="select" name="taxType" id="invoice-tax-type"><option value="INTRA_STATE">Intra-state · CGST + SGST</option><option value="INTER_STATE">Inter-state · IGST</option></select></label>${field("Shipping address","shippingAddress","",{textarea:true,full:true})}${field("Notes","notes","",{textarea:true,full:true})}${field("Terms & conditions","terms",business.invoice_terms||"",{textarea:true,full:true})}</div><div class="surface" style="margin-top:22px"><div class="surface-head"><h2>Invoice items</h2><button type="button" class="button secondary" id="add-line">Add line</button></div><div id="invoice-lines" class="invoice-lines" style="padding:16px"></div></div><div id="invoice-preview" class="invoice-total"></div><div class="form-actions"><button type="button" class="button secondary" id="cancel">Cancel</button><button class="button">Create invoice</button></div></form>`;
  const lines=document.getElementById("invoice-lines");
  function addLine(selected="",quantity=1,discount=0){const wrapper=document.createElement("div");wrapper.className="invoice-line";wrapper.innerHTML=`<select class="select product-select" required>${productOptions(selected)}</select><input class="input quantity" aria-label="Quantity" type="number" min="0.001" step="0.001" value="${quantity}" required><input class="input discount" aria-label="Discount percentage" title="Discount %" type="number" min="0" max="100" step="0.01" value="${discount}"><button type="button" class="button danger remove-line">×</button>`;lines.append(wrapper);wrapper.querySelector(".remove-line").addEventListener("click",()=>{if(lines.children.length>1){wrapper.remove();preview();}});wrapper.querySelectorAll("select,input").forEach(element=>element.addEventListener("input",preview));}
  function preview(){let subtotal=0,discount=0,tax=0;lines.querySelectorAll(".invoice-line").forEach(line=>{const product=activeProducts.find(row=>row.id===line.querySelector("select").value);const quantity=Number(line.querySelector(".quantity").value)||0;const discountPercent=Math.min(100,Math.max(0,Number(line.querySelector(".discount").value)||0));if(product){const base=Math.round(product.price_in_paise*quantity);const reduction=Math.round(base*discountPercent/100);subtotal+=base;discount+=reduction;tax+=Math.round((base-reduction)*product.tax_rate_basis_points/10000);}});document.getElementById("invoice-preview").innerHTML=`<div><span>Subtotal</span><b>${money(subtotal)}</b></div><div><span>Discount</span><b>− ${money(discount)}</b></div><div><span>GST</span><b>${money(tax)}</b></div><div class="grand"><span>Total</span><b>${money(subtotal-discount+tax)}</b></div>`;}
  addLine();preview();document.getElementById("add-line").addEventListener("click",()=>addLine());document.getElementById("cancel").addEventListener("click",()=>navigate("invoices"));document.getElementById("customer-mode").addEventListener("change",event=>{const walkin=event.target.value==="walkin";document.getElementById("walkin-fields").hidden=!walkin;document.getElementById("saved-customer").hidden=walkin;});
  document.getElementById("invoice-form").addEventListener("submit",async(event)=>{event.preventDefault();const form=Object.fromEntries(new FormData(event.currentTarget));const walkin=document.getElementById("customer-mode").value==="walkin";const items=[...lines.querySelectorAll(".invoice-line")].map(line=>({productId:line.querySelector("select").value,quantity:line.querySelector(".quantity").value,discountPercent:line.querySelector(".discount").value}));try{const result=await invoke("billing:create-invoice",{...form,customerId:walkin?null:form.customerId,walkInName:walkin?form.walkInName:null,walkInPhone:walkin?form.walkInPhone:null,items});notify(`Invoice ${result.invoiceNumber} created.`);await navigate("invoice-view",result.id);}catch(error){notify(error.message,true);}});
}

async function renderInvoice(content,id){
  const [invoice,business]=await Promise.all([invoke("billing:invoice",{id}),invoke("billing:settings")]);
  if(!invoice)throw new Error("Invoice not found.");
  const balance=invoice.total_in_paise-invoice.paid_in_paise;
  const cgst=invoice.items.reduce((sum,item)=>sum+Number(item.cgst_in_paise||0),0),sgst=invoice.items.reduce((sum,item)=>sum+Number(item.sgst_in_paise||0),0),igst=invoice.items.reduce((sum,item)=>sum+Number(item.igst_in_paise||0),0);
  const action=`<div class="screen-only invoice-actions"><button class="button secondary" id="back">Back</button><button class="button secondary" id="print-thermal">Print ${business.thermal_paper_width||80}mm receipt</button><button class="button" id="print-a4">Print / Save A4 PDF</button></div>`;
  const itemRows=invoice.items.map(item=>`<tr><td><b>${esc(item.description)}</b><small class="table-sub">${esc(item.sku)}${item.hsn_sac?` · HSN/SAC ${esc(item.hsn_sac)}`:""}</small></td><td>${item.quantity} ${esc(item.unit)}</td><td>${money(item.unit_price_in_paise)}</td><td>${money(item.discount_in_paise||0)}</td><td>${item.tax_rate_basis_points/100}%</td><td>${money(Number(item.taxable_in_paise||item.line_subtotal_in_paise)+item.line_tax_in_paise)}</td></tr>`).join("");
  const thermalItems=invoice.items.map(item=>`<tr><td>${esc(item.description)}<small>${item.quantity} × ${money(item.unit_price_in_paise)}</small></td><td>${money(Number(item.taxable_in_paise||item.line_subtotal_in_paise)+item.line_tax_in_paise)}</td></tr>`).join("");
  content.innerHTML=`${pageHeader("Customer invoice",invoice.invoice_number,`${invoice.customer_name} · ${date(invoice.issued_at)}`,action)}<article class="surface invoice-sheet a4-invoice"><header class="gst-invoice-head"><div><p class="eyebrow">Tax invoice</p><h1>${esc(business.company_name)}</h1><p>${esc(business.address)}</p><p>${esc([business.phone,business.email].filter(Boolean).join(" · "))}</p>${business.gstin?`<p><b>GSTIN:</b> ${esc(business.gstin)}</p>`:""}</div><div class="invoice-number"><span>Invoice number</span><b>${esc(invoice.invoice_number)}</b><span>Invoice date</span><b>${date(invoice.issued_at)}</b><span>Due date</span><b>${invoice.due_at?date(invoice.due_at):"On receipt"}</b></div></header><section class="invoice-addresses"><div><p class="eyebrow">Bill to</p><h2>${esc(invoice.customer_name)}</h2><p>${esc(invoice.customer_phone)}</p><p>${esc(invoice.customer_address)}</p>${invoice.customer_gstin?`<p><b>GSTIN:</b> ${esc(invoice.customer_gstin)}</p>`:""}</div><div><p class="eyebrow">Ship to</p><p>${esc(invoice.shipping_address||invoice.customer_address||"Same as billing address")}</p><p><b>GST treatment:</b> ${invoice.tax_type==="INTER_STATE"?"Inter-state (IGST)":"Intra-state (CGST + SGST)"}</p></div></section><div class="table-wrap invoice-items-table"><table><thead><tr><th>Product / HSN</th><th>Qty</th><th>Rate</th><th>Discount</th><th>GST</th><th>Total</th></tr></thead><tbody>${itemRows}</tbody></table></div><div class="invoice-total"><div><span>Subtotal</span><b>${money(invoice.subtotal_in_paise)}</b></div>${invoice.discount_in_paise?`<div><span>Discount</span><b>− ${money(invoice.discount_in_paise)}</b></div>`:""}${cgst?`<div><span>CGST</span><b>${money(cgst)}</b></div><div><span>SGST</span><b>${money(sgst)}</b></div>`:""}${igst?`<div><span>IGST</span><b>${money(igst)}</b></div>`:""}<div class="grand"><span>Grand total</span><b>${money(invoice.total_in_paise)}</b></div><div><span>Paid</span><b>${money(invoice.paid_in_paise)}</b></div><div><span>Balance</span><b>${money(balance)}</b></div></div>${invoice.notes?`<section class="invoice-copy"><b>Notes</b><p>${esc(invoice.notes)}</p></section>`:""}${invoice.terms?`<section class="invoice-copy"><b>Terms & conditions</b><p>${esc(invoice.terms)}</p></section>`:""}${business.invoice_footer?`<footer class="invoice-footer">${esc(business.invoice_footer)}</footer>`:""}</article><article class="thermal-receipt receipt-${business.thermal_paper_width===58?58:80}"><header><h1>${esc(business.company_name)}</h1><p>${esc(business.address)}</p>${business.gstin?`<p>GSTIN: ${esc(business.gstin)}</p>`:""}<p>${esc(business.phone)}</p></header><div class="receipt-rule"></div><p><b>${esc(invoice.invoice_number)}</b><br>${date(invoice.issued_at,true)}<br>Customer: ${esc(invoice.customer_name)} · ${esc(invoice.customer_phone)}</p><div class="receipt-rule"></div><table><tbody>${thermalItems}</tbody></table><div class="receipt-rule"></div><dl><div><dt>Subtotal</dt><dd>${money(invoice.subtotal_in_paise)}</dd></div>${invoice.discount_in_paise?`<div><dt>Discount</dt><dd>− ${money(invoice.discount_in_paise)}</dd></div>`:""}<div><dt>GST</dt><dd>${money(invoice.tax_in_paise)}</dd></div><div class="receipt-grand"><dt>Total</dt><dd>${money(invoice.total_in_paise)}</dd></div><div><dt>Paid</dt><dd>${money(invoice.paid_in_paise)}</dd></div><div><dt>Balance</dt><dd>${money(balance)}</dd></div></dl><div class="receipt-rule"></div><footer>${esc(business.invoice_footer||"Thank you for your business.")}</footer></article>${balance>0?`<div class="screen-only" style="margin-top:18px"><button class="button" id="record-payment">Record payment</button></div>`:""}`;
  function printMode(mode){document.body.dataset.printMode=mode;window.print();}
  document.getElementById("back").addEventListener("click",()=>navigate("invoices"));
  document.getElementById("print-a4").addEventListener("click",()=>printMode("a4"));
  document.getElementById("print-thermal").addEventListener("click",()=>printMode("thermal"));
  document.getElementById("record-payment")?.addEventListener("click",()=>navigate("payment-form",id));
  if(state.autoPrintInvoice){state.autoPrintInvoice=false;setTimeout(()=>printMode(invoice.sale_mode==="POS"?"thermal":"a4"),250);}
}

async function renderPayments(content){const rows=await invoke("billing:payments");content.innerHTML=`${pageHeader("Local receipts","Payments","Payments are reconciled against local invoices.",`<button class="button" id="new-payment">Record payment</button>`)}<section class="surface">${rows.length?`<div class="table-wrap"><table><thead><tr><th>Date</th><th>Invoice</th><th>Customer</th><th>Method</th><th>Reference</th><th>Amount</th></tr></thead><tbody>${rows.map(row=>`<tr data-filter-row><td>${date(row.paid_at)}</td><td>${esc(row.invoice_number)}</td><td>${esc(row.customer_name)}</td><td>${esc(row.method.replaceAll("_"," "))}</td><td>${esc(row.reference||"—")}</td><td><b>${money(row.amount_in_paise)}</b></td></tr>`).join("")}</tbody></table></div>`:`<p class="empty">No local payments yet.</p>`}</section>`;document.getElementById("new-payment").addEventListener("click",()=>navigate("payment-form"));}

async function renderPaymentForm(content,selectedId=""){const invoices=(await invoke("billing:invoices")).filter(row=>!["PAID","CANCELLED"].includes(row.status)&&row.total_in_paise>row.paid_in_paise);if(!invoices.length){content.innerHTML=pageHeader("Local receipts","No unpaid invoices","All invoices are paid or no invoices have been created.");return;}content.innerHTML=`${pageHeader("Local receipt","Record payment","Selecting an invoice fills its outstanding balance automatically.")}<form id="payment-form" class="panel form-grid"><label class="field full"><span>Invoice</span><select class="select" name="invoiceId" id="payment-invoice" required><option value="">Select invoice</option>${invoices.map(row=>`<option value="${esc(row.id)}" data-balance="${(row.total_in_paise-row.paid_in_paise)/100}" ${row.id===selectedId?"selected":""}>${esc(row.invoice_number)} · ${esc(row.customer_name)} · Balance ${money(row.total_in_paise-row.paid_in_paise)}</option>`).join("")}</select></label>${field("Amount (₹)","amount","",{type:"number",step:"0.01",min:0,required:true})}<label class="field"><span>Payment method</span><select class="select" name="method"><option>CASH</option><option>UPI</option><option>CARD</option><option value="BANK_TRANSFER">Bank transfer</option><option>OTHER</option></select></label>${field("Paid date","paidAt",today(),{type:"date",required:true})}${field("Reference","reference")}${field("Notes","notes","",{textarea:true,full:true})}<div class="form-actions field full"><button type="button" id="cancel" class="button secondary">Cancel</button><button class="button">Record payment</button></div></form>`;const select=document.getElementById("payment-invoice"),amount=document.querySelector('[name="amount"]');function fill(){amount.value=select.selectedOptions[0]?.dataset.balance||"";}select.addEventListener("change",fill);if(selectedId)fill();document.getElementById("cancel").addEventListener("click",()=>navigate("payments"));document.getElementById("payment-form").addEventListener("submit",async event=>{event.preventDefault();try{const result=await invoke("billing:record-payment",Object.fromEntries(new FormData(event.currentTarget)));notify(result.message);await navigate("payments");}catch(error){notify(error.message,true);}});}

async function renderReports(content){const data=await invoke("billing:reports");const max=Math.max(...data.monthly.map(row=>row.sales),1);content.innerHTML=`${pageHeader("Local analytics","Reports","Calculated entirely from this computer's SQLite data.")}<section class="cards"><article class="card"><small>Total sales</small><strong>${money(data.totals.sales)}</strong></article><article class="card"><small>Received</small><strong>${money(data.totals.received)}</strong></article><article class="card"><small>Outstanding</small><strong>${money(data.totals.outstanding)}</strong></article><article class="card"><small>Invoices</small><strong>${data.totals.invoices}</strong></article></section><section class="surface"><div class="surface-head"><h2>Monthly sales</h2></div>${data.monthly.length?`<div style="padding:22px">${data.monthly.map(row=>`<div style="display:grid;grid-template-columns:90px 1fr 130px;gap:12px;align-items:center;margin:13px 0"><b>${esc(row.month)}</b><span style="height:12px;background:var(--soft)"><i style="display:block;width:${Math.max(2,row.sales/max*100)}%;height:100%;background:var(--brand)"></i></span><strong>${money(row.sales)}</strong></div>`).join("")}</div>`:`<p class="empty">No sales data yet.</p>`}</section>`;}

async function renderSettings(content){const business=await invoke("billing:settings");content.innerHTML=`${pageHeader("This computer","Settings","Business identity, GST, invoice, receipt and optional encrypted cloud configuration.")}<form id="settings-form" class="panel form-grid">${field("Business name","companyName",business.company_name,{required:true})}${field("Contact person","contactPerson",business.contact_person)}${field("Email","email",business.email,{type:"email"})}${field("Phone","phone",business.phone)}${field("GSTIN","gstin",business.gstin)}${field("State code","stateCode",business.state_code)}${field("Invoice prefix","invoicePrefix",business.invoice_prefix,{required:true})}${field("Low-stock threshold","lowStockThreshold",business.low_stock_threshold,{type:"number",step:"0.001",min:0})}<label class="field"><span>Thermal receipt width</span><select class="select" name="thermalPaperWidth"><option value="80" ${business.thermal_paper_width!==58?"selected":""}>80 mm</option><option value="58" ${business.thermal_paper_width===58?"selected":""}>58 mm</option></select></label>${field("Address","address",business.address,{textarea:true,full:true})}${field("Default invoice terms","invoiceTerms",business.invoice_terms,{textarea:true,full:true})}${field("Invoice / receipt footer","invoiceFooter",business.invoice_footer,{textarea:true,full:true})}<div class="form-actions field full"><button class="button">Save local settings</button></div></form><section class="surface" style="padding:24px"><p class="eyebrow">Optional online migration</p><h2 style="margin-top:7px">Cloud backup and restore</h2><p class="muted">Local SQLite remains the source of truth. Each explicit backup creates a separate encrypted recovery point.</p><p class="warning">Restoring replaces the current local billing database. A complete SQLite safety copy is created automatically before replacement.</p><div id="cloud-status" class="notice">Cloud status has not been checked.</div><div id="cloud-history"></div><div class="cloud-grid"><article class="cloud-card"><h3>Backup to cloud</h3><p class="muted">Upload a new encrypted version without deleting earlier recovery points.</p><button class="button" id="cloud-backup">Backup local data</button></article><article class="cloud-card"><h3>Restore from cloud</h3><p class="muted">Choose a recovery point above, then restore it after activating this computer.</p><button class="button secondary" id="cloud-restore">Restore selected backup</button></article></div><div class="form-actions"><button class="button secondary" id="validate-license">Validate license online</button></div></section>`;
  document.getElementById("settings-form").addEventListener("submit",async event=>{event.preventDefault();try{const result=await invoke("billing:save-settings",Object.fromEntries(new FormData(event.currentTarget)));notify(result.message);state.business=await invoke("billing:settings");}catch(error){notify(error.message,true);}});
  const cloudStatus=document.getElementById("cloud-status");invoke("cloud:status").then(result=>{cloudStatus.textContent=result.available?`Latest cloud backup: ${date(result.metadata.backedUpAt,true)} from ${result.metadata.deviceName}. ${result.metadata.counts.invoices} invoices, ${result.metadata.counts.products} products.`:"No cloud backup exists for this license yet.";document.getElementById("cloud-history").innerHTML=result.available?`<label class="field"><span>Available recovery points</span><select class="select" id="backup-version">${result.backups.map(row=>`<option value="${esc(row.id)}">${date(row.backedUpAt,true)} · ${esc(row.deviceName)} · ${row.counts.invoices} invoices · v${esc(row.appVersion)}</option>`).join("")}</select></label>`:"";}).catch(error=>{cloudStatus.textContent=`Cloud unavailable: ${error.message}`;cloudStatus.classList.add("error");});
  document.getElementById("cloud-backup").addEventListener("click",async event=>{if(!await confirmAction("Create a new cloud backup?","A new encrypted recovery point will be added. Earlier backup versions will remain available."))return;event.currentTarget.disabled=true;event.currentTarget.textContent="Uploading…";try{const result=await invoke("cloud:backup");notify(result.message||"Encrypted cloud backup completed.");await renderSettings(content);}catch(error){notify(error.message,true);event.currentTarget.disabled=false;event.currentTarget.textContent="Backup local data";}});
  document.getElementById("cloud-restore").addEventListener("click",async event=>{const id=document.getElementById("backup-version")?.value;if(!id){notify("Create or select a cloud backup first.",true);return;}if(!await confirmAction("Replace local data from selected backup?","A local safety copy will be created first. Current records will then be replaced by the selected recovery point."))return;event.currentTarget.disabled=true;event.currentTarget.textContent="Restoring…";try{const result=await invoke("cloud:restore",{id});notify(`${result.message} Safety copy: ${result.backupPath}`);await navigate("dashboard");}catch(error){notify(error.message,true);event.currentTarget.disabled=false;event.currentTarget.textContent="Restore selected backup";}});
  document.getElementById("validate-license").addEventListener("click",async event=>{event.currentTarget.disabled=true;event.currentTarget.textContent="Validating…";try{state.license=await invoke("license:validate");notify(`License valid until ${date(state.license.validUntil,true)}.`);}catch(error){notify(error.message,true);}finally{event.currentTarget.disabled=false;event.currentTarget.textContent="Validate license online";}});
}

boot();
