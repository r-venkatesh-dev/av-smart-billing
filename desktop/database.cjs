/* eslint-disable @typescript-eslint/no-require-imports -- Electron main-process module */
const Database = require("better-sqlite3");
const { randomUUID } = require("node:crypto");
const fs = require("node:fs");
const path = require("node:path");

const SCHEMA_VERSION = 1;

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
    insert into app_meta(key, value) values ('schema_version', '${SCHEMA_VERSION}') on conflict(key) do update set value=excluded.value;
  `);
  db.prepare(`insert into business(id, company_name, updated_at) values ('local-business', 'My Business', ?) on conflict(id) do nothing`).run(now());

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
    const counts = db.prepare(`select
      (select count(*) from customers where status='ACTIVE') customers,
      (select count(*) from products where status='ACTIVE') products,
      (select count(*) from products where status='ACTIVE' and stock_quantity <= ?) low_stock,
      (select count(*) from invoices) invoices,
      (select coalesce(sum(total_in_paise),0) from invoices where status <> 'CANCELLED') sales,
      (select coalesce(sum(amount_in_paise),0) from payments) received
    `).get(business.low_stock_threshold);
    const recent = db.prepare(`select i.*, coalesce((select sum(amount_in_paise) from payments p where p.invoice_id=i.id),0) paid_in_paise from invoices i order by issued_at desc limit 8`).all();
    return { business, counts, recent };
  }

  function saveCustomer(input) {
    const id = clean(input.id) || randomUUID();
    const existing = db.prepare("select created_at from customers where id=?").get(id);
    const timestamp = now();
    const values = {
      id,
      name: requireText(input.name, "Customer name", 2),
      email: optional(input.email, 180),
      phone: clean(input.phone, 40),
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

  function saveProduct(input) {
    const id = clean(input.id) || randomUUID();
    const existing = db.prepare("select created_at from products where id=?").get(id);
    const timestamp = now();
    const price = Math.round(number(input.price) * 100);
    const tax = Math.round(number(input.taxRate) * 100);
    const stock = number(input.stockQuantity);
    if (price < 0 || tax < 0 || tax > 10000 || stock < 0) throw new Error("Enter valid product price, tax and stock values.");
    const values = {
      id,
      name: requireText(input.name, "Product name", 2),
      sku: requireText(input.sku, "SKU", 1, 80).toUpperCase(),
      description: clean(input.description, 500),
      unit: requireText(input.unit || "unit", "Unit", 1, 24),
      price_in_paise: price,
      tax_rate_basis_points: tax,
      stock_quantity: stock,
      status: input.status === "INACTIVE" ? "INACTIVE" : "ACTIVE",
      created_at: existing?.created_at || timestamp,
      updated_at: timestamp,
    };
    try {
      db.prepare(`insert into products(id,name,sku,description,unit,price_in_paise,tax_rate_basis_points,stock_quantity,status,created_at,updated_at)
        values(@id,@name,@sku,@description,@unit,@price_in_paise,@tax_rate_basis_points,@stock_quantity,@status,@created_at,@updated_at)
        on conflict(id) do update set name=excluded.name,sku=excluded.sku,description=excluded.description,unit=excluded.unit,price_in_paise=excluded.price_in_paise,tax_rate_basis_points=excluded.tax_rate_basis_points,stock_quantity=excluded.stock_quantity,status=excluded.status,updated_at=excluded.updated_at`).run(values);
    } catch (error) {
      if (String(error.message).includes("UNIQUE")) throw new Error("That SKU is already used by another product.");
      throw error;
    }
    return { id, message: existing ? "Product updated." : "Product created." };
  }

  function deleteProduct(id) {
    const used = db.prepare("select count(*) count from invoice_items where product_id=?").get(id).count;
    if (used) {
      db.prepare("update products set status='INACTIVE',updated_at=? where id=?").run(now(), id);
      return { message: "Product has invoice history and was archived safely." };
    }
    db.prepare("delete from products where id=?").run(id);
    return { message: "Product deleted." };
  }

  const createInvoice = db.transaction((input) => {
    const business = getBusiness();
    const timestamp = now();
    let customer = null;
    if (input.customerId) customer = db.prepare("select * from customers where id=? and status='ACTIVE'").get(input.customerId);
    if (input.customerId && !customer) throw new Error("Selected customer is unavailable.");
    const customerName = customer?.name || requireText(input.walkInName, "Walk-in customer name", 2);
    const customerPhone = customer?.phone || requireText(input.walkInPhone, "Walk-in mobile number", 5, 40);
    const rows = Array.isArray(input.items) ? input.items : [];
    if (!rows.length) throw new Error("Add at least one product to the invoice.");
    const items = rows.map((item) => {
      const product = db.prepare("select * from products where id=? and status='ACTIVE'").get(item.productId);
      const quantity = number(item.quantity);
      if (!product || quantity <= 0) throw new Error("Select a valid product and quantity.");
      if (product.stock_quantity < quantity) throw new Error(`Only ${product.stock_quantity} ${product.unit} of ${product.name} is available.`);
      const subtotal = Math.round(product.price_in_paise * quantity);
      const tax = Math.round(subtotal * product.tax_rate_basis_points / 10000);
      return { product, quantity, subtotal, tax };
    });
    const subtotal = items.reduce((sum, item) => sum + item.subtotal, 0);
    const tax = items.reduce((sum, item) => sum + item.tax, 0);
    const id = randomUUID();
    const invoiceNumber = `${business.invoice_prefix}-${String(business.next_invoice_number).padStart(6, "0")}`;
    const issuedAt = input.issuedAt ? new Date(input.issuedAt).toISOString() : timestamp;
    const dueAt = input.dueAt ? new Date(input.dueAt).toISOString() : null;
    db.prepare(`insert into invoices(id,customer_id,customer_name,customer_phone,customer_email,customer_address,customer_gstin,invoice_number,issued_at,due_at,status,subtotal_in_paise,tax_in_paise,total_in_paise,notes,created_at,updated_at)
      values(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`).run(id, customer?.id || null, customerName, customerPhone, customer?.email || null, customer?.address || "", customer?.gstin || null, invoiceNumber, issuedAt, dueAt, "DUE", subtotal, tax, subtotal + tax, clean(input.notes, 1000), timestamp, timestamp);
    const insertItem = db.prepare(`insert into invoice_items(id,invoice_id,product_id,description,sku,unit,quantity,unit_price_in_paise,tax_rate_basis_points,line_subtotal_in_paise,line_tax_in_paise,created_at) values(?,?,?,?,?,?,?,?,?,?,?,?)`);
    const reduceStock = db.prepare("update products set stock_quantity=stock_quantity-?,updated_at=? where id=?");
    for (const item of items) {
      insertItem.run(randomUUID(), id, item.product.id, item.product.name, item.product.sku, item.product.unit, item.quantity, item.product.price_in_paise, item.product.tax_rate_basis_points, item.subtotal, item.tax, timestamp);
      reduceStock.run(item.quantity, timestamp, item.product.id);
    }
    db.prepare("update business set next_invoice_number=next_invoice_number+1,updated_at=? where id='local-business'").run(timestamp);
    return { id, invoiceNumber };
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

  function saveSettings(input) {
    const prefix = requireText(input.invoicePrefix || "INV", "Invoice prefix", 1, 12).toUpperCase();
    if (!/^[A-Z0-9-]+$/.test(prefix)) throw new Error("Invoice prefix can contain only letters, numbers and hyphens.");
    db.prepare(`update business set company_name=?,contact_person=?,email=?,phone=?,address=?,gstin=?,currency_code='INR',invoice_prefix=?,low_stock_threshold=?,invoice_footer=?,updated_at=? where id='local-business'`).run(
      requireText(input.companyName, "Business name", 2), clean(input.contactPerson, 120), optional(input.email, 180), clean(input.phone, 40), clean(input.address, 500), optional(input.gstin, 15)?.toUpperCase() ?? null, prefix, Math.max(0, number(input.lowStockThreshold, 5)), clean(input.invoiceFooter, 500), now(),
    );
    return { message: "Business settings saved locally." };
  }

  function reports() {
    const monthly = db.prepare(`select substr(issued_at,1,7) month,count(*) invoice_count,sum(total_in_paise) sales from invoices where status<>'CANCELLED' group by substr(issued_at,1,7) order by month desc limit 12`).all().reverse();
    const totals = db.prepare(`select coalesce(sum(total_in_paise),0) sales,(select coalesce(sum(amount_in_paise),0) from payments) received,count(*) invoices from invoices where status<>'CANCELLED'`).get();
    const outstanding = totals.sales - totals.received;
    return { monthly, totals: { ...totals, outstanding } };
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
    };
  }

  const restoreSnapshot = db.transaction((snapshot) => {
    if (!snapshot || snapshot.version !== SCHEMA_VERSION || !snapshot.business) throw new Error("This cloud backup format is not supported.");
    db.exec("delete from payments; delete from invoice_items; delete from invoices; delete from products; delete from customers;");
    const b = snapshot.business;
    db.prepare(`update business set company_name=?,contact_person=?,email=?,phone=?,address=?,gstin=?,currency_code=?,invoice_prefix=?,next_invoice_number=?,low_stock_threshold=?,invoice_footer=?,updated_at=? where id='local-business'`).run(clean(b.company_name,180)||"My Business",clean(b.contact_person,120),optional(b.email,180),clean(b.phone,40),clean(b.address,500),optional(b.gstin,15),"INR",clean(b.invoice_prefix,12)||"INV",Math.max(1,number(b.next_invoice_number,1)),Math.max(0,number(b.low_stock_threshold,5)),clean(b.invoice_footer,500),now());
    const customerStatement = db.prepare(`insert into customers(id,name,email,phone,address,gstin,status,created_at,updated_at) values(@id,@name,@email,@phone,@address,@gstin,@status,@created_at,@updated_at)`);
    for (const row of snapshot.customers || []) customerStatement.run(row);
    const productStatement = db.prepare(`insert into products(id,name,sku,description,unit,price_in_paise,tax_rate_basis_points,stock_quantity,status,created_at,updated_at) values(@id,@name,@sku,@description,@unit,@price_in_paise,@tax_rate_basis_points,@stock_quantity,@status,@created_at,@updated_at)`);
    for (const row of snapshot.products || []) productStatement.run(row);
    const invoiceStatement = db.prepare(`insert into invoices(id,customer_id,customer_name,customer_phone,customer_email,customer_address,customer_gstin,invoice_number,issued_at,due_at,status,subtotal_in_paise,tax_in_paise,total_in_paise,notes,created_at,updated_at) values(@id,@customer_id,@customer_name,@customer_phone,@customer_email,@customer_address,@customer_gstin,@invoice_number,@issued_at,@due_at,@status,@subtotal_in_paise,@tax_in_paise,@total_in_paise,@notes,@created_at,@updated_at)`);
    for (const row of snapshot.invoices || []) invoiceStatement.run(row);
    const itemStatement = db.prepare(`insert into invoice_items(id,invoice_id,product_id,description,sku,unit,quantity,unit_price_in_paise,tax_rate_basis_points,line_subtotal_in_paise,line_tax_in_paise,created_at) values(@id,@invoice_id,@product_id,@description,@sku,@unit,@quantity,@unit_price_in_paise,@tax_rate_basis_points,@line_subtotal_in_paise,@line_tax_in_paise,@created_at)`);
    for (const row of snapshot.invoiceItems || []) itemStatement.run(row);
    const paymentStatement = db.prepare(`insert into payments(id,invoice_id,amount_in_paise,method,reference,paid_at,notes,created_at) values(@id,@invoice_id,@amount_in_paise,@method,@reference,@paid_at,@notes,@created_at)`);
    for (const row of snapshot.payments || []) paymentStatement.run(row);
    return { message: "Cloud backup restored to this computer." };
  });

  function counts() {
    return {
      customers: db.prepare("select count(*) count from customers").get().count,
      products: db.prepare("select count(*) count from products").get().count,
      invoices: db.prepare("select count(*) count from invoices").get().count,
      payments: db.prepare("select count(*) count from payments").get().count,
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
