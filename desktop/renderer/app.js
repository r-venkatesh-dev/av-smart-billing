const root = document.getElementById("app");
const toast = document.getElementById("toast");
const confirmDialog = document.getElementById("confirm-dialog");
const state = { page: "dashboard", license: null, device: null, business: null, query: "", invoiceDraft: { customerMode: "saved", items: [{}] } };

const navItems = [
  ["dashboard", "▦", "Dashboard"], ["customers", "♙", "Customers"], ["products", "□", "Products"],
  ["invoices", "▤", "Invoices"], ["payments", "₹", "Payments"], ["reports", "↗", "Reports"], ["settings", "⚙", "Settings"],
];

function esc(value) {
  return String(value ?? "").replace(/[&<>'"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" })[character]);
}
function money(paise) { return new Intl.NumberFormat("en-IN", { style: "currency", currency: "INR" }).format(Number(paise || 0) / 100); }
function date(value, time = false) { if (!value) return "—"; return new Date(value).toLocaleString("en-IN", time ? { dateStyle: "medium", timeStyle: "short" } : { dateStyle: "medium" }); }
function today() { return new Date().toISOString().slice(0, 10); }
function inputDate(days = 0) { const value = new Date(); value.setDate(value.getDate() + days); return value.toISOString().slice(0, 10); }
function status(value) { return `<span class="status ${esc(value)}">${esc(String(value).replaceAll("_", " "))}</span>`; }

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
  root.innerHTML = `<main class="activation"><section class="activation-card"><div class="brand-mark">₹</div><p class="eyebrow" style="margin-top:18px">AV Smartbilling Desktop</p><h1>${expired ? "Validate this installation" : "Activate this device"}</h1><p class="muted">Billing data is stored locally in SQLite and works offline. Internet is needed only for activation, periodic validation, cloud backup and restore.</p>${state.license?.error ? `<p class="notice error">${esc(state.license.error)}</p>` : ""}
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
  root.innerHTML = `<div class="shell"><aside class="sidebar" id="sidebar"><div class="logo"><div class="brand-mark" style="width:38px;height:38px;font-size:20px">₹</div><div><strong>AV Smartbilling</strong><small>Offline Billing Desk</small></div></div><nav class="nav">${navItems.map(([id, icon, label]) => `<button data-nav="${id}"><b>${icon}</b>${label}</button>`).join("")}</nav><footer class="side-foot"><p>${esc(state.license.customerName)}</p><small>${esc(state.license.planName)} · Local SQLite</small></footer></aside><div class="body"><header class="topbar"><button class="button secondary mobile-menu" id="mobile-menu">Menu</button><input id="global-filter" class="search" placeholder="Filter this page…"><span class="offline-pill"><span class="dot"></span>Offline ready</span></header><main id="content" class="content"></main></div></div>`;
  root.querySelectorAll("[data-nav]").forEach((button) => button.addEventListener("click", () => navigate(button.dataset.nav)));
  document.getElementById("mobile-menu").addEventListener("click", () => document.getElementById("sidebar").classList.toggle("open"));
  document.getElementById("global-filter").addEventListener("input", (event) => {
    state.query = event.target.value.toLowerCase();
    document.querySelectorAll("[data-filter-row]").forEach((row) => { row.hidden = !row.textContent.toLowerCase().includes(state.query); });
  });
}

function pageHeader(eyebrow, title, description, action = "") {
  return `<header class="page-head"><div><p class="eyebrow">${esc(eyebrow)}</p><h1>${esc(title)}</h1><p class="muted">${esc(description)}</p></div>${action}</header>`;
}

async function navigate(page, detail) {
  state.page = page; state.query = "";
  document.getElementById("global-filter").value = "";
  root.querySelectorAll("[data-nav]").forEach((button) => button.classList.toggle("active", button.dataset.nav === page));
  document.getElementById("sidebar").classList.remove("open");
  const content = document.getElementById("content");
  content.innerHTML = `<div class="loading"><span class="spinner"></span>Loading local data…</div>`;
  try {
    if (page === "dashboard") await renderDashboard(content);
    if (page === "customers") await renderCustomers(content);
    if (page === "customer-form") await renderCustomerForm(content, detail);
    if (page === "products") await renderProducts(content);
    if (page === "product-form") await renderProductForm(content, detail);
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
  document.getElementById("customer-form").addEventListener("submit",async(event)=>{event.preventDefault();if(customer.id&&!await confirmAction("Update customer?","Save these changes to the local customer record?"))return;try{const result=await invoke("billing:save-customer",Object.fromEntries(new FormData(event.currentTarget)));notify(result.message);await navigate("customers");}catch(error){notify(error.message,true);}});
}

async function renderProducts(content) {
  const rows=await invoke("billing:products");
  content.innerHTML=`${pageHeader("Local inventory","Products","Products, prices and stock stored in SQLite.",`<button class="button" id="new-product">Add product</button>`)}<section class="surface">${rows.length?`<div class="table-wrap"><table><thead><tr><th>Product</th><th>SKU</th><th>Price</th><th>Tax</th><th>Stock</th><th>Status</th><th></th></tr></thead><tbody>${rows.map(row=>`<tr data-filter-row><td><b>${esc(row.name)}</b></td><td>${esc(row.sku)}</td><td>${money(row.price_in_paise)}</td><td>${row.tax_rate_basis_points/100}%</td><td>${row.stock_quantity} ${esc(row.unit)}</td><td>${status(row.status)}</td><td class="actions"><button class="link-button" data-edit-product="${esc(row.id)}">Edit</button> <button class="link-button danger-text" data-delete-product="${esc(row.id)}" data-name="${esc(row.name)}">Delete</button></td></tr>`).join("")}</tbody></table></div>`:`<p class="empty">No local products yet.</p>`}</section>`;
  document.getElementById("new-product").addEventListener("click",()=>navigate("product-form"));
  content.querySelectorAll("[data-edit-product]").forEach(button=>button.addEventListener("click",()=>navigate("product-form",rows.find(row=>row.id===button.dataset.editProduct))));
  content.querySelectorAll("[data-delete-product]").forEach(button=>button.addEventListener("click",async()=>{if(!await confirmAction(`Delete ${button.dataset.name}?`,"Products already used on invoices will be archived instead of removed."))return;try{const result=await invoke("billing:delete-product",{id:button.dataset.deleteProduct});notify(result.message);await navigate("products");}catch(error){notify(error.message,true);}}));
}

async function renderProductForm(content, product={}) {
  content.innerHTML=`${pageHeader("Local inventory",product.id?"Edit product":"Add product","Prices are entered in rupees and saved internally as paise.")}<form id="product-form" class="panel form-grid"><input type="hidden" name="id" value="${esc(product.id||"")}">${field("Product name","name",product.name,{required:true})}${field("SKU","sku",product.sku,{required:true})}${field("Price (₹)","price",product.price_in_paise!==undefined?product.price_in_paise/100:"",{type:"number",step:"0.01",min:0,required:true})}${field("Tax rate (%)","taxRate",product.tax_rate_basis_points!==undefined?product.tax_rate_basis_points/100:0,{type:"number",step:"0.01",min:0,required:true})}${field("Stock quantity","stockQuantity",product.stock_quantity??0,{type:"number",step:"0.001",min:0,required:true})}${field("Unit","unit",product.unit||"unit",{required:true})}${field("Description","description",product.description,{textarea:true,full:true})}<label class="field"><span>Status</span><select class="select" name="status"><option value="ACTIVE" ${product.status!=="INACTIVE"?"selected":""}>Active</option><option value="INACTIVE" ${product.status==="INACTIVE"?"selected":""}>Inactive</option></select></label><div class="form-actions field full"><button type="button" class="button secondary" id="cancel">Cancel</button><button class="button">${product.id?"Update product":"Create product"}</button></div></form>`;
  document.getElementById("cancel").addEventListener("click",()=>navigate("products"));
  document.getElementById("product-form").addEventListener("submit",async(event)=>{event.preventDefault();if(product.id&&!await confirmAction("Update product?","Save these product and stock changes locally?"))return;try{const result=await invoke("billing:save-product",Object.fromEntries(new FormData(event.currentTarget)));notify(result.message);await navigate("products");}catch(error){notify(error.message,true);}});
}

async function renderInvoices(content) {
  const rows=await invoke("billing:invoices");content.innerHTML=`${pageHeader("Local sales","Invoices","Create, view and print invoices without internet.",`<button class="button" id="new-invoice">Create invoice</button>`)}<section class="surface">${invoiceTable(rows)}</section>`;document.getElementById("new-invoice").addEventListener("click",()=>navigate("invoice-form"));bindInvoiceLinks(content);
}

async function renderInvoiceForm(content) {
  const [customers,products]=await Promise.all([invoke("billing:customers"),invoke("billing:products")]);
  const activeCustomers=customers.filter(row=>row.status==="ACTIVE"),activeProducts=products.filter(row=>row.status==="ACTIVE"&&row.stock_quantity>0);
  if(!activeProducts.length){content.innerHTML=`${pageHeader("Local invoice","Products required","Add an active product with available stock before creating an invoice.",`<button class="button" id="go-products">Open products</button>`)}`;document.getElementById("go-products").addEventListener("click",()=>navigate("products"));return;}
  const productOptions=(selected="")=>`<option value="">Select product</option>${activeProducts.map(row=>`<option value="${esc(row.id)}" ${selected===row.id?"selected":""}>${esc(row.name)} · ${esc(row.sku)} · ${money(row.price_in_paise)} · Stock ${row.stock_quantity}</option>`).join("")}`;
  content.innerHTML=`${pageHeader("Local invoice","Create invoice","Stock and invoice numbering are updated in one SQLite transaction.")}<form id="invoice-form" class="panel"><div class="form-grid"><label class="field"><span>Customer type</span><select class="select" id="customer-mode"><option value="saved">Saved customer</option><option value="walkin">Walk-in customer</option></select></label><label class="field" id="saved-customer"><span>Customer</span><select class="select" name="customerId"><option value="">Select customer</option>${activeCustomers.map(row=>`<option value="${esc(row.id)}">${esc(row.name)} · ${esc(row.phone)}</option>`).join("")}</select></label><div id="walkin-fields" class="field full" hidden><div class="form-grid">${field("Customer name","walkInName")}${field("Mobile number","walkInPhone")}</div></div>${field("Invoice date","issuedAt",today(),{type:"date",required:true})}${field("Due date","dueAt",inputDate(7),{type:"date"})}${field("Notes","notes","",{textarea:true,full:true})}</div><div class="surface" style="margin-top:22px"><div class="surface-head"><h2>Invoice items</h2><button type="button" class="button secondary" id="add-line">Add line</button></div><div id="invoice-lines" class="invoice-lines" style="padding:16px"></div></div><div id="invoice-preview" class="invoice-total"></div><div class="form-actions"><button type="button" class="button secondary" id="cancel">Cancel</button><button class="button">Create invoice</button></div></form>`;
  const lines=document.getElementById("invoice-lines");
  function addLine(selected="",quantity=1){const wrapper=document.createElement("div");wrapper.className="invoice-line";wrapper.innerHTML=`<select class="select product-select" required>${productOptions(selected)}</select><input class="input quantity" type="number" min="0.001" step="0.001" value="${quantity}" required><button type="button" class="button danger remove-line">×</button>`;lines.append(wrapper);wrapper.querySelector(".remove-line").addEventListener("click",()=>{if(lines.children.length>1){wrapper.remove();preview();}});wrapper.querySelectorAll("select,input").forEach(element=>element.addEventListener("input",preview));}
  function preview(){let subtotal=0,tax=0;lines.querySelectorAll(".invoice-line").forEach(line=>{const product=activeProducts.find(row=>row.id===line.querySelector("select").value);const quantity=Number(line.querySelector("input").value)||0;if(product){const base=Math.round(product.price_in_paise*quantity);subtotal+=base;tax+=Math.round(base*product.tax_rate_basis_points/10000);}});document.getElementById("invoice-preview").innerHTML=`<div><span>Subtotal</span><b>${money(subtotal)}</b></div><div><span>Tax</span><b>${money(tax)}</b></div><div class="grand"><span>Total</span><b>${money(subtotal+tax)}</b></div>`;}
  addLine();preview();document.getElementById("add-line").addEventListener("click",()=>addLine());document.getElementById("cancel").addEventListener("click",()=>navigate("invoices"));document.getElementById("customer-mode").addEventListener("change",event=>{const walkin=event.target.value==="walkin";document.getElementById("walkin-fields").hidden=!walkin;document.getElementById("saved-customer").hidden=walkin;});
  document.getElementById("invoice-form").addEventListener("submit",async(event)=>{event.preventDefault();const form=Object.fromEntries(new FormData(event.currentTarget));const walkin=document.getElementById("customer-mode").value==="walkin";const items=[...lines.querySelectorAll(".invoice-line")].map(line=>({productId:line.querySelector("select").value,quantity:line.querySelector("input").value}));try{const result=await invoke("billing:create-invoice",{...form,customerId:walkin?null:form.customerId,walkInName:walkin?form.walkInName:null,walkInPhone:walkin?form.walkInPhone:null,items});notify(`Invoice ${result.invoiceNumber} created.`);await navigate("invoice-view",result.id);}catch(error){notify(error.message,true);}});
}

async function renderInvoice(content,id){const [invoice,business]=await Promise.all([invoke("billing:invoice",{id}),invoke("billing:settings")]);if(!invoice)throw new Error("Invoice not found.");const balance=invoice.total_in_paise-invoice.paid_in_paise;content.innerHTML=`${pageHeader("Customer invoice",invoice.invoice_number,`${invoice.customer_name} · ${date(invoice.issued_at)}`,`<div class="screen-only"><button class="button secondary" id="back">Back</button> <button class="button" id="print">Print / Save PDF</button></div>`)}<article class="surface invoice-sheet"><div class="invoice-meta"><div><p class="eyebrow">From</p><h2>${esc(business.company_name)}</h2><p class="muted">${esc(business.address)}<br>${esc(business.phone)}${business.gstin?`<br>GSTIN: ${esc(business.gstin)}`:""}</p></div><div><p class="eyebrow">Bill to</p><h2>${esc(invoice.customer_name)}</h2><p class="muted">${esc(invoice.customer_phone)}<br>${esc(invoice.customer_address)}${invoice.customer_gstin?`<br>GSTIN: ${esc(invoice.customer_gstin)}`:""}</p></div></div><div class="table-wrap" style="margin-top:24px"><table><thead><tr><th>Product</th><th>Qty</th><th>Rate</th><th>Tax</th><th>Total</th></tr></thead><tbody>${invoice.items.map(item=>`<tr><td><b>${esc(item.description)}</b><br><small>${esc(item.sku)}</small></td><td>${item.quantity} ${esc(item.unit)}</td><td>${money(item.unit_price_in_paise)}</td><td>${money(item.line_tax_in_paise)}</td><td>${money(item.line_subtotal_in_paise+item.line_tax_in_paise)}</td></tr>`).join("")}</tbody></table></div><div class="invoice-total"><div><span>Subtotal</span><b>${money(invoice.subtotal_in_paise)}</b></div><div><span>Tax</span><b>${money(invoice.tax_in_paise)}</b></div><div class="grand"><span>Total</span><b>${money(invoice.total_in_paise)}</b></div><div><span>Paid</span><b>${money(invoice.paid_in_paise)}</b></div><div><span>Balance</span><b>${money(balance)}</b></div></div>${invoice.notes?`<p class="muted"><b>Notes:</b> ${esc(invoice.notes)}</p>`:""}${business.invoice_footer?`<p class="muted" style="text-align:center;margin-top:30px">${esc(business.invoice_footer)}</p>`:""}</article>${balance>0?`<div class="screen-only" style="margin-top:18px"><button class="button" id="record-payment">Record payment</button></div>`:""}`;document.getElementById("back").addEventListener("click",()=>navigate("invoices"));document.getElementById("print").addEventListener("click",()=>window.print());document.getElementById("record-payment")?.addEventListener("click",()=>navigate("payment-form",id));}

async function renderPayments(content){const rows=await invoke("billing:payments");content.innerHTML=`${pageHeader("Local receipts","Payments","Payments are reconciled against local invoices.",`<button class="button" id="new-payment">Record payment</button>`)}<section class="surface">${rows.length?`<div class="table-wrap"><table><thead><tr><th>Date</th><th>Invoice</th><th>Customer</th><th>Method</th><th>Reference</th><th>Amount</th></tr></thead><tbody>${rows.map(row=>`<tr data-filter-row><td>${date(row.paid_at)}</td><td>${esc(row.invoice_number)}</td><td>${esc(row.customer_name)}</td><td>${esc(row.method.replaceAll("_"," "))}</td><td>${esc(row.reference||"—")}</td><td><b>${money(row.amount_in_paise)}</b></td></tr>`).join("")}</tbody></table></div>`:`<p class="empty">No local payments yet.</p>`}</section>`;document.getElementById("new-payment").addEventListener("click",()=>navigate("payment-form"));}

async function renderPaymentForm(content,selectedId=""){const invoices=(await invoke("billing:invoices")).filter(row=>!["PAID","CANCELLED"].includes(row.status)&&row.total_in_paise>row.paid_in_paise);if(!invoices.length){content.innerHTML=pageHeader("Local receipts","No unpaid invoices","All invoices are paid or no invoices have been created.");return;}content.innerHTML=`${pageHeader("Local receipt","Record payment","Selecting an invoice fills its outstanding balance automatically.")}<form id="payment-form" class="panel form-grid"><label class="field full"><span>Invoice</span><select class="select" name="invoiceId" id="payment-invoice" required><option value="">Select invoice</option>${invoices.map(row=>`<option value="${esc(row.id)}" data-balance="${(row.total_in_paise-row.paid_in_paise)/100}" ${row.id===selectedId?"selected":""}>${esc(row.invoice_number)} · ${esc(row.customer_name)} · Balance ${money(row.total_in_paise-row.paid_in_paise)}</option>`).join("")}</select></label>${field("Amount (₹)","amount","",{type:"number",step:"0.01",min:0,required:true})}<label class="field"><span>Payment method</span><select class="select" name="method"><option>CASH</option><option>UPI</option><option>CARD</option><option value="BANK_TRANSFER">Bank transfer</option><option>OTHER</option></select></label>${field("Paid date","paidAt",today(),{type:"date",required:true})}${field("Reference","reference")}${field("Notes","notes","",{textarea:true,full:true})}<div class="form-actions field full"><button type="button" id="cancel" class="button secondary">Cancel</button><button class="button">Record payment</button></div></form>`;const select=document.getElementById("payment-invoice"),amount=document.querySelector('[name="amount"]');function fill(){amount.value=select.selectedOptions[0]?.dataset.balance||"";}select.addEventListener("change",fill);if(selectedId)fill();document.getElementById("cancel").addEventListener("click",()=>navigate("payments"));document.getElementById("payment-form").addEventListener("submit",async event=>{event.preventDefault();try{const result=await invoke("billing:record-payment",Object.fromEntries(new FormData(event.currentTarget)));notify(result.message);await navigate("payments");}catch(error){notify(error.message,true);}});}

async function renderReports(content){const data=await invoke("billing:reports");const max=Math.max(...data.monthly.map(row=>row.sales),1);content.innerHTML=`${pageHeader("Local analytics","Reports","Calculated entirely from this computer's SQLite data.")}<section class="cards"><article class="card"><small>Total sales</small><strong>${money(data.totals.sales)}</strong></article><article class="card"><small>Received</small><strong>${money(data.totals.received)}</strong></article><article class="card"><small>Outstanding</small><strong>${money(data.totals.outstanding)}</strong></article><article class="card"><small>Invoices</small><strong>${data.totals.invoices}</strong></article></section><section class="surface"><div class="surface-head"><h2>Monthly sales</h2></div>${data.monthly.length?`<div style="padding:22px">${data.monthly.map(row=>`<div style="display:grid;grid-template-columns:90px 1fr 130px;gap:12px;align-items:center;margin:13px 0"><b>${esc(row.month)}</b><span style="height:12px;background:var(--soft)"><i style="display:block;width:${Math.max(2,row.sales/max*100)}%;height:100%;background:var(--brand)"></i></span><strong>${money(row.sales)}</strong></div>`).join("")}</div>`:`<p class="empty">No sales data yet.</p>`}</section>`;}

async function renderSettings(content){const business=await invoke("billing:settings");content.innerHTML=`${pageHeader("This computer","Settings","Business configuration and optional encrypted cloud migration.")}<form id="settings-form" class="panel form-grid">${field("Business name","companyName",business.company_name,{required:true})}${field("Contact person","contactPerson",business.contact_person)}${field("Email","email",business.email,{type:"email"})}${field("Phone","phone",business.phone)}${field("GSTIN","gstin",business.gstin)}${field("Invoice prefix","invoicePrefix",business.invoice_prefix,{required:true})}${field("Low-stock threshold","lowStockThreshold",business.low_stock_threshold,{type:"number",step:"0.001",min:0})}${field("Address","address",business.address,{textarea:true,full:true})}${field("Invoice footer","invoiceFooter",business.invoice_footer,{textarea:true,full:true})}<div class="form-actions field full"><button class="button">Save local settings</button></div></form><section class="surface" style="padding:24px"><p class="eyebrow">Optional online migration</p><h2 style="margin-top:7px">Cloud backup and restore</h2><p class="muted">Local SQLite remains the source of truth. Cloud data is encrypted using this license before upload.</p><p class="warning">Restoring replaces the current local billing database. A complete SQLite safety copy is created automatically before replacement.</p><div id="cloud-status" class="notice">Cloud status has not been checked.</div><div class="cloud-grid"><article class="cloud-card"><h3>Backup to cloud</h3><p class="muted">Upload an encrypted snapshot from this computer for transfer or disaster recovery.</p><button class="button" id="cloud-backup">Backup local data</button></article><article class="cloud-card"><h3>Restore from cloud</h3><p class="muted">Download the latest snapshot after activating a replacement computer with the same license.</p><button class="button secondary" id="cloud-restore">Restore to this computer</button></article></div><div class="form-actions"><button class="button secondary" id="validate-license">Validate license online</button></div></section>`;
  document.getElementById("settings-form").addEventListener("submit",async event=>{event.preventDefault();try{const result=await invoke("billing:save-settings",Object.fromEntries(new FormData(event.currentTarget)));notify(result.message);state.business=await invoke("billing:settings");}catch(error){notify(error.message,true);}});
  const cloudStatus=document.getElementById("cloud-status");invoke("cloud:status").then(result=>{cloudStatus.textContent=result.available?`Latest cloud backup: ${date(result.metadata.backedUpAt,true)} from ${result.metadata.deviceName}. ${result.metadata.counts.invoices} invoices, ${result.metadata.counts.products} products.`:"No cloud backup exists for this license yet.";}).catch(error=>{cloudStatus.textContent=`Cloud unavailable: ${error.message}`;cloudStatus.classList.add("error");});
  document.getElementById("cloud-backup").addEventListener("click",async event=>{if(!await confirmAction("Backup local data to cloud?","This will replace the previous cloud backup for this license with the current local data."))return;event.currentTarget.disabled=true;event.currentTarget.textContent="Uploading…";try{const result=await invoke("cloud:backup");notify(result.message||"Encrypted cloud backup completed.");await renderSettings(content);}catch(error){notify(error.message,true);event.currentTarget.disabled=false;event.currentTarget.textContent="Backup local data";}});
  document.getElementById("cloud-restore").addEventListener("click",async event=>{if(!await confirmAction("Replace local data from cloud?","A safety copy will be created first. Current local records will then be replaced by the latest cloud backup."))return;event.currentTarget.disabled=true;event.currentTarget.textContent="Restoring…";try{const result=await invoke("cloud:restore");notify(`${result.message} Safety copy: ${result.backupPath}`);await navigate("dashboard");}catch(error){notify(error.message,true);event.currentTarget.disabled=false;event.currentTarget.textContent="Restore to this computer";}});
  document.getElementById("validate-license").addEventListener("click",async event=>{event.currentTarget.disabled=true;event.currentTarget.textContent="Validating…";try{state.license=await invoke("license:validate");notify(`License valid until ${date(state.license.validUntil,true)}.`);}catch(error){notify(error.message,true);}finally{event.currentTarget.disabled=false;event.currentTarget.textContent="Validate license online";}});
}

boot();
