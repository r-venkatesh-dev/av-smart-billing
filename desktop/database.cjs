/* eslint-disable @typescript-eslint/no-require-imports -- Electron main-process module */
const Database = require("better-sqlite3");
const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const SCHEMA_VERSION = 2;

function now() {
  return new Date().toISOString();
}

function clean(value, max = 500) {
  return String(value ?? "").trim().slice(0, max);
}

function optional(value, max = 500) {
  const result = clean(value, max);
  return result || null;
}

function number(value, fallback = 0) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function requireText(value, label, min = 1, max = 180) {
  const result = clean(value, max);
  if (result.length < min) throw new Error(`${label} is required.`);
  return result;
}

function mobileNumber(value, { required = false, label = "Mobile number" } = {}) {
  const result = String(value ?? "").trim();
  if (!result && !required) return "";
  if (!/^\d{10}$/.test(result)) throw new Error(`${label} must contain exactly 10 digits.`);
  return result;
}

function hasColumn(db, table, column) {
  return db.prepare(`pragma table_info(${table})`).all().some((row) => row.name === column);
}

function addColumn(db, table, definition) {
  const column = definition.trim().split(/\s+/)[0];
  if (!hasColumn(db, table, column)) db.exec(`alter table ${table} add column ${definition}`);
}

function createBillingDatabase(databasePath) {
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });
  const db = new Database(databasePath);
  db.pragma("journal_mode = WAL");
  db.pragma("foreign_keys = ON");
  db.pragma("busy_timeout = 5000");
  db.exec(`
    create table if not exists app_meta (
      key text primary key,
      value text not null
    );
    create table if not exists business (
      id text primary key,
      company_name text not null,
      contact_person text not null default '',
      email text,
      phone text not null default '',
      address text not null default '',
      gstin text,
      currency_code text not null default 'INR',
      invoice_prefix text not null default 'INV',
      next_invoice_number integer not null default 1,
      low_stock_threshold real not null default 5,
      invoice_footer text not null default '',
      updated_at text not null
    );
    create table if not exists customers (
      id text primary key,
      name text not null,
      email text,
      phone text not null default '',
      address text not null default '',
      gstin text,
      status text not null default 'ACTIVE' check(status in ('ACTIVE','INACTIVE')),
      created_at text not null,
      updated_at text not null
    );
    create table if not exists products (
      id text primary key,
      name text not null,
      sku text not null unique,
      description text not null default '',
      unit text not null default 'unit',
      price_in_paise integer not null check(price_in_paise >= 0),
      tax_rate_basis_points integer not null default 0 check(tax_rate_basis_points between 0 and 10000),
      stock_quantity real not null default 0 check(stock_quantity >= 0),
      status text not null default 'ACTIVE' check(status in ('ACTIVE','INACTIVE')),
      created_at text not null,
      updated_at text not null
    );
    create table if not exists invoices (
      id text primary key,
      customer_id text references customers(id) on delete restrict,
      customer_name text not null,
      customer_phone text not null default '',
      customer_email text,
      customer_address text not null default '',
      customer_gstin text,
      invoice_number text not null unique,
      issued_at text not null,
      due_at text,
      status text not null default 'DUE' check(status in ('DUE','PARTIALLY_PAID','PAID','CANCELLED')),
      subtotal_in_paise integer not null,
      tax_in_paise integer not null,
      total_in_paise integer not null,
      notes text not null default '',
      created_at text not null,
      updated_at text not null
    );
    create table if not exists invoice_items (
      id text primary key,
      invoice_id text not null references invoices(id) on delete cascade,
      product_id text references products(id) on delete restrict,
      description text not null,
      sku text not null default '',
      unit text not null default 'unit',
      quantity real not null check(quantity > 0),
      unit_price_in_paise integer not null,
      tax_rate_basis_points integer not null,
      line_subtotal_in_paise integer not null,
      line_tax_in_paise integer not null,
      created_at text not null
    );
    create table if not exists payments (
      id text primary key,
      invoice_id text not null references invoices(id) on delete restrict,
      amount_in_paise integer not null check(amount_in_paise > 0),
      method text not null check(method in ('CASH','CARD','UPI','BANK_TRANSFER','OTHER')),
      reference text,
      paid_at text not null,
      notes text not null default '',
      created_at text not null
    );
    create index if not exists customers_status_name_idx on customers(status, name);
    create index if not exists products_status_name_idx on products(status, name);
    create index if not exists invoices_issued_idx on invoices(issued_at desc);
    create index if not exists payments_paid_idx on payments(paid_at desc);
  `);

  addColumn(db, "products", "barcode text");
  addColumn(db, "products", "category text not null default ''");
  addColumn(db, "products", "hsn_sac text not null default ''");
  addColumn(db, "products", "purchase_price_in_paise integer not null default 0 check(purchase_price_in_paise >= 0)");
  addColumn(db, "products", "low_stock_threshold real");
  addColumn(db, "invoices", "shipping_address text not null default ''");
  addColumn(db, "invoices", "discount_in_paise integer not null default 0 check(discount_in_paise >= 0)");
  addColumn(db, "invoices", "terms text not null default ''");
  addColumn(db, "invoices", "sale_mode text not null default 'INVOICE'");
  addColumn(db, "invoices", "tax_type text not null default 'INTRA_STATE'");
  addColumn(db, "invoice_items", "hsn_sac text not null default ''");
  addColumn(db, "invoice_items", "discount_in_paise integer not null default 0 check(discount_in_paise >= 0)");
  addColumn(db, "invoice_items", "taxable_in_paise integer not null default 0 check(taxable_in_paise >= 0)");
  addColumn(db, "invoice_items", "cgst_in_paise integer not null default 0 check(cgst_in_paise >= 0)");
  addColumn(db, "invoice_items", "sgst_in_paise integer not null default 0 check(sgst_in_paise >= 0)");
  addColumn(db, "invoice_items", "igst_in_paise integer not null default 0 check(igst_in_paise >= 0)");
  addColumn(db, "business", "state_code text not null default ''");
  addColumn(db, "business", "invoice_terms text not null default ''");
  addColumn(db, "business", "thermal_paper_width integer not null default 80");

  db.exec(`
    create unique index if not exists products_barcode_unique_idx on products(barcode) where barcode is not null and barcode <> '';
    create index if not exists products_category_idx on products(category, name);
    create table if not exists product_categories (
      id text primary key,
      name text not null unique collate nocase,
      status text not null default 'ACTIVE' check(status in ('ACTIVE','INACTIVE')),
      created_at text not null,
      updated_at text not null
    );
    create table if not exists stock_movements (
      id text primary key,
      product_id text not null references products(id) on delete restrict,
      movement_type text not null check(movement_type in ('OPENING','PURCHASE','SALE','RETURN','ADJUSTMENT')),
      quantity_change real not null check(quantity_change <> 0),
      quantity_after real not null check(quantity_after >= 0),
      reference_type text,
      reference_id text,
      notes text not null default '',
      created_at text not null
    );
    create index if not exists stock_movements_product_created_idx on stock_movements(product_id, created_at desc);
    create table if not exists held_bills (
      id text primary key,
      label text not null,
      payload text not null,
      created_at text not null,
      updated_at text not null
    );
    insert into app_meta(key, value) values ('schema_version', '${SCHEMA_VERSION}') on conflict(key) do update set value=excluded.value;
  `);
  db.exec(`
    update invoice_items
    set hsn_sac = coalesce((select p.hsn_sac from products p where p.id=invoice_items.product_id), ''),
        taxable_in_paise = line_subtotal_in_paise,
        cgst_in_paise = cast(line_tax_in_paise / 2 as integer),
        sgst_in_paise = line_tax_in_paise - cast(line_tax_in_paise / 2 as integer)
    where taxable_in_paise = 0 and line_subtotal_in_paise > 0 and cgst_in_paise = 0 and sgst_in_paise = 0 and igst_in_paise = 0;
  `);
  db.prepare(`insert into business(id, company_name, updated_at) values ('local-business', 'My Business', ?) on conflict(id) do nothing`).run(now());
  db.prepare(`insert into stock_movements(id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_at)
    select lower(hex(randomblob(4)))||'-'||lower(hex(randomblob(2)))||'-4'||substr(lower(hex(randomblob(2))),2)||'-a'||substr(lower(hex(randomblob(2))),2)||'-'||lower(hex(randomblob(6))),
      p.id,'OPENING',p.stock_quantity,p.stock_quantity,'MIGRATION',null,'Opening balance created during inventory-ledger upgrade',p.created_at
    from products p where p.stock_quantity > 0 and not exists(select 1 from stock_movements sm where sm.product_id=p.id)`).run();

  const listCustomers = db.prepare(`
    select c.*, (select count(*) from invoices i where i.customer_id=c.id) invoice_count
    from customers c order by c.status='ACTIVE' desc, c.name collate nocase
  `);
  const listProducts = db.prepare(`
    select p.*, (select count(*) from invoice_items ii where ii.product_id=p.id) invoice_count
    from products p order by p.status='ACTIVE' desc, p.name collate nocase
  `);

  function getBusiness() {
    return db.prepare("select * from business where id='local-business'").get();
  }

  function dashboard() {
    const business = getBusiness();
    const todayPrefix = new Date().toISOString().slice(0, 10);
    const counts = db.prepare(`select
      (select count(*) from customers where status='ACTIVE') customers,
      (select count(*) from products where status='ACTIVE') products,
      (select count(*) from products where status='ACTIVE' and stock_quantity <= coalesce(low_stock_threshold, ?)) low_stock,
      (select count(*) from invoices) invoices,
      (select coalesce(sum(total_in_paise),0) from invoices where status <> 'CANCELLED') sales,
      (select coalesce(sum(amount_in_paise),0) from payments) received
    `).get(business.low_stock_threshold);
    const today = db.prepare(`select count(*) invoices,coalesce(sum(total_in_paise),0) sales from invoices where status<>'CANCELLED' and substr(issued_at,1,10)=?`).get(todayPrefix);
    const recent = db.prepare(`select i.*, coalesce((select sum(amount_in_paise) from payments p where p.invoice_id=i.id),0) paid_in_paise from invoices i order by issued_at desc limit 8`).all();
    const lowStock = db.prepare(`select id,name,sku,unit,stock_quantity,coalesce(low_stock_threshold,?) threshold from products where status='ACTIVE' and stock_quantity<=coalesce(low_stock_threshold,?) order by stock_quantity asc limit 8`).all(business.low_stock_threshold, business.low_stock_threshold);
    const trend = db.prepare(`select substr(issued_at,1,10) day,coalesce(sum(total_in_paise),0) sales from invoices where status<>'CANCELLED' and issued_at>=? group by substr(issued_at,1,10) order by day`).all(new Date(Date.now() - 6 * 86400000).toISOString().slice(0, 10));
    return { business, counts: { ...counts, outstanding: counts.sales - counts.received }, today, recent, lowStock, trend };
  }

  function saveCustomer(input) {
    const id = clean(input.id) || randomUUID();
    const existing = db.prepare("select created_at from customers where id=?").get(id);
    const timestamp = now();
    const values = {
      id,
      name: requireText(input.name, "Customer name", 2),
      email: optional(input.email, 180),
      phone: mobileNumber(input.phone),
      address: clean(input.address, 500),
      gstin: optional(input.gstin, 15)?.toUpperCase() ?? null,
      status: input.status === "INACTIVE" ? "INACTIVE" : "ACTIVE",
      created_at: existing?.created_at || timestamp,
      updated_at: timestamp,
    };
    db.prepare(`insert into customers(id,name,email,phone,address,gstin,status,created_at,updated_at)
      values(@id,@name,@email,@phone,@address,@gstin,@status,@created_at,@updated_at)
      on conflict(id) do update set name=excluded.name,email=excluded.email,phone=excluded.phone,address=excluded.address,gstin=excluded.gstin,status=excluded.status,updated_at=excluded.updated_at`).run(values);
    return { id, message: existing ? "Customer updated." : "Customer created." };
  }

  function deleteCustomer(id) {
    const used = db.prepare("select count(*) count from invoices where customer_id=?").get(id).count;
    if (used) {
      db.prepare("update customers set status='INACTIVE',updated_at=? where id=?").run(now(), id);
      return { message: "Customer has invoice history and was archived safely." };
    }
    db.prepare("delete from customers where id=?").run(id);
    return { message: "Customer deleted." };
  }

  const saveProduct = db.transaction((input) => {
    const id = clean(input.id) || randomUUID();
    const existing = db.prepare("select * from products where id=?").get(id);
    const timestamp = now();
    const price = Math.round(number(input.price) * 100);
    const purchasePrice = Math.round(number(input.purchasePrice) * 100);
    const tax = Math.round(number(input.taxRate) * 100);
    const stock = number(input.stockQuantity);
    const threshold = input.lowStockThreshold === "" || input.lowStockThreshold === null || input.lowStockThreshold === undefined ? null : number(input.lowStockThreshold);
    if (price < 0 || purchasePrice < 0 || tax < 0 || tax > 10000 || stock < 0 || (threshold !== null && threshold < 0)) throw new Error("Enter valid product price, tax, threshold and stock values.");
    const values = {
      id,
      name: requireText(input.name, "Product name", 2),
      sku: requireText(input.sku, "SKU", 1, 80).toUpperCase(),
      barcode: optional(input.barcode, 80),
      category: clean(input.category, 120),
      hsn_sac: clean(input.hsnSac, 20).toUpperCase(),
      description: clean(input.description, 500),
      unit: requireText(input.unit || "unit", "Unit", 1, 24),
      purchase_price_in_paise: purchasePrice,
      price_in_paise: price,
      tax_rate_basis_points: tax,
      stock_quantity: stock,
      low_stock_threshold: threshold,
      status: input.status === "INACTIVE" ? "INACTIVE" : "ACTIVE",
      created_at: existing?.created_at || timestamp,
      updated_at: timestamp,
    };
    try {
      db.prepare(`insert into products(id,name,sku,barcode,category,hsn_sac,description,unit,purchase_price_in_paise,price_in_paise,tax_rate_basis_points,stock_quantity,low_stock_threshold,status,created_at,updated_at)
        values(@id,@name,@sku,@barcode,@category,@hsn_sac,@description,@unit,@purchase_price_in_paise,@price_in_paise,@tax_rate_basis_points,@stock_quantity,@low_stock_threshold,@status,@created_at,@updated_at)
        on conflict(id) do update set name=excluded.name,sku=excluded.sku,barcode=excluded.barcode,category=excluded.category,hsn_sac=excluded.hsn_sac,description=excluded.description,unit=excluded.unit,purchase_price_in_paise=excluded.purchase_price_in_paise,price_in_paise=excluded.price_in_paise,tax_rate_basis_points=excluded.tax_rate_basis_points,stock_quantity=excluded.stock_quantity,low_stock_threshold=excluded.low_stock_threshold,status=excluded.status,updated_at=excluded.updated_at`).run(values);
    } catch (error) {
      if (String(error.message).includes("products.barcode")) throw new Error("That barcode is already used by another product.");
      if (String(error.message).includes("UNIQUE")) throw new Error("That SKU is already used by another product.");
      throw error;
    }
    const change = stock - number(existing?.stock_quantity);
    if (change !== 0) {
      db.prepare(`insert into stock_movements(id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_at) values(?,?,?,?,?,?,?,?,?)`)
        .run(randomUUID(), id, existing ? "ADJUSTMENT" : "OPENING", change, stock, "PRODUCT", id, existing ? "Stock changed from product editor" : "Opening stock", timestamp);
    }
    return { id, message: existing ? "Product updated." : "Product created." };
  });

  const deleteProduct = db.transaction((id) => {
    const usedByInvoice = db.prepare("select count(*) count from invoice_items where product_id=?").get(id).count;
    if (usedByInvoice) {
      db.prepare("update products set status='INACTIVE',updated_at=? where id=?").run(now(), id);
      return { mode: "archived", message: "Product was removed from the catalogue. Its invoice history remains available." };
    }
    db.prepare("delete from stock_movements where product_id=?").run(id);
    db.prepare("delete from products where id=?").run(id);
    return { mode: "deleted", message: "Product permanently deleted." };
  });

  const createInvoice = db.transaction((input) => {
    const business = getBusiness();
    const timestamp = now();
    let customer = null;
    if (input.customerId) customer = db.prepare("select * from customers where id=? and status='ACTIVE'").get(input.customerId);
    if (input.customerId && !customer) throw new Error("Selected customer is unavailable.");
    const customerName = customer?.name || requireText(input.walkInName, "Walk-in customer name", 2);
    const customerPhone = customer?.phone || mobileNumber(input.walkInPhone, { required: true, label: "Walk-in mobile number" });
    const rows = Array.isArray(input.items) ? input.items : [];
    if (!rows.length) throw new Error("Add at least one product to the invoice.");
    const requested = new Map();
    for (const row of rows) requested.set(clean(row.productId), (requested.get(clean(row.productId)) || 0) + number(row.quantity));
    for (const [productId, quantity] of requested) {
      const product = db.prepare("select name,unit,stock_quantity from products where id=? and status='ACTIVE'").get(productId);
      if (!product || quantity <= 0) throw new Error("Select a valid product and quantity.");
      if (product.stock_quantity < quantity) throw new Error(`Only ${product.stock_quantity} ${product.unit} of ${product.name} is available.`);
    }
    const taxType = input.taxType === "INTER_STATE" ? "INTER_STATE" : "INTRA_STATE";
    const items = rows.map((item) => {
      const product = db.prepare("select * from products where id=? and status='ACTIVE'").get(item.productId);
      const quantity = number(item.quantity);
      if (!product || quantity <= 0) throw new Error("Select a valid product and quantity.");
      const subtotal = Math.round(product.price_in_paise * quantity);
      const discountPercent = Math.min(100, Math.max(0, number(item.discountPercent)));
      const discount = Math.round(subtotal * discountPercent / 100);
      const taxable = subtotal - discount;
      const tax = Math.round(taxable * product.tax_rate_basis_points / 10000);
      const cgst = taxType === "INTRA_STATE" ? Math.floor(tax / 2) : 0;
      const sgst = taxType === "INTRA_STATE" ? tax - cgst : 0;
      const igst = taxType === "INTER_STATE" ? tax : 0;
      return { product, quantity, subtotal, discount, taxable, tax, cgst, sgst, igst };
    });
    const subtotal = items.reduce((sum, item) => sum + item.subtotal, 0);
    const discount = items.reduce((sum, item) => sum + item.discount, 0);
    const tax = items.reduce((sum, item) => sum + item.tax, 0);
    const id = randomUUID();
    const invoiceNumber = `${business.invoice_prefix}-${String(business.next_invoice_number).padStart(6, "0")}`;
    const issuedAt = input.issuedAt ? new Date(input.issuedAt).toISOString() : timestamp;
    const dueAt = input.dueAt ? new Date(input.dueAt).toISOString() : null;
    db.prepare(`insert into invoices(id,customer_id,customer_name,customer_phone,customer_email,customer_address,customer_gstin,shipping_address,invoice_number,issued_at,due_at,status,subtotal_in_paise,discount_in_paise,tax_in_paise,total_in_paise,notes,terms,sale_mode,tax_type,created_at,updated_at)
      values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(id, customer?.id || null, customerName, customerPhone, customer?.email || null, customer?.address || "", customer?.gstin || null, clean(input.shippingAddress || customer?.address, 500), invoiceNumber, issuedAt, dueAt, "DUE", subtotal, discount, tax, subtotal - discount + tax, clean(input.notes, 1000), clean(input.terms || business.invoice_terms, 1500), input.saleMode === "POS" ? "POS" : "INVOICE", taxType, timestamp, timestamp);
    const insertItem = db.prepare(`insert into invoice_items(id,invoice_id,product_id,description,sku,hsn_sac,unit,quantity,unit_price_in_paise,tax_rate_basis_points,discount_in_paise,taxable_in_paise,cgst_in_paise,sgst_in_paise,igst_in_paise,line_subtotal_in_paise,line_tax_in_paise,created_at) values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`);
    const reduceStock = db.prepare("update products set stock_quantity=stock_quantity-?,updated_at=? where id=?");
    for (const item of items) {
      insertItem.run(randomUUID(), id, item.product.id, item.product.name, item.product.sku, item.product.hsn_sac, item.product.unit, item.quantity, item.product.price_in_paise, item.product.tax_rate_basis_points, item.discount, item.taxable, item.cgst, item.sgst, item.igst, item.subtotal, item.tax, timestamp);
      reduceStock.run(item.quantity, timestamp, item.product.id);
      const quantityAfter = db.prepare("select stock_quantity from products where id=?").get(item.product.id).stock_quantity;
      db.prepare(`insert into stock_movements(id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_at) values(?,?,?,?,?,?,?,?,?)`)
        .run(randomUUID(), item.product.id, "SALE", -item.quantity, quantityAfter, "INVOICE", id, invoiceNumber, timestamp);
    }
    db.prepare("update business set next_invoice_number=next_invoice_number+1,updated_at=? where id='local-business'").run(timestamp);
    return { id, invoiceNumber, totalInPaise: subtotal - discount + tax };
  });

  function listInvoices() {
    return db.prepare(`select i.*,coalesce((select sum(amount_in_paise) from payments p where p.invoice_id=i.id),0) paid_in_paise from invoices i order by issued_at desc`).all();
  }

  function getInvoice(id) {
    const invoice = db.prepare(`select i.*,coalesce((select sum(amount_in_paise) from payments p where p.invoice_id=i.id),0) paid_in_paise from invoices i where id=?`).get(id);
    if (!invoice) return null;
    invoice.items = db.prepare("select * from invoice_items where invoice_id=? order by created_at").all(id);
    invoice.payments = db.prepare("select * from payments where invoice_id=? order by paid_at desc").all(id);
    return invoice;
  }

  const recordPayment = db.transaction((input) => {
    const invoice = getInvoice(input.invoiceId);
    if (!invoice || ["PAID", "CANCELLED"].includes(invoice.status)) throw new Error("Select an unpaid invoice.");
    const amount = Math.round(number(input.amount) * 100);
    const balance = invoice.total_in_paise - invoice.paid_in_paise;
    if (amount <= 0 || amount > balance) throw new Error("Payment must be greater than zero and cannot exceed the invoice balance.");
    const method = ["CASH", "CARD", "UPI", "BANK_TRANSFER", "OTHER"].includes(input.method) ? input.method : "CASH";
    const timestamp = now();
    const id = randomUUID();
    db.prepare("insert into payments(id,invoice_id,amount_in_paise,method,reference,paid_at,notes,created_at) values(?,?,?,?,?,?,?,?)").run(id, invoice.id, amount, method, optional(input.reference, 120), input.paidAt ? new Date(input.paidAt).toISOString() : timestamp, clean(input.notes, 500), timestamp);
    db.prepare("update invoices set status=?,updated_at=? where id=?").run(amount === balance ? "PAID" : "PARTIALLY_PAID", timestamp, invoice.id);
    return { id, message: "Payment recorded." };
  });

  function listPayments() {
    return db.prepare(`select p.*,i.invoice_number,i.customer_name,i.total_in_paise from payments p join invoices i on i.id=p.invoice_id order by p.paid_at desc`).all();
  }

  const createPosSale = db.transaction((input) => {
    const invoice = createInvoice({ ...input, saleMode: "POS", dueAt: null });
    const method = ["CASH", "CARD", "UPI", "BANK_TRANSFER", "OTHER", "CREDIT"].includes(input.paymentMethod) ? input.paymentMethod : "CASH";
    const receivedInPaise = Math.round(number(input.amountReceived) * 100);
    let payment = null;
    if (method !== "CREDIT") {
      const amountInPaise = Math.min(invoice.totalInPaise, receivedInPaise || invoice.totalInPaise);
      if (amountInPaise <= 0) throw new Error("Enter the amount received for this sale.");
      payment = recordPayment({ invoiceId: invoice.id, amount: amountInPaise / 100, method, reference: input.reference, notes: "POS checkout" });
    }
    return { ...invoice, payment, changeInPaise: method === "CASH" ? Math.max(0, receivedInPaise - invoice.totalInPaise) : 0 };
  });

  function holdBill(input) {
    const items = Array.isArray(input.items) ? input.items.filter((item) => clean(item.productId) && number(item.quantity) > 0) : [];
    if (!items.length) throw new Error("Add at least one product before holding the bill.");
    const id = clean(input.id) || randomUUID();
    const timestamp = now();
    const existing = db.prepare("select created_at from held_bills where id=?").get(id);
    db.prepare(`insert into held_bills(id,label,payload,created_at,updated_at) values(?,?,?,?,?)
      on conflict(id) do update set label=excluded.label,payload=excluded.payload,updated_at=excluded.updated_at`)
      .run(id, clean(input.label, 100) || `Held bill ${new Date().toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })}`, JSON.stringify({ ...input, id, items }), existing?.created_at || timestamp, timestamp);
    return { id, message: "Bill held safely on this computer." };
  }

  function listHeldBills() {
    return db.prepare("select id,label,payload,created_at,updated_at from held_bills order by updated_at desc").all().map((row) => ({ ...row, payload: JSON.parse(row.payload) }));
  }

  function deleteHeldBill(id) {
    db.prepare("delete from held_bills where id=?").run(clean(id));
    return { message: "Held bill removed." };
  }

  const adjustStock = db.transaction((input) => {
    const product = db.prepare("select * from products where id=?").get(clean(input.productId));
    if (!product) throw new Error("Product not found.");
    const movementType = ["PURCHASE", "RETURN", "ADJUSTMENT"].includes(input.movementType) ? input.movementType : "ADJUSTMENT";
    let change = number(input.quantity);
    if (movementType === "ADJUSTMENT") change = number(input.quantity) - product.stock_quantity;
    if (movementType !== "ADJUSTMENT" && change <= 0) throw new Error("Quantity must be greater than zero.");
    const quantityAfter = product.stock_quantity + change;
    if (quantityAfter < 0) throw new Error("Stock cannot become negative.");
    const timestamp = now();
    db.prepare("update products set stock_quantity=?,updated_at=? where id=?").run(quantityAfter, timestamp, product.id);
    db.prepare(`insert into stock_movements(id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_at) values(?,?,?,?,?,?,?,?,?)`)
      .run(randomUUID(), product.id, movementType, change, quantityAfter, movementType, optional(input.reference, 120), clean(input.notes, 500), timestamp);
    return { message: `${product.name} stock updated to ${quantityAfter} ${product.unit}.` };
  });

  function inventory() {
    const business = getBusiness();
    const products = db.prepare(`select *,coalesce(low_stock_threshold,?) effective_low_stock_threshold from products order by name collate nocase`).all(business.low_stock_threshold);
    const movements = db.prepare(`select sm.*,p.name product_name,p.sku,p.unit from stock_movements sm join products p on p.id=sm.product_id order by sm.created_at desc limit 250`).all();
    return { products, movements };
  }

  function generateSku() {
    const prefix = "AV";
    const latest = db.prepare("select sku from products where sku like 'AV-%' order by created_at desc limit 1").get();
    const current = Number(String(latest?.sku || "").split("-").pop()) || 0;
    let candidate = `${prefix}-${String(current + 1).padStart(5, "0")}`;
    while (db.prepare("select 1 from products where sku=?").get(candidate)) candidate = `${prefix}-${String(Number(candidate.slice(3)) + 1).padStart(5, "0")}`;
    return candidate;
  }

  function saveSettings(input) {
    const prefix = requireText(input.invoicePrefix || "INV", "Invoice prefix", 1, 12).toUpperCase();
    if (!/^[A-Z0-9-]+$/.test(prefix)) throw new Error("Invoice prefix can contain only letters, numbers and hyphens.");
    const paperWidth = Number(input.thermalPaperWidth) === 58 ? 58 : 80;
    db.prepare(`update business set company_name=?,contact_person=?,email=?,phone=?,address=?,gstin=?,state_code=?,currency_code='INR',invoice_prefix=?,low_stock_threshold=?,invoice_footer=?,invoice_terms=?,thermal_paper_width=?,updated_at=? where id='local-business'`).run(
      requireText(input.companyName, "Business name", 2), clean(input.contactPerson, 120), optional(input.email, 180), mobileNumber(input.phone), clean(input.address, 500), optional(input.gstin, 15)?.toUpperCase() ?? null, clean(input.stateCode, 2), prefix, Math.max(0, number(input.lowStockThreshold, 5)), clean(input.invoiceFooter, 500), clean(input.invoiceTerms, 1500), paperWidth, now(),
    );
    return { message: "Business settings saved locally." };
  }

  function reports(input = {}) {
    const from = /^\d{4}-\d{2}-\d{2}$/.test(String(input.from || "")) ? `${input.from}T00:00:00.000Z` : "0000-01-01T00:00:00.000Z";
    const to = /^\d{4}-\d{2}-\d{2}$/.test(String(input.to || "")) ? `${input.to}T23:59:59.999Z` : "9999-12-31T23:59:59.999Z";
    if (from > to) throw new Error("The report start date must be before the end date.");
    const monthly = db.prepare(`select substr(issued_at,1,7) month,count(*) invoice_count,sum(total_in_paise) sales from invoices where status<>'CANCELLED' and issued_at between ? and ? group by substr(issued_at,1,7) order by month`).all(from, to);
    const totals = db.prepare(`select coalesce(sum(total_in_paise),0) sales,count(*) invoices from invoices where status<>'CANCELLED' and issued_at between ? and ?`).get(from, to);
    totals.received = db.prepare(`select coalesce(sum(p.amount_in_paise),0) received from payments p join invoices i on i.id=p.invoice_id where p.paid_at between ? and ? and i.status<>'CANCELLED'`).get(from, to).received;
    const outstanding = totals.sales - totals.received;
    const invoices = db.prepare(`select i.invoice_number,i.issued_at,i.customer_name,i.status,i.total_in_paise,coalesce((select sum(amount_in_paise) from payments p where p.invoice_id=i.id),0) paid_in_paise from invoices i where i.status<>'CANCELLED' and i.issued_at between ? and ? order by i.issued_at desc`).all(from, to);
    const paymentMethods = db.prepare(`select p.method,count(*) payment_count,coalesce(sum(p.amount_in_paise),0) amount_in_paise from payments p join invoices i on i.id=p.invoice_id where p.paid_at between ? and ? and i.status<>'CANCELLED' group by p.method order by amount_in_paise desc`).all(from, to);
    return { from, to, monthly, invoices, paymentMethods, totals: { ...totals, outstanding } };
  }

  function exportSnapshot() {
    return {
      version: SCHEMA_VERSION,
      exportedAt: now(),
      business: getBusiness(),
      customers: db.prepare("select * from customers order by created_at").all(),
      products: db.prepare("select * from products order by created_at").all(),
      invoices: db.prepare("select * from invoices order by created_at").all(),
      invoiceItems: db.prepare("select * from invoice_items order by created_at").all(),
      payments: db.prepare("select * from payments order by created_at").all(),
      stockMovements: db.prepare("select * from stock_movements order by created_at").all(),
      productCategories: db.prepare("select * from product_categories order by created_at").all(),
      heldBills: db.prepare("select * from held_bills order by created_at").all(),
    };
  }

  const restoreSnapshot = db.transaction((snapshot) => {
    if (!snapshot || ![1, SCHEMA_VERSION].includes(snapshot.version) || !snapshot.business) throw new Error("This cloud backup format is not supported.");
    db.exec("delete from held_bills; delete from stock_movements; delete from product_categories; delete from payments; delete from invoice_items; delete from invoices; delete from products; delete from customers;");
    const b = snapshot.business;
    db.prepare(`update business set company_name=?,contact_person=?,email=?,phone=?,address=?,gstin=?,state_code=?,currency_code=?,invoice_prefix=?,next_invoice_number=?,low_stock_threshold=?,invoice_footer=?,invoice_terms=?,thermal_paper_width=?,updated_at=? where id='local-business'`).run(clean(b.company_name,180)||"My Business",clean(b.contact_person,120),optional(b.email,180),clean(b.phone,40),clean(b.address,500),optional(b.gstin,15),clean(b.state_code,2),"INR",clean(b.invoice_prefix,12)||"INV",Math.max(1,number(b.next_invoice_number,1)),Math.max(0,number(b.low_stock_threshold,5)),clean(b.invoice_footer,500),clean(b.invoice_terms,1500),number(b.thermal_paper_width)===58?58:80,now());
    const customerStatement = db.prepare(`insert into customers(id,name,email,phone,address,gstin,status,created_at,updated_at) values(@id,@name,@email,@phone,@address,@gstin,@status,@created_at,@updated_at)`);
    for (const row of snapshot.customers || []) customerStatement.run(row);
    const productStatement = db.prepare(`insert into products(id,name,sku,barcode,category,hsn_sac,description,unit,purchase_price_in_paise,price_in_paise,tax_rate_basis_points,stock_quantity,low_stock_threshold,status,created_at,updated_at) values(@id,@name,@sku,@barcode,@category,@hsn_sac,@description,@unit,@purchase_price_in_paise,@price_in_paise,@tax_rate_basis_points,@stock_quantity,@low_stock_threshold,@status,@created_at,@updated_at)`);
    for (const row of snapshot.products || []) productStatement.run({ ...row, barcode: row.barcode || null, category: row.category || "", hsn_sac: row.hsn_sac || "", purchase_price_in_paise: number(row.purchase_price_in_paise), low_stock_threshold: row.low_stock_threshold ?? null });
    const invoiceStatement = db.prepare(`insert into invoices(id,customer_id,customer_name,customer_phone,customer_email,customer_address,customer_gstin,shipping_address,invoice_number,issued_at,due_at,status,subtotal_in_paise,discount_in_paise,tax_in_paise,total_in_paise,notes,terms,sale_mode,tax_type,created_at,updated_at) values(@id,@customer_id,@customer_name,@customer_phone,@customer_email,@customer_address,@customer_gstin,@shipping_address,@invoice_number,@issued_at,@due_at,@status,@subtotal_in_paise,@discount_in_paise,@tax_in_paise,@total_in_paise,@notes,@terms,@sale_mode,@tax_type,@created_at,@updated_at)`);
    for (const row of snapshot.invoices || []) invoiceStatement.run({ ...row, shipping_address: row.shipping_address || "", discount_in_paise: number(row.discount_in_paise), terms: row.terms || "", sale_mode: row.sale_mode || "INVOICE", tax_type: row.tax_type || "INTRA_STATE" });
    const itemStatement = db.prepare(`insert into invoice_items(id,invoice_id,product_id,description,sku,hsn_sac,unit,quantity,unit_price_in_paise,tax_rate_basis_points,discount_in_paise,taxable_in_paise,cgst_in_paise,sgst_in_paise,igst_in_paise,line_subtotal_in_paise,line_tax_in_paise,created_at) values(@id,@invoice_id,@product_id,@description,@sku,@hsn_sac,@unit,@quantity,@unit_price_in_paise,@tax_rate_basis_points,@discount_in_paise,@taxable_in_paise,@cgst_in_paise,@sgst_in_paise,@igst_in_paise,@line_subtotal_in_paise,@line_tax_in_paise,@created_at)`);
    for (const row of snapshot.invoiceItems || []) itemStatement.run({ ...row, hsn_sac: row.hsn_sac || "", discount_in_paise: number(row.discount_in_paise), taxable_in_paise: row.taxable_in_paise ?? Math.max(0, number(row.line_subtotal_in_paise) - number(row.discount_in_paise)), cgst_in_paise: number(row.cgst_in_paise), sgst_in_paise: number(row.sgst_in_paise), igst_in_paise: number(row.igst_in_paise) });
    const paymentStatement = db.prepare(`insert into payments(id,invoice_id,amount_in_paise,method,reference,paid_at,notes,created_at) values(@id,@invoice_id,@amount_in_paise,@method,@reference,@paid_at,@notes,@created_at)`);
    for (const row of snapshot.payments || []) paymentStatement.run(row);
    const categoryStatement = db.prepare(`insert into product_categories(id,name,status,created_at,updated_at) values(@id,@name,@status,@created_at,@updated_at)`);
    for (const row of snapshot.productCategories || []) categoryStatement.run(row);
    const movementStatement = db.prepare(`insert into stock_movements(id,product_id,movement_type,quantity_change,quantity_after,reference_type,reference_id,notes,created_at) values(@id,@product_id,@movement_type,@quantity_change,@quantity_after,@reference_type,@reference_id,@notes,@created_at)`);
    if (snapshot.stockMovements?.length) for (const row of snapshot.stockMovements) movementStatement.run(row);
    else for (const row of snapshot.products || []) if (number(row.stock_quantity) > 0) movementStatement.run({ id: randomUUID(), product_id: row.id, movement_type: "OPENING", quantity_change: number(row.stock_quantity), quantity_after: number(row.stock_quantity), reference_type: "RESTORE", reference_id: null, notes: "Opening balance from legacy backup", created_at: row.created_at || now() });
    const heldStatement = db.prepare(`insert into held_bills(id,label,payload,created_at,updated_at) values(@id,@label,@payload,@created_at,@updated_at)`);
    for (const row of snapshot.heldBills || []) heldStatement.run(row);
    return { message: "Cloud backup restored to this computer." };
  });

  function counts() {
    return {
      customers: db.prepare("select count(*) count from customers").get().count,
      products: db.prepare("select count(*) count from products").get().count,
      invoices: db.prepare("select count(*) count from invoices").get().count,
      payments: db.prepare("select count(*) count from payments").get().count,
      stockMovements: db.prepare("select count(*) count from stock_movements").get().count,
    };
  }

  return {
    path: databasePath,
    dashboard,
    getBusiness,
    listCustomers: () => listCustomers.all(),
    saveCustomer,
    deleteCustomer,
    listProducts: () => listProducts.all(),
    saveProduct,
    deleteProduct,
    createInvoice,
    createPosSale,
    holdBill,
    listHeldBills,
    deleteHeldBill,
    adjustStock,
    inventory,
    generateSku,
    listInvoices,
    getInvoice,
    recordPayment,
    listPayments,
    saveSettings,
    reports,
    exportSnapshot,
    restoreSnapshot,
    counts,
    backup: (target) => db.backup(target),
    close: () => db.close(),
  };
}

module.exports = { createBillingDatabase };
